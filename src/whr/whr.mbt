///|
/// Whole-History Rating (WHR) Engine based on Rémi Coulom (2008).
/// Models each player's time-varying skill as a Wiener process (Brownian motion)
/// and globally optimizes the entire historical trajectory via Newton-Raphson
/// over the tridiagonal Hessian of the log-posterior distribution.

///|
/// Conversion scale between natural log-gamma r and Elo rating: 400 / ln(10).
pub const WHR_ELO_SCALE : Double = 173.7177927613

///|
/// Configuration parameters for the Whole-History Rating engine.
pub(all) struct WHRConfig {
  /// Wiener process variance growth rate w^2 (in Elo^2 per day, default 14.0).
  w2_elo_per_day : Double
  /// Virtual prior games (draws against mean 0.0) anchored on a player's first day.
  virtual_prior_games : Double
  /// Prior Gaussian variance on initial rating r_0 (in natural log-gamma scale).
  initial_prior_variance : Double
  /// Maximum Newton-Raphson step magnitude to ensure global stability.
  max_newton_step : Double
  /// Convergence tolerance on gradient norm.
  tolerance : Double
} derive(Eq, Debug)

///|
/// Construct a custom WHRConfig.
pub fn WHRConfig::new(
  w2_elo_per_day~ : Double = 14.0,
  virtual_prior_games~ : Double = 2.0,
  initial_prior_variance~ : Double = 4.0,
  max_newton_step~ : Double = 2.5,
  tolerance~ : Double = 1.0e-5,
) -> WHRConfig {
  {
    w2_elo_per_day,
    virtual_prior_games,
    initial_prior_variance,
    max_newton_step,
    tolerance,
  }
}

///|
/// Default WHRConfig calibrated for competitive board games and esports ladders.
pub fn WHRConfig::default() -> WHRConfig {
  {
    w2_elo_per_day: 14.0,
    virtual_prior_games: 2.0,
    initial_prior_variance: 4.0,
    max_newton_step: 2.5,
    tolerance: 1.0e-5,
  }
}

///|
/// Convert w2 from Elo^2/day to natural log-gamma^2/day:
/// w2_nat = w2_elo / (400 / ln(10))^2.
pub fn WHRConfig::w2_natural(self : WHRConfig) -> Double {
  self.w2_elo_per_day / (WHR_ELO_SCALE * WHR_ELO_SCALE)
}

///|
/// A single opponent encounter recorded for a player on a specific day epoch.
pub(all) struct WHRDayMatch {
  opponent_id : String
  opponent_day_index : Int32
  score : Double
  handicap_nat : Double
  weight : Double
} derive(Eq, Debug)

///|
/// Construct a WHRDayMatch entry.
pub fn WHRDayMatch::new(
  opponent_id : String,
  opponent_day_index : Int32,
  score : Double,
  handicap_nat~ : Double = 0.0,
  weight~ : Double = 1.0,
) -> WHRDayMatch {
  { opponent_id, opponent_day_index, score, handicap_nat, weight, }
}

///|
/// A single time-slice (day / epoch) node in a player's Whole-History trajectory.
pub(all) struct WHRPlayerDay {
  day_epoch : Int32
  /// Natural log-skill parameter r(t) = ln(gamma(t)).
  mut r : Double
  /// Posterior uncertainty variance sigma^2(t) in natural log-skill scale.
  mut uncertainty_var : Double
  /// Matches contested by this player on this day.
  matches : Array[WHRDayMatch]
  /// Whether this is the player's inaugural day (receives virtual anchor prior).
  is_first_day : Bool
} derive(Eq, Debug)

///|
/// Construct a WHRPlayerDay node.
pub fn WHRPlayerDay::new(
  day_epoch : Int32,
  r~ : Double = 0.0,
  uncertainty_var~ : Double = 1.0,
  is_first_day~ : Bool = false,
) -> WHRPlayerDay {
  { day_epoch, r, uncertainty_var, matches: [], is_first_day, }
}

///|
/// Convert natural log-skill r to standard Elo scale (centered at 1500.0).
pub fn WHRPlayerDay::elo(
  self : WHRPlayerDay,
  base~ : Double = 1500.0,
) -> Double {
  base + self.r * WHR_ELO_SCALE
}

///|
/// Convert natural uncertainty standard deviation to Elo rating deviation (RD).
pub fn WHRPlayerDay::elo_deviation(self : WHRPlayerDay) -> Double {
  let safe_var = if self.uncertainty_var < 0.0 {
    0.0
  } else {
    self.uncertainty_var
  }
  safe_var.sqrt() * WHR_ELO_SCALE
}

