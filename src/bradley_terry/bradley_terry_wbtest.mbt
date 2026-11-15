///|
test "Bradley-Terry: 1v1 update moves winner up and loser down" {
  let a = BradleyTerryRating::new(beta=0.0)
  let b = BradleyTerryRating::new(beta=0.0)

  let (new_a, new_b) = rate_1v1_bt(a, b, @types.GameOutcome::Win)

  assert_true(new_a.beta > 0.0)
  assert_true(new_b.beta < 0.0)
  assert_true((new_a.beta + new_b.beta).abs() < 0.000001)
}

///|
test "Bradley-Terry: batch fitting aligns with empirical win rates" {
  // A beats B, B beats C, A beats C
  let pairs = [(0, 1, 1.0), (0, 1, 1.0), (1, 2, 1.0), (1, 2, 1.0), (0, 2, 1.0)]

  let ratings = batch_fit_bt(pairs, 3, iterations=60, lr=0.1)

  // Rank order must be: A > B > C
  assert_true(ratings[0].beta > ratings[1].beta)
  assert_true(ratings[1].beta > ratings[2].beta)
}

///|
test "Thurstone-Mosteller: 1v1 closed form Gaussian updates" {
  let a = ThurstoneMostellerRating::default()
  let b = ThurstoneMostellerRating::default()

  let (new_a, new_b) = rate_1v1_tm(a, b, @types.GameOutcome::Win)

  // Winner mu increases, loser decreases
  assert_true(new_a.mu > 25.0)
  assert_true(new_b.mu < 25.0)

  // Both uncertainties decrease
  assert_true(new_a.sigma < 25.0 / 3.0)
  assert_true(new_b.sigma < 25.0 / 3.0)

  // Draw preserves symmetry
  let (draw_a, draw_b) = rate_1v1_tm(a, b, @types.GameOutcome::Draw)
  assert_true((draw_a.mu - draw_b.mu).abs() < 0.000001)
}
