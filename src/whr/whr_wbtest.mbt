///|
test "WHR multi-day trajectory optimization and Brownian bridge interpolation" {
  let engine = WHREngine::new()

  // Day 1: Alice beats Bob, Bob beats Charlie
  engine.record_match("Alice", "Bob", @types.GameOutcome::Win, day_epoch=1)
  engine.record_match("Bob", "Charlie", @types.GameOutcome::Win, day_epoch=1)

  // Day 10: Alice beats Bob again, Charlie loses to Bob
  engine.record_match("Alice", "Bob", @types.GameOutcome::Win, day_epoch=10)
  engine.record_match("Bob", "Charlie", @types.GameOutcome::Win, day_epoch=10)

  // Day 20: Alice beats Charlie
  engine.record_match("Alice", "Charlie", @types.GameOutcome::Win, day_epoch=20)

  let final_delta = engine.run_iterations(iterations=15)
  assert_true(final_delta < 0.1)

  let alice_d20 = engine.query_rating_at_day("Alice", 20)
  let bob_d20 = engine.query_rating_at_day("Bob", 20)
  let charlie_d20 = engine.query_rating_at_day("Charlie", 20)

  assert_true(alice_d20.elo() > bob_d20.elo())
  assert_true(bob_d20.elo() > charlie_d20.elo())

  // Interpolation at Day 5 (between Day 1 and Day 10)
  let alice_d5 = engine.query_rating_at_day("Alice", 5)
  assert_true(alice_d5.elo() > 1500.0)
  assert_true(alice_d5.elo_deviation() > 0.0)

  let prob_ab = engine.predict_win_at_day("Alice", "Charlie", 20)
  assert_true(prob_ab > 0.6)

  let standings = engine.export_standings()
  assert_eq(standings.length(), 3)
  assert_eq(standings[0].0, "Alice")
}