///|
/// Convert a WHRPlayerDay state to a standard SkillRate Bayesian `@types.Rating` (mu=25 scale).
pub fn WHRPlayerDay::to_bayesian_rating(self : WHRPlayerDay) -> @types.Rating {
  let elo_val = self.elo()
  let elo_rd = self.elo_deviation()
  @types.Rating::new(elo_val / 60.0, elo_rd / 60.0)
}

///|
/// Longitudinal history of a single player across all active days.
pub(all) struct WHRPlayerTimeline {
  player_id : String
  days : Array[WHRPlayerDay]
} derive(Eq, Debug)

///|
/// Construct an empty WHRPlayerTimeline for a player.
pub fn WHRPlayerTimeline::new(player_id : String) -> WHRPlayerTimeline {
  { player_id, days: [], }
}

///|
/// Find or insert a chronologically ordered WHRPlayerDay for `day_epoch`.
/// Returns the index of the day in `self.days`.
pub fn WHRPlayerTimeline::ensure_day(
  self : WHRPlayerTimeline,
  day_epoch : Int32,
) -> Int32 {
  let n = self.days.length()
  for i = 0; i < n; i = i + 1 {
    if self.days[i].day_epoch == day_epoch {
      return i
    }
    if self.days[i].day_epoch > day_epoch {
      let init_r = if i > 0 { self.days[i - 1].r } else { self.days[i].r }
      let node = WHRPlayerDay::new(
        day_epoch,
        r=init_r,
        uncertainty_var=1.0,
        is_first_day=i == 0,
      )
      if i == 0 {
        self.days[0] = {
          day_epoch: self.days[0].day_epoch,
          r: self.days[0].r,
          uncertainty_var: self.days[0].uncertainty_var,
          matches: self.days[0].matches,
          is_first_day: false,
        }
      }
      // Shift elements right and insert at i
      self.days.push(node)
      let mut k = self.days.length() - 1
      while k > i {
        self.days[k] = self.days[k - 1]
        k = k - 1
      }
      self.days[i] = node
      return i
    }
  }
  let init_r = if n > 0 { self.days[n - 1].r } else { 0.0 }
  let node = WHRPlayerDay::new(
    day_epoch,
    r=init_r,
    uncertainty_var=1.0,
    is_first_day=n == 0,
  )
  self.days.push(node)
  n
}

///|
/// Return the player's latest WHRPlayerDay snapshot, if any.
pub fn WHRPlayerTimeline::latest_day(self : WHRPlayerTimeline) -> WHRPlayerDay? {
  let n = self.days.length()
  if n == 0 {
    None
  } else {
    Some(self.days[n - 1])
  }
}

///|
/// Return the player's peak historical Elo rating across all recorded days.
pub fn WHRPlayerTimeline::peak_elo(
  self : WHRPlayerTimeline,
  base~ : Double = 1500.0,
) -> Double {
  let n = self.days.length()
  if n == 0 {
    return base
  }
  let mut best = self.days[0].elo(base~)
  for i = 1; i < n; i = i + 1 {
    let cur = self.days[i].elo(base~)
    if cur > best {
      best = cur
    }
  }
  best
}

///|
/// Whole-History Rating global store and optimization engine.
pub(all) struct WHREngine {
  config : WHRConfig
  timelines : Array[WHRPlayerTimeline]
  mut total_matches : Int32
} derive(Eq, Debug)

///|
/// Create a new WHREngine with optional configuration.
pub fn WHREngine::new(config~ : WHRConfig = WHRConfig::default()) -> WHREngine {
  { config, timelines: [], total_matches: 0, }
}

///|
/// Find or create a player timeline index by `player_id`.
pub fn WHREngine::ensure_player(self : WHREngine, player_id : String) -> Int32 {
  let n = self.timelines.length()
  for i = 0; i < n; i = i + 1 {
    if self.timelines[i].player_id == player_id {
      return i
    }
  }
  self.timelines.push(WHRPlayerTimeline::new(player_id))
  n
}

///|
/// Lookup a player timeline by ID.
pub fn WHREngine::find_player(
  self : WHREngine,
  player_id : String,
) -> WHRPlayerTimeline? {
  for t in self.timelines {
    if t.player_id == player_id {
      return Some(t)
    }
  }
  None
}

///|
///Lookup a specific opponent's natural log-skill r on a given day index.
fn WHREngine::get_player_day_r(
  self : WHREngine,
  player_id : String,
  day_index : Int32,
) -> Double {
  for t in self.timelines {
    if t.player_id == player_id {
      if day_index >= 0 && day_index < t.days.length() {
        return t.days[day_index].r
      } else if !t.days.is_empty() {
        return t.days[t.days.length() - 1].r
      }
      return 0.0
    }
  }
  0.0
}

