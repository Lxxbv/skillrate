///|
/// Competitive Tournament & Esports Bracket Orchestration Engine.
/// Supports Single-Elimination, Double-Elimination (with Grand Finals Bracket Reset),
/// Round-Robin (Berger Circle Schedule & Sonneborn-Berger Tiebreaks),
/// Multi-Round Swiss System (with Buchholz & Median-Buchholz Tiebreaks),
/// and Monte Carlo Championship Forecast Simulations.

///|
/// A seeded tournament entrant with rating and tiebreak statistics.
pub(all) struct TournamentEntrant {
  id : String
  name : String
  seed : Int32
  mut rating : @types.Rating
  mut points : Double
  mut match_wins : Int32
  mut match_losses : Int32
  mut match_draws : Int32
  mut sonneborn_berger : Double
  mut buchholz : Double
  mut median_buchholz : Double
  opponents_faced : Array[String]
} derive(Eq, Debug)

///|
/// Construct a new TournamentEntrant.
pub fn TournamentEntrant::new(
  id : String,
  name~ : String = "",
  seed~ : Int32 = 1,
  rating~ : @types.Rating = @types.Rating::default(),
) -> TournamentEntrant {
  let display = if name == "" { id } else { name }
  {
    id,
    name: display,
    seed,
    rating,
    points: 0.0,
    match_wins: 0,
    match_losses: 0,
    match_draws: 0,
    sonneborn_berger: 0.0,
    buchholz: 0.0,
    median_buchholz: 0.0,
    opponents_faced: [],
  }
}

///|
/// Check if this entrant has already played against `opponent_id`.
pub fn TournamentEntrant::has_played(
  self : TournamentEntrant,
  opponent_id : String,
) -> Bool {
  for opp in self.opponents_faced {
    if opp == opponent_id {
      return true
    }
  }
  false
}

///|
/// Seed an array of `@types.Player` into sorted `TournamentEntrant` records
/// ordered descending by conservative rating ordinal (mu - 3*sigma).
pub fn seed_entrants_by_rating(
  players : Array[@types.Player],
  z~ : Double = 3.0,
) -> Array[TournamentEntrant] {
  let n = players.length()
  let copy = players.copy()
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n - 1 - i; j = j + 1 {
      if copy[j].rating.ordinal(z~) < copy[j + 1].rating.ordinal(z~) {
        let tmp = copy[j]
        copy[j] = copy[j + 1]
        copy[j + 1] = tmp
      }
    }
  }
  let entrants : Array[TournamentEntrant] = []
  for i = 0; i < n; i = i + 1 {
    let p = copy[i]
    entrants.push(
      TournamentEntrant::new(p.id, name=p.name, seed=i + 1, rating=p.rating),
    )
  }
  entrants
}

// -----------------------------------------------------------------------------
// 1. Single-Elimination Bracket Engine (Power-of-2 Seeding & Bye Advancement)
// -----------------------------------------------------------------------------

///|
/// A single match node inside an elimination bracket.
pub(all) struct BracketMatch {
  match_id : Int32
  round : Int32
  slot_a : String
  slot_b : String
  mut winner : String
  mut loser : String
  mut completed : Bool
  is_bye : Bool
} derive(Eq, Debug)

///|
/// Construct a BracketMatch node.
pub fn BracketMatch::new(
  match_id : Int32,
  round : Int32,
  slot_a : String,
  slot_b : String,
) -> BracketMatch {
  if slot_b == "BYE" && slot_a != "BYE" {
    {
      match_id,
      round,
      slot_a,
      slot_b,
      winner: slot_a,
      loser: "BYE",
      completed: true,
      is_bye: true,
    }
  } else if slot_a == "BYE" && slot_b != "BYE" {
    {
      match_id,
      round,
      slot_a,
      slot_b,
      winner: slot_b,
      loser: "BYE",
      completed: true,
      is_bye: true,
    }
  } else {
    {
      match_id,
      round,
      slot_a,
      slot_b,
      winner: "",
      loser: "",
      completed: false,
      is_bye: false,
    }
  }
}

///|
/// Compute smallest power of two >= n (minimum 2).
pub fn next_power_of_two(n : Int32) -> Int32 {
  let mut p = 2
  while p < n {
    p = p * 2
  }
  p
}

