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

///|
test "MatchmakingQueue dynamic window expansion" {
  let queue = MatchmakingQueue::new()
  let p1 = QueuedPlayer::new("Alice", @types.Rating::new(30.0, 3.0), 0)
  let p2 = QueuedPlayer::new("Bob", @types.Rating::new(38.0, 3.0), 0)

  queue.enqueue(p1)
  queue.enqueue(p2)

  // At tick 0, gap is 8.0, base_window=3.0 -> no match found
  let match_at_0 = queue.find_pair(0, base_window=3.0, expansion_rate=0.5)
  assert_true(match_at_0 is None)

  // At tick 12, window expands: 3.0 + 0.5 * 12 = 9.0 >= 8.0 -> match found!
  let match_at_12 = queue.find_pair(12, base_window=3.0, expansion_rate=0.5)
  assert_true(match_at_12 is Some(_))
  assert_eq(queue.players.length(), 0)
}

///|
test "TeamBalancer balances 6 players into two fair teams" {
  let players = [
    @types.Player::new("p1", rating=@types.Rating::new(40.0, 3.0)),
    @types.Player::new("p2", rating=@types.Rating::new(35.0, 3.0)),
    @types.Player::new("p3", rating=@types.Rating::new(30.0, 3.0)),
    @types.Player::new("p4", rating=@types.Rating::new(28.0, 3.0)),
    @types.Player::new("p5", rating=@types.Rating::new(24.0, 3.0)),
    @types.Player::new("p6", rating=@types.Rating::new(20.0, 3.0)),
  ]

  let (team_a, team_b, quality) = balance_teams(players)
  assert_eq(team_a.length(), 3)
  assert_eq(team_b.length(), 3)

  // Quality should be high (> 0.5)
  assert_true(quality > 0.5)

  // Team sums must be close
  let mut sum_a = 0.0
  let mut sum_b = 0.0
  for p in team_a {
    sum_a = sum_a + p.rating.mu
  }
  for p in team_b {
    sum_b = sum_b + p.rating.mu
  }
  assert_true((sum_a - sum_b).abs() <= 5.0)
}

///|
test "Batch lobby pairing and smurf win-streak acceleration" {
  let queue = MatchmakingQueue::new()
  queue.enqueue(QueuedPlayer::new("p1", @types.Rating::new(25.0, 3.0), 0))
  queue.enqueue(QueuedPlayer::new("p2", @types.Rating::new(26.0, 3.0), 0))
  queue.enqueue(QueuedPlayer::new("p3", @types.Rating::new(40.0, 3.0), 0))
  queue.enqueue(QueuedPlayer::new("p4", @types.Rating::new(41.5, 3.0), 0))

  let pairs = queue.batch_pair_all(2, base_window=2.5, expansion_rate=0.5)
  assert_eq(pairs.length(), 2)
  assert_eq(queue.players.length(), 0)

  let normal_mult = smurf_acceleration_factor(1, 0.3)
  assert_eq(normal_mult, 1.0)

  let smurf_mult = smurf_acceleration_factor(6, 2.8)
  assert_true(smurf_mult > 1.8 && smurf_mult <= 2.5)
}

///|
test "2-Opt local search team balancer and 5v5 Role-Based MOBA queue" {
  let players = [
    @types.Player::new("p1", rating=@types.Rating::new(42.0, 2.0)),
    @types.Player::new("p2", rating=@types.Rating::new(38.0, 2.0)),
    @types.Player::new("p3", rating=@types.Rating::new(31.0, 2.0)),
    @types.Player::new("p4", rating=@types.Rating::new(29.0, 2.0)),
    @types.Player::new("p5", rating=@types.Rating::new(23.0, 2.0)),
    @types.Player::new("p6", rating=@types.Rating::new(19.0, 2.0)),
  ]
  let (_, _, q_snake) = balance_teams(players)
  let (opt_a, opt_b, q_2opt) = optimize_teams_2opt(players)
  assert_eq(opt_a.length(), 3)
  assert_eq(opt_b.length(), 3)
  assert_true(q_2opt >= q_snake - 1.0e-9)

  let rq = RoleMatchmakingQueue::new()
  let roles = [
    @types.TacticalRole::Top,
    @types.TacticalRole::Jungle,
    @types.TacticalRole::Mid,
    @types.TacticalRole::Bot,
    @types.TacticalRole::Support,
  ]
  for i = 0; i < 5; i = i + 1 {
    rq.enqueue(
      RoleQueuedPlayer::new(
        "blue_" + i.to_string(),
        @types.Rating::new(26.0, 3.0),
        roles[i],
      ),
    )
    rq.enqueue(
      RoleQueuedPlayer::new(
        "red_" + i.to_string(),
        @types.Rating::new(25.0, 3.0),
        roles[i],
      ),
    )
  }
  let lobby = rq.assemble_5v5_lobby(10)
  assert_true(lobby is Some(_))
  assert_eq(rq.pool.length(), 0)
}
