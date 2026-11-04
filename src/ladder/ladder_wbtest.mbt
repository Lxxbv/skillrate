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