///|
/// Generate canonical tournament bracket seed order of size `bracket_size` (power of 2)
/// so that Seed 1 plays Seed N, Seed 2 plays Seed N-1, and top seeds meet as late as possible.
pub fn generate_fold_seed_order(bracket_size : Int32) -> Array[Int32] {
  let size = next_power_of_two(bracket_size)
  let mut seeds = [1, 2]
  let mut cur_len = 2
  while cur_len < size {
    let next_len = cur_len * 2
    let expanded : Array[Int32] = []
    for s in seeds {
      expanded.push(s)
      expanded.push(next_len + 1 - s)
    }
    seeds = expanded
    cur_len = next_len
  }
  seeds
}

///|
/// Single-Elimination Knockout Tournament state.
pub(all) struct SingleEliminationBracket {
  entrants : Array[TournamentEntrant]
  bracket_size : Int32
  mut current_round : Int32
  rounds : Array[Array[BracketMatch]]
  mut next_match_id : Int32
  mut champion_id : String
} derive(Eq, Debug)

///|
/// Build a seeded SingleEliminationBracket from a list of players.
pub fn SingleEliminationBracket::from_players(
  players : Array[@types.Player],
) -> SingleEliminationBracket {
  let entrants = seed_entrants_by_rating(players)
  let n = entrants.length()
  let bsize = next_power_of_two(if n < 2 { 2 } else { n })
  let seed_order = generate_fold_seed_order(bsize)

  let round1 : Array[BracketMatch] = []
  let mut mid = 1
  let mut idx = 0
  while idx + 1 < seed_order.length() {
    let s1 = seed_order[idx]
    let s2 = seed_order[idx + 1]
    let id1 = if s1 <= n { entrants[s1 - 1].id } else { "BYE" }
    let id2 = if s2 <= n { entrants[s2 - 1].id } else { "BYE" }
    round1.push(BracketMatch::new(mid, 1, id1, id2))
    mid = mid + 1
    idx = idx + 2
  }

  {
    entrants,
    bracket_size: bsize,
    current_round: 1,
    rounds: [round1],
    next_match_id: mid,
    champion_id: "",
  }
}

///|
/// Lookup an entrant's current Rating by ID.
pub fn SingleEliminationBracket::get_rating(
  self : SingleEliminationBracket,
  player_id : String,
) -> @types.Rating {
  for e in self.entrants {
    if e.id == player_id {
      return e.rating
    }
  }
  @types.Rating::default()
}

///|
/// Update an entrant's Rating after a bracket match.
fn SingleEliminationBracket::set_rating(
  self : SingleEliminationBracket,
  player_id : String,
  new_rating : @types.Rating,
  won : Bool,
) -> Unit {
  for e in self.entrants {
    if e.id == player_id {
      e.rating = new_rating
      if won {
        e.match_wins = e.match_wins + 1
        e.points = e.points + 1.0
      } else {
        e.match_losses = e.match_losses + 1
      }
      return
    }
  }
}

///|
/// Record the winner of a match in the current active round and update OpenSkill ratings.
/// When all matches in the current round finish, automatically generates the next round or crowns the champion.
pub fn SingleEliminationBracket::record_match_winner(
  self : SingleEliminationBracket,
  match_id : Int32,
  winner_id : String,
) -> Bool {
  if self.rounds.is_empty() {
    return false
  }
  let cur_matches = self.rounds[self.rounds.length() - 1]
  let mut found = false

  for m in cur_matches {
    if m.match_id == match_id && !m.completed {
      if winner_id != m.slot_a && winner_id != m.slot_b {
        return false
      }
      let loser_id = if winner_id == m.slot_a { m.slot_b } else { m.slot_a }
      m.winner = winner_id
      m.loser = loser_id
      m.completed = true
      found = true

      let r_win = self.get_rating(winner_id)
      let r_lose = self.get_rating(loser_id)
      let (up_w, up_l) = @openskill.rate_2teams(
        [r_win],
        [r_lose],
        @types.GameOutcome::Win,
      )
      self.set_rating(winner_id, up_w[0], true)
      self.set_rating(loser_id, up_l[0], false)
      break
    }
  }

  if !found {
    return false
  }

  // Check if entire round is complete
  let mut all_done = true
  for m in cur_matches {
    if !m.completed {
      all_done = false
      break
    }
  }

  if all_done {
    if cur_matches.length() == 1 {
      self.champion_id = cur_matches[0].winner
    } else {
      let next_r = self.current_round + 1
      let next_matches : Array[BracketMatch] = []
      let mut i = 0
      while i + 1 < cur_matches.length() {
        let w1 = cur_matches[i].winner
        let w2 = cur_matches[i + 1].winner
        next_matches.push(BracketMatch::new(self.next_match_id, next_r, w1, w2))
        self.next_match_id = self.next_match_id + 1
        i = i + 2
      }
      self.current_round = next_r
      self.rounds.push(next_matches)
      if next_matches.length() == 1 && next_matches[0].completed {
        self.champion_id = next_matches[0].winner
      }
    }
  }
  true
}

