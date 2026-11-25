///|
/// Competitive tier names based on conservative score (mu - 3*sigma).
pub fn resolve_tier(conservative_score : Double) -> String {
  if conservative_score < 10.0 {
    "Bronze"
  } else if conservative_score < 20.0 {
    "Silver"
  } else if conservative_score < 30.0 {
    "Gold"
  } else if conservative_score < 40.0 {
    "Platinum"
  } else if conservative_score < 50.0 {
    "Diamond"
  } else {
    "Master"
  }
}

///|
/// A player's entry on the competitive ladder.
pub(all) struct LadderEntry {
  player_id : String
  name : String
  mut rating : @types.Rating
  mut conservative_score : Double
  mut tier : String
  mut rank : Int32
  mut wins : Int32
  mut losses : Int32
  mut draws : Int32
  mut last_active_epoch : Int64
} derive(Eq, Debug)

///|
/// Construct a new LadderEntry for a player.
pub fn LadderEntry::new(
  player_id : String,
  name~ : String = "",
  rating~ : @types.Rating = @types.Rating::default(),
  epoch~ : Int64 = 0,
) -> LadderEntry {
  let display_name = if name == "" { player_id } else { name }
  let score = rating.ordinal()
  let tier = resolve_tier(score)
  {
    player_id,
    name: display_name,
    rating,
    conservative_score: score,
    tier,
    rank: 0,
    wins: 0,
    losses: 0,
    draws: 0,
    last_active_epoch: epoch,
  }
}

///|
/// Competitive leaderboard holding all ranked players.
pub(all) struct Leaderboard {
  entries : Array[LadderEntry]
} derive(Eq, Debug)

///|
/// Create a new empty Leaderboard.
pub fn Leaderboard::new() -> Leaderboard {
  { entries: [], }
}

///|
/// Register a new player to the leaderboard if not already present.
pub fn Leaderboard::register_player(
  self : Leaderboard,
  id : String,
  name~ : String = "",
  rating~ : @types.Rating = @types.Rating::default(),
  epoch~ : Int64 = 0,
) -> Unit {
  for e in self.entries {
    if e.player_id == id {
      return
    }
  }
  self.entries.push(LadderEntry::new(id, name~, rating~, epoch~))
}

///|
/// Find a player's ladder entry by ID.
pub fn Leaderboard::find_entry(self : Leaderboard, id : String) -> LadderEntry? {
  for e in self.entries {
    if e.player_id == id {
      return Some(e)
    }
  }
  None
}

///|
/// Record a match between two players using OpenSkill rating update.
pub fn Leaderboard::record_match(
  self : Leaderboard,
  player_a_id : String,
  player_b_id : String,
  outcome : @types.GameOutcome,
  epoch~ : Int64 = 0,
) -> Bool {
  let entry_a = match self.find_entry(player_a_id) {
    Some(e) => e
    None => return false
  }
  let entry_b = match self.find_entry(player_b_id) {
    Some(e) => e
    None => return false
  }

  // Update ratings via OpenSkill 2-team evaluation
  let (updated_a, updated_b) = @openskill.rate_2teams(
    [entry_a.rating],
    [entry_b.rating],
    outcome,
  )

  entry_a.rating = updated_a[0]
  entry_a.conservative_score = entry_a.rating.ordinal()
  entry_a.tier = resolve_tier(entry_a.conservative_score)
  entry_a.last_active_epoch = epoch

  entry_b.rating = updated_b[0]
  entry_b.conservative_score = entry_b.rating.ordinal()
  entry_b.tier = resolve_tier(entry_b.conservative_score)
  entry_b.last_active_epoch = epoch

  match outcome {
    Win => {
      entry_a.wins = entry_a.wins + 1
      entry_b.losses = entry_b.losses + 1
    }
    Loss => {
      entry_a.losses = entry_a.losses + 1
      entry_b.wins = entry_b.wins + 1
    }
    Draw => {
      entry_a.draws = entry_a.draws + 1
      entry_b.draws = entry_b.draws + 1
    }
  }

  true
}

