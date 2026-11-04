///|
test "Match quality 1v1 symmetry and bounds" {
  let r1 = @types.Rating::default()
  let r2 = @types.Rating::default()

  // Equal players have symmetric quality in (0, 1]
  let q_even = match_quality_1v1(r1, r2)
  assert_true(q_even > 0.4 && q_even <= 1.0)

  // Symmetry: Q(A, B) == Q(B, A)
  let q_rev = match_quality_1v1(r2, r1)
  assert_true((q_even - q_rev).abs() < 1.0e-9)

  // Huge skill gap results in near-zero quality (blowout)
  let pro = @types.Rating::new(60.0, 2.0)
  let noob = @types.Rating::new(10.0, 2.0)
  let q_blowout = match_quality_1v1(pro, noob)
  assert_true(q_blowout < 0.01)
  assert_false(is_fair_match([[pro], [noob]], min_quality=0.5))
}

///|
test "Match quality multi-team and fair threshold" {
  let t1 = [@types.Rating::default()]
  let t2 = [@types.Rating::default()]
  let t3 = [@types.Rating::default()]

  let q_3teams = match_quality_teams([t1, t2, t3])
  assert_true(q_3teams > 0.4)
  assert_true(is_fair_match([t1, t2, t3], min_quality=0.4))
}

///|
test "Win probability matrix" {
  let t1 = [@types.Rating::new(30.0, 4.0)]
  let t2 = [@types.Rating::new(25.0, 4.0)]
  let t3 = [@types.Rating::new(20.0, 4.0)]

  let mat = win_probability_matrix([t1, t2, t3])
  assert_eq(mat.length(), 3)

  // Diagonal is 0.5
  assert_eq(mat[0][0], 0.5)
  assert_eq(mat[1][1], 0.5)
  assert_eq(mat[2][2], 0.5)

  // T1 > T2 > T3
  assert_true(mat[0][1] > 0.5)
  assert_true(mat[1][2] > 0.5)
  assert_true(mat[0][2] > mat[0][1])

  // Complementarity: P(i beats j) + P(j beats i) == 1.0
  assert_true((mat[0][1] + mat[1][0] - 1.0).abs() < 1.0e-9)
  assert_true((mat[1][2] + mat[2][1] - 1.0).abs() < 1.0e-9)
}
