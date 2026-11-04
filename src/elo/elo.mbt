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