// -----------------------------------------------------------------------------
// 2. Double-Elimination Tournament Engine (Winners, Losers & Grand Finals Reset)
// -----------------------------------------------------------------------------

///|
/// Double-Elimination tournament state tracking active Winners Bracket (WB),
/// Losers Bracket (LB), and Grand Finals (with Bracket Reset support).
pub(all) struct DoubleEliminationTournament {
  entrants : Array[TournamentEntrant]
  winners_pool : Array[String]
  losers_pool : Array[String]
  eliminated : Array[String]
  completed_matches : Array[BracketMatch]
  mut next_match_id : Int32
  mut bracket_reset_triggered : Bool
  mut champion_id : String
} derive(Eq, Debug)

///|
/// Initialize a DoubleEliminationTournament from a list of players.
pub fn DoubleEliminationTournament::from_players(
  players : Array[@types.Player],
) -> DoubleEliminationTournament {
  let entrants = seed_entrants_by_rating(players)
  let wb : Array[String] = []
  for e in entrants {
    wb.push(e.id)
  }
  {
    entrants,
    winners_pool: wb,
    losers_pool: [],
    eliminated: [],
    completed_matches: [],
    next_match_id: 1,
    bracket_reset_triggered: false,
    champion_id: "",
  }
}

///|
/// Lookup entrant rating in DoubleEliminationTournament.
pub fn DoubleEliminationTournament::get_rating(
  self : DoubleEliminationTournament,
  player_id : String,
) -> @types.Rating {
  for e in self.entrants {
    if e.id == player_id {
      return e.rating
    }
  }
  @types.Rating::default()
}