///|
/// Sort all entries by conservative score in descending order and assign ranks.
pub fn Leaderboard::sort_and_rank(self : Leaderboard) -> Array[LadderEntry] {
  // Sort descending by conservative_score
  let n = self.entries.length()
  for i in 0..<n {
    for j in 0..<(n - 1 - i) {
      if self.entries[j].conservative_score <
        self.entries[j + 1].conservative_score {
        let temp = self.entries[j]
        self.entries[j] = self.entries[j + 1]
        self.entries[j + 1] = temp
      }
    }
  }

  for i in 0..<n {
    self.entries[i].rank = i + 1
  }

  self.entries
}

///|
/// Apply rating uncertainty decay (inflation of sigma) to inactive players.
pub fn Leaderboard::apply_inactivity_decay(
  self : Leaderboard,
  current_epoch : Int64,
  inactive_threshold~ : Int64 = 604800, // 7 days in seconds
  decay_sigma_increase~ : Double = 0.5,
) -> Unit {
  for e in self.entries {
    let inactive_duration = current_epoch - e.last_active_epoch
    if inactive_duration >= inactive_threshold {
      let new_sigma = e.rating.sigma + decay_sigma_increase
      let max_sigma = 25.0 / 3.0
      let capped_sigma = if new_sigma > max_sigma {
        max_sigma
      } else {
        new_sigma
      }
      e.rating = @types.Rating::new(e.rating.mu, capped_sigma)
      e.conservative_score = e.rating.ordinal()
      e.tier = resolve_tier(e.conservative_score)
    }
  }
}

///|
/// Render a clean ASCII formatted leaderboard table.
pub fn Leaderboard::render_ascii_table(
  self : Leaderboard,
  limit~ : Int32 = 10,
) -> String {
  let ranked = self.sort_and_rank()
  let count = if ranked.length() < limit { ranked.length() } else { limit }

  let mut s = "Rank | Name            | Tier     | Score    | Mu / Sigma      | Record\n"
  s = s +
    "-----+-----------------+----------+----------+-----------------+--------\n"

  for i in 0..<count {
    let e = ranked[i]
    let rank_str = e.rank.to_string()
    let score_str = e.conservative_score.to_string()
    let mu_str = e.rating.mu.to_string()
    let sigma_str = e.rating.sigma.to_string()
    let record_str = e.wins.to_string() +
      "W/" +
      e.losses.to_string() +
      "L/" +
      e.draws.to_string() +
      "D"

    s = s +
      rank_str +
      "    | " +
      e.name +
      " | " +
      e.tier +
      " | " +
      score_str +
      " | " +
      mu_str +
      " / " +
      sigma_str +
      " | " +
      record_str +
      "\n"
  }
  s
}

// -----------------------------------------------------------------------------
// Season Lifecycle & Soft Reset
// -----------------------------------------------------------------------------

///|
/// Execute a seasonal soft reset across the entire leaderboard:
/// mu' = alpha * mu + (1 - alpha) * 25.0
/// sigma' = min(sqrt(sigma^2 + 4.0), 25.0 / 3.0)
pub fn Leaderboard::soft_reset_season(
  self : Leaderboard,
  alpha~ : Double = 0.75,
) -> Unit {
  let default_mu = 25.0
  let max_sigma = 25.0 / 3.0

  for e in self.entries {
    let new_mu = alpha * e.rating.mu + (1.0 - alpha) * default_mu
    let raw_sigma = (e.rating.sigma * e.rating.sigma + 4.0).sqrt()
    let new_sigma = if raw_sigma > max_sigma { max_sigma } else { raw_sigma }

    e.rating = @types.Rating::new(new_mu, new_sigma)
    e.conservative_score = e.rating.ordinal()
    e.tier = resolve_tier(e.conservative_score)
    e.wins = 0
    e.losses = 0
    e.draws = 0
  }
  let _ = self.sort_and_rank()
}

