///|
test "Rating construction and default values" {
  let r = Rating::default()
  assert_eq(r.mu, 25.0)
  assert_true((r.sigma - 8.333333333333334).abs() < 1.0e-9)
  assert_true((r.ordinal() - 0.0).abs() < 1.0e-9)
  assert_true((r.variance() - 69.44444444444444).abs() < 1.0e-9)

  let custom = Rating::new(1500.0, 350.0)
  assert_eq(custom.mu, 1500.0)
  assert_eq(custom.sigma, 350.0)
  assert_eq(custom.ordinal(z=2.0), 800.0)
}

///|
test "GameOutcome scores and inversion" {
  assert_eq(GameOutcome::Win.to_score(), 1.0)
  assert_eq(GameOutcome::Loss.to_score(), 0.0)
  assert_eq(GameOutcome::Draw.to_score(), 0.5)

  assert_eq(GameOutcome::Win.reverse(), GameOutcome::Loss)
  assert_eq(GameOutcome::Loss.reverse(), GameOutcome::Win)
  assert_eq(GameOutcome::Draw.reverse(), GameOutcome::Draw)

  assert_eq(GameOutcome::from_score(1.0), GameOutcome::Win)
  assert_eq(GameOutcome::from_score(0.0), GameOutcome::Loss)
  assert_eq(GameOutcome::from_score(0.5), GameOutcome::Draw)
}

///|
test "Player and Team construction" {
  let p1 = Player::new("p1", name="Alice")
  assert_eq(p1.id, "p1")
  assert_eq(p1.name, "Alice")
  assert_eq(p1.rating.mu, 25.0)

  let p2 = Player::new("p2")
  assert_eq(p2.name, "p2")

  let t = Team::new("t1", [p1, p2], weight=1.5)
  assert_eq(t.id, "t1")
  assert_eq(t.players.length(), 2)
  assert_eq(t.weight, 1.5)

  let t_single = Team::single(p1)
  assert_eq(t_single.players.length(), 1)
  assert_eq(t_single.weight, 1.0)
}

///|
test "Confidence intervals, belief fusion, MMR conversion, and telemetry weights" {
  let r1 = Rating::new(30.0, 4.0)
  let r2 = Rating::new(20.0, 4.0)
  let ci1 = r1.confidence_interval(z=2.0)
  assert_eq(ci1.lower, 22.0)
  assert_eq(ci1.upper, 38.0)
  assert_true(ci1.contains(30.0))

  // Fusing two equal precision ratings N(30, 16) and N(20, 16) gives mean 25.0 and variance 8.0
  let fused = r1.fuse_belief(r2)
  assert_true((fused.mu - 25.0).abs() < 1.0e-9)
  assert_true(fused.sigma < 4.0)

  let mmr = r1.to_mmr()
  let back = Rating::from_mmr(mmr, sigma=4.0)
  assert_true((back.mu - 30.0).abs() < 1.0e-9)

  let perf = MatchPerformance::new(
    "p1",
    kills=10,
    deaths=2,
    assists=8,
    damage_share=0.32,
  )
  assert_true(perf.kda_ratio() == 9.0)
  assert_true(perf.contribution_weight() > 1.0)
}
