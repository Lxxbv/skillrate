///|
test "Single-elimination bracket seeding, byes, and champion progression" {
  let players = [
    @types.Player::new("p1", rating=@types.Rating::new(40.0, 2.0)),
    @types.Player::new("p2", rating=@types.Rating::new(35.0, 2.0)),
    @types.Player::new("p3", rating=@types.Rating::new(30.0, 2.0)),
  ]
  let bracket = SingleEliminationBracket::from_players(players)
  assert_eq(bracket.bracket_size, 4)
  assert_eq(bracket.rounds[0].length(), 2)

  // Seed 1 vs Seed 4 (BYE) should auto-complete in Round 1
  let r1 = bracket.rounds[0]
  assert_true(r1[0].is_bye || r1[1].is_bye)

  // Play the non-bye match in Round 1
  for m in r1 {
    if !m.completed {
      let ok = bracket.record_match_winner(m.match_id, m.slot_a)
      assert_true(ok)
    }
  }

  // Now Round 2 (Finals) should be generated
  assert_eq(bracket.current_round, 2)
  let finals = bracket.rounds[1][0]
  let ok_final = bracket.record_match_winner(finals.match_id, "p1")
  assert_true(ok_final)
  assert_eq(bracket.champion_id, "p1")
}

///|
test "Double-elimination bracket progression and Grand Finals bracket reset" {
  let players = [
    @types.Player::new("A", rating=@types.Rating::new(42.0, 2.0)),
    @types.Player::new("B", rating=@types.Rating::new(38.0, 2.0)),
    @types.Player::new("C", rating=@types.Rating::new(34.0, 2.0)),
    @types.Player::new("D", rating=@types.Rating::new(30.0, 2.0)),
  ]
  let de = DoubleEliminationTournament::from_players(players)

  // Force B to lose in WB Finals to A, win LB Finals, and then beat A in Grand Finals Set 1 & Set 2!
  let mut gf_count = 0
  let champ = de.run_to_completion(fn(p1, p2) {
    if (p1 == "A" && p2 == "B") || (p1 == "B" && p2 == "A") {
      gf_count = gf_count + 1
      if gf_count == 1 {
        "A" // WB Finals: A beats B
      } else {
        "B" // Grand Finals Set 1 & Set 2: B beats A twice (triggers bracket reset!)
      }
    } else if p1 < p2 {
      p1
    } else {
      p2
    }
  })

  assert_eq(champ, "B")
  assert_true(de.bracket_reset_triggered)
}

///|
test "Round-Robin Berger schedule, Swiss Buchholz tiebreaks, and Monte Carlo forecast" {
  let sched = generate_round_robin_schedule(["A", "B", "C", "D"])
  assert_eq(sched.length(), 3)
  assert_eq(sched[0].length(), 2)

  let players = [
    @types.Player::new("A", rating=@types.Rating::new(42.0, 2.0)),
    @types.Player::new("B", rating=@types.Rating::new(35.0, 2.0)),
    @types.Player::new("C", rating=@types.Rating::new(28.0, 2.0)),
    @types.Player::new("D", rating=@types.Rating::new(22.0, 2.0)),
  ]

  let swiss = SwissTournament::new(players, total_rounds=2)
  let r1_pairs = swiss.pair_next_round()
  assert_eq(r1_pairs.length(), 2)
  for p in r1_pairs {
    swiss.record_result(p.0, p.1, @types.GameOutcome::Win)
  }
  let r2_pairs = swiss.pair_next_round()
  assert_eq(r2_pairs.length(), 2)
  for p in r2_pairs {
    swiss.record_result(p.0, p.1, @types.GameOutcome::Win)
  }
  let standings = swiss.update_tiebreaks_and_sort()
  assert_eq(standings[0].points, 2.0)

  let forecasts = forecast_single_elimination_monte_carlo(
    players,
    simulations=100,
  )
  assert_eq(forecasts.length(), 4)
  assert_true(forecasts[0].win_title_prob > forecasts[3].win_title_prob)
}