// -----------------------------------------------------------------------------
// Placement Match Tracker & Demotion Protection
// -----------------------------------------------------------------------------

///|
/// Tracks provisional placement status for competitive players.
pub(all) struct PlacementTracker {
  provisional_threshold : Int32
  records : Array[(String, Int32)]
} derive(Eq, Debug)

///|
/// Construct a PlacementTracker.
pub fn PlacementTracker::new(threshold~ : Int32 = 5) -> PlacementTracker {
  { provisional_threshold: threshold, records: [], }
}

///|
/// Check if a player is still in provisional placement matches.
pub fn PlacementTracker::is_provisional(
  self : PlacementTracker,
  player_id : String,
) -> Bool {
  for r in self.records {
    let (id, count) = r
    if id == player_id {
      return count < self.provisional_threshold
    }
  }
  true
}

///|
/// Record a match played and return remaining placement matches.
pub fn PlacementTracker::record_match(
  self : PlacementTracker,
  player_id : String,
) -> Int32 {
  for i = 0; i < self.records.length(); i = i + 1 {
    let (id, count) = self.records[i]
    if id == player_id {
      let new_count = count + 1
      self.records[i] = (id, new_count)
      let rem = self.provisional_threshold - new_count
      return if rem < 0 { 0 } else { rem }
    }
  }
  self.records.push((player_id, 1))
  let rem = self.provisional_threshold - 1
  if rem < 0 {
    0
  } else {
    rem
  }
}

///|
/// Generate Swiss-system tournament pairings for the current round by sorting
/// players by conservative score and pairing adjacent brackets.
pub fn Leaderboard::swiss_pair_round(
  self : Leaderboard,
) -> Array[(LadderEntry, LadderEntry)] {
  let sorted = self.sort_and_rank()
  let pairs : Array[(LadderEntry, LadderEntry)] = []
  let mut i = 0
  while i + 1 < sorted.length() {
    pairs.push((sorted[i], sorted[i + 1]))
    i = i + 2
  }
  pairs
}

///|
/// Tier promotion series tracker (Best-of-N series, e.g. Bo3 or Bo5).
pub(all) struct PromotionSeries {
  player_id : String
  target_tier : String
  wins_required : Int32
  mut wins : Int32
  mut losses : Int32
} derive(Eq, Debug)

///|
/// Create a new PromotionSeries (default Best-of-3 requiring 2 wins).
pub fn PromotionSeries::new(
  player_id : String,
  target_tier : String,
  wins_required~ : Int32 = 2,
) -> PromotionSeries {
  { player_id, target_tier, wins_required, wins: 0, losses: 0, }
}

///|
/// Record a game in the promotion series.
/// Returns Some(true) if promoted, Some(false) if series failed, or None if still in progress.
pub fn PromotionSeries::record_game(
  self : PromotionSeries,
  won : Bool,
) -> Bool? {
  if won {
    self.wins = self.wins + 1
  } else {
    self.losses = self.losses + 1
  }
  if self.wins >= self.wins_required {
    Some(true)
  } else if self.losses >= self.wins_required {
    Some(false)
  } else {
    None
  }
}

// -----------------------------------------------------------------------------
// Visible Division Hierarchy, League Points (LP) Rubber-Banding & Demotion Shield
// -----------------------------------------------------------------------------

///|
/// Visible competitive division state (e.g., Gold II - 65 LP) decoupled from hidden MMR.
pub(all) struct DivisionState {
  player_id : String
  mut tier_index : Int32 // 0=Bronze, 1=Silver, 2=Gold, 3=Platinum, 4=Diamond, 5=Master, 6=Grandmaster, 7=Challenger
  mut subdivision : Int32 // 4 (IV) down to 1 (I); 1 for Master+
  mut league_points : Int32 // 0..100 for standard tiers, uncapped for Master+
  mut demotion_shield_games : Int32
  mut hidden_mmr : Double
} derive(Eq, Debug)

