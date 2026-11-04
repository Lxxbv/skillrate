///|
test "Mark Glickman official paper benchmark calculation" {
  // Setup player from Glickman's paper: "Example of the Glicko-2 system"
  let player = Glicko2Rating::new(1500.0, 200.0, 0.06)

  // 3 opponents
  let opp1 = Glicko2Rating::new(1400.0, 30.0, 0.06)
  let opp2 = Glicko2Rating::new(1550.0, 100.0, 0.06)
  let opp3 = Glicko2Rating::new(1700.0, 300.0, 0.06)

  let matches = [
    OpponentMatch::new(opp1, 1.0), // Win
    OpponentMatch::new(opp2, 0.0), // Loss
    OpponentMatch::new(opp3, 0.0), // Loss
  ]

  let cfg = Glicko2Config::new(tau=0.5)
  let updated = rate_period(player, matches, config=cfg)

  // Assert paper values:
  // Expected rating: ~1464.06 (within 0.1 tolerance)
  assert_true((updated.rating - 1464.06).abs() < 0.1)

  // Expected deviation: ~151.52 (within 0.1 tolerance)
  assert_true((updated.deviation - 151.52).abs() < 0.1)

  // Expected volatility: ~0.05999 (within 0.0001 tolerance)
  assert_true((updated.volatility - 0.05999).abs() < 0.0001)
}

///|
test "Glicko-2 inactivity period deviation inflation" {
  let player = Glicko2Rating::new(1500.0, 200.0, 0.06)
  let no_matches : Array[OpponentMatch] = []

  let updated = rate_period(player, no_matches)

  // Rating and volatility remain unchanged
  assert_eq(updated.rating, 1500.0)
  assert_eq(updated.volatility, 0.06)

  // Deviation increases due to inactivity
  assert_true(updated.deviation > 200.0)
  assert_true((updated.deviation - 200.27).abs() < 0.1)
}

///|
test "Glicko-2 1v1 duel update" {
  let p1 = Glicko2Rating::default()
  let p2 = Glicko2Rating::default()

  let (new1, new2) = rate_1v1(p1, p2, @types.GameOutcome::Win)

  // Winner rating increases, loser decreases
  assert_true(new1.rating > 1500.0)
  assert_true(new2.rating < 1500.0)

  // Both deviations decrease because a match was played
  assert_true(new1.deviation < 350.0)
  assert_true(new2.deviation < 350.0)
}
