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

// -----------------------------------------------------------------------------
// 2-Opt Local Search Team Balancer & Premade Party Synergy Offset
// -----------------------------------------------------------------------------

///|
/// Calculate premade party MMR synergy offset (in Bayesian mu units).
/// Coordinated duo/trio/five-stack parties receive an effective skill boost
/// to compensate for voice communication and tactical coordination.
pub fn party_synergy_mu_bonus(party_size : Int32) -> Double {
  if party_size <= 1 {
    0.0
  } else if party_size == 2 {
    0.85
  } else if party_size == 3 {
    1.45
  } else if party_size == 4 {
    2.10
  } else {
    2.80
  }
}

///|
/// Optimize a two-team partition using 2-Opt pairwise swap local search
/// to strictly maximize `match_quality_2teams`.
pub fn optimize_teams_2opt(
  players : Array[@types.Player],
  max_passes~ : Int32 = 20,
) -> (Array[@types.Player], Array[@types.Player], Double) {
  let (init_a, init_b, _) = balance_teams(players)
  let team_a = init_a.copy()
  let team_b = init_b.copy()
  let na = team_a.length()
  let nb = team_b.length()
  if na == 0 || nb == 0 {
    return (team_a, team_b, 1.0)
  }

  let mut cur_quality = match_quality_2teams(
    team_a.map(fn(p) { p.rating }),
    team_b.map(fn(p) { p.rating }),
  )

  for _pass = 0; _pass < max_passes; _pass = _pass + 1 {
    let mut improved = false
    for i = 0; i < na; i = i + 1 {
      for j = 0; j < nb; j = j + 1 {
        // Tentatively swap team_a[i] and team_b[j]
        let tmp = team_a[i]
        team_a[i] = team_b[j]
        team_b[j] = tmp

        let candidate_q = match_quality_2teams(
          team_a.map(fn(p) { p.rating }),
          team_b.map(fn(p) { p.rating }),
        )
        if candidate_q > cur_quality + 1.0e-6 {
          cur_quality = candidate_q
          improved = true
        } else {
          // Revert swap
          let rev = team_a[i]
          team_a[i] = team_b[j]
          team_b[j] = rev
        }
      }
    }
    if !improved {
      break
    }
  }

  (team_a, team_b, cur_quality)
}

// -----------------------------------------------------------------------------
// Role-Based 5v5 MOBA Matchmaking Engine (Top / Jungle / Mid / Bot / Support)
// -----------------------------------------------------------------------------

///|
/// A player queued with primary and secondary tactical roles, latency ping, and party ID.
pub(all) struct RoleQueuedPlayer {
  id : String
  rating : @types.Rating
  primary_role : @types.TacticalRole
  secondary_role : @types.TacticalRole
  enqueue_tick : Int32
  ping_ms : Int32
  party_id : String
} derive(Eq, Debug)

///|
/// Construct a RoleQueuedPlayer.
pub fn RoleQueuedPlayer::new(
  id : String,
  rating : @types.Rating,
  primary_role : @types.TacticalRole,
  secondary_role~ : @types.TacticalRole = @types.TacticalRole::Flex,
  enqueue_tick~ : Int32 = 0,
  ping_ms~ : Int32 = 25,
  party_id~ : String = "",
) -> RoleQueuedPlayer {
  { id, rating, primary_role, secondary_role, enqueue_tick, ping_ms, party_id, }
}

///|
/// Check if a RoleQueuedPlayer can fill `target_role` via primary, secondary, or Flex.
pub fn RoleQueuedPlayer::matches_role(
  self : RoleQueuedPlayer,
  target_role : @types.TacticalRole,
  allow_secondary~ : Bool = true,
) -> Bool {
  if self.primary_role == target_role ||
    self.primary_role == @types.TacticalRole::Flex {
    return true
  }
  if allow_secondary &&
    (
      self.secondary_role == target_role ||
      self.secondary_role == @types.TacticalRole::Flex
    ) {
    return true
  }
  false
}

///|
/// Balanced 5v5 role-assigned match lobby.
pub(all) struct RoleBalancedLobby {
  blue_team : Array[(RoleQueuedPlayer, @types.TacticalRole)]
  red_team : Array[(RoleQueuedPlayer, @types.TacticalRole)]
  overall_quality : Double
  lane_fairness_score : Double
  average_ping_ms : Double
} derive(Eq, Debug)

///|
/// Role-aware matchmaking queue for 5v5 tactical games.
pub(all) struct RoleMatchmakingQueue {
  pool : Array[RoleQueuedPlayer]
} derive(Eq, Debug)

///|
/// Construct an empty RoleMatchmakingQueue.
pub fn RoleMatchmakingQueue::new() -> RoleMatchmakingQueue {
  { pool: [], }
}

///|
/// Enqueue a RoleQueuedPlayer.
pub fn RoleMatchmakingQueue::enqueue(
  self : RoleMatchmakingQueue,
  player : RoleQueuedPlayer,
) -> Unit {
  self.pool.push(player)
}

///|
/// Compute lane-by-lane matchup fairness across 5 assigned roles in [0.0, 1.0].
pub fn compute_lane_fairness(
  blue : Array[(RoleQueuedPlayer, @types.TacticalRole)],
  red : Array[(RoleQueuedPlayer, @types.TacticalRole)],
) -> Double {
  let k = if blue.length() < red.length() {
    blue.length()
  } else {
    red.length()
  }
  if k == 0 {
    return 1.0
  }
  let mut sum_q = 0.0
  for i = 0; i < k; i = i + 1 {
    let q_lane = match_quality_1v1(blue[i].0.rating, red[i].0.rating)
    sum_q = sum_q + q_lane
  }
  sum_q / k.to_double()
}

