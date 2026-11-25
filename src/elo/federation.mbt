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

///|
/// Rate a player across a tournament period under DWZ rules.
pub fn rate_dwz_period(
  player : DWZRating,
  matches : Array[(DWZRating, Double)],
  age_base~ : Double = 10.0,
) -> DWZRating {
  let n = matches.length()
  if n == 0 {
    return player
  }
  let mut actual_score = 0.0
  let mut expected_sum = 0.0
  for m in matches {
    let (opp, s) = m
    actual_score = actual_score + s
    expected_sum = expected_sum + predict_win_dwz(player, opp)
  }
  let e_coeff = dwz_development_coeff(player.rating, player.index, age_base~)
  let denom = e_coeff + n.to_double()
  let new_r = player.rating + 800.0 / denom * (actual_score - expected_sum)
  DWZRating::new(rating=new_r, index=player.index + 1)
}

///|
/// Rate a player across a tournament period under ECF rules.
pub fn rate_ecf_period(
  player : ECFRating,
  matches : Array[(ECFRating, Double)],
  period_games~ : Double = 30.0,
) -> ECFRating {
  let mut cur = player
  for m in matches {
    let (opp, s) = m
    let outcome = @types.GameOutcome::from_score(s)
    let (updated, _) = rate_ecf_1v1(cur, opp, outcome, period_games~)
    cur = updated
  }
  cur
}

// -----------------------------------------------------------------------------
// Ingo Rating System (Anton Hoesslinger 1948, German Chess Federation Predecessor)
// -----------------------------------------------------------------------------

///|
/// Ingo rating representation.
/// Note: In the Ingo system, LOWER numbers indicate STRONGER skill!
/// Standard conversion: Elo = 2840 - 8 * Ingo (default Ingo 167.5 == 1500 Elo).
pub(all) struct IngoRating {
  rating : Double
  age : Int32
} derive(Eq, Debug)

///|
/// Construct a new IngoRating (default 167.5 ~ 1500 Elo, age=25).
pub fn IngoRating::new(
  rating~ : Double = 167.5,
  age~ : Int32 = 25,
) -> IngoRating {
  { rating, age, }
}

///|
/// Default IngoRating (167.5).
pub fn IngoRating::default() -> IngoRating {
  { rating: 167.5, age: 25, }
}

///|
/// Convert Ingo rating to standard FIDE Elo: Elo = 2840 - 8 * Ingo.
pub fn IngoRating::to_elo(self : IngoRating) -> Double {
  2840.0 - 8.0 * self.rating
}

///|
/// Construct an IngoRating from standard FIDE Elo: Ingo = (2840 - Elo) / 8.
pub fn IngoRating::from_elo(elo : Double, age~ : Int32 = 25) -> IngoRating {
  { rating: (2840.0 - elo) / 8.0, age, }
}

///|
/// Resolve Ingo development factor j based on player age:
/// under 15 -> 10.0, 15..20 -> 15.0, over 20 -> 20.0.
pub fn IngoRating::development_factor(self : IngoRating) -> Double {
  if self.age < 15 {
    10.0
  } else if self.age <= 20 {
    15.0
  } else {
    20.0
  }
}

///|
/// Predict winning probability of Player A against Player B in Ingo:
/// E = 0.5 + (R_B - R_A) / 100, clamped to [0.0, 1.0].
pub fn predict_win_ingo(a : IngoRating, b : IngoRating) -> Double {
  let raw = 0.5 + (b.rating - a.rating) / 100.0
  if raw < 0.01 {
    0.01
  } else if raw > 0.99 {
    0.99
  } else {
    raw
  }
}

///|
/// Rate a 1v1 contest under the Ingo system:
///Perf_A = R_B - 50 * (2 * S_A - 1)
///R_A' = (Perf_A * 1 + R_A * j) / (1 + j)
pub fn rate_ingo_1v1(
  a : IngoRating,
  b : IngoRating,
  outcome : @types.GameOutcome,
) -> (IngoRating, IngoRating) {
  let s_a = outcome.to_score()
  let s_b = 1.0 - s_a

  // Lower Ingo is better, so winning reduces Ingo score by 50 relative to opponent
  let perf_a = b.rating - 50.0 * (2.0 * s_a - 1.0)
  let perf_b = a.rating - 50.0 * (2.0 * s_b - 1.0)

  let j_a = a.development_factor()
  let j_b = b.development_factor()

  let new_a = (perf_a + a.rating * j_a) / (1.0 + j_a)
  let new_b = (perf_b + b.rating * j_b) / (1.0 + j_b)

  (
    IngoRating::new(rating=new_a, age=a.age),
    IngoRating::new(rating=new_b, age=b.age),
  )
}

