///|
/// Scale conversion factor between Glicko original scale and Glicko-2 internal scale.
/// Approximately 400 / ln(10) = 173.7177927613.
pub const SCALE : Double = 173.7177927613

///|
/// A participant's rating in the Glicko-2 system.
pub(all) struct Glicko2Rating {
  rating : Double
  deviation : Double
  volatility : Double
} derive(Eq, Debug)

///|
/// Construct a new Glicko2Rating.
pub fn Glicko2Rating::new(
  rating : Double,
  deviation : Double,
  volatility : Double,
) -> Glicko2Rating {
  { rating, deviation, volatility, }
}

///|
/// Default Glicko-2 rating for unrated players (1500.0, 350.0, 0.06).
pub fn Glicko2Rating::default() -> Glicko2Rating {
  { rating: 1500.0, deviation: 350.0, volatility: 0.06, }
}

///|
/// Convert to generic Rating domain model.
pub fn Glicko2Rating::to_rating(self : Glicko2Rating) -> @types.Rating {
  @types.Rating::new(self.rating, self.deviation)
}

///|
/// Create Glicko2Rating from generic Rating domain model.
pub fn Glicko2Rating::from_rating(
  r : @types.Rating,
  volatility~ : Double = 0.06,
) -> Glicko2Rating {
  { rating: r.mu, deviation: r.sigma, volatility, }
}

///|
/// Conservative rating: rating - z * deviation (e.g. 95% lower bound with z=2.0).
pub fn Glicko2Rating::ordinal(
  self : Glicko2Rating,
  z~ : Double = 2.0,
) -> Double {
  self.rating - z * self.deviation
}

///|
/// System configuration for Glicko-2 calculation.
pub(all) struct Glicko2Config {
  tau : Double
  tolerance : Double
} derive(Eq, Debug)

///|
/// Create a custom Glicko2Config.
pub fn Glicko2Config::new(
  tau~ : Double = 0.5,
  tolerance~ : Double = 1.0e-6,
) -> Glicko2Config {
  { tau, tolerance, }
}

///|
/// Default Glicko2Config (tau=0.5, tolerance=1.0e-6).
pub fn Glicko2Config::default() -> Glicko2Config {
  { tau: 0.5, tolerance: 1.0e-6, }
}

///|
/// Single match opponent entry in a Glicko-2 rating period.
pub(all) struct OpponentMatch {
  opponent : Glicko2Rating
  score : Double // 1.0 = win, 0.5 = draw, 0.0 = loss
} derive(Eq, Debug)

///|
/// Construct an opponent match entry.
pub fn OpponentMatch::new(
  opponent : Glicko2Rating,
  score : Double,
) -> OpponentMatch {
  { opponent, score, }
}

///|
/// Auxiliary function g(phi):
/// g(phi) = 1 / sqrt(1 + 3 * phi^2 / pi^2)
pub fn g(phi : Double) -> Double {
  let pi = @smath.PI
  let pi_sq = pi * pi
  let denom = (1.0 + 3.0 * phi * phi / pi_sq).sqrt()
  1.0 / denom
}

///|
/// Auxiliary expectation function E(mu, mu_j, phi_j):
/// E(mu, mu_j, phi_j) = 1 / (1 + exp(-g(phi_j) * (mu - mu_j)))
pub fn expected_score(mu : Double, mu_j : Double, phi_j : Double) -> Double {
  let g_val = g(phi_j)
  let exponent = -g_val * (mu - mu_j)
  1.0 / (1.0 + @core_math.exp(exponent))
}

///|
/// Predict winning probability of Player A beating Player B in Glicko-2.
pub fn predict_win(a : Glicko2Rating, b : Glicko2Rating) -> Double {
  let mu_a = (a.rating - 1500.0) / SCALE
  let mu_b = (b.rating - 1500.0) / SCALE
  let phi_b = b.deviation / SCALE
  expected_score(mu_a, mu_b, phi_b)
}

