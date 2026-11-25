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

// -----------------------------------------------------------------------------
// Extended Top-Level Facade: Federation Systems, WHR, Spectral, Tournament & Analytics
// -----------------------------------------------------------------------------

///|
/// Rate a 1v1 match using the German Ingo system (lower Ingo = higher skill).
pub fn rate_ingo(
  player_a : @elo.IngoRating,
  player_b : @elo.IngoRating,
  outcome : @types.GameOutcome,
) -> (@elo.IngoRating, @elo.IngoRating) {
  @elo.rate_ingo_1v1(player_a, player_b, outcome)
}

///|
/// Rate a 1v1 match using the US Chess Federation (USCF) system.
pub fn rate_uscf(
  player_a : @elo.USCFRating,
  player_b : @elo.USCFRating,
  outcome : @types.GameOutcome,
) -> (@elo.USCFRating, @elo.USCFRating) {
  @elo.rate_uscf_1v1(player_a, player_b, outcome)
}

///|
/// Rate a 1v1 match using official FIDE rating regulations (K=40/20/10 & 400-point cap).
pub fn rate_fide(
  player_a : @elo.FIDERating,
  player_b : @elo.FIDERating,
  outcome : @types.GameOutcome,
) -> (@elo.FIDERating, @elo.FIDERating) {
  @elo.rate_fide_1v1(player_a, player_b, outcome)
}

///|
/// Rate a 1v1 match using the Davidson tie-aware paired comparison model.
pub fn rate_davidson(
  player_a : @bt.BradleyTerryRating,
  player_b : @bt.BradleyTerryRating,
  outcome : @types.GameOutcome,
  nu~ : Double = 0.5,
) -> (@bt.BradleyTerryRating, @bt.BradleyTerryRating) {
  @bt.rate_1v1_davidson(player_a, player_b, outcome, nu~)
}

///|
/// Rate a 1v1 match using the Rao-Kupper tie threshold model.
pub fn rate_rao_kupper(
  player_a : @bt.BradleyTerryRating,
  player_b : @bt.BradleyTerryRating,
  outcome : @types.GameOutcome,
  theta~ : Double = 1.25,
) -> (@bt.BradleyTerryRating, @bt.BradleyTerryRating) {
  @bt.rate_1v1_rao_kupper(player_a, player_b, outcome, theta~)
}

///|
/// Create a new Whole-History Rating (WHR) longitudinal optimization engine.
pub fn new_whr_engine() -> @whr.WHREngine {
  @whr.WHREngine::new()
}

///|
/// Solve Colley's bias-free matrix ratings for a tournament league.
pub fn solve_colley(
  num_participants : Int32,
  matches : Array[(Int32, Int32, Double)],
) -> Array[@spectral.ColleyRating] {
  @spectral.solve_colley_ratings(num_participants, matches)
}

///|
/// Solve Massey's least-squares ratings with offensive and defensive decomposition.
pub fn solve_massey(
  num_participants : Int32,
  score_matches : Array[(Int32, Int32, Double, Double)],
) -> Array[@spectral.MasseyRating] {
  @spectral.solve_massey_ratings(num_participants, score_matches)
}

///|
/// Solve Markov Chain / PageRank centrality ratings from pairwise match outcomes.
pub fn solve_markov_pagerank(
  num_participants : Int32,
  matches : Array[(Int32, Int32, Double)],
) -> Array[@spectral.MarkovRating] {
  @spectral.solve_markov_pagerank_ratings(num_participants, matches)
}

///|
/// Create a Single-Elimination knockout tournament bracket seeded by conservative rating.
pub fn new_single_elimination_bracket(
  players : Array[@types.Player],
) -> @tournament.SingleEliminationBracket {
  @tournament.SingleEliminationBracket::from_players(players)
}

///|
/// Create a Double-Elimination tournament bracket with Grand Finals bracket reset.
pub fn new_double_elimination_tournament(
  players : Array[@types.Player],
) -> @tournament.DoubleEliminationTournament {
  @tournament.DoubleEliminationTournament::from_players(players)
}

///|
/// Create a multi-round Swiss-System tournament manager with Buchholz tiebreaks.
pub fn new_swiss_tournament(
  players : Array[@types.Player],
  total_rounds~ : Int32 = 5,
) -> @tournament.SwissTournament {
  @tournament.SwissTournament::new(players, total_rounds~)
}

///|
/// Forecast tournament championship and podium probabilities via Monte Carlo simulation.
pub fn forecast_tournament(
  players : Array[@types.Player],
  simulations~ : Int32 = 200,
) -> Array[@tournament.ChampionshipForecast] {
  @tournament.forecast_single_elimination_monte_carlo(players, simulations~)
}

///|
/// Benchmark all 15 rating algorithms on a historical match log and rank by Brier score.
pub fn benchmark_all_algorithms(
  history : Array[@types.HistoricalMatch],
) -> Array[@unified.AlgorithmBacktestResult] {
  @unified.compare_all_algorithms_on_history(history)
}

///|
/// Evaluate probabilistic forecast calibration (ECE, MCE, Brier score, Log-Loss).
pub fn evaluate_forecast_calibration(
  records : Array[@analytics.PredictionRecord],
  num_bins~ : Int32 = 10,
) -> @analytics.CalibrationReport {
  @analytics.evaluate_calibration(records, num_bins~)
}

///|
/// Detect account boosting or intentional deranking via Page's two-sided CUSUM test.
pub fn detect_account_boosting(
  player_id : String,
  observations : Array[(Double, Double)],
) -> @analytics.CusumAnomalyReport {
  @analytics.detect_cusum_regime_shift(player_id, observations)
}

///|
/// Compute macro-level rating ecosystem health telemetry (Gini, Skewness, Kurtosis).
pub fn ecosystem_telemetry(
  ratings : Array[@types.Rating],
) -> @analytics.EcosystemTelemetry {
  @analytics.compute_ecosystem_telemetry(ratings)
}
