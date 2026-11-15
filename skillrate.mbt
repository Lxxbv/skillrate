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
/// Create a new classic Glicko-1 rating (r=1500.0, RD=350.0).
pub fn glicko_rating(
  r~ : Double = 1500.0,
  rd~ : Double = 350.0,
) -> @glicko.GlickoRating {
  @glicko.GlickoRating::new(rating=r, deviation=rd)
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
/// Rate a 1v1 match using the classic Glicko-1 system.
pub fn rate_glicko(
  player_a : @glicko.GlickoRating,
  player_b : @glicko.GlickoRating,
  outcome : @types.GameOutcome,
) -> (@glicko.GlickoRating, @glicko.GlickoRating) {
  @glicko.rate_1v1(player_a, player_b, outcome)
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
/// Rate a 1v1 match using the Bradley-Terry model.
pub fn rate_bradley_terry(
  player_a : @bt.BradleyTerryRating,
  player_b : @bt.BradleyTerryRating,
  outcome : @types.GameOutcome,
) -> (@bt.BradleyTerryRating, @bt.BradleyTerryRating) {
  @bt.rate_1v1_bt(player_a, player_b, outcome)
}

///|
/// Rate a 1v1 match using the Thurstone-Mosteller model.
pub fn rate_thurstone_mosteller(
  player_a : @bt.ThurstoneMostellerRating,
  player_b : @bt.ThurstoneMostellerRating,
  outcome : @types.GameOutcome,
) -> (@bt.ThurstoneMostellerRating, @bt.ThurstoneMostellerRating) {
  @bt.rate_1v1_tm(player_a, player_b, outcome)
}

///|
/// Rate a 1v1 match using the German Chess Federation DWZ system.
pub fn rate_dwz(
  player_a : @elo.DWZRating,
  player_b : @elo.DWZRating,
  outcome : @types.GameOutcome,
) -> (@elo.DWZRating, @elo.DWZRating) {
  @elo.rate_dwz_1v1(player_a, player_b, outcome)
}

///|
/// Rate a 1v1 match using the English Chess Federation ECF grading system.
pub fn rate_ecf(
  player_a : @elo.ECFRating,
  player_b : @elo.ECFRating,
  outcome : @types.GameOutcome,
) -> (@elo.ECFRating, @elo.ECFRating) {
  @elo.rate_ecf_1v1(player_a, player_b, outcome)
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
/// Unified 1v1 dispatch across any of the 8 algorithms.
pub fn rate_unified_1v1(
  algo : @unified.AlgorithmKind,
  player_a : @types.Rating,
  player_b : @types.Rating,
  outcome : @types.GameOutcome,
) -> (@types.Rating, @types.Rating) {
  @unified.rate_1v1(algo, player_a, player_b, outcome)
}

///|
/// Unified topology-driven match rating across all 8 algorithms and 4 topologies.
pub fn rate_topology(
  algo : @unified.AlgorithmKind,
  topology : @unified.MatchTopology,
  teams : Array[Array[@types.Rating]],
  ranks : Array[Int32],
) -> Array[Array[@types.Rating]] {
  @unified.rate_topology(algo, topology, teams, ranks)
}

///|
/// Free-For-All (FFA) rating where each player competes individually.
pub fn rate_ffa(
  players : Array[@types.Rating],
  ranks : Array[Int32],
  algo~ : @unified.AlgorithmKind = @unified.AlgorithmKind::OpenSkill,
) -> Array[@types.Rating] {
  @unified.rate_ffa(players, ranks, algo~)
}

///|
/// Calculate FIDE / USCF standard performance rating.
pub fn performance_rating(
  opponent_ratings : Array[Double],
  total_score : Double,
) -> Double {
  @unified.performance_rating(opponent_ratings, total_score)
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
/// Balance a pool of players into two fair teams minimizing skill difference.
pub fn balance_teams(
  players : Array[@types.Player],
) -> (Array[@types.Player], Array[@types.Player], Double) {
  @matchmaker.balance_teams(players)
}

///|
/// Initialize a new matchmaking queue with dynamic rating window expansion.
pub fn new_matchmaking_queue() -> @matchmaker.MatchmakingQueue {
  @matchmaker.MatchmakingQueue::new()
}

///|
/// Initialize a new competitive leaderboard with tier tracking and conservative scoring.
pub fn new_leaderboard() -> @ladder.Leaderboard {
  @ladder.Leaderboard::new()
}

///|
/// Initialize a placement match tracker for provisional status.
pub fn new_placement_tracker(
  threshold~ : Int32 = 5,
) -> @ladder.PlacementTracker {
  @ladder.PlacementTracker::new(threshold~)
}