///|
/// Calculate updated Glicko-2 rating after a rating period with m opponents.
pub fn rate_period(
  player : Glicko2Rating,
  matches : Array[OpponentMatch],
  config~ : Glicko2Config = Glicko2Config::default(),
) -> Glicko2Rating {
  // If no matches were played, apply inactivity deviation inflation
  if matches.length() == 0 {
    let phi = player.deviation / SCALE
    let phi_prime = (phi * phi + player.volatility * player.volatility).sqrt()
    return {
      rating: player.rating,
      deviation: phi_prime * SCALE,
      volatility: player.volatility,
    }
  }

  // Step 2: Convert to Glicko-2 internal scale
  let mu = (player.rating - 1500.0) / SCALE
  let phi = player.deviation / SCALE
  let sigma = player.volatility

  // Step 3 & 4: Compute variance v and delta
  let mut v_inv = 0.0
  let mut delta_sum = 0.0

  for m in matches {
    let mu_j = (m.opponent.rating - 1500.0) / SCALE
    let phi_j = m.opponent.deviation / SCALE
    let g_j = g(phi_j)
    let e_j = expected_score(mu, mu_j, phi_j)

    v_inv = v_inv + g_j * g_j * e_j * (1.0 - e_j)
    delta_sum = delta_sum + g_j * (m.score - e_j)
  }

  let v = 1.0 / v_inv
  let delta = v * delta_sum

  // Step 5: Solve for new volatility sigma'
  let a = @core_math.ln(sigma * sigma)
  let tau = config.tau
  let tau_sq = tau * tau
  let phi_sq = phi * phi

  let f = fn(x : Double) -> Double {
    let exp_x = @core_math.exp(x)
    let d = phi_sq + v + exp_x
    let num = exp_x * (delta * delta - phi_sq - v - exp_x)
    let term1 = num / (2.0 * d * d)
    let term2 = (x - a) / tau_sq
    term1 - term2
  }

  let mut a_bracket = a
  let mut b_bracket = if delta * delta > phi_sq + v {
    @core_math.ln(delta * delta - phi_sq - v)
  } else {
    let mut k = 1.0
    while f(a - k * tau) < 0.0 {
      k = k + 1.0
    }
    a - k * tau
  }

  let mut fa = f(a_bracket)
  let mut fb = f(b_bracket)

  while (b_bracket - a_bracket).abs() > config.tolerance {
    let denom = fb - fa
    let c = if denom.abs() < 1.0e-14 {
      (a_bracket + b_bracket) / 2.0
    } else {
      a_bracket + (a_bracket - b_bracket) * fa / denom
    }
    let fc = f(c)
    if fc * fb <= 0.0 {
      a_bracket = b_bracket
      fa = fb
    } else {
      fa = fa * 0.5
    }
    b_bracket = c
    fb = fc
  }

  let sigma_prime = @core_math.exp(a_bracket / 2.0)

  // Step 6: Update rating deviation to pre-period value
  let phi_star = (phi_sq + sigma_prime * sigma_prime).sqrt()

  // Step 7: Update phi' and mu'
  let phi_prime = 1.0 / (1.0 / (phi_star * phi_star) + 1.0 / v).sqrt()
  let mu_prime = mu + phi_prime * phi_prime * delta_sum

  // Step 8: Convert back to original scale
  {
    rating: mu_prime * SCALE + 1500.0,
    deviation: phi_prime * SCALE,
    volatility: sigma_prime,
  }
}

///|
/// Update two players after a single 1v1 match in Glicko-2.
pub fn rate_1v1(
  player_a : Glicko2Rating,
  player_b : Glicko2Rating,
  outcome : @types.GameOutcome,
  config~ : Glicko2Config = Glicko2Config::default(),
) -> (Glicko2Rating, Glicko2Rating) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a

  let match_for_a = [OpponentMatch::new(player_b, score_a)]
  let match_for_b = [OpponentMatch::new(player_a, score_b)]

  let new_a = rate_period(player_a, match_for_a, config~)
  let new_b = rate_period(player_b, match_for_b, config~)

  (new_a, new_b)
}

// -----------------------------------------------------------------------------
// Extended Glicko-2 Capabilities: Multi-Period Decay, Teams, Volatility Analytics
// -----------------------------------------------------------------------------

///|
/// Apply inactivity rating deviation growth over `periods` unplayed rating periods:
/// phi_new = sqrt(phi^2 + periods * sigma^2)
pub fn step_inactivity_periods(
  player : Glicko2Rating,
  periods~ : Int32 = 1,
  max_deviation~ : Double = 350.0,
) -> Glicko2Rating {
  if periods <= 0 {
    return player
  }
  let phi = player.deviation / SCALE
  let sigma = player.volatility
  let pf = periods.to_double()
  let phi_prime = (phi * phi + pf * sigma * sigma).sqrt()
  let new_rd = phi_prime * SCALE
  let clamped_rd = if new_rd > max_deviation { max_deviation } else { new_rd }
  {
    rating: player.rating,
    deviation: clamped_rd,
    volatility: player.volatility,
  }
}