///|
/// Simulate or resolve one deterministic step of the Double-Elimination tournament
/// using a caller-supplied match resolver `(player_a, player_b) -> winner_id`.
/// Automatically moves Winners Bracket losers to the Losers Bracket, eliminates
/// Losers Bracket losers, and executes the Grand Finals (including a Bracket Reset if the LB champion wins Set 1).
pub fn DoubleEliminationTournament::run_to_completion(
  self : DoubleEliminationTournament,
  decide_winner : (String, String) -> String,
) -> String {
  let mut round_num = 1
  // Advance Winners Bracket and Losers Bracket until 1 remains in each
  while self.winners_pool.length() > 1 || self.losers_pool.length() > 1 {
    // 1. Play Winners Bracket round if more than 1 player in WB
    let newly_dropped : Array[String] = []
    if self.winners_pool.length() > 1 {
      let next_wb : Array[String] = []
      let mut i = 0
      while i + 1 < self.winners_pool.length() {
        let a = self.winners_pool[i]
        let b = self.winners_pool[i + 1]
        let w = decide_winner(a, b)
        let l = if w == a { b } else { a }
        let bm = BracketMatch::new(self.next_match_id, round_num, a, b)
        bm.winner = w
        bm.loser = l
        bm.completed = true
        self.completed_matches.push(bm)
        self.next_match_id = self.next_match_id + 1
        next_wb.push(w)
        newly_dropped.push(l)
        i = i + 2
      }
      if i < self.winners_pool.length() {
        next_wb.push(self.winners_pool[i])
      }
      self.winners_pool.clear()
      for p in next_wb {
        self.winners_pool.push(p)
      }
    }

    for d in newly_dropped {
      self.losers_pool.push(d)
    }

    // 2. Play Losers Bracket survival round if more than 1 player in LB
    if self.losers_pool.length() > 1 {
      let next_lb : Array[String] = []
      let mut j = 0
      while j + 1 < self.losers_pool.length() {
        let a = self.losers_pool[j]
        let b = self.losers_pool[j + 1]
        let w = decide_winner(a, b)
        let l = if w == a { b } else { a }
        let bm = BracketMatch::new(self.next_match_id, round_num, a, b)
        bm.winner = w
        bm.loser = l
        bm.completed = true
        self.completed_matches.push(bm)
        self.next_match_id = self.next_match_id + 1
        next_lb.push(w)
        self.eliminated.push(l)
        j = j + 2
      }
      if j < self.losers_pool.length() {
        next_lb.push(self.losers_pool[j])
      }
      self.losers_pool.clear()
      for p in next_lb {
        self.losers_pool.push(p)
      }
    }

    round_num = round_num + 1
  }

  if self.winners_pool.is_empty() {
    return ""
  }
  if self.losers_pool.is_empty() {
    self.champion_id = self.winners_pool[0]
    return self.champion_id
  }

  // Grand Finals Set 1: unbeaten WB champion vs 1-loss LB champion
  let wb_champ = self.winners_pool[0]
  let lb_champ = self.losers_pool[0]
  let gf1_winner = decide_winner(wb_champ, lb_champ)
  let gf1 = BracketMatch::new(self.next_match_id, round_num, wb_champ, lb_champ)
  gf1.winner = gf1_winner
  gf1.loser = if gf1_winner == wb_champ { lb_champ } else { wb_champ }
  gf1.completed = true
  self.completed_matches.push(gf1)
  self.next_match_id = self.next_match_id + 1

  if gf1_winner == wb_champ {
    self.champion_id = wb_champ
    self.eliminated.push(lb_champ)
  } else {
    // Bracket Reset! Both finalists now have 1 loss; play decisive Grand Finals Set 2
    self.bracket_reset_triggered = true
    let gf2_winner = decide_winner(wb_champ, lb_champ)
    let gf2_loser = if gf2_winner == wb_champ { lb_champ } else { wb_champ }
    let gf2 = BracketMatch::new(
      self.next_match_id,
      round_num + 1,
      wb_champ,
      lb_champ,
    )
    gf2.winner = gf2_winner
    gf2.loser = gf2_loser
    gf2.completed = true
    self.completed_matches.push(gf2)
    self.next_match_id = self.next_match_id + 1
    self.champion_id = gf2_winner
    self.eliminated.push(gf2_loser)
  }

  self.champion_id
}

// -----------------------------------------------------------------------------
// 3. Round-Robin Schedule (Berger Circle Method) & Sonneborn-Berger Tiebreaks
// -----------------------------------------------------------------------------

///|
/// Generate a full Round-Robin tournament schedule of (player_a_id, player_b_id) pairings per round
/// using the official FIDE Berger Circle rotation algorithm.
pub fn generate_round_robin_schedule(
  player_ids : Array[String],
) -> Array[Array[(String, String)]] {
  let n = player_ids.length()
  if n < 2 {
    return []
  }

  let ring : Array[String] = []
  for id in player_ids {
    ring.push(id)
  }
  if n % 2 == 1 {
    ring.push("BYE")
  }

  let m = ring.length()
  let num_rounds = m - 1
  let half = m / 2
  let schedule : Array[Array[(String, String)]] = []

  for r = 0; r < num_rounds; r = r + 1 {
    let round_pairs : Array[(String, String)] = []
    for i = 0; i < half; i = i + 1 {
      let p1 = ring[i]
      let p2 = ring[m - 1 - i]
      if p1 != "BYE" && p2 != "BYE" {
        if r % 2 == 0 {
          round_pairs.push((p1, p2))
        } else {
          round_pairs.push((p2, p1))
        }
      }
    }
    schedule.push(round_pairs)

    // Rotate elements 1..m-1 clockwise while keeping ring[0] fixed
    let last = ring[m - 1]
    let mut k = m - 1
    while k > 1 {
      ring[k] = ring[k - 1]
      k = k - 1
    }
    ring[1] = last
  }

  schedule
}

