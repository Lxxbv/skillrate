///|
test "Leaderboard registration and match recording" {
  let board = Leaderboard::new()
  board.register_player("p1", name="Alice")
  board.register_player("p2", name="Bob")

  assert_eq(board.entries.length(), 2)

  // Record a match: Alice beats Bob
  let ok = board.record_match("p1", "p2", @types.GameOutcome::Win, epoch=1000)
  assert_true(ok)

  let alice = board.find_entry("p1").unwrap()
  let bob = board.find_entry("p2").unwrap()

  assert_eq(alice.wins, 1)
  assert_eq(alice.losses, 0)
  assert_eq(bob.wins, 0)
  assert_eq(bob.losses, 1)

  assert_true(alice.conservative_score > bob.conservative_score)

  // Rank sorting
  let ranked = board.sort_and_rank()
  assert_eq(ranked[0].player_id, "p1")
  assert_eq(ranked[0].rank, 1)
  assert_eq(ranked[1].player_id, "p2")
  assert_eq(ranked[1].rank, 2)
}

///|
test "Leaderboard inactivity decay" {
  let board = Leaderboard::new()
  board.register_player("active", name="Active Player", epoch=1000000)
  board.register_player("inactive", name="Inactive Player", epoch=1000)

  // Simulate Alice winning some games so her sigma is low
  let active = board.find_entry("active").unwrap()
  active.rating = @types.Rating::new(30.0, 4.0)
  active.conservative_score = active.rating.ordinal()

  let inactive = board.find_entry("inactive").unwrap()
  inactive.rating = @types.Rating::new(30.0, 4.0)
  inactive.conservative_score = inactive.rating.ordinal()

  // Apply decay at current_epoch = 1000000 (inactive has been idle for 999,000s > 604,800s)
  board.apply_inactivity_decay(
    1000000,
    inactive_threshold=604800,
    decay_sigma_increase=1.0,
  )

  // Active player unchanged
  assert_eq(active.rating.sigma, 4.0)

  // Inactive player's uncertainty increased to 5.0, lowering conservative score
  assert_true(inactive.rating.sigma > 4.0)
  assert_true(inactive.conservative_score < active.conservative_score)
}

///|
test "Leaderboard ASCII table rendering" {
  let board = Leaderboard::new()
  board.register_player("u1", name="Alpha")
  board.register_player("u2", name="Bravo")

  let _ = board.record_match("u1", "u2", @types.GameOutcome::Win)
  let table = board.render_ascii_table()

  assert_true(table.contains("Rank | Name"))
  assert_true(table.contains("Alpha"))
  assert_true(table.contains("Bravo"))
}

///|
test "Leaderboard season soft reset" {
  let board = Leaderboard::new()
  board.register_player(
    "top",
    name="TopGM",
    rating=@types.Rating::new(45.0, 3.0),
  )
  let top = board.find_entry("top").unwrap()
  top.wins = 25

  board.soft_reset_season(alpha=0.7)

  // Wins reset to 0
  assert_eq(top.wins, 0)

  // Rating compressed toward 25.0: 0.7 * 45 + 0.3 * 25 = 31.5 + 7.5 = 39.0
  assert_true(top.rating.mu < 45.0)
  assert_true(top.rating.mu > 25.0)

  // Uncertainty increases
  assert_true(top.rating.sigma > 3.0)
}

///|
test "PlacementTracker provisional matches progress" {
  let tracker = PlacementTracker::new(threshold=3)
  assert_true(tracker.is_provisional("player1"))

  let rem1 = tracker.record_match("player1")
  assert_eq(rem1, 2)
  assert_true(tracker.is_provisional("player1"))

  let rem2 = tracker.record_match("player1")
  assert_eq(rem2, 1)

  let rem3 = tracker.record_match("player1")
  assert_eq(rem3, 0)
  assert_false(tracker.is_provisional("player1"))
}

///|
test "Swiss tournament pairing and Bo3 promotion series" {
  let board = Leaderboard::new()
  board.register_player("p1", rating=@types.Rating::new(40.0, 2.0))
  board.register_player("p2", rating=@types.Rating::new(38.0, 2.0))
  board.register_player("p3", rating=@types.Rating::new(28.0, 2.0))
  board.register_player("p4", rating=@types.Rating::new(26.0, 2.0))

  let pairings = board.swiss_pair_round()
  assert_eq(pairings.length(), 2)
  assert_eq(pairings[0].0.player_id, "p1")
  assert_eq(pairings[0].1.player_id, "p2")

  let promo = PromotionSeries::new("p1", "Diamond", wins_required=2)
  assert_true(promo.record_game(true) is None)
  assert_true(promo.record_game(false) is None)
  assert_eq(promo.record_game(true), Some(true))
}
