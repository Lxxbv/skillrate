///|
/// Constant q = ln(10) / 400 ~ 0.00575646273248511421
pub const Q : Double = 0.00575646273248511421

///|
/// Classic Glicko-1 rating representation.
pub(all) struct GlickoRating {
  rating : Double
  deviation : Double
} derive(Eq, Debug)

///|
/// Construct a new GlickoRating.
pub fn GlickoRating::new(
  rating~ : Double = 1500.0,
  deviation~ : Double = 350.0,
) -> GlickoRating {
  { rating, deviation, }
}

///|
/// Default GlickoRating with rating 1500.0 and uncalibrated deviation 350.0.
pub fn GlickoRating::default() -> GlickoRating {
  { rating: 1500.0, deviation: 350.0, }
}

///|
/// Conservative rating estimate: rating - z * deviation (default 95% bound, z=2.0).
pub fn GlickoRating::ordinal(self : GlickoRating, z~ : Double = 2.0) -> Double {
  self.rating - z * self.deviation
}

///|
/// Configuration options for the classic Glicko-1 system.
pub(all) struct GlickoConfig {
  c : Double
  min_deviation : Double
  max_deviation : Double
} derive(Eq, Debug)

///|
/// Create GlickoConfig with specified parameters.
pub fn GlickoConfig::new(
  c~ : Double = 63.2,
  min_deviation~ : Double = 30.0,
  max_deviation~ : Double = 350.0,
) -> GlickoConfig {
  { c, min_deviation, max_deviation, }
}

///|
/// Default GlickoConfig with c=63.2 (typical for weekly/monthly rating periods).
pub fn GlickoConfig::default() -> GlickoConfig {
  { c: 63.2, min_deviation: 30.0, max_deviation: 350.0, }
}

///|
/// An opponent match record in a Glicko rating period.
pub(all) struct GlickoOpponent {
  rating : GlickoRating
  score : Double
} derive(Eq, Debug)

///|
/// Construct an opponent match record.
pub fn GlickoOpponent::new(
  rating : GlickoRating,
  score : Double,
) -> GlickoOpponent {
  { rating, score, }
}

///|
/// Glicko weighting function g(RD) = 1 / sqrt(1 + 3 * q^2 * RD^2 / pi^2).
pub fn g(rd : Double) -> Double {
  let pi = @smath.PI
  let denom = (1.0 + 3.0 * Q * Q * rd * rd / (pi * pi)).sqrt()
  1.0 / denom
}

///|
/// Expected game score of a player against an opponent:
/// E(s) = 1 / (1 + 10^(-g(RD_j) * (r - r_j) / 400))
pub fn expected_score(
  player_rating : Double,
  opponent_rating : Double,
  opponent_rd : Double,
) -> Double {
  let g_val = g(opponent_rd)
  let exponent = -g_val * (player_rating - opponent_rating) / 400.0
  let pow10 = @core_math.exp(exponent * 2.302585092994046)
  1.0 / (1.0 + pow10)
}

///|
/// Update a player's rating deviation over an inactive period of time:
/// RD' = min(sqrt(RD^2 + c^2 * t), max_deviation)
pub fn step_inactivity(
  player : GlickoRating,
  periods~ : Double = 1.0,
  config~ : GlickoConfig = GlickoConfig::default(),
) -> GlickoRating {
  let new_rd2 = player.deviation * player.deviation +
    config.c * config.c * periods
  let raw_rd = new_rd2.sqrt()
  let bounded_rd = if raw_rd > config.max_deviation {
    config.max_deviation
  } else {
    raw_rd
  }
  { rating: player.rating, deviation: bounded_rd, }
}

///|
/// Rate a player over a rating period with zero or more matches.
pub fn rate_period(
  player : GlickoRating,
  matches : Array[GlickoOpponent],
  periods~ : Double = 0.0,
  config~ : GlickoConfig = GlickoConfig::default(),
) -> GlickoRating {
  if matches.is_empty() {
    return step_inactivity(player, periods=1.0, config~)
  }

  // Pre-period deviation update if inactive time elapsed
  let active_player = if periods > 0.0 {
    step_inactivity(player, periods~, config~)
  } else {
    player
  }
  let r = active_player.rating
  let rd = active_player.deviation

  // Accumulate d^2 denominator and score delta
  let mut d2_inv = 0.0
  let mut score_sum = 0.0

  for m in matches {
    let opp_r = m.rating.rating
    let opp_rd = m.rating.deviation
    let g_j = g(opp_rd)
    let e_j = expected_score(r, opp_r, opp_rd)

    d2_inv = d2_inv + g_j * g_j * e_j * (1.0 - e_j)
    score_sum = score_sum + g_j * (m.score - e_j)
  }

  let d2 = 1.0 / (Q * Q * d2_inv)
  let rd_inv2 = 1.0 / (rd * rd)
  let denom = rd_inv2 + 1.0 / d2

  let new_r = r + Q / denom * score_sum
  let new_rd = (1.0 / denom).sqrt()

  let clamped_rd = if new_rd < config.min_deviation {
    config.min_deviation
  } else if new_rd > config.max_deviation {
    config.max_deviation
  } else {
    new_rd
  }

  { rating: new_r, deviation: clamped_rd, }
}

///|
/// Rate a 1v1 match between two players under classic Glicko.
pub fn rate_1v1(
  player_a : GlickoRating,
  player_b : GlickoRating,
  outcome : @types.GameOutcome,
  config~ : GlickoConfig = GlickoConfig::default(),
) -> (GlickoRating, GlickoRating) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a

  let match_a = [GlickoOpponent::new(player_b, score_a)]
  let match_b = [GlickoOpponent::new(player_a, score_b)]

  let new_a = rate_period(player_a, match_a, config~)
  let new_b = rate_period(player_b, match_b, config~)

  (new_a, new_b)
}

///|
/// Predict winning probability of Player A beating Player B in Glicko.
pub fn predict_win(player_a : GlickoRating, player_b : GlickoRating) -> Double {
  let combined_rd = (player_a.deviation * player_a.deviation +
  player_b.deviation * player_b.deviation).sqrt()
  expected_score(player_a.rating, player_b.rating, combined_rd)
}
