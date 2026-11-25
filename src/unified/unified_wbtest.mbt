///|
test "Unified 1v1 rating dispatch across all 8 algorithms" {
  let r_a = @types.Rating::new(30.0, 5.0)
  let r_b = @types.Rating::new(20.0, 5.0)

  let algos = [
    AlgorithmKind::Elo,
    AlgorithmKind::Glicko,
    AlgorithmKind::Glicko2,
    AlgorithmKind::OpenSkill,
    AlgorithmKind::ThurstoneMosteller,
    AlgorithmKind::BradleyTerry,
    AlgorithmKind::DWZ,
    AlgorithmKind::ECF,
  ]

  for algo in algos {
    let (new_a, new_b) = rate_1v1(algo, r_a, r_b, @types.GameOutcome::Win)
    assert_true(new_a.mu > r_a.mu)
    assert_true(new_b.mu < r_b.mu)

    let prob = predict_win(algo, r_a, r_b)
    assert_true(prob > 0.5)
  }
}

///|
test "Unified Free-For-All (FFA) and Topology dispatch across algorithms" {
  let p1 = @types.Rating::default()
  let p2 = @types.Rating::default()
  let p3 = @types.Rating::default()
  let p4 = @types.Rating::default()

  // 1st place p1, 2nd p2, 3rd p3, 4th p4
  let ranks = [1, 2, 3, 4]
  let updated = rate_ffa([p1, p2, p3, p4], ranks)

  assert_eq(updated.length(), 4)
  assert_true(updated[0].mu > updated[1].mu)
  assert_true(updated[1].mu > updated[2].mu)
  assert_true(updated[2].mu > updated[3].mu)

  // Test FFA with Glicko2 via unified dispatch
  let updated_g2 = rate_ffa(
    [p1, p2, p3, p4],
    ranks,
    algo=AlgorithmKind::Glicko2,
  )
  assert_true(updated_g2[0].mu > updated_g2[1].mu)
  assert_true(updated_g2[1].mu > updated_g2[2].mu)

  // Test TwoTeam topology dispatch with ThurstoneMosteller
  let topo_res = rate_topology(
    AlgorithmKind::ThurstoneMosteller,
    MatchTopology::TwoTeam,
    [[p1, p2], [p3, p4]],
    [1, 2],
  )
  assert_true(topo_res[0][0].mu > 25.0)
  assert_true(topo_res[1][0].mu < 25.0)
}

///|
test "FIDE Performance Rating 400-rule" {
  let opponents = [2000.0, 2000.0, 2000.0, 2000.0]
  // 50% score against 2000 opponents gives 2000 performance rating
  let perf_even = performance_rating(opponents, 2.0)
  assert_true((perf_even - 2000.0).abs() < 1.0)

  // 4 wins (100% score) against 2000 gives ~2800 performance rating
  let perf_perfect = performance_rating(opponents, 4.0)
  assert_true(perf_perfect > 2700.0)
}

///|
test "Unified 15-algorithm backtest comparator on historical match log" {
  let history = [
    @types.HistoricalMatch::new(1, "Alpha", "Beta", @types.GameOutcome::Win),
    @types.HistoricalMatch::new(2, "Alpha", "Gamma", @types.GameOutcome::Win),
    @types.HistoricalMatch::new(3, "Beta", "Gamma", @types.GameOutcome::Win),
    @types.HistoricalMatch::new(4, "Alpha", "Beta", @types.GameOutcome::Win),
  ]

  let results = compare_all_algorithms_on_history(history)
  assert_eq(results.length(), 15)
  assert_true(results[0].brier_score <= results[14].brier_score)
  assert_eq(results[0].matches_evaluated, 4)
}
