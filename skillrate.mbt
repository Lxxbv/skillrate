///|
/// High-level unified facade API for the SkillRate competitive rating suite.
/// Allows consumers to import `"Lxxbv/skillrate"` and access all features directly.

///|
/// Create a new Bayesian rating with default parameters (mu=25.0, sigma=8.333).
pub fn rating(
  mu~ : Double = 25.0,
  sigma~ : Double = 25.0 / 3.0,
) -> @types.Rating {
  @types.Rating::new(mu, sigma)
}

///|
/// Create a new Glicko-2 rating with default parameters (r=1500.0, RD=350.0, vol=0.06).
pub fn glicko2_rating(
  r~ : Double = 1500.0,
  rd~ : Double = 350.0,
  vol~ : Double = 0.06,
) -> @glicko2.Glicko2Rating {
  @glicko2.Glicko2Rating::new(r, rd, vol)
}

///|
/// Rate a 1v1 match using the classic Elo system.
pub fn rate_elo(
  rating_a : Double,
  rating_b : Double,
  outcome : @types.GameOutcome,
  k_factor~ : Double = 32.0,
) -> (Double, Double) {
  let cfg = @elo.EloConfig::new(k_factor~)
  @elo.rate_1v1(rating_a, rating_b, outcome, config=cfg)
}

///|
/// Rate a 1v1 match using the Glicko-2 system.
pub fn rate_glicko2(
  player_a : @glicko2.Glicko2Rating,
  player_b : @glicko2.Glicko2Rating,
  outcome : @types.GameOutcome,
  tau~ : Double = 0.5,
) -> (@glicko2.Glicko2Rating, @glicko2.Glicko2Rating) {
  let cfg = @glicko2.Glicko2Config::new(tau~)
  @glicko2.rate_1v1(player_a, player_b, outcome, config=cfg)
}

///|
/// Rate a multi-team match using the OpenSkill Bayesian system.
pub fn rate_openskill(
  teams : Array[Array[@types.Rating]],
  ranks~ : Array[Int32] = [],
  weights~ : Array[Array[Double]] = [],
) -> Array[Array[@types.Rating]] {
  @openskill.rate_teams(teams, ranks~, weights~)
}

///|
/// Calculate match quality (balance index in (0, 1]) between two participants or teams.
pub fn match_quality(
  player_a : @types.Rating,
  player_b : @types.Rating,
) -> Double {
  @matchmaker.match_quality_1v1(player_a, player_b)
}

///|
/// Calculate win probability of Team A beating Team B.
pub fn win_probability(
  team_a : Array[@types.Rating],
  team_b : Array[@types.Rating],
) -> Double {
  @openskill.predict_win(team_a, team_b)
}

///|
/// Initialize a new competitive leaderboard with tier tracking and conservative scoring.
pub fn new_leaderboard() -> @ladder.Leaderboard {
  @ladder.Leaderboard::new()
}
