///|
test "Elo expected score symmetry" {
  // Equal rating gives 50% probability
  let e_equal = expected_score(1500.0, 1500.0)
  assert_true((e_equal - 0.5).abs() < 1.0e-9)

  // 400 points difference gives approx 10:1 ratio (~0.90909)
  let e_diff400 = expected_score(1600.0, 1200.0)
  assert_true((e_diff400 - 0.9090909).abs() < 1.0e-5)

  // E_A + E_B == 1
  let e_a = expected_score(1700.0, 1450.0)
  let e_b = expected_score(1450.0, 1700.0)
  assert_true((e_a + e_b - 1.0).abs() < 1.0e-9)
}

///|
test "Elo 1v1 match rating updates" {
  let cfg = EloConfig::default() // K=32.0

  // Equal match: winner gains 16, loser drops 16
  let (new_a, new_b) = rate_1v1(
    1500.0,
    1500.0,
    @types.GameOutcome::Win,
    config=cfg,
  )
  assert_true((new_a - 1516.0).abs() < 1.0e-9)
  assert_true((new_b - 1484.0).abs() < 1.0e-9)

  // Draw between equal players results in no change
  let (draw_a, draw_b) = rate_1v1(
    1500.0,
    1500.0,
    @types.GameOutcome::Draw,
    config=cfg,
  )
  assert_true((draw_a - 1500.0).abs() < 1.0e-9)
  assert_true((draw_b - 1500.0).abs() < 1.0e-9)

  // Underdog win causes large rating swing
  let (underdog_win, fav_loss) = rate_1v1(
    1200.0,
    1600.0,
    @types.GameOutcome::Win,
    config=cfg,
  )
  assert_true(underdog_win > 1228.0)
  assert_true(fav_loss < 1572.0)
}

///|
test "Elo adaptive K-factor" {
  let adaptive_cfg = EloConfig::new(adaptive_k=true)

  // Newbie player has K=40
  let k_newbie = resolve_k_factor(adaptive_cfg, 1500.0, matches_played=10)
  assert_eq(k_newbie, 40.0)

  // Veteran standard player has K=32
  let k_standard = resolve_k_factor(adaptive_cfg, 1800.0, matches_played=50)
  assert_eq(k_standard, 32.0)

  // Master player (rating >= 2400) has K=16
  let k_master = resolve_k_factor(adaptive_cfg, 2500.0, matches_played=100)
  assert_eq(k_master, 16.0)
}

///|
test "DWZ rating 1v1 update and win prediction" {
  let p1 = DWZRating::new(rating=1600.0, index=5)
  let p2 = DWZRating::new(rating=1400.0, index=5)

  let prob = predict_win_dwz(p1, p2)
  assert_true(prob > 0.75 && prob < 0.77)

  let (new_p1, new_p2) = rate_dwz_1v1(p1, p2, @types.GameOutcome::Win)
  assert_true(new_p1.rating > 1600.0)
  assert_true(new_p2.rating < 1400.0)
  assert_eq(new_p1.index, 6)
  assert_eq(new_p2.index, 6)
}

///|
test "ECF grading 1v1 update and 40-point cap rule" {
  let a = ECFRating::new(rating=120.0)
  let b = ECFRating::new(rating=120.0)

  let (win_a, loss_b) = rate_ecf_1v1(a, b, @types.GameOutcome::Win)
  assert_true((win_a.rating - (120.0 + 50.0 / 30.0)).abs() < 1.0e-6)
  assert_true((loss_b.rating - (120.0 - 50.0 / 30.0)).abs() < 1.0e-6)

  // Elo conversion symmetry
  let elo = a.to_elo()
  let back = ECFRating::from_elo(elo)
  assert_true((back.rating - 120.0).abs() < 1.0e-9)
}

///|
test "Ingo, USCF, FIDE regulations, and Best-of-N series probabilities" {
  let ingo_a = IngoRating::default()
  let ingo_b = IngoRating::default()
  let (up_ia, up_ib) = rate_ingo_1v1(ingo_a, ingo_b, @types.GameOutcome::Win)
  assert_true(up_ia.rating < ingo_a.rating)
  assert_true(up_ib.rating > ingo_b.rating)

  let uscf_a = USCFRating::new(
    rating=1600.0,
    games_played=20,
    peak_rating=1850.0,
  )
  assert_eq(uscf_a.rating_floor(), 1600.0)

  let init_fide = calculate_initial_fide_rating([1900.0, 1900.0, 1900.0], 2.0)
  assert_true(init_fide > 1800.0 && init_fide < 2000.0)

  let bo1 = predict_series_bo(1650.0, 1500.0, 1)
  let bo5 = predict_series_bo(1650.0, 1500.0, 5)
  assert_true(bo5 > bo1)
}
