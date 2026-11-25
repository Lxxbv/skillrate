///|
/// Configuration options for the classic Elo rating system.
pub struct EloConfig {
  k_factor : Double
  initial_rating : Double
  adaptive_k : Bool
} derive(Eq, Debug)

///|
/// Create an EloConfig with custom parameters.
pub fn EloConfig::new(
  k_factor~ : Double = 32.0,
  initial_rating~ : Double = 1500.0,
  adaptive_k~ : Bool = false,
) -> EloConfig {
  { k_factor, initial_rating, adaptive_k, }
}

///|
/// Default EloConfig with standard K=32.0 and initial rating 1500.0.
pub fn EloConfig::default() -> EloConfig {
  { k_factor: 32.0, initial_rating: 1500.0, adaptive_k: false, }
}

///|
/// Calculate expected score of player A against player B using logistic function:
/// E_A = 1 / (1 + 10^((R_B - R_A) / 400))
pub fn expected_score(rating_a : Double, rating_b : Double) -> Double {
  let exponent = (rating_b - rating_a) / 400.0
  let pow10 = @core_math.pow(10.0, exponent)
  1.0 / (1.0 + pow10)
}

///|
/// Resolve effective K-factor. If adaptive_k is enabled:
/// - Placement phase (matches < 30): K = 40.0
/// - Grandmaster phase (rating >= 2400.0): K = 16.0
/// - Standard phase: K = 32.0 (or configured k_factor)
pub fn resolve_k_factor(
  config : EloConfig,
  rating : Double,
  matches_played~ : Int32 = 30,
) -> Double {
  if !config.adaptive_k {
    return config.k_factor
  }
  if matches_played < 30 {
    40.0
  } else if rating >= 2400.0 {
    16.0
  } else {
    config.k_factor
  }
}

///|
/// Update ratings of two players after a 1v1 match based on GameOutcome.
/// Returns (new_rating_a, new_rating_b).
pub fn rate_1v1(
  rating_a : Double,
  rating_b : Double,
  outcome : @types.GameOutcome,
  config~ : EloConfig = EloConfig::default(),
  matches_a~ : Int32 = 30,
  matches_b~ : Int32 = 30,
) -> (Double, Double) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a

  let exp_a = expected_score(rating_a, rating_b)
  let exp_b = 1.0 - exp_a

  let k_a = resolve_k_factor(config, rating_a, matches_played=matches_a)
  let k_b = resolve_k_factor(config, rating_b, matches_played=matches_b)

  let new_a = rating_a + k_a * (score_a - exp_a)
  let new_b = rating_b + k_b * (score_b - exp_b)

  (new_a, new_b)
}

///|
/// Update ratings of two players with direct numerical scores (e.g. 1.0 for win, 0.5 for draw, 0.0 for loss).
pub fn rate_score(
  rating_a : Double,
  rating_b : Double,
  score_a : Double,
  config~ : EloConfig = EloConfig::default(),
) -> (Double, Double) {
  let exp_a = expected_score(rating_a, rating_b)
  let exp_b = 1.0 - exp_a

  let new_a = rating_a + config.k_factor * (score_a - exp_a)
  let new_b = rating_b + config.k_factor * (1.0 - score_a - exp_b)

  (new_a, new_b)
}

// -----------------------------------------------------------------------------
// Extended Elo Models: Margin of Victory, Home Advantage, Series & Period Batch
// -----------------------------------------------------------------------------

///|
/// Calculate expected score incorporating a home-field or first-mover advantage
/// (e.g., +35 Elo for playing White in Chess, or +65 Elo for home team in sports).
pub fn expected_score_with_advantage(
  rating_a : Double,
  rating_b : Double,
  advantage_a : Double,
) -> Double {
  expected_score(rating_a + advantage_a, rating_b)
}

///|
/// Rate a 1v1 match accounting for home-field / first-mover advantage.
pub fn rate_1v1_with_advantage(
  rating_a : Double,
  rating_b : Double,
  outcome : @types.GameOutcome,
  advantage_a : Double,
  config~ : EloConfig = EloConfig::default(),
) -> (Double, Double) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a
  let exp_a = expected_score_with_advantage(rating_a, rating_b, advantage_a)
  let exp_b = 1.0 - exp_a
  let new_a = rating_a + config.k_factor * (score_a - exp_a)
  let new_b = rating_b + config.k_factor * (score_b - exp_b)
  (new_a, new_b)
}