///|
/// Evaluate a completed Round-Robin league given entrants and recorded matches
/// `(id_a, id_b, outcome_for_a)`.
/// Computes total points, match W/L/D, Sonneborn-Berger tiebreak score
/// (sum of defeated opponents' scores + half of drawn opponents' scores),
/// and returns entrants sorted by (Points, Sonneborn-Berger, Rating Ordinal).
pub fn evaluate_round_robin_standings(
  players : Array[@types.Player],
  results : Array[(String, String, @types.GameOutcome)],
) -> Array[TournamentEntrant] {
  let entrants = seed_entrants_by_rating(players)
  let n = entrants.length()

  // First pass: accumulate raw points and W/L/D
  for res in results {
    let (id_a, id_b, outcome) = res
    let s_a = outcome.to_score()
    let s_b = 1.0 - s_a

    for i = 0; i < n; i = i + 1 {
      if entrants[i].id == id_a {
        entrants[i].points = entrants[i].points + s_a
        entrants[i].opponents_faced.push(id_b)
        match outcome {
          Win => entrants[i].match_wins = entrants[i].match_wins + 1
          Loss => entrants[i].match_losses = entrants[i].match_losses + 1
          Draw => entrants[i].match_draws = entrants[i].match_draws + 1
        }
      } else if entrants[i].id == id_b {
        entrants[i].points = entrants[i].points + s_b
        entrants[i].opponents_faced.push(id_a)
        match outcome {
          Win => entrants[i].match_losses = entrants[i].match_losses + 1
          Loss => entrants[i].match_wins = entrants[i].match_wins + 1
          Draw => entrants[i].match_draws = entrants[i].match_draws + 1
        }
      }
    }
  }

  // Second pass: compute Sonneborn-Berger (Neustadtl) score for every entrant
  for res in results {
    let (id_a, id_b, outcome) = res
    let s_a = outcome.to_score()
    let s_b = 1.0 - s_a

    let mut pts_a = 0.0
    let mut pts_b = 0.0
    for e in entrants {
      if e.id == id_a {
        pts_a = e.points
      } else if e.id == id_b {
        pts_b = e.points
      }
    }

    for i = 0; i < n; i = i + 1 {
      if entrants[i].id == id_a {
        entrants[i].sonneborn_berger = entrants[i].sonneborn_berger +
          s_a * pts_b
      } else if entrants[i].id == id_b {
        entrants[i].sonneborn_berger = entrants[i].sonneborn_berger +
          s_b * pts_a
      }
    }
  }

  // Sort descending by (Points, Sonneborn-Berger, Rating.ordinal)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n - 1 - i; j = j + 1 {
      let a = entrants[j]
      let b = entrants[j + 1]
      let swap = if (a.points - b.points).abs() > 1.0e-6 {
        a.points < b.points
      } else if (a.sonneborn_berger - b.sonneborn_berger).abs() > 1.0e-6 {
        a.sonneborn_berger < b.sonneborn_berger
      } else {
        a.rating.ordinal() < b.rating.ordinal()
      }
      if swap {
        entrants[j] = b
        entrants[j + 1] = a
      }
    }
  }

  entrants
}

// -----------------------------------------------------------------------------
// 4. Multi-Round Swiss-System Tournament Engine (No-Rematch & Buchholz Tiebreaks)
// -----------------------------------------------------------------------------

///|
/// Swiss-System Tournament Manager with strict no-rematch pairing and Buchholz tiebreakers.
pub(all) struct SwissTournament {
  entrants : Array[TournamentEntrant]
  mut current_round : Int32
  total_rounds : Int32
} derive(Eq, Debug)

///|
/// Initialize a SwissTournament from an array of players and target number of rounds.
pub fn SwissTournament::new(
  players : Array[@types.Player],
  total_rounds~ : Int32 = 5,
) -> SwissTournament {
  {
    entrants: seed_entrants_by_rating(players),
    current_round: 0,
    total_rounds,
  }
}