///|
/// Record a historical match between `player_a` and `player_b` on `day_epoch`.
/// `handicap_elo_a` is an optional Elo advantage granted to `player_a`.
pub fn WHREngine::record_match(
  self : WHREngine,
  player_a : String,
  player_b : String,
  outcome : @types.GameOutcome,
  day_epoch~ : Int32 = 0,
  handicap_elo_a~ : Double = 0.0,
  weight~ : Double = 1.0,
) -> Unit {
  if player_a == player_b {
    return
  }
  let idx_a = self.ensure_player(player_a)
  let idx_b = self.ensure_player(player_b)

  let day_idx_a = self.timelines[idx_a].ensure_day(day_epoch)
  let day_idx_b = self.timelines[idx_b].ensure_day(day_epoch)

  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a
  let h_nat = handicap_elo_a / WHR_ELO_SCALE

  self.timelines[idx_a].days[day_idx_a].matches.push(
    WHRDayMatch::new(player_b, day_idx_b, score_a, handicap_nat=h_nat, weight~),
  )
  self.timelines[idx_b].days[day_idx_b].matches.push(
    WHRDayMatch::new(player_a, day_idx_a, score_b, handicap_nat=-h_nat, weight~),
  )
  self.total_matches = self.total_matches + 1
}

///|
/// Load a batch of `@types.HistoricalMatch` records into the WHREngine.
pub fn WHREngine::ingest_history(
  self : WHREngine,
  history : Array[@types.HistoricalMatch],
) -> Unit {
  for m in history {
    self.record_match(
      m.player_a,
      m.player_b,
      m.outcome,
      day_epoch=m.day_epoch,
      handicap_elo_a=m.handicap_a,
      weight=m.weight,
    )
  }
}

///|
/// Compute the 1D gradient and negative diagonal Hessian contribution of all matches
/// played by a player on a single day `day_node`.
fn WHREngine::compute_day_likelihood_derivatives(
  self : WHREngine,
  day_node : WHRPlayerDay,
) -> (Double, Double) {
  let r_i = day_node.r
  let mut grad = 0.0
  let mut neg_hess = 0.0

  // Virtual prior draws against r=0.0 on the player's inaugural day
  if day_node.is_first_day {
    let v_games = self.config.virtual_prior_games
    if v_games > 0.0 {
      let p_prior = @smath.logistic_cdf(r_i)
      grad = grad + v_games * (0.5 - p_prior)
      neg_hess = neg_hess + v_games * p_prior * (1.0 - p_prior)
    }
    let prior_var = self.config.initial_prior_variance
    if prior_var > 1.0e-6 {
      grad = grad - r_i / prior_var
      neg_hess = neg_hess + 1.0 / prior_var
    }
  }

  for m in day_node.matches {
    let r_opp = self.get_player_day_r(m.opponent_id, m.opponent_day_index)
    let diff = r_i + m.handicap_nat - r_opp
    let p_win = @smath.logistic_cdf(diff)
    let w = m.weight
    grad = grad + w * (m.score - p_win)
    neg_hess = neg_hess + w * p_win * (1.0 - p_win)
  }

  // Ensure positive definiteness
  let safe_neg_hess = if neg_hess < 1.0e-6 { 1.0e-6 } else { neg_hess }
  (grad, safe_neg_hess)
}

