///|
/// DWZ (Deutsche Wertungszahl) rating representation used by the German Chess Federation.
/// Tracks both the skill rating and the evaluation index (number of tournaments evaluated).
pub(all) struct DWZRating {
  rating : Double
  index : Int32
} derive(Eq, Debug)

///|
/// Construct a new DWZRating (default rating=1500.0, index=1).
pub fn DWZRating::new(
  rating~ : Double = 1500.0,
  index~ : Int32 = 1,
) -> DWZRating {
  { rating, index, }
}

///|
/// Default uncalibrated DWZRating.
pub fn DWZRating::default() -> DWZRating {
  { rating: 1500.0, index: 1, }
}

///|
/// Predict winning probability in DWZ using Gaussian normal CDF:
/// P(D) = Phi((R_A - R_B) / (200 * sqrt(2)))
pub fn predict_win_dwz(a : DWZRating, b : DWZRating) -> Double {
  let denom = 282.84271247461903
  @smath.normal_cdf((a.rating - b.rating) / denom)
}

///|
/// Compute DWZ development coefficient E based on current rating and age base J.
pub fn dwz_development_coeff(
  rating : Double,
  index : Int32,
  age_base~ : Double = 10.0,
) -> Double {
  let ratio = rating / 1000.0
  let e0 = ratio * ratio * ratio * ratio + age_base
  let max_e = if index < 6 { (index * 5).to_double() } else { 30.0 }
  let safe_max = if max_e < 5.0 { 5.0 } else { max_e }
  if e0 < 5.0 {
    5.0
  } else if e0 > safe_max {
    safe_max
  } else {
    e0
  }
}

///|
/// Rate a 1v1 match using the official DWZ formula:
/// R' = R + (800 / (E + 1)) * (S - E(S))
pub fn rate_dwz_1v1(
  a : DWZRating,
  b : DWZRating,
  outcome : @types.GameOutcome,
  age_base~ : Double = 10.0,
) -> (DWZRating, DWZRating) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a

  let exp_a = predict_win_dwz(a, b)
  let exp_b = 1.0 - exp_a

  let e_a = dwz_development_coeff(a.rating, a.index, age_base~)
  let e_b = dwz_development_coeff(b.rating, b.index, age_base~)

  let new_r_a = a.rating + 800.0 / (e_a + 1.0) * (score_a - exp_a)
  let new_r_b = b.rating + 800.0 / (e_b + 1.0) * (score_b - exp_b)

  (
    DWZRating::new(rating=new_r_a, index=a.index + 1),
    DWZRating::new(rating=new_r_b, index=b.index + 1),
  )
}

// -----------------------------------------------------------------------------
// ECF (English Chess Federation) Grading System
// -----------------------------------------------------------------------------

///|
/// ECF (English Chess Federation) rating representation (default 100.0 ~ 1450 Elo).
pub(all) struct ECFRating {
  rating : Double
} derive(Eq, Debug)

///|
/// Construct a new ECFRating.
pub fn ECFRating::new(rating~ : Double = 100.0) -> ECFRating {
  { rating, }
}

///|
/// Default ECFRating (100.0).
pub fn ECFRating::default() -> ECFRating {
  { rating: 100.0, }
}

///|
/// Convert ECF grade to FIDE Elo rating: Elo = 7.5 * ECF + 700.
pub fn ECFRating::to_elo(self : ECFRating) -> Double {
  self.rating * 7.5 + 700.0
}

///|
/// Convert FIDE Elo rating to ECF grade: ECF = (Elo - 700) / 7.5.
pub fn ECFRating::from_elo(elo : Double) -> ECFRating {
  { rating: (elo - 700.0) / 7.5, }
}

///|
/// Predict winning probability between two ECF ratings.
pub fn predict_win_ecf(a : ECFRating, b : ECFRating) -> Double {
  expected_score(a.to_elo(), b.to_elo())
}

///|
/// Rate a 1v1 match under the ECF 40-point cap / 50-point bonus rolling average system.
pub fn rate_ecf_1v1(
  a : ECFRating,
  b : ECFRating,
  outcome : @types.GameOutcome,
  period_games~ : Double = 30.0,
) -> (ECFRating, ECFRating) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a

  // Clamp effective opponent grade difference within [-40, +40]
  let diff_ab = b.rating - a.rating
  let eff_b = if diff_ab > 40.0 {
    a.rating + 40.0
  } else if diff_ab < -40.0 {
    a.rating - 40.0
  } else {
    b.rating
  }

  let diff_ba = a.rating - b.rating
  let eff_a = if diff_ba > 40.0 {
    b.rating + 40.0
  } else if diff_ba < -40.0 {
    b.rating - 40.0
  } else {
    a.rating
  }

  let perf_a = eff_b + 50.0 * (2.0 * score_a - 1.0)
  let perf_b = eff_a + 50.0 * (2.0 * score_b - 1.0)

  let new_a = a.rating + (perf_a - a.rating) / period_games
  let new_b = b.rating + (perf_b - b.rating) / period_games

  (ECFRating::new(rating=new_a), ECFRating::new(rating=new_b))
}