///|
/// Recompute Buchholz (sum of all opponents' points) and Median-Buchholz
/// (Buchholz excluding highest and lowest opponent scores) for all entrants,
/// then sort standings descending by (Points, Buchholz, Median-Buchholz, Rating Ordinal).
pub fn SwissTournament::update_tiebreaks_and_sort(
  self : SwissTournament,
) -> Array[TournamentEntrant] {
  let n = self.entrants.length()

  for i = 0; i < n; i = i + 1 {
    let opp_scores : Array[Double] = []
    let mut sum_bh = 0.0
    for opp_id in self.entrants[i].opponents_faced {
      for j = 0; j < n; j = j + 1 {
        if self.entrants[j].id == opp_id {
          let pts = self.entrants[j].points
          opp_scores.push(pts)
          sum_bh = sum_bh + pts
          break
        }
      }
    }
    self.entrants[i].buchholz = sum_bh

    // Median-Buchholz (Buchholz Cut-1 / Median): drop min and max if >= 3 opponents
    let k = opp_scores.length()
    if k >= 3 {
      let mut min_s = opp_scores[0]
      let mut max_s = opp_scores[0]
      for s in opp_scores {
        if s < min_s {
          min_s = s
        }
        if s > max_s {
          max_s = s
        }
      }
      self.entrants[i].median_buchholz = sum_bh - min_s - max_s
    } else {
      self.entrants[i].median_buchholz = sum_bh
    }
  }

  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n - 1 - i; j = j + 1 {
      let a = self.entrants[j]
      let b = self.entrants[j + 1]
      let swap = if (a.points - b.points).abs() > 1.0e-6 {
        a.points < b.points
      } else if (a.buchholz - b.buchholz).abs() > 1.0e-6 {
        a.buchholz < b.buchholz
      } else if (a.median_buchholz - b.median_buchholz).abs() > 1.0e-6 {
        a.median_buchholz < b.median_buchholz
      } else {
        a.rating.ordinal() < b.rating.ordinal()
      }
      if swap {
        self.entrants[j] = b
        self.entrants[j + 1] = a
      }
    }
  }

  self.entrants
}

///|
/// Generate non-repeating Swiss pairings for the next round.
/// Sorts players by current Swiss standing and greedily pairs each unmatched player
/// with the highest-ranked opponent they have not yet faced.
pub fn SwissTournament::pair_next_round(
  self : SwissTournament,
) -> Array[(String, String)] {
  let _ = self.update_tiebreaks_and_sort()
  let n = self.entrants.length()
  let used = Array::make(n, false)
  let pairs : Array[(String, String)] = []

  for i = 0; i < n; i = i + 1 {
    if used[i] {
      continue
    }
    let mut partner = -1
    // First try to find highest ranked opponent not yet faced
    for j = i + 1; j < n; j = j + 1 {
      if !used[j] && !self.entrants[i].has_played(self.entrants[j].id) {
        partner = j
        break
      }
    }
    // Fallback if all remaining candidates were already played
    if partner == -1 {
      for j = i + 1; j < n; j = j + 1 {
        if !used[j] {
          partner = j
          break
        }
      }
    }

    if partner != -1 {
      used[i] = true
      used[partner] = true
      pairs.push((self.entrants[i].id, self.entrants[partner].id))
    }
  }

  self.current_round = self.current_round + 1
  pairs
}

///|
/// Record a Swiss match outcome and update points, opponent lists, and ratings.
pub fn SwissTournament::record_result(
  self : SwissTournament,
  id_a : String,
  id_b : String,
  outcome : @types.GameOutcome,
) -> Unit {
  let s_a = outcome.to_score()
  let s_b = 1.0 - s_a
  let n = self.entrants.length()
  let mut idx_a = -1
  let mut idx_b = -1

  for i = 0; i < n; i = i + 1 {
    if self.entrants[i].id == id_a {
      idx_a = i
    } else if self.entrants[i].id == id_b {
      idx_b = i
    }
  }

  if idx_a == -1 || idx_b == -1 {
    return
  }

  self.entrants[idx_a].points = self.entrants[idx_a].points + s_a
  self.entrants[idx_a].opponents_faced.push(id_b)
  self.entrants[idx_b].points = self.entrants[idx_b].points + s_b
  self.entrants[idx_b].opponents_faced.push(id_a)

  match outcome {
    Win => {
      self.entrants[idx_a].match_wins = self.entrants[idx_a].match_wins + 1
      self.entrants[idx_b].match_losses = self.entrants[idx_b].match_losses + 1
    }
    Loss => {
      self.entrants[idx_a].match_losses = self.entrants[idx_a].match_losses + 1
      self.entrants[idx_b].match_wins = self.entrants[idx_b].match_wins + 1
    }
    Draw => {
      self.entrants[idx_a].match_draws = self.entrants[idx_a].match_draws + 1
      self.entrants[idx_b].match_draws = self.entrants[idx_b].match_draws + 1
    }
  }

  let (up_a, up_b) = @openskill.rate_2teams(
    [self.entrants[idx_a].rating],
    [self.entrants[idx_b].rating],
    outcome,
  )
  self.entrants[idx_a].rating = up_a[0]
  self.entrants[idx_b].rating = up_b[0]
}

