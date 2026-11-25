///|
test "Glicko-1: basic 1v1 win / loss adjustment" {
  let p1 = GlickoRating::new(rating=1500.0, deviation=200.0)
  let p2 = GlickoRating::new(rating=1400.0, deviation=100.0)

  let (new_p1, new_p2) = rate_1v1(p1, p2, @types.GameOutcome::Win)

  // Winner rating increases, loser decreases
  assert_true(new_p1.rating > 1500.0)
  assert_true(new_p2.rating < 1400.0)

  // Both players' uncertainty decreases with match observation
  assert_true(new_p1.deviation < 200.0)
  assert_true(new_p2.deviation < 100.0)
}

///|
test "Glicko-1: multi-opponent period update" {
  let player = GlickoRating::new(rating=1500.0, deviation=200.0)
  let opponents = [
    GlickoOpponent::new(GlickoRating::new(rating=1400.0, deviation=30.0), 1.0),
    GlickoOpponent::new(GlickoRating::new(rating=1550.0, deviation=100.0), 0.0),
    GlickoOpponent::new(GlickoRating::new(rating=1700.0, deviation=300.0), 0.0),
  ]

  let updated = rate_period(player, opponents)

  // Player played 1 win (vs 1400) and 2 losses (vs 1550 and 1700)
  assert_true(updated.rating < 1500.0)
  assert_true(updated.deviation < 200.0)
  assert_true(updated.deviation >= 30.0)
}

///|
test "Glicko-1: win probability prediction symmetry" {
  let a = GlickoRating::new(rating=1600.0, deviation=100.0)
  let b = GlickoRating::new(rating=1400.0, deviation=100.0)

  let p_ab = predict_win(a, b)
  let p_ba = predict_win(b, a)

  assert_true(p_ab > 0.5)
  assert_true(p_ba < 0.5)
  assert_true((p_ab + p_ba - 1.0).abs() < 0.000001)
}

///|
test "Glicko-1: inactivity deviation growth" {
  let active = GlickoRating::new(rating=1800.0, deviation=60.0)
  let inactive = step_inactivity(active, periods=5.0)

  assert_true(inactive.rating == 1800.0)
  assert_true(inactive.deviation > 60.0)
}

///|
test "Glicko-1 team attribution and batch period evaluation" {
  let t_a = [
    GlickoRating::new(rating=1500.0, deviation=200.0),
    GlickoRating::new(rating=1500.0, deviation=100.0),
  ]
  let t_b = [
    GlickoRating::new(rating=1500.0, deviation=150.0),
    GlickoRating::new(rating=1500.0, deviation=150.0),
  ]
  let (up_a, up_b) = rate_two_teams_glicko(t_a, t_b, @types.GameOutcome::Win)
  assert_true(up_a[0].rating > up_a[1].rating) // higher RD player absorbs larger share
  assert_true(up_b[0].rating < 1500.0)

  let batch = evaluate_batch_period(
    [GlickoRating::default(), GlickoRating::default()],
    [(0, 1, 1.0)],
  )
  assert_true(batch[0].rating > batch[1].rating)
}
