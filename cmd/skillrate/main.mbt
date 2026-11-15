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

  // --- Section 5: Bradley-Terry & Thurstone-Mosteller (LLM Benchmark) ---
  println("[5] Bradley-Terry & Thurstone-Mosteller (LLM Chatbot Arena)")
  let bt_gpt4 = @bt.BradleyTerryRating::new(beta=0.8)
  let bt_claude = @bt.BradleyTerryRating::new(beta=0.6)
  let bt_prob = @bt.predict_win_bt(bt_gpt4, bt_claude)
  println("Model A (GPT-4, beta=0.8) vs Model B (Claude-3.5, beta=0.6)")
  println("Win probability of Model A: " + (bt_prob * 100.0).to_string() + "%")

  let (up_gpt4, up_claude) = @bt.rate_1v1_bt(
    bt_gpt4,
    bt_claude,
    @types.GameOutcome::Win,
  )
  println("After Human Preference Evaluation (Model A wins):")
  println("  Model A new beta: " + up_gpt4.beta.to_string())
  println("  Model B new beta: " + up_claude.beta.to_string())
  println("")

  // --- Section 6: Dynamic Matchmaking Queue & Team Balancer ---
  println("[6] Matchmaking Queue & Fair Team Balancer")
  let pool = [
    @types.Player::new(
      "p1",
      rating=@types.Rating::new(38.0, 3.0),
      name="Striker",
    ),
    @types.Player::new(
      "p2",
      rating=@types.Rating::new(34.0, 3.0),
      name="Guardian",
    ),
    @types.Player::new(
      "p3",
      rating=@types.Rating::new(31.0, 3.0),
      name="Sniper",
    ),
    @types.Player::new("p4", rating=@types.Rating::new(28.0, 3.0), name="Medic"),
    @types.Player::new("p5", rating=@types.Rating::new(25.0, 3.0), name="Scout"),
    @types.Player::new(
      "p6",
      rating=@types.Rating::new(22.0, 3.0),
      name="Engineer",
    ),
  ]
  let (team_blue, team_red, bal_quality) = @matchmaker.balance_teams(pool)
  println("Auto-partitioning 6 players into two 3v3 teams:")
  println(
    "  Balanced Match Quality: " + (bal_quality * 100.0).to_string() + "%",
  )
  println(
    "  Blue Team: " +
    team_blue[0].name +
    ", " +
    team_blue[1].name +
    ", " +
    team_blue[2].name,
  )
  println(
    "  Red Team:  " +
    team_red[0].name +
    ", " +
    team_red[1].name +
    ", " +
    team_red[2].name,
  )
  println("")

  // --- Section 7: Season Soft Reset & Placement Tracking ---
  println("[7] Season Soft Reset & Placement Tracker")
  let tracker = @ladder.PlacementTracker::new(threshold=5)
  let rem_matches = tracker.record_match("challenger_1")
  println(
    "New player provisional placement: " +
    tracker.is_provisional("challenger_1").to_string(),
  )
  println("Remaining placement matches: " + rem_matches.to_string())

  println("Executing Season Soft Reset across Leaderboard...")
  board.soft_reset_season(alpha=0.7)
  let reset_table = board.render_ascii_table(limit=3)
  println("Leaderboard after Soft Reset:")
  println(reset_table)

  // --- Section 8: DWZ, ECF & Unified Topology Dispatch ---
  println("[8] DWZ, ECF & Unified Topology Dispatch (FFA / Multi-Team)")
  let (dwz_w, dwz_l) = @elo.rate_dwz_1v1(
    @elo.DWZRating::new(rating=1600.0, index=5),
    @elo.DWZRating::new(rating=1500.0, index=5),
    @types.GameOutcome::Win,
  )
  println(
    "DWZ 1v1 Update: Winner=" +
    dwz_w.rating.to_string() +
    ", Loser=" +
    dwz_l.rating.to_string(),
  )
  let ffa_res = @unified.rate_ffa(
    [
      @types.Rating::default(),
      @types.Rating::default(),
      @types.Rating::default(),
      @types.Rating::default(),
    ],
    [1, 2, 3, 4],
    algo=@unified.AlgorithmKind::ThurstoneMosteller,
  )
  println(
    "FFA 4-Player Thurstone-Mosteller 1st Place mu: " +
    ffa_res[0].mu.to_string(),
  )

  println("Demonstration completed successfully.")
}
