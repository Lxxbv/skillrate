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

// -----------------------------------------------------------------------------
// Extended Glicko-1 Capabilities: Confidence Bounds, Teams & Round-Robin Periods
// -----------------------------------------------------------------------------

///|
/// Compute a 95% (or custom z-score) confidence interval [r - z*RD, r + z*RD].
pub fn GlickoRating::confidence_interval(
  self : GlickoRating,
  z~ : Double = 1.96,
) -> @types.ConfidenceInterval {
  @types.ConfidenceInterval::from_gaussian(
    self.rating,
    self.deviation,
    z_score=z,
  )
}

///|
/// Calculate rating reliability index in [0.0, 1.0]:
/// 1.0 - (RD / max_deviation), where 0.0 is uncalibrated (RD=350) and > 0.85 is tournament-established.
pub fn GlickoRating::reliability_index(
  self : GlickoRating,
  max_deviation~ : Double = 350.0,
) -> Double {
  let safe_max = if max_deviation <= 1.0 { 350.0 } else { max_deviation }
  let ratio = 1.0 - self.deviation / safe_max
  if ratio < 0.0 {
    0.0
  } else if ratio > 1.0 {
    1.0
  } else {
    ratio
  }
}

///|
/// Calculate optimal time constant c given average RD, target max RD, and periods to full decay:
/// c = sqrt((RD_max^2 - RD_min^2) / periods_to_uncalibrated)
pub fn compute_time_constant_c(
  min_rd~ : Double = 50.0,
  max_rd~ : Double = 350.0,
  periods_to_reset~ : Double = 30.0,
) -> Double {
  let safe_p = if periods_to_reset <= 1.0 { 1.0 } else { periods_to_reset }
  let diff_sq = max_rd * max_rd - min_rd * min_rd
  if diff_sq <= 0.0 {
    10.0
  } else {
    (diff_sq / safe_p).sqrt()
  }
}

///|
/// Predict winning probability incorporating a rating handicap / first-mover advantage for Player A.
pub fn predict_win_with_handicap(
  player_a : GlickoRating,
  player_b : GlickoRating,
  handicap_a : Double,
) -> Double {
  let combined_rd = (player_a.deviation * player_a.deviation +
  player_b.deviation * player_b.deviation).sqrt()
  expected_score(player_a.rating + handicap_a, player_b.rating, combined_rd)
}

///|
/// Rate a 1v1 match with an explicit rating handicap / komi advantage for Player A.
pub fn rate_1v1_with_handicap(
  player_a : GlickoRating,
  player_b : GlickoRating,
  outcome : @types.GameOutcome,
  handicap_a : Double,
  config~ : GlickoConfig = GlickoConfig::default(),
) -> (GlickoRating, GlickoRating) {
  let score_a = outcome.to_score()
  let score_b = 1.0 - score_a

  let shifted_b_for_a = GlickoRating::new(
    rating=player_b.rating - handicap_a,
    deviation=player_b.deviation,
  )
  let shifted_a_for_b = GlickoRating::new(
    rating=player_a.rating + handicap_a,
    deviation=player_a.deviation,
  )

  let new_a = rate_period(
    player_a,
    [GlickoOpponent::new(shifted_b_for_a, score_a)],
    config~,
  )
  let new_b = rate_period(
    player_b,
    [GlickoOpponent::new(shifted_a_for_b, score_b)],
    config~,
  )
  (new_a, new_b)
}

///|
/// Compute composite team Glicko-1 rating (mean rating, root-mean-square deviation).
pub fn composite_team_glicko(team : Array[GlickoRating]) -> GlickoRating {
  let n = team.length()
  if n == 0 {
    return GlickoRating::default()
  }
  let mut sum_r = 0.0
  let mut sum_var = 0.0
  for p in team {
    sum_r = sum_r + p.rating
    sum_var = sum_var + p.deviation * p.deviation
  }
  let nf = n.to_double()
  GlickoRating::new(rating=sum_r / nf, deviation=(sum_var / nf).sqrt())
}

