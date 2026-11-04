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