///|
/// Assemble a role-complete 5v5 match lobby (Top, Jungle, Mid, Bot, Support) from the queue.
/// Pairs two candidates per role whose skill difference is within the dynamic wait window,
/// and assigns them to Blue vs Red to minimize total team skill imbalance.
pub fn RoleMatchmakingQueue::assemble_5v5_lobby(
  self : RoleMatchmakingQueue,
  current_tick : Int32,
  base_window~ : Double = 5.0,
  expansion_rate~ : Double = 0.5,
) -> RoleBalancedLobby? {
  if self.pool.length() < 10 {
    return None
  }

  let required_roles = [
    @types.TacticalRole::Top,
    @types.TacticalRole::Jungle,
    @types.TacticalRole::Mid,
    @types.TacticalRole::Bot,
    @types.TacticalRole::Support,
  ]

  let used = Array::make(self.pool.length(), false)
  let role_pairs : Array[(Int32, Int32, @types.TacticalRole)] = []

  for role in required_roles {
    let mut found_i = -1
    let mut found_j = -1

    for i = 0; i < self.pool.length(); i = i + 1 {
      if used[i] || !self.pool[i].matches_role(role, allow_secondary=true) {
        continue
      }
      let p1 = self.pool[i]
      let wait1 = if current_tick > p1.enqueue_tick {
        (current_tick - p1.enqueue_tick).to_double()
      } else {
        0.0
      }
      let win1 = base_window + expansion_rate * wait1

      for j = i + 1; j < self.pool.length(); j = j + 1 {
        if used[j] || !self.pool[j].matches_role(role, allow_secondary=true) {
          continue
        }
        let p2 = self.pool[j]
        let wait2 = if current_tick > p2.enqueue_tick {
          (current_tick - p2.enqueue_tick).to_double()
        } else {
          0.0
        }
        let win2 = base_window + expansion_rate * wait2
        let allowed = if win1 > win2 { win1 } else { win2 }

        if (p1.rating.mu - p2.rating.mu).abs() <= allowed {
          found_i = i
          found_j = j
          break
        }
      }
      if found_i != -1 {
        break
      }
    }

    if found_i == -1 || found_j == -1 {
      return None
    }
    used[found_i] = true
    used[found_j] = true
    role_pairs.push((found_i, found_j, role))
  }

  // Assign each role pair to Blue vs Red greedily to balance total team mu
  let blue_team : Array[(RoleQueuedPlayer, @types.TacticalRole)] = []
  let red_team : Array[(RoleQueuedPlayer, @types.TacticalRole)] = []
  let mut sum_blue = 0.0
  let mut sum_red = 0.0
  let mut ping_sum = 0.0

  for rp in role_pairs {
    let (idx1, idx2, role) = rp
    let p1 = self.pool[idx1]
    let p2 = self.pool[idx2]
    ping_sum = ping_sum + (p1.ping_ms + p2.ping_ms).to_double()

    let (higher, lower) = if p1.rating.mu >= p2.rating.mu {
      (p1, p2)
    } else {
      (p2, p1)
    }

    if sum_blue <= sum_red {
      blue_team.push((higher, role))
      red_team.push((lower, role))
      sum_blue = sum_blue + higher.rating.mu
      sum_red = sum_red + lower.rating.mu
    } else {
      blue_team.push((lower, role))
      red_team.push((higher, role))
      sum_blue = sum_blue + lower.rating.mu
      sum_red = sum_red + higher.rating.mu
    }
  }

  // Remove matched players from pool (in reverse index order)
  let mut k = self.pool.length() - 1
  while k >= 0 {
    if used[k] {
      let _ = self.pool.remove(k)
    }
    k = k - 1
  }

  let blue_ratings = blue_team.map(fn(pair) { pair.0.rating })
  let red_ratings = red_team.map(fn(pair) { pair.0.rating })
  let overall_q = match_quality_2teams(blue_ratings, red_ratings)
  let lane_q = compute_lane_fairness(blue_team, red_team)

  Some({
    blue_team,
    red_team,
    overall_quality: overall_q,
    lane_fairness_score: lane_q,
    average_ping_ms: ping_sum / 10.0,
  })
}

///|
/// Group an array of players into an M-player Free-For-All / Battle Royale lobby
/// centered around a target skill `anchor_mu`, selecting the closest available participants.
pub fn assemble_battle_royale_lobby(
  candidates : Array[@types.Player],
  lobby_size : Int32,
  anchor_mu~ : Double = 25.0,
) -> (Array[@types.Player], Double) {
  let n = candidates.length()
  if n == 0 || lobby_size <= 0 {
    return ([], 0.0)
  }
  let sorted = candidates.copy()
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n - 1 - i; j = j + 1 {
      let d1 = (sorted[j].rating.mu - anchor_mu).abs()
      let d2 = (sorted[j + 1].rating.mu - anchor_mu).abs()
      if d1 > d2 {
        let tmp = sorted[j]
        sorted[j] = sorted[j + 1]
        sorted[j + 1] = tmp
      }
    }
  }

  let take = if lobby_size < n { lobby_size } else { n }
  let selected : Array[@types.Player] = []
  let mut sum_mu = 0.0
  for i = 0; i < take; i = i + 1 {
    selected.push(sorted[i])
    sum_mu = sum_mu + sorted[i].rating.mu
  }
  let mean_mu = sum_mu / take.to_double()
  let mut var_spread = 0.0
  for p in selected {
    let d = p.rating.mu - mean_mu
    var_spread = var_spread + d * d
  }
  let std_spread = (var_spread / take.to_double()).sqrt()
  (selected, std_spread)
}
