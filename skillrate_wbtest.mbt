test "SkillRate top-level facade API" {
  // 1. Elo facade
  let (new_a, new_b) = rate_elo(1500.0, 1500.0, @types.GameOutcome::Win)
  assert_eq(new_a, 1516.0)
  assert_eq(new_b, 1484.0)

  // 2. Glicko-2 facade
  let g_a = glicko2_rating(r=1500.0, rd=200.0, vol=0.06)
  let g_b = glicko2_rating(r=1500.0, rd=200.0, vol=0.06)
  let (new_ga, new_gb) = rate_glicko2(g_a, g_b, @types.GameOutcome::Win)
  assert_true(new_ga.rating > 1500.0)
  assert_true(new_gb.rating < 1500.0)

  // 3. OpenSkill facade
  let t1 = [rating()]
  let t2 = [rating()]
  let updated_teams = rate_openskill([t1, t2], ranks=[1, 2])
  assert_true(updated_teams[0][0].mu > 25.0)
  assert_true(updated_teams[1][0].mu < 25.0)

  // 4. Match quality and win probability
  let q = match_quality(t1[0], t2[0])
  assert_true(q > 0.4)
  let prob = win_probability(t1, t2)
  assert_true((prob - 0.5).abs() < 1.0e-9)

  // 5. Leaderboard
  let board = new_leaderboard()
  board.register_player("carlsen", name="Magnus")
  assert_eq(board.entries.length(), 1)
}