// -----------------------------------------------------------------------------
// USCF (United States Chess Federation) Rating System
// -----------------------------------------------------------------------------

///|
/// USCF rating representation with effective game count and floor protection.
pub(all) struct USCFRating {
  rating : Double
  games_played : Int32
  peak_rating : Double
} derive(Eq, Debug)

///|
/// Construct a new USCFRating.
pub fn USCFRating::new(
  rating~ : Double = 1500.0,
  games_played~ : Int32 = 30,
  peak_rating~ : Double = 1500.0,
) -> USCFRating {
  let p = if peak_rating < rating { rating } else { peak_rating }
  { rating, games_played, peak_rating: p, }
}

///|
/// Default USCFRating (1500.0).
pub fn USCFRating::default() -> USCFRating {
  { rating: 1500.0, games_played: 30, peak_rating: 1500.0, }
}

///|
/// Compute USCF effective number of games N_e = min(games_played, 50).
pub fn USCFRating::effective_games(self : USCFRating) -> Double {
  let g = if self.games_played < 1 {
    1
  } else if self.games_played > 50 {
    50
  } else {
    self.games_played
  }
  g.to_double()
}

///|
/// Compute official USCF rating floor (100-point increments below peak, minimum 100).
pub fn USCFRating::rating_floor(self : USCFRating) -> Double {
  if self.peak_rating < 1400.0 {
    100.0
  } else {
    let raw_floor = self.peak_rating - 200.0
    let stepped = (raw_floor / 100.0).to_int().to_double() * 100.0
    if stepped < 100.0 {
      100.0
    } else {
      stepped
    }
  }
}

///|
/// Predict winning probability in USCF.
pub fn predict_win_uscf(a : USCFRating, b : USCFRating) -> Double {
  expected_score(a.rating, b.rating)
}

///|
/// Rate a 1v1 contest under USCF rules with dynamic K = 800 / (N_e + 1) and floor clamping.
pub fn rate_uscf_1v1(
  a : USCFRating,
  b : USCFRating,
  outcome : @types.GameOutcome,
) -> (USCFRating, USCFRating) {
  let s_a = outcome.to_score()
  let s_b = 1.0 - s_a
  let exp_a = predict_win_uscf(a, b)
  let exp_b = 1.0 - exp_a

  let k_a = 800.0 / (a.effective_games() + 1.0)
  let k_b = 800.0 / (b.effective_games() + 1.0)

  let raw_a = a.rating + k_a * (s_a - exp_a)
  let raw_b = b.rating + k_b * (s_b - exp_b)

  let floor_a = a.rating_floor()
  let floor_b = b.rating_floor()

  let final_a = if raw_a < floor_a { floor_a } else { raw_a }
  let final_b = if raw_b < floor_b { floor_b } else { raw_b }

  (
    USCFRating::new(
      rating=final_a,
      games_played=a.games_played + 1,
      peak_rating=a.peak_rating,
    ),
    USCFRating::new(
      rating=final_b,
      games_played=b.games_played + 1,
      peak_rating=b.peak_rating,
    ),
  )
}

///|
/// Rate a player across a multi-round USCF tournament including the USCF bonus threshold B=14.0.
pub fn rate_uscf_tournament(
  player : USCFRating,
  matches : Array[(USCFRating, Double)],
  bonus_threshold~ : Double = 14.0,
) -> USCFRating {
  let m = matches.length()
  if m == 0 {
    return player
  }
  let mf = m.to_double()
  let ne = player.effective_games()
  let k = 800.0 / (ne + mf)

  let mut score_sum = 0.0
  let mut exp_sum = 0.0
  for item in matches {
    let (opp, s) = item
    score_sum = score_sum + s
    exp_sum = exp_sum + predict_win_uscf(player, opp)
  }

  let base_delta = k * (score_sum - exp_sum)
  let bonus = if m >= 3 && base_delta > bonus_threshold * mf.sqrt() {
    base_delta - bonus_threshold * mf.sqrt()
  } else {
    0.0
  }

  let raw_rating = player.rating + base_delta + bonus
  let floor = player.rating_floor()
  let clamped = if raw_rating < floor { floor } else { raw_rating }
  USCFRating::new(
    rating=clamped,
    games_played=player.games_played + m,
    peak_rating=player.peak_rating,
  )
}