///|
/// Execute one Newton-Raphson optimization pass and covariance update for a single player's
/// full longitudinal timeline using the tridiagonal Wiener-process Hessian.
/// Returns the maximum absolute parameter change |delta_r| across the player's timeline.
pub fn WHREngine::optimize_player_timeline(
  self : WHREngine,
  player_index : Int32,
) -> Double {
  if player_index < 0 || player_index >= self.timelines.length() {
    return 0.0
  }
  let timeline = self.timelines[player_index]
  let n = timeline.days.length()
  if n == 0 {
    return 0.0
  }

  // Single-day exact 1D Newton step
  if n == 1 {
    let (grad, neg_hess) = self.compute_day_likelihood_derivatives(
      timeline.days[0],
    )
    let raw_step = grad / neg_hess
    let max_s = self.config.max_newton_step
    let step = if raw_step > max_s {
      max_s
    } else if raw_step < -max_s {
      -max_s
    } else {
      raw_step
    }
    timeline.days[0].r = timeline.days[0].r + step
    timeline.days[0].uncertainty_var = 1.0 / neg_hess
    return step.abs()
  }

  // Build Wiener process precision terms sigma_k^{-2} = 1 / (w^2 * (t_{k+1} - t_k))
  let w2 = self.config.w2_natural()
  let wiener_prec : Array[Double] = []
  for i = 0; i < n - 1; i = i + 1 {
    let dt = (timeline.days[i + 1].day_epoch - timeline.days[i].day_epoch).to_double()
    let safe_dt = if dt < 1.0 { 1.0 } else { dt }
    let var_step = w2 * safe_dt
    let prec = if var_step < 1.0e-9 { 1.0e9 } else { 1.0 / var_step }
    wiener_prec.push(prec)
  }

  // Construct tridiagonal negative Hessian (-H) and total gradient vector g
  let sub = Array::make(n, 0.0)
  let diag = Array::make(n, 0.0)
  let sup = Array::make(n, 0.0)
  let grad_vec = Array::make(n, 0.0)

  for i = 0; i < n; i = i + 1 {
    let (g_like, h_like) = self.compute_day_likelihood_derivatives(
      timeline.days[i],
    )
    let mut g_total = g_like
    let mut h_total = h_like

    if i > 0 {
      let p_prev = wiener_prec[i - 1]
      let diff_prev = timeline.days[i].r - timeline.days[i - 1].r
      g_total = g_total - p_prev * diff_prev
      h_total = h_total + p_prev
      sub[i] = -p_prev
    }
    if i < n - 1 {
      let p_next = wiener_prec[i]
      let diff_next = timeline.days[i].r - timeline.days[i + 1].r
      g_total = g_total - p_next * diff_next
      h_total = h_total + p_next
      sup[i] = -p_next
    }

    diag[i] = h_total
    grad_vec[i] = g_total
  }

  // Solve (-H) * delta = grad_vec in O(n) time via Thomas tridiagonal solver
  let delta = @smath.solve_tridiagonal(sub, diag, sup, grad_vec)
  let max_s = self.config.max_newton_step
  let mut max_change = 0.0

  for i = 0; i < n; i = i + 1 {
    let raw_d = delta[i]
    let d = if raw_d > max_s {
      max_s
    } else if raw_d < -max_s {
      -max_s
    } else {
      raw_d
    }
    timeline.days[i].r = timeline.days[i].r + d
    if d.abs() > max_change {
      max_change = d.abs()
    }
  }

  // Update posterior marginal variances sigma^2(t_i) from diagonal of (-H)^{-1}
  self.update_timeline_uncertainties(player_index, sub, diag, sup)
  max_change
}

///|
/// Extract marginal posterior variances diag((-H)^{-1}) for a tridiagonal precision matrix
/// using forward/backward UL-LDLT diagonal recurrences (Coulom 2008 Section 3.3).
fn WHREngine::update_timeline_uncertainties(
  self : WHREngine,
  player_index : Int32,
  sub : Array[Double],
  diag : Array[Double],
  sup : Array[Double],
) -> Unit {
  let timeline = self.timelines[player_index]
  let n = timeline.days.length()
  if n == 0 {
    return
  }

  // Forward LDL^T sweep
  let d_fwd = Array::make(n, 0.0)
  d_fwd[0] = if diag[0] < 1.0e-9 { 1.0e-9 } else { diag[0] }
  for i = 1; i < n; i = i + 1 {
    let v = diag[i] - sub[i] * sup[i - 1] / d_fwd[i - 1]
    d_fwd[i] = if v < 1.0e-9 { 1.0e-9 } else { v }
  }

  // Backward UDU^T sweep
  let d_bwd = Array::make(n, 0.0)
  d_bwd[n - 1] = if diag[n - 1] < 1.0e-9 { 1.0e-9 } else { diag[n - 1] }
  let mut k = n - 2
  while k >= 0 {
    let v = diag[k] - sup[k] * sub[k + 1] / d_bwd[k + 1]
    d_bwd[k] = if v < 1.0e-9 { 1.0e-9 } else { v }
    k = k - 1
  }

  for i = 0; i < n; i = i + 1 {
    let denom = d_fwd[i] + d_bwd[i] - diag[i]
    let safe_denom = if denom < 1.0e-6 { 1.0e-6 } else { denom }
    timeline.days[i].uncertainty_var = 1.0 / safe_denom
  }
}