///|
/// Construct a new DivisionState (default Silver IV, 0 LP, hidden_mmr = 1500.0).
pub fn DivisionState::new(
  player_id : String,
  tier_index~ : Int32 = 1,
  subdivision~ : Int32 = 4,
  league_points~ : Int32 = 0,
  hidden_mmr~ : Double = 1500.0,
) -> DivisionState {
  {
    player_id,
    tier_index,
    subdivision,
    league_points,
    demotion_shield_games: 3,
    hidden_mmr,
  }
}

///|
/// Return the canonical tier name for `tier_index`.
pub fn tier_name_from_index(idx : Int32) -> String {
  if idx <= 0 {
    "Bronze"
  } else if idx == 1 {
    "Silver"
  } else if idx == 2 {
    "Gold"
  } else if idx == 3 {
    "Platinum"
  } else if idx == 4 {
    "Diamond"
  } else if idx == 5 {
    "Master"
  } else if idx == 6 {
    "Grandmaster"
  } else {
    "Challenger"
  }
}

///|
/// Format visible rank label (e.g. "Gold II (75 LP)" or "Challenger (420 LP)").
pub fn DivisionState::format_label(self : DivisionState) -> String {
  let tname = tier_name_from_index(self.tier_index)
  if self.tier_index >= 5 {
    tname + " (" + self.league_points.to_string() + " LP)"
  } else {
    let sub_roman = if self.subdivision == 1 {
      "I"
    } else if self.subdivision == 2 {
      "II"
    } else if self.subdivision == 3 {
      "III"
    } else {
      "IV"
    }
    tname + " " + sub_roman + " (" + self.league_points.to_string() + " LP)"
  }
}

///|
/// Compute target baseline MMR corresponding to the player's current visible division.
pub fn DivisionState::expected_division_mmr(self : DivisionState) -> Double {
  let base_tier_mmr = 1100.0 + self.tier_index.to_double() * 300.0
  let sub_offset = (4 - self.subdivision).to_double() * 75.0
  base_tier_mmr + sub_offset
}

///|
/// Calculate rubber-banded LP gain or loss based on the discrepancy between
/// hidden MMR and visible division MMR:
/// When hidden_mmr > expected_division_mmr, player gains more LP (+25..+34) and loses less (-11..-16).
pub fn DivisionState::calculate_lp_delta(
  self : DivisionState,
  outcome : @types.GameOutcome,
  base_gain~ : Int32 = 22,
) -> Int32 {
  let mmr_gap = self.hidden_mmr - self.expected_division_mmr()
  // Each 35 MMR above visible rank adds +1 LP on win and cushions -1 LP on loss
  let bonus = (mmr_gap / 35.0).to_int()
  let clamped_bonus = if bonus > 12 {
    12
  } else if bonus < -10 {
    -10
  } else {
    bonus
  }

  match outcome {
    Win => {
      let gain = base_gain + clamped_bonus
      if gain < 10 {
        10
      } else {
        gain
      }
    }
    Loss => {
      let loss = -(base_gain - clamped_bonus)
      if loss > -8 {
        -8
      } else {
        loss
      }
    }
    Draw => clamped_bonus / 3
  }
}

