///|
/// Default beta for match quality calculation (half of standard deviation 25/3).
pub const DEFAULT_BETA : Double = 4.166666666666667

///|
/// Calculate match quality between two participants (1v1).
/// Returns a value in (0.0, 1.0], where 1.0 represents a perfectly balanced match.
pub fn match_quality_1v1(
  player_a : @types.Rating,
  player_b : @types.Rating,
  beta~ : Double = DEFAULT_BETA,
) -> Double {
  let delta_mu = player_a.mu - player_b.mu
  let beta_sq = beta * beta
  let denom_var = player_a.variance() + player_b.variance() + 2.0 * beta_sq

  let exponent = -(delta_mu * delta_mu) / (2.0 * denom_var)
  let exp_term = @core_math.exp(exponent)
  let scale_term = (2.0 * beta_sq / denom_var).sqrt()

  exp_term * scale_term
}

///|
/// Calculate match quality between two multi-player teams.
pub fn match_quality_2teams(
  team_a : Array[@types.Rating],
  team_b : Array[@types.Rating],
  beta~ : Double = DEFAULT_BETA,
) -> Double {
  let mut mu_a = 0.0
  let mut var_a = 0.0
  for r in team_a {
    mu_a = mu_a + r.mu
    var_a = var_a + r.variance()
  }

  let mut mu_b = 0.0
  let mut var_b = 0.0
  for r in team_b {
    mu_b = mu_b + r.mu
    var_b = var_b + r.variance()
  }

  let delta_mu = mu_a - mu_b
  let beta_sq = beta * beta
  let denom_var = var_a + var_b + 2.0 * beta_sq

  let exponent = -(delta_mu * delta_mu) / (2.0 * denom_var)
  let exp_term = @core_math.exp(exponent)
  let scale_term = (2.0 * beta_sq / denom_var).sqrt()

  exp_term * scale_term
}

///|
/// Calculate overall match quality for multi-team games (N teams)
/// by computing the geometric mean of all pairwise match qualities.
pub fn match_quality_teams(
  teams : Array[Array[@types.Rating]],
  beta~ : Double = DEFAULT_BETA,
) -> Double {
  let k = teams.length()
  if k < 2 {
    return 1.0
  }
  if k == 2 {
    return match_quality_2teams(teams[0], teams[1], beta~)
  }

  let mut log_sum = 0.0
  let mut pairs_count = 0.0

  for i in 0..<k {
    for j in (i + 1)..<k {
      let q = match_quality_2teams(teams[i], teams[j], beta~)
      let safe_q = if q < 1.0e-12 { 1.0e-12 } else { q }
      log_sum = log_sum + @core_math.ln(safe_q)
      pairs_count = pairs_count + 1.0
    }
  }

  if pairs_count == 0.0 {
    1.0
  } else {
    @core_math.exp(log_sum / pairs_count)
  }
}

///|
/// Check if a match is considered fair given a minimum quality threshold (default 0.5).
pub fn is_fair_match(
  teams : Array[Array[@types.Rating]],
  min_quality~ : Double = 0.5,
  beta~ : Double = DEFAULT_BETA,
) -> Bool {
  match_quality_teams(teams, beta~) >= min_quality
}

///|
/// Compute a full win probability matrix between all teams.
/// matrix[i][j] gives the probability that Team i beats Team j.
pub fn win_probability_matrix(
  teams : Array[Array[@types.Rating]],
  beta~ : Double = DEFAULT_BETA,
) -> Array[Array[Double]] {
  let k = teams.length()
  let matrix = []

  let team_means = []
  let team_vars = []
  for t in teams {
    let mut m = 0.0
    let mut v = 0.0
    for r in t {
      m = m + r.mu
      v = v + r.variance()
    }
    team_means.push(m)
    team_vars.push(v)
  }

  let beta_sq = beta * beta

  for i in 0..<k {
    let row = []
    for j in 0..<k {
      if i == j {
        row.push(0.5)
      } else {
        let diff = team_means[i] - team_means[j]
        let c = (team_vars[i] + team_vars[j] + 2.0 * beta_sq).sqrt()
        let prob = @smath.normal_cdf(diff / c)
        row.push(prob)
      }
    }
    matrix.push(row)
  }

  matrix
}

// -----------------------------------------------------------------------------
// Advanced Matchmaking Queue & Dynamic Rating Window Expansion
// -----------------------------------------------------------------------------

///|
/// A player waiting in the matchmaking queue.
pub(all) struct QueuedPlayer {
  id : String
  rating : @types.Rating
  enqueue_tick : Int32
} derive(Eq, Debug)

///|
/// Construct a new queued player.
pub fn QueuedPlayer::new(
  id : String,
  rating : @types.Rating,
  enqueue_tick : Int32,
) -> QueuedPlayer {
  { id, rating, enqueue_tick, }
}

///|
/// Matchmaking queue with dynamic window expansion.
pub(all) struct MatchmakingQueue {
  players : Array[QueuedPlayer]
} derive(Eq, Debug)

///|
/// Create a new empty MatchmakingQueue.
pub fn MatchmakingQueue::new() -> MatchmakingQueue {
  { players: [], }
}