///|
/// Compute a 95% (or custom z-score) confidence interval [r - z*RD, r + z*RD].
pub fn Glicko2Rating::confidence_interval(
  self : Glicko2Rating,
  z~ : Double = 1.96,
) -> @types.ConfidenceInterval {
  @types.ConfidenceInterval::from_gaussian(
    self.rating,
    self.deviation,
    z_score=z,
  )
}

///|
/// Check whether a player's volatility sigma exceeds an anomaly threshold
/// (indicating erratic performance, account sharing, or rapid skill jump).
pub fn Glicko2Rating::is_volatile_anomaly(
  self : Glicko2Rating,
  threshold~ : Double = 0.085,
) -> Bool {
  self.volatility >= threshold
}

///|
/// Predict expected match score in Glicko-2 taking into account both players'
/// combined rating deviations: g(sqrt(phi_A^2 + phi_B^2)).
pub fn predict_win_combined(a : Glicko2Rating, b : Glicko2Rating) -> Double {
  let mu_a = (a.rating - 1500.0) / SCALE
  let mu_b = (b.rating - 1500.0) / SCALE
  let phi_a = a.deviation / SCALE
  let phi_b = b.deviation / SCALE
  let phi_comb = (phi_a * phi_a + phi_b * phi_b).sqrt()
  expected_score(mu_a, mu_b, phi_comb)
}

///|
/// Predict winning probability with a rating advantage / komi for Player A.
pub fn predict_win_with_advantage(
  a : Glicko2Rating,
  b : Glicko2Rating,
  advantage_a : Double,
) -> Double {
  let shifted_a = Glicko2Rating::new(
    a.rating + advantage_a,
    a.deviation,
    a.volatility,
  )
  predict_win_combined(shifted_a, b)
}

///|
/// Rate a 1v1 match in Glicko-2 with a first-mover / home-field rating advantage.
pub fn rate_1v1_with_advantage(
  player_a : Glicko2Rating,
  player_b : Glicko2Rating,
  outcome : @types.GameOutcome,
  advantage_a : Double,
  config~ : Glicko2Config = Glicko2Config::default(),
) -> (Glicko2Rating, Glicko2Rating) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a

  let eff_b = Glicko2Rating::new(
    player_b.rating - advantage_a,
    player_b.deviation,
    player_b.volatility,
  )
  let eff_a = Glicko2Rating::new(
    player_a.rating + advantage_a,
    player_a.deviation,
    player_a.volatility,
  )

  let new_a = rate_period(
    player_a,
    [OpponentMatch::new(eff_b, score_a)],
    config~,
  )
  let new_b = rate_period(
    player_b,
    [OpponentMatch::new(eff_a, score_b)],
    config~,
  )
  (new_a, new_b)
}

///|
/// Compute composite team Glicko-2 rating (mean rating, RMS deviation, RMS volatility).
pub fn composite_team_glicko2(team : Array[Glicko2Rating]) -> Glicko2Rating {
  let n = team.length()
  if n == 0 {
    return Glicko2Rating::default()
  }
  let mut sum_r = 0.0
  let mut sum_rd_sq = 0.0
  let mut sum_vol_sq = 0.0
  for p in team {
    sum_r = sum_r + p.rating
    sum_rd_sq = sum_rd_sq + p.deviation * p.deviation
    sum_vol_sq = sum_vol_sq + p.volatility * p.volatility
  }
  let nf = n.to_double()
  Glicko2Rating::new(
    sum_r / nf,
    (sum_rd_sq / nf).sqrt(),
    (sum_vol_sq / nf).sqrt(),
  )
}