///|
/// Apply a match result to a player's visible DivisionState, handling automatic
/// subdivision promotions, tier promotions (with 3-game demotion shield), and demotion protection.
pub fn DivisionState::apply_match_outcome(
  self : DivisionState,
  outcome : @types.GameOutcome,
  new_hidden_mmr : Double,
) -> Int32 {
  self.hidden_mmr = new_hidden_mmr
  let delta = self.calculate_lp_delta(outcome)

  // Apex tiers (Master / Grandmaster / Challenger) have uncapped LP
  if self.tier_index >= 5 {
    let next_lp = self.league_points + delta
    if next_lp < 0 {
      if self.demotion_shield_games > 0 {
        self.demotion_shield_games = self.demotion_shield_games - 1
        self.league_points = 0
      } else {
        // Demote to Diamond I (75 LP)
        self.tier_index = 4
        self.subdivision = 1
        self.league_points = 75
      }
    } else {
      self.league_points = next_lp
      if self.league_points >= 500 {
        self.tier_index = 7 // Challenger
      } else if self.league_points >= 250 {
        self.tier_index = 6 // Grandmaster
      } else {
        self.tier_index = 5 // Master
      }
    }
    return delta
  }

  let raw_lp = self.league_points + delta
  if raw_lp >= 100 {
    // Promote subdivision or tier
    let overflow = raw_lp - 100
    if self.subdivision > 1 {
      self.subdivision = self.subdivision - 1
      self.league_points = overflow
      self.demotion_shield_games = 2
    } else {
      self.tier_index = self.tier_index + 1
      self.subdivision = if self.tier_index >= 5 { 1 } else { 4 }
      self.league_points = overflow
      self.demotion_shield_games = 3
    }
  } else if raw_lp < 0 {
    if self.league_points > 0 {
      // Clamp at 0 LP before consuming demotion shield
      self.league_points = 0
    } else if self.demotion_shield_games > 0 {
      self.demotion_shield_games = self.demotion_shield_games - 1
      self.league_points = 0
    } else if self.subdivision < 4 {
      self.subdivision = self.subdivision + 1
      self.league_points = 75
    } else if self.tier_index > 0 {
      self.tier_index = self.tier_index - 1
      self.subdivision = 1
      self.league_points = 75
    } else {
      self.league_points = 0
    }
  } else {
    self.league_points = raw_lp
    if delta > 0 && self.demotion_shield_games < 1 {
      self.demotion_shield_games = 1
    }
  }
  delta
}

// -----------------------------------------------------------------------------
// Historical Leaderboard Snapshots & Climb Trajectory Diffs
// -----------------------------------------------------------------------------

///|
/// Immutable point-in-time snapshot of a player's rank and conservative score.
pub(all) struct PlayerRankSnapshot {
  player_id : String
  rank : Int32
  conservative_score : Double
  mu : Double
  sigma : Double
} derive(Eq, Debug)

///|
/// Rank and score progression delta between two historical leaderboard snapshots.
pub(all) struct RankClimbDiff {
  player_id : String
  old_rank : Int32
  new_rank : Int32
  rank_delta : Int32 // positive means climbed higher (e.g., from #5 to #2 -> +3)
  score_delta : Double
  mu_delta : Double
} derive(Eq, Debug)

///|
/// Capture a sorted snapshot of the current Leaderboard state.
pub fn Leaderboard::take_snapshot(
  self : Leaderboard,
) -> Array[PlayerRankSnapshot] {
  let ranked = self.sort_and_rank()
  let snaps : Array[PlayerRankSnapshot] = []
  for e in ranked {
    snaps.push({
      player_id: e.player_id,
      rank: e.rank,
      conservative_score: e.conservative_score,
      mu: e.rating.mu,
      sigma: e.rating.sigma,
    })
  }
  snaps
}

///|
/// Compare an older snapshot against a newer snapshot and return `RankClimbDiff` records
/// sorted descending by `score_delta` (Most Improved Players first).
pub fn diff_leaderboard_snapshots(
  before : Array[PlayerRankSnapshot],
  after : Array[PlayerRankSnapshot],
) -> Array[RankClimbDiff] {
  let diffs : Array[RankClimbDiff] = []
  for cur in after {
    for prev in before {
      if cur.player_id == prev.player_id {
        diffs.push({
          player_id: cur.player_id,
          old_rank: prev.rank,
          new_rank: cur.rank,
          rank_delta: prev.rank - cur.rank,
          score_delta: cur.conservative_score - prev.conservative_score,
          mu_delta: cur.mu - prev.mu,
        })
        break
      }
    }
  }

  let m = diffs.length()
  for i = 0; i < m; i = i + 1 {
    for j = 0; j < m - 1 - i; j = j + 1 {
      if diffs[j].score_delta < diffs[j + 1].score_delta {
        let tmp = diffs[j]
        diffs[j] = diffs[j + 1]
        diffs[j + 1] = tmp
      }
    }
  }
  diffs
}