// -----------------------------------------------------------------------------
// 5. Monte Carlo Championship & Podium Forecast Simulator
// -----------------------------------------------------------------------------

///|
/// Championship forecast metrics for a tournament participant across Monte Carlo simulations.
pub(all) struct ChampionshipForecast {
  player_id : String
  seed : Int32
  win_title_prob : Double
  reach_finals_prob : Double
  reach_semifinals_prob : Double
} derive(Eq, Debug)

///|
/// Run `simulations` Monte Carlo Single-Elimination tournament simulations
/// using Gaussian skill distributions and `@smath.DeterministicRng` to forecast
/// title, finals, and semifinal probabilities for every participant.
pub fn forecast_single_elimination_monte_carlo(
  players : Array[@types.Player],
  simulations~ : Int32 = 200,
  seed~ : Int64 = 20261125L,
) -> Array[ChampionshipForecast] {
  let entrants = seed_entrants_by_rating(players)
  let n = entrants.length()
  if n == 0 {
    return []
  }
  let safe_sims = if simulations < 1 { 1 } else { simulations }
  let rng = @smath.DeterministicRng::new(seed~)

  let bsize = next_power_of_two(if n < 2 { 2 } else { n })
  let seed_order = generate_fold_seed_order(bsize)

  let title_counts = Array::make(n, 0)
  let final_counts = Array::make(n, 0)
  let semi_counts = Array::make(n, 0)

  for _sim = 0; _sim < safe_sims; _sim = _sim + 1 {
    // Build initial slot array of entrant indices (-1 for BYE)
    let mut active : Array[Int32] = []
    for s in seed_order {
      if s <= n {
        active.push(s - 1)
      } else {
        active.push(-1)
      }
    }

    while active.length() > 1 {
      if active.length() == 4 {
        for idx in active {
          if idx >= 0 {
            semi_counts[idx] = semi_counts[idx] + 1
          }
        }
      }
      if active.length() == 2 {
        for idx in active {
          if idx >= 0 {
            final_counts[idx] = final_counts[idx] + 1
          }
        }
      }

      let next_round : Array[Int32] = []
      let mut i = 0
      while i + 1 < active.length() {
        let a = active[i]
        let b = active[i + 1]
        if a == -1 {
          next_round.push(b)
        } else if b == -1 {
          next_round.push(a)
        } else {
          let prob_a = @openskill.predict_win([entrants[a].rating], [
            entrants[b].rating,
          ])
          let roll = rng.next_double()
          if roll < prob_a {
            next_round.push(a)
          } else {
            next_round.push(b)
          }
        }
        i = i + 2
      }
      active = next_round
    }

    if active.length() == 1 && active[0] >= 0 {
      title_counts[active[0]] = title_counts[active[0]] + 1
    }
  }

  let sim_f = safe_sims.to_double()
  let forecasts : Array[ChampionshipForecast] = []
  for i = 0; i < n; i = i + 1 {
    forecasts.push({
      player_id: entrants[i].id,
      seed: entrants[i].seed,
      win_title_prob: title_counts[i].to_double() / sim_f,
      reach_finals_prob: final_counts[i].to_double() / sim_f,
      reach_semifinals_prob: semi_counts[i].to_double() / sim_f,
    })
  }
  forecasts
}