// -----------------------------------------------------------------------------
// FIDE Official Rating Regulations (K=40/20/10 & Virtual Draw Initial Rating)
// -----------------------------------------------------------------------------

///|
/// Official FIDE player rating record.
pub(all) struct FIDERating {
  rating : Double
  games_played : Int32
  ever_reached_2400 : Bool
  is_under_18 : Bool
} derive(Eq, Debug)

///|
/// Construct a FIDERating record.
pub fn FIDERating::new(
  rating~ : Double = 1500.0,
  games_played~ : Int32 = 30,
  ever_reached_2400~ : Bool = false,
  is_under_18~ : Bool = false,
) -> FIDERating {
  let reached = ever_reached_2400 || rating >= 2400.0
  { rating, games_played, ever_reached_2400: reached, is_under_18, }
}

///|
/// Resolve official FIDE development coefficient K:
/// - K = 40 for new players (< 30 games) or U18 players under 2300
/// - K = 10 for players who have ever reached 2400
/// - K = 20 for all other standard players
pub fn FIDERating::k_factor(self : FIDERating) -> Double {
  if self.games_played < 30 || (self.is_under_18 && self.rating < 2300.0) {
    40.0
  } else if self.ever_reached_2400 || self.rating >= 2400.0 {
    10.0
  } else {
    20.0
  }
}

///|
/// Rate a 1v1 game under FIDE regulations (including the FIDE 400-point difference cap).
pub fn rate_fide_1v1(
  a : FIDERating,
  b : FIDERating,
  outcome : @types.GameOutcome,
) -> (FIDERating, FIDERating) {
  let s_a = outcome.to_score()
  let s_b = 1.0 - s_a

  // FIDE 400-point rule: rating difference > 400 is treated as 400
  let diff_ab = if b.rating - a.rating > 400.0 {
    400.0
  } else if b.rating - a.rating < -400.0 {
    -400.0
  } else {
    b.rating - a.rating
  }
  let exp_a = 1.0 / (1.0 + @core_math.pow(10.0, diff_ab / 400.0))
  let exp_b = 1.0 - exp_a

  let new_a = a.rating + a.k_factor() * (s_a - exp_a)
  let new_b = b.rating + b.k_factor() * (s_b - exp_b)

  (
    FIDERating::new(
      rating=new_a,
      games_played=a.games_played + 1,
      ever_reached_2400=a.ever_reached_2400,
      is_under_18=a.is_under_18,
    ),
    FIDERating::new(
      rating=new_b,
      games_played=b.games_played + 1,
      ever_reached_2400=b.ever_reached_2400,
      is_under_18=b.is_under_18,
    ),
  )
}

///|
/// Official FIDE 2024 Initial Rating formula for an unrated player:
/// Appends two virtual draws against hypothetical 1800-rated opponents.
pub fn calculate_initial_fide_rating(
  opponent_ratings : Array[Double],
  total_score : Double,
) -> Double {
  let n = opponent_ratings.length()
  if n == 0 {
    return 1500.0
  }
  let mut sum_opp = 3600.0 // 2 virtual opponents at 1800
  for r in opponent_ratings {
    sum_opp = sum_opp + r
  }
  let total_games = (n + 2).to_double()
  let avg_opp = sum_opp / total_games
  let adj_score = total_score + 1.0 // two virtual draws = +1.0
  let p = adj_score / total_games
  let safe_p = if p <= 0.01 { 0.01 } else if p >= 0.99 { 0.99 } else { p }
  let dp = -400.0 * (@core_math.ln((1.0 - safe_p) / safe_p) / 2.302585092994046)
  avg_opp + dp
}