///|
/// Rate a Two-Team match under Glicko-1 using variance-proportional update attribution:
/// Players with higher uncertainty (RD^2) absorb a proportionally larger share of the team rating update.
pub fn rate_two_teams_glicko(
  team_a : Array[GlickoRating],
  team_b : Array[GlickoRating],
  outcome : @types.GameOutcome,
  config~ : GlickoConfig = GlickoConfig::default(),
) -> (Array[GlickoRating], Array[GlickoRating]) {
  if team_a.is_empty() || team_b.is_empty() {
    return (team_a, team_b)
  }
  let comp_a = composite_team_glicko(team_a)
  let comp_b = composite_team_glicko(team_b)
  let (new_comp_a, new_comp_b) = rate_1v1(comp_a, comp_b, outcome, config~)

  let delta_r_a = new_comp_a.rating - comp_a.rating
  let rd_ratio_a = if comp_a.deviation > 1.0e-6 {
    new_comp_a.deviation / comp_a.deviation
  } else {
    1.0
  }

  let mut total_var_a = 0.0
  for p in team_a {
    total_var_a = total_var_a + p.deviation * p.deviation
  }
  let avg_var_a = total_var_a / team_a.length().to_double()

  let updated_a : Array[GlickoRating] = []
  for p in team_a {
    let weight = if avg_var_a > 1.0e-6 {
      p.deviation * p.deviation / avg_var_a
    } else {
      1.0
    }
    let new_rd = p.deviation * rd_ratio_a
    let clamped_rd = if new_rd < config.min_deviation {
      config.min_deviation
    } else if new_rd > config.max_deviation {
      config.max_deviation
    } else {
      new_rd
    }
    updated_a.push(
      GlickoRating::new(
        rating=p.rating + delta_r_a * weight,
        deviation=clamped_rd,
      ),
    )
  }

  let delta_r_b = new_comp_b.rating - comp_b.rating
  let rd_ratio_b = if comp_b.deviation > 1.0e-6 {
    new_comp_b.deviation / comp_b.deviation
  } else {
    1.0
  }

  let mut total_var_b = 0.0
  for p in team_b {
    total_var_b = total_var_b + p.deviation * p.deviation
  }
  let avg_var_b = total_var_b / team_b.length().to_double()

  let updated_b : Array[GlickoRating] = []
  for p in team_b {
    let weight = if avg_var_b > 1.0e-6 {
      p.deviation * p.deviation / avg_var_b
    } else {
      1.0
    }
    let new_rd = p.deviation * rd_ratio_b
    let clamped_rd = if new_rd < config.min_deviation {
      config.min_deviation
    } else if new_rd > config.max_deviation {
      config.max_deviation
    } else {
      new_rd
    }
    updated_b.push(
      GlickoRating::new(
        rating=p.rating + delta_r_b * weight,
        deviation=clamped_rd,
      ),
    )
  }

  (updated_a, updated_b)
}

///|
/// Evaluate a simultaneous multi-player Glicko-1 rating period from a list of match tuples
/// (player_i_index, player_j_index, score_for_i).
/// All players are updated simultaneously against their opponents' pre-period ratings.
pub fn evaluate_batch_period(
  players : Array[GlickoRating],
  matches : Array[(Int32, Int32, Double)],
  elapsed_periods~ : Double = 0.0,
  config~ : GlickoConfig = GlickoConfig::default(),
) -> Array[GlickoRating] {
  let n = players.length()
  if n == 0 {
    return []
  }

  let buckets : Array[Array[GlickoOpponent]] = []
  for _ in 0..<n {
    buckets.push([])
  }

  for m in matches {
    let (i, j, s_i) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      buckets[i].push(GlickoOpponent::new(players[j], s_i))
      buckets[j].push(GlickoOpponent::new(players[i], 1.0 - s_i))
    }
  }

  let updated : Array[GlickoRating] = []
  for idx = 0; idx < n; idx = idx + 1 {
    updated.push(
      rate_period(players[idx], buckets[idx], periods=elapsed_periods, config~),
    )
  }
  updated
}
