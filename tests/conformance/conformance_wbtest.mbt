test "Conformance: Glicko-2 extreme rating gap convergence" {
  // 2800 Grandmaster vs 800 Novice
  let gm = @glicko2.Glicko2Rating::new(2800.0, 40.0, 0.05)
  let novice = @glicko2.Glicko2Rating::new(800.0, 350.0, 0.06)

  // GM wins as expected
  let (new_gm, new_novice) = @glicko2.rate_1v1(gm, novice, @types.GameOutcome::Win)
  assert_true(new_gm.rating >= 2800.0)
  assert_true(new_gm.rating <= 2801.0) // Minimal gain due to massive expected advantage
  assert_true(new_novice.rating < 800.0)
  assert_true(new_novice.deviation >= 349.0) // Near-zero information gain leaves deviation essentially unchanged

  // Upset: Novice wins against GM!
  let (upset_gm, upset_novice) = @glicko2.rate_1v1(gm, novice, @types.GameOutcome::Loss)
  assert_true(upset_gm.rating < 2800.0) // GM rating drops on loss
  assert_true(upset_novice.rating > 800.0) // Novice rating increases on win
}

test "Conformance: OpenSkill 4-team tournament multi-placement" {
  let t1 = [@types.Rating::default()]
  let t2 = [@types.Rating::default()]
  let t3 = [@types.Rating::default()]
  let t4 = [@types.Rating::default()]

  let res = @openskill.rate_teams([t1, t2, t3, t4], ranks=[1, 2, 3, 4])
  assert_eq(res.length(), 4)

  // Strict monotonicity: Rank 1 > Rank 2 > Rank 3 > Rank 4
  assert_true(res[0][0].mu > res[1][0].mu)
  assert_true(res[1][0].mu > res[2][0].mu)
  assert_true(res[2][0].mu > res[3][0].mu)

  // Conservation of skill sum across all 4 teams
  let sum_mu = res[0][0].mu + res[1][0].mu + res[2][0].mu + res[3][0].mu
  assert_true((sum_mu - 100.0).abs() < 1.0e-7)

  // All uncertainties decreased symmetrically
  assert_true(res[0][0].sigma < 8.3333333)
  assert_true(res[3][0].sigma < 8.3333333)
}

test "Conformance: OpenSkill weighted asymmetric player impact" {
  let carry = @types.Rating::default()
  let support = @types.Rating::default()
  let opponent = @types.Rating::default()

  // Team A: Carry (weight 2.0) + Support (weight 1.0)
  // Team B: Solo (weight 1.0)
  let updated = @openskill.rate_teams(
    [[carry, support], [opponent]],
    ranks=[1, 2],
    weights=[[2.0, 1.0], [1.0]],
  )

  let new_carry = updated[0][0]
  let new_support = updated[0][1]

  // Carry should receive higher delta due to higher weight contribution
  assert_true(new_carry.mu - 25.0 > new_support.mu - 25.0)
}

test "Conformance: 1000 simulated matches stability (No NaN / Inf / Negative variance)" {
  let mut p1 = @types.Rating::default()
  let mut p2 = @types.Rating::default()

  for i in 0..<1000 {
    let outcome = if i % 2 == 0 {
      @types.GameOutcome::Win
    } else if i % 5 == 0 {
      @types.GameOutcome::Draw
    } else {
      @types.GameOutcome::Loss
    }
    let (next1, next2) = @openskill.rate_2teams([p1], [p2], outcome)
    p1 = next1[0]
    p2 = next2[0]

    // Verify mathematical bounds
    assert_true(p1.sigma > 0.0001)
    assert_true(p2.sigma > 0.0001)
    assert_true(p1.mu > -500.0 && p1.mu < 500.0)
    assert_true(p2.mu > -500.0 && p2.mu < 500.0)
  }
}
