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
