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