///|
/// Rate a Two-Team match under Glicko-2 with variance-proportional skill attribution.
pub fn rate_two_teams_glicko2(
  team_a : Array[Glicko2Rating],
  team_b : Array[Glicko2Rating],
  outcome : @types.GameOutcome,
  config~ : Glicko2Config = Glicko2Config::default(),
) -> (Array[Glicko2Rating], Array[Glicko2Rating]) {
  if team_a.is_empty() || team_b.is_empty() {
    return (team_a, team_b)
  }
  let comp_a = composite_team_glicko2(team_a)
  let comp_b = composite_team_glicko2(team_b)
  let (new_comp_a, new_comp_b) = rate_1v1(comp_a, comp_b, outcome, config~)

  let delta_a = new_comp_a.rating - comp_a.rating
  let rd_ratio_a = if comp_a.deviation > 1.0e-6 {
    new_comp_a.deviation / comp_a.deviation
  } else {
    1.0
  }
  let vol_ratio_a = if comp_a.volatility > 1.0e-6 {
    new_comp_a.volatility / comp_a.volatility
  } else {
    1.0
  }

  let mut sum_var_a = 0.0
  for p in team_a {
    sum_var_a = sum_var_a + p.deviation * p.deviation
  }
  let mean_var_a = sum_var_a / team_a.length().to_double()

  let out_a : Array[Glicko2Rating] = []
  for p in team_a {
    let w = if mean_var_a > 1.0e-6 {
      p.deviation * p.deviation / mean_var_a
    } else {
      1.0
    }
    out_a.push(
      Glicko2Rating::new(
        p.rating + delta_a * w,
        p.deviation * rd_ratio_a,
        p.volatility * vol_ratio_a,
      ),
    )
  }

  let delta_b = new_comp_b.rating - comp_b.rating
  let rd_ratio_b = if comp_b.deviation > 1.0e-6 {
    new_comp_b.deviation / comp_b.deviation
  } else {
    1.0
  }
  let vol_ratio_b = if comp_b.volatility > 1.0e-6 {
    new_comp_b.volatility / comp_b.volatility
  } else {
    1.0
  }

  let mut sum_var_b = 0.0
  for p in team_b {
    sum_var_b = sum_var_b + p.deviation * p.deviation
  }
  let mean_var_b = sum_var_b / team_b.length().to_double()

  let out_b : Array[Glicko2Rating] = []
  for p in team_b {
    let w = if mean_var_b > 1.0e-6 {
      p.deviation * p.deviation / mean_var_b
    } else {
      1.0
    }
    out_b.push(
      Glicko2Rating::new(
        p.rating + delta_b * w,
        p.deviation * rd_ratio_b,
        p.volatility * vol_ratio_b,
      ),
    )
  }

  (out_a, out_b)
}

///|
/// Rate a Free-For-All (FFA) contest under Glicko-2 by treating all pairwise placement outcomes
/// as simultaneous matches within a single Glicko-2 rating period.
pub fn rate_ffa_glicko2(
  players : Array[Glicko2Rating],
  ranks : Array[Int32],
  config~ : Glicko2Config = Glicko2Config::default(),
) -> Array[Glicko2Rating] {
  let n = players.length()
  if n <= 1 {
    return players
  }
  let results : Array[Glicko2Rating] = []
  for i = 0; i < n; i = i + 1 {
    let r_i = if i < ranks.length() { ranks[i] } else { i + 1 }
    let matches_i : Array[OpponentMatch] = []
    for j = 0; j < n; j = j + 1 {
      if i != j {
        let r_j = if j < ranks.length() { ranks[j] } else { j + 1 }
        let score = if r_i < r_j { 1.0 } else if r_i > r_j { 0.0 } else { 0.5 }
        matches_i.push(OpponentMatch::new(players[j], score))
      }
    }
    results.push(rate_period(players[i], matches_i, config~))
  }
  results
}

///|
/// Evaluate a simultaneous tournament period for an array of Glicko-2 players
/// given match tuples (player_i_idx, player_j_idx, score_for_i).
pub fn evaluate_tournament_period(
  players : Array[Glicko2Rating],
  matches : Array[(Int32, Int32, Double)],
  config~ : Glicko2Config = Glicko2Config::default(),
) -> Array[Glicko2Rating] {
  let n = players.length()
  if n == 0 {
    return []
  }
  let buckets : Array[Array[OpponentMatch]] = []
  for _ in 0..<n {
    buckets.push([])
  }
  for m in matches {
    let (i, j, s_i) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      buckets[i].push(OpponentMatch::new(players[j], s_i))
      buckets[j].push(OpponentMatch::new(players[i], 1.0 - s_i))
    }
  }
  let updated : Array[Glicko2Rating] = []
  for i = 0; i < n; i = i + 1 {
    updated.push(rate_period(players[i], buckets[i], config~))
  }
  updated
}
