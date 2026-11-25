///|
test "Colley bias-free matrix ratings and Massey offense/defense decomposition" {
  // 4-participant mini-league where 0 beats 1, 2, 3; 1 beats 2, 3; 2 beats 3
  let matches = [
    (0, 1, 1.0),
    (0, 2, 1.0),
    (0, 3, 1.0),
    (1, 2, 1.0),
    (1, 3, 1.0),
    (2, 3, 1.0),
  ]

  let colley = solve_colley_ratings(4, matches)
  assert_eq(colley.length(), 4)
  assert_true(colley[0].colley_score > colley[1].colley_score)
  assert_true(colley[1].colley_score > colley[2].colley_score)
  assert_true(colley[2].colley_score > colley[3].colley_score)
  assert_true(colley[0].to_elo() > 1500.0)

  let score_matches = [
    (0, 1, 30.0, 18.0),
    (0, 2, 35.0, 14.0),
    (0, 3, 42.0, 10.0),
    (1, 2, 28.0, 20.0),
    (1, 3, 31.0, 12.0),
    (2, 3, 24.0, 17.0),
  ]
  let massey = solve_massey_ratings(4, score_matches)
  assert_eq(massey.length(), 4)
  assert_true(massey[0].overall_rating > massey[1].overall_rating)
  assert_true(massey[1].overall_rating > massey[2].overall_rating)
  assert_true(massey[2].overall_rating > massey[3].overall_rating)

  let spread_03 = predict_massey_spread(massey[0], massey[3])
  assert_true(spread_03 > 10.0)
}

///|
test "Markov PageRank random-walker and Keener Perron-Frobenius ratings" {
  let matches = [(0, 1, 1.0), (0, 2, 1.0), (1, 2, 1.0)]
  let markov = solve_markov_pagerank_ratings(3, matches)
  assert_eq(markov.length(), 3)
  assert_true(markov[0].stationary_prob > markov[1].stationary_prob)
  assert_true(markov[1].stationary_prob > markov[2].stationary_prob)

  let keener = solve_keener_ratings(3, [
    (0, 1, 25.0, 10.0),
    (0, 2, 30.0, 5.0),
    (1, 2, 20.0, 12.0),
  ])
  assert_eq(keener.length(), 3)
  assert_true(keener[0] > keener[1])
  assert_true(keener[1] > keener[2])

  let hits = solve_hits_authority_hub_ratings(3, matches)
  assert_eq(hits.length(), 3)
  assert_true(hits[0].authority_score > hits[2].authority_score)

  // Cyclic rock-paper-scissors triad: 0 beats 1, 1 beats 2, 2 beats 0
  let rps = [(0, 1, 1.0), (1, 2, 1.0), (2, 0, 1.0)]
  let hodge = analyze_hodgerank_intransitivity(3, rps)
  assert_eq(hodge.cyclic_triads_count, 1)
  assert_true(hodge.cyclicity_ratio > 0.9)
}