///|
/// Compute autocorrelation-adjusted Margin-of-Victory (MoV) multiplier
/// (FiveThirtyEight / Elo-MoV formulation):
/// M = ln(|point_diff| + 1) * (2.2 / (0.001 * (R_winner - R_loser) + 2.2))
pub fn mov_multiplier(
  winner_rating : Double,
  loser_rating : Double,
  point_diff : Double,
) -> Double {
  let abs_diff = point_diff.abs()
  if abs_diff <= 0.0 {
    return 1.0
  }
  let log_term = @core_math.ln(abs_diff + 1.0)
  let denom = 0.001 * (winner_rating - loser_rating) + 2.2
  let safe_denom = if denom < 0.25 { 0.25 } else { denom }
  let auto_corr = 2.2 / safe_denom
  let mult = log_term * auto_corr
  if mult < 0.5 {
    0.5
  } else if mult > 3.5 {
    3.5
  } else {
    mult
  }
}

///|
/// Rate a 1v1 match with Margin-of-Victory (score_points_a vs score_points_b) scaling.
pub fn rate_mov_1v1(
  rating_a : Double,
  rating_b : Double,
  points_a : Double,
  points_b : Double,
  config~ : EloConfig = EloConfig::default(),
) -> (Double, Double) {
  let outcome = if points_a > points_b {
    @types.GameOutcome::Win
  } else if points_a < points_b {
    @types.GameOutcome::Loss
  } else {
    @types.GameOutcome::Draw
  }
  let mult = match outcome {
    Win => mov_multiplier(rating_a, rating_b, points_a - points_b)
    Loss => mov_multiplier(rating_b, rating_a, points_b - points_a)
    Draw => 1.0
  }
  let score_a = outcome.to_score()
  let exp_a = expected_score(rating_a, rating_b)
  let delta = config.k_factor * mult * (score_a - exp_a)
  (rating_a + delta, rating_b - delta)
}

///|
/// Rate a player across a multi-match tournament rating period.
/// Each tuple in `matches` is (opponent_rating, actual_score).
pub fn rate_period(
  player_rating : Double,
  matches : Array[(Double, Double)],
  config~ : EloConfig = EloConfig::default(),
  matches_played~ : Int32 = 30,
) -> Double {
  if matches.is_empty() {
    return player_rating
  }
  let k = resolve_k_factor(config, player_rating, matches_played~)
  let mut total_delta = 0.0
  for m in matches {
    let (opp_r, score) = m
    let exp_s = expected_score(player_rating, opp_r)
    total_delta = total_delta + (score - exp_s)
  }
  player_rating + k * total_delta
}

///|
/// Inverse Elo formula: calculate rating difference (R_A - R_B) required
/// to achieve a desired expected win probability p in (0, 1).
pub fn rating_diff_for_win_rate(target_prob : Double) -> Double {
  let clamped = if target_prob <= 0.001 {
    0.001
  } else if target_prob >= 0.999 {
    0.999
  } else {
    target_prob
  }
  -400.0 * (@core_math.ln(1.0 / clamped - 1.0) / 2.302585092994046)
}

///|
/// Calculate exact winning probability for a Best-of-N series (e.g., Bo3, Bo5, Bo7)
/// using negative binomial / independent Bernoulli trial summation.
pub fn predict_series_bo(
  rating_a : Double,
  rating_b : Double,
  best_of : Int32,
) -> Double {
  let p = expected_score(rating_a, rating_b)
  let q = 1.0 - p
  let wins_needed = best_of / 2 + 1
  if wins_needed <= 1 {
    return p
  }

  // Probability that A reaches `wins_needed` before B reaches `wins_needed`:
  // sum_{k = 0}^{wins_needed - 1} C(wins_needed - 1 + k, k) * p^{wins_needed} * q^k
  let mut p_pow = 1.0
  for _ in 0..<wins_needed {
    p_pow = p_pow * p
  }

  let mut total_prob = 0.0
  let mut comb = 1.0
  let mut q_pow = 1.0
  for k = 0; k < wins_needed; k = k + 1 {
    if k > 0 {
      comb = comb * (wins_needed - 1 + k).to_double() / k.to_double()
      q_pow = q_pow * q
    }
    total_prob = total_prob + comb * p_pow * q_pow
  }
  if total_prob > 1.0 {
    1.0
  } else if total_prob < 0.0 {
    0.0
  } else {
    total_prob
  }
}

///|
/// Normalize an array of Elo ratings to eliminate rating inflation or deflation drift,
/// shifting the population mean back to `target_mean` (default 1500.0).
pub fn normalize_pool_inflation(
  ratings : Array[Double],
  target_mean~ : Double = 1500.0,
) -> Array[Double] {
  let n = ratings.length()
  if n == 0 {
    return []
  }
  let mut sum = 0.0
  for r in ratings {
    sum = sum + r
  }
  let current_mean = sum / n.to_double()
  let shift = target_mean - current_mean
  let normalized : Array[Double] = []
  for r in ratings {
    normalized.push(r + shift)
  }
  normalized
}