///|
/// Enqueue a player into the matchmaking queue.
pub fn MatchmakingQueue::enqueue(
  self : MatchmakingQueue,
  player : QueuedPlayer,
) -> Unit {
  self.players.push(player)
}

///|
/// Remove a player from queue by ID.
pub fn MatchmakingQueue::remove(self : MatchmakingQueue, id : String) -> Bool {
  for i = 0; i < self.players.length(); i = i + 1 {
    if self.players[i].id == id {
      let _ = self.players.remove(i)
      return true
    }
  }
  false
}

///|
/// Try to find a balanced 1v1 match in queue with dynamic window expansion:
/// allowed_delta = base_window + expansion_rate * wait_time
pub fn MatchmakingQueue::find_pair(
  self : MatchmakingQueue,
  current_tick : Int32,
  base_window~ : Double = 3.0,
  expansion_rate~ : Double = 0.5,
) -> (QueuedPlayer, QueuedPlayer)? {
  let len = self.players.length()
  if len < 2 {
    return None
  }

  for i = 0; i < len; i = i + 1 {
    let p1 = self.players[i]
    let wait_time1 = (current_tick - p1.enqueue_tick).to_double()
    let safe_wait1 = if wait_time1 < 0.0 { 0.0 } else { wait_time1 }
    let window1 = base_window + expansion_rate * safe_wait1

    for j = i + 1; j < len; j = j + 1 {
      let p2 = self.players[j]
      let wait_time2 = (current_tick - p2.enqueue_tick).to_double()
      let safe_wait2 = if wait_time2 < 0.0 { 0.0 } else { wait_time2 }
      let window2 = base_window + expansion_rate * safe_wait2

      let max_allowed_gap = if window1 > window2 { window1 } else { window2 }
      let diff = (p1.rating.mu - p2.rating.mu).abs()

      if diff <= max_allowed_gap {
        let first = self.players[i]
        let second = self.players[j]
        let _ = self.players.remove(j)
        let _ = self.players.remove(i)
        return Some((first, second))
      }
    }
  }

  None
}

// -----------------------------------------------------------------------------
// Team Balancer (Fair Auto-Partitioner)
// -----------------------------------------------------------------------------

///|
/// Partition an even pool of players into two balanced teams minimizing skill discrepancy.
pub fn balance_teams(
  players : Array[@types.Player],
) -> (Array[@types.Player], Array[@types.Player], Double) {
  let n = players.length()
  if n == 0 {
    return ([], [], 1.0)
  }

  // Clone players array
  let sorted_players = players.copy()

  // Sort by rating mu descending (bubble sort for zero-dependency)
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n - i - 1; j = j + 1 {
      if sorted_players[j].rating.mu < sorted_players[j + 1].rating.mu {
        let temp = sorted_players[j]
        sorted_players[j] = sorted_players[j + 1]
        sorted_players[j + 1] = temp
      }
    }
  }

  // Greedy snake-draft assignment (A, B, B, A, ...)
  let team_a : Array[@types.Player] = []
  let team_b : Array[@types.Player] = []
  let mut sum_a = 0.0
  let mut sum_b = 0.0

  for i = 0; i < n; i = i + 1 {
    let p = sorted_players[i]
    if team_a.length() < (n + 1) / 2 &&
      (sum_a <= sum_b || team_b.length() >= n / 2) {
      team_a.push(p)
      sum_a = sum_a + p.rating.mu
    } else {
      team_b.push(p)
      sum_b = sum_b + p.rating.mu
    }
  }

  let ratings_a = team_a.map(fn(p) { p.rating })
  let ratings_b = team_b.map(fn(p) { p.rating })
  let quality = match_quality_2teams(ratings_a, ratings_b)

  (team_a, team_b, quality)
}

///|
/// Batch-pair as many valid 1v1 matches as possible from the matchmaking queue
/// in a single tick using dynamic rating windows.
pub fn MatchmakingQueue::batch_pair_all(
  self : MatchmakingQueue,
  current_tick : Int32,
  base_window~ : Double = 3.0,
  expansion_rate~ : Double = 0.5,
) -> Array[(QueuedPlayer, QueuedPlayer)] {
  let pairs : Array[(QueuedPlayer, QueuedPlayer)] = []
  while true {
    match self.find_pair(current_tick, base_window~, expansion_rate~) {
      Some(pair) => pairs.push(pair)
      None => break
    }
  }
  pairs
}

///|
/// Calculate dynamic MMR acceleration factor (smurf / win-streak detection).
/// Returns a multiplier in [1.0, 2.5] based on consecutive win streak and
/// cumulative surprise (actual score minus expected score).
pub fn smurf_acceleration_factor(
  win_streak : Int32,
  cumulative_surprise : Double,
) -> Double {
  if win_streak < 3 && cumulative_surprise <= 1.0 {
    return 1.0
  }
  let streak_bonus = if win_streak >= 3 {
    (win_streak - 2).to_double() * 0.15
  } else {
    0.0
  }
  let surprise_bonus = if cumulative_surprise > 1.0 {
    (cumulative_surprise - 1.0) * 0.25
  } else {
    0.0
  }
  let raw = 1.0 + streak_bonus + surprise_bonus
  if raw > 2.5 {
    2.5
  } else {
    raw
  }
}
