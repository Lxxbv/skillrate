///|
/// SkillRate CLI Demonstration entry point.
fn main {
  println("==================================================================")
  println("  SkillRate: Modern Rating, Ranking & Matchmaking Suite (MoonBit)")
  println("==================================================================")
  println("")

  // --- Section 1: Classic Elo Demonstration ---
  println("[1] Classic Elo 1v1 Demonstration")
  let elo_a = 1600.0
  let elo_b = 1400.0
  let exp_a = @elo.expected_score(elo_a, elo_b)
  println(
    "Player A (" +
    elo_a.to_string() +
    ") vs Player B (" +
    elo_b.to_string() +
    ")",
  )
  println(
    "Expected win rate: A=" +
    (exp_a * 100.0).to_string() +
    "%, B=" +
    ((1.0 - exp_a) * 100.0).to_string() +
    "%",
  )

  let (new_elo_a, new_elo_b) = @elo.rate_1v1(
    elo_a,
    elo_b,
    @types.GameOutcome::Win,
  )
  println(
    "Result: Player A Wins -> New A=" +
    new_elo_a.to_string() +
    ", New B=" +
    new_elo_b.to_string(),
  )
  println("")

  // --- Section 2: Glicko-2 Industrial 1v1 Demonstration ---
  println("[2] Glicko-2 Rating Period & Volatility Iteration")
  let g2_player = @glicko2.Glicko2Rating::new(1500.0, 200.0, 0.06)
  let g2_opp1 = @glicko2.Glicko2Rating::new(1400.0, 30.0, 0.06)
  let g2_opp2 = @glicko2.Glicko2Rating::new(1550.0, 100.0, 0.06)
  let g2_opp3 = @glicko2.Glicko2Rating::new(1700.0, 300.0, 0.06)

  println("Initial Player: R=1500.0, RD=200.0, Vol=0.06")
  println(
    "Matches: Opp1(1400/30: Win), Opp2(1550/100: Loss), Opp3(1700/300: Loss)",
  )

  let g2_matches = [
    @glicko2.OpponentMatch::new(g2_opp1, 1.0),
    @glicko2.OpponentMatch::new(g2_opp2, 0.0),
    @glicko2.OpponentMatch::new(g2_opp3, 0.0),
  ]
  let g2_updated = @glicko2.rate_period(g2_player, g2_matches)
  println(
    "Updated Player: R=" +
    g2_updated.rating.to_string() +
    ", RD=" +
    g2_updated.deviation.to_string() +
    ", Vol=" +
    g2_updated.volatility.to_string(),
  )
  println("")

  // --- Section 3: OpenSkill Multi-Team & Match Quality ---
  println("[3] OpenSkill 2v2 Team Match with Match Quality Assessment")
  let p_alpha1 = @types.Rating::new(28.0, 6.0)
  let p_alpha2 = @types.Rating::new(26.0, 6.0)
  let p_bravo1 = @types.Rating::new(27.0, 6.0)
  let p_bravo2 = @types.Rating::new(25.0, 6.0)

  let team_alpha = [p_alpha1, p_alpha2]
  let team_bravo = [p_bravo1, p_bravo2]

  let quality = @matchmaker.match_quality_2teams(team_alpha, team_bravo)
  let win_prob_alpha = @openskill.predict_win(team_alpha, team_bravo)
  println("Team Alpha vs Team Bravo")
  println(
    "Pre-game Match Quality: " +
    (quality * 100.0).to_string() +
    "% (Balanced: " +
    (quality >= 0.5).to_string() +
    ")",
  )
  println(
    "Team Alpha Win Probability: " + (win_prob_alpha * 100.0).to_string() + "%",
  )

  let updated_teams = @openskill.rate_teams([team_alpha, team_bravo], ranks=[
    1, 2,
  ])
  println("Match Result: Team Alpha Victory!")
  println(
    "Alpha[0]: mu=" +
    updated_teams[0][0].mu.to_string() +
    ", sigma=" +
    updated_teams[0][0].sigma.to_string(),
  )
  println(
    "Bravo[0]: mu=" +
    updated_teams[1][0].mu.to_string() +
    ", sigma=" +
    updated_teams[1][0].sigma.to_string(),
  )
  println("")

  // --- Section 4: Live Competitive Leaderboard ---
  println(
    "[4] Competitive Leaderboard Table (Conservative Scoring: mu - 3*sigma)",
  )
  let board = @ladder.Leaderboard::new()
  board.register_player(
    "carlsen",
    name="Magnus C.",
    rating=@types.Rating::new(45.0, 2.0),
  )
  board.register_player(
    "hikaru",
    name="Hikaru N.",
    rating=@types.Rating::new(43.0, 2.2),
  )
  board.register_player(
    "ding",
    name="Ding L.",
    rating=@types.Rating::new(41.0, 2.5),
  )
  board.register_player(
    "novice",
    name="Challenger",
    rating=@types.Rating::default(),
  )

  let _ = board.record_match("carlsen", "hikaru", @types.GameOutcome::Win)
  let _ = board.record_match("hikaru", "ding", @types.GameOutcome::Win)
  let _ = board.record_match("carlsen", "ding", @types.GameOutcome::Draw)
  let _ = board.record_match("ding", "novice", @types.GameOutcome::Win)

  let table = board.render_ascii_table(limit=10)
  println(table)
  println("Demonstration completed successfully.")
}