///|
/// Run global Whole-History Rating optimization over `iterations` sweeps across all players.
/// Returns the final maximum parameter step change across the population.
pub fn WHREngine::run_iterations(
  self : WHREngine,
  iterations~ : Int32 = 20,
) -> Double {
  let num_players = self.timelines.length()
  if num_players == 0 {
    return 0.0
  }
  let mut last_max_delta = 0.0
  for _it = 0; _it < iterations; _it = _it + 1 {
    let mut sweep_max = 0.0
    for p = 0; p < num_players; p = p + 1 {
      let d = self.optimize_player_timeline(p)
      if d > sweep_max {
        sweep_max = d
      }
    }
    last_max_delta = sweep_max
    if sweep_max <= self.config.tolerance {
      break
    }
  }
  last_max_delta
}

///|
/// Interpolate or extrapolate a player's rating and uncertainty at any arbitrary `query_day`
/// using Brownian bridge variance interpolation between surrounding recorded days.
pub fn WHREngine::query_rating_at_day(
  self : WHREngine,
  player_id : String,
  query_day : Int32,
) -> WHRPlayerDay {
  let timeline = match self.find_player(player_id) {
    Some(t) => t
    None =>
      return WHRPlayerDay::new(
        query_day,
        r=0.0,
        uncertainty_var=self.config.initial_prior_variance,
      )
  }
  let n = timeline.days.length()
  if n == 0 {
    return WHRPlayerDay::new(
      query_day,
      r=0.0,
      uncertainty_var=self.config.initial_prior_variance,
    )
  }

  let w2 = self.config.w2_natural()
  // Before first recorded day
  if query_day <= timeline.days[0].day_epoch {
    let first = timeline.days[0]
    let dt = (first.day_epoch - query_day).to_double()
    return WHRPlayerDay::new(
      query_day,
      r=first.r,
      uncertainty_var=first.uncertainty_var + w2 * dt,
    )
  }

  // After last recorded day
  let last = timeline.days[n - 1]
  if query_day >= last.day_epoch {
    let dt = (query_day - last.day_epoch).to_double()
    return WHRPlayerDay::new(
      query_day,
      r=last.r,
      uncertainty_var=last.uncertainty_var + w2 * dt,
    )
  }

  // Brownian bridge interpolation between day[i] and day[i+1]
  for i = 0; i < n - 1; i = i + 1 {
    let d1 = timeline.days[i]
    let d2 = timeline.days[i + 1]
    if query_day == d1.day_epoch {
      return d1
    }
    if query_day > d1.day_epoch && query_day < d2.day_epoch {
      let span = (d2.day_epoch - d1.day_epoch).to_double()
      let alpha = (query_day - d1.day_epoch).to_double() / span
      let interp_r = (1.0 - alpha) * d1.r + alpha * d2.r
      let bridge_var = alpha * (1.0 - alpha) * span * w2
      let interp_var = (1.0 - alpha) * d1.uncertainty_var +
        alpha * d2.uncertainty_var +
        bridge_var
      return WHRPlayerDay::new(
        query_day,
        r=interp_r,
        uncertainty_var=interp_var,
      )
    }
  }
  last
}

///|
/// Predict winning probability of `player_a` against `player_b` at `query_day`.
pub fn WHREngine::predict_win_at_day(
  self : WHREngine,
  player_a : String,
  player_b : String,
  query_day : Int32,
  handicap_elo_a~ : Double = 0.0,
) -> Double {
  let state_a = self.query_rating_at_day(player_a, query_day)
  let state_b = self.query_rating_at_day(player_b, query_day)
  let h_nat = handicap_elo_a / WHR_ELO_SCALE
  let combined_var = state_a.uncertainty_var + state_b.uncertainty_var
  // Logistic-Gaussian convolution attenuation factor: 1 / sqrt(1 + 3 * var / pi^2)
  let atten = 1.0 / (1.0 + 3.0 * combined_var / (@smath.PI * @smath.PI)).sqrt()
  @smath.logistic_cdf(atten * (state_a.r + h_nat - state_b.r))
}

///|
/// Export current WHR standings sorted descending by latest conservative Elo (Elo - 2 * RD).
pub fn WHREngine::export_standings(
  self : WHREngine,
  z~ : Double = 2.0,
) -> Array[(String, Double, Double, Double)] {
  let rows : Array[(String, Double, Double, Double)] = []
  for t in self.timelines {
    match t.latest_day() {
      Some(d) => {
        let elo = d.elo()
        let rd = d.elo_deviation()
        let conservative = elo - z * rd
        rows.push((t.player_id, elo, rd, conservative))
      }
      None => ()
    }
  }
  let m = rows.length()
  for i = 0; i < m; i = i + 1 {
    for j = 0; j < m - 1 - i; j = j + 1 {
      if rows[j].3 < rows[j + 1].3 {
        let tmp = rows[j]
        rows[j] = rows[j + 1]
        rows[j + 1] = tmp
      }
    }
  }
  rows
}
