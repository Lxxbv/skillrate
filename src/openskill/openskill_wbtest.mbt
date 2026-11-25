///|
test "OpenSkill 1v1 match between default players" {
  let a = @types.Rating::default()
  let b = @types.Rating::default()

  let (new_a, new_b) = rate_2teams([a], [b], @types.GameOutcome::Win)

  let r_a = new_a[0]
  let r_b = new_b[0]

  // Winner gained rating, loser lost rating
  assert_true(r_a.mu > 25.0)
  assert_true(r_b.mu < 25.0)

  // Conservation of mean in symmetric 1v1 match
  assert_true((r_a.mu + r_b.mu - 50.0).abs() < 1.0e-9)

  // Both uncertainties decrease
  assert_true(r_a.sigma < a.sigma)
  assert_true(r_b.sigma < b.sigma)
  assert_true((r_a.sigma - r_b.sigma).abs() < 1.0e-9)

  // Winner conservative rating increased
  assert_true(r_a.ordinal() > a.ordinal())
}

///|
test "OpenSkill 1v1 draw between default players" {
  let a = @types.Rating::default()
  let b = @types.Rating::default()

  let (new_a, new_b) = rate_2teams([a], [b], @types.GameOutcome::Draw)

  let r_a = new_a[0]
  let r_b = new_b[0]

  // Ratings remain exactly symmetric and unchanged
  assert_true((r_a.mu - 25.0).abs() < 1.0e-9)
  assert_true((r_b.mu - 25.0).abs() < 1.0e-9)

  // Both sigmas decreased because match information was acquired
  assert_true(r_a.sigma < a.sigma)
  assert_true(r_b.sigma < b.sigma)
}

///|
test "OpenSkill 2v2 team match" {
  let a1 = @types.Rating::default()
  let a2 = @types.Rating::default()
  let b1 = @types.Rating::default()
  let b2 = @types.Rating::default()

  let updated = rate_teams([[a1, a2], [b1, b2]], ranks=[1, 2])

  let team_a = updated[0]
  let team_b = updated[1]

  // All team A players gained skill
  assert_true(team_a[0].mu > 25.0)
  assert_true(team_a[1].mu > 25.0)

  // All team B players dropped skill
  assert_true(team_b[0].mu < 25.0)
  assert_true(team_b[1].mu < 25.0)

  // All sigmas shrank
  assert_true(team_a[0].sigma < a1.sigma)
  assert_true(team_b[0].sigma < b1.sigma)
}

///|
test "OpenSkill 3-team Free-for-All" {
  let t1 = [@types.Rating::default()]
  let t2 = [@types.Rating::default()]
  let t3 = [@types.Rating::default()]

  // 1st, 2nd, 3rd place
  let updated = rate_teams([t1, t2, t3], ranks=[1, 2, 3])

  let r1 = updated[0][0]
  let r2 = updated[1][0]
  let r3 = updated[2][0]

  // 1st place > 2nd place > 3rd place
  assert_true(r1.mu > r2.mu)
  assert_true(r2.mu > r3.mu)
  assert_true(r1.mu > 25.0)
  assert_true(r3.mu < 25.0)
}

///|
test "OpenSkill asymmetric handicap teams (2 vs 1)" {
  let a1 = @types.Rating::default()
  let a2 = @types.Rating::default()
  let b_boss = @types.Rating::new(50.0, 5.0) // Boss player

  let updated = rate_teams([[a1, a2], [b_boss]], ranks=[1, 2])

  // Normal execution without NaN or panic
  assert_true(updated[0][0].mu > 25.0)
  assert_true(updated[0][1].mu > 25.0)
  assert_true(updated[1][0].mu < 50.0)
}

///|
test "OpenSkill win probability prediction" {
  let team_even_1 = [@types.Rating::default()]
  let team_even_2 = [@types.Rating::default()]

  let prob_even = predict_win(team_even_1, team_even_2)
  assert_true((prob_even - 0.5).abs() < 1.0e-9)

  let team_strong = [@types.Rating::new(35.0, 5.0)]
  let team_weak = [@types.Rating::new(20.0, 5.0)]

  let prob_strong = predict_win(team_strong, team_weak)
  assert_true(prob_strong > 0.8)

  let prob_weak = predict_win(team_weak, team_strong)
  assert_true((prob_strong + prob_weak - 1.0).abs() < 1.0e-9)
}

///|
test "OpenSkill Weng-Lin BT-Full, Plackett-Luce, and Telemetry MVP weighting" {
  let t1 = [@types.Rating::default(), @types.Rating::default()]
  let t2 = [@types.Rating::default(), @types.Rating::default()]

  let bt_res = rate_teams_bradley_terry_full([t1, t2], ranks=[1, 2])
  assert_true(bt_res[0][0].mu > 25.0)
  assert_true(bt_res[1][0].mu < 25.0)

  let pl_res = rate_teams_plackett_luce([t1, t2], ranks=[1, 2])
  assert_true(pl_res[0][0].mu > 25.0)

  let perfs = [
    [
      @types.MatchPerformance::new(
        "p1",
        kills=15,
        deaths=1,
        assists=10,
        damage_share=0.45,
      ),
      @types.MatchPerformance::new(
        "p2",
        kills=1,
        deaths=8,
        assists=2,
        damage_share=0.10,
      ),
    ],
    [
      @types.MatchPerformance::new(
        "p3",
        kills=8,
        deaths=3,
        assists=6,
        damage_share=0.35,
      ),
      @types.MatchPerformance::new(
        "p4",
        kills=0,
        deaths=10,
        assists=1,
        damage_share=0.10,
      ),
    ],
  ]
  let tele_res = rate_teams_with_telemetry([t1, t2], perfs, [1, 2])
  // MVP p1 gains more rating than passenger p2 on the winning team
  assert_true(tele_res[0][0].mu > tele_res[0][1].mu)
  // Top performer p3 loses less rating than p4 on the losing team
  assert_true(tele_res[1][0].mu > tele_res[1][1].mu)
}
