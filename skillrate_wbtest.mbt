///|
test "SkillRate top-level facade API" {
  // 1. Elo facade
  let (new_a, new_b) = rate_elo(1500.0, 1500.0, @types.GameOutcome::Win)
  assert_eq(new_a, 1516.0)
  assert_eq(new_b, 1484.0)

  // 2. Glicko-1 facade
  let g1_a = glicko_rating(r=1500.0, rd=200.0)
  let g1_b = glicko_rating(r=1500.0, rd=200.0)
  let (up_g1a, up_g1b) = rate_glicko(g1_a, g1_b, @types.GameOutcome::Win)
  assert_true(up_g1a.rating > 1500.0)
  assert_true(up_g1b.rating < 1500.0)

  // 3. Glicko-2 facade
  let g_a = glicko2_rating(r=1500.0, rd=200.0, vol=0.06)
  let g_b = glicko2_rating(r=1500.0, rd=200.0, vol=0.06)
  let (new_ga, new_gb) = rate_glicko2(g_a, g_b, @types.GameOutcome::Win)
  assert_true(new_ga.rating > 1500.0)
  assert_true(new_gb.rating < 1500.0)

  // 4. Bradley-Terry & Thurstone-Mosteller facade
  let bt_a = @bt.BradleyTerryRating::new(beta=0.0)
  let bt_b = @bt.BradleyTerryRating::new(beta=0.0)
  let (new_bta, new_btb) = rate_bradley_terry(
    bt_a,
    bt_b,
    @types.GameOutcome::Win,
  )
  assert_true(new_bta.beta > 0.0)
  assert_true(new_btb.beta < 0.0)

  let tm_a = @bt.ThurstoneMostellerRating::default()
  let tm_b = @bt.ThurstoneMostellerRating::default()
  let (new_tma, new_tmb) = rate_thurstone_mosteller(
    tm_a,
    tm_b,
    @types.GameOutcome::Win,
  )
  assert_true(new_tma.mu > 25.0)
  assert_true(new_tmb.mu < 25.0)

  // 5. OpenSkill & Unified FFA
  let t1 = [rating()]
  let t2 = [rating()]
  let updated_teams = rate_openskill([t1, t2], ranks=[1, 2])
  assert_true(updated_teams[0][0].mu > 25.0)
  assert_true(updated_teams[1][0].mu < 25.0)

  let ffa_out = rate_ffa([rating(), rating(), rating()], [1, 2, 3])
  assert_eq(ffa_out.length(), 3)
  assert_true(ffa_out[0].mu > ffa_out[1].mu)

  // 6. Match quality, win probability and performance rating
  let q = match_quality(t1[0], t2[0])
  assert_true(q > 0.4)
  let prob = win_probability(t1, t2)
  assert_true((prob - 0.5).abs() < 1.0e-9)

  let perf = performance_rating([1500.0, 1500.0], 1.0)
  assert_true((perf - 1500.0).abs() < 1.0)

  // 7. MatchmakingQueue, TeamBalancer, PlacementTracker & Leaderboard
  let queue = new_matchmaking_queue()
  queue.enqueue(@matchmaker.QueuedPlayer::new("Alice", rating(), 0))
  assert_eq(queue.players.length(), 1)

  let (ba, bb, bq) = balance_teams([
    @types.Player::new("p1", rating=rating(mu=30.0)),
    @types.Player::new("p2", rating=rating(mu=20.0)),
  ])
  assert_eq(ba.length(), 1)
  assert_eq(bb.length(), 1)
  assert_true(bq > 0.0)

  let tracker = new_placement_tracker(threshold=5)
  assert_true(tracker.is_provisional("Alice"))

  let board = new_leaderboard()
  board.register_player("carlsen", name="Magnus")
  assert_eq(board.entries.length(), 1)

  // 8. DWZ, ECF & Unified Topology facade
  let (dwz_a, dwz_b) = rate_dwz(
    @elo.DWZRating::default(),
    @elo.DWZRating::default(),
    @types.GameOutcome::Win,
  )
  assert_true(dwz_a.rating > dwz_b.rating)

  let (ecf_a, ecf_b) = rate_ecf(
    @elo.ECFRating::default(),
    @elo.ECFRating::default(),
    @types.GameOutcome::Win,
  )
  assert_true(ecf_a.rating > ecf_b.rating)

  let topo_out = rate_topology(
    @unified.AlgorithmKind::DWZ,
    @unified.MatchTopology::TwoTeam,
    [[rating()], [rating()]],
    [1, 2],
  )
  assert_true(topo_out[0][0].mu > topo_out[1][0].mu)
}
