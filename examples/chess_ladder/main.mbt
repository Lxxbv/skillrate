///|
/// Chess Ladder Simulator: Simulating an international chess tournament.
fn main {
  println("==================================================================")
  println("  Chess Tournament & Glicko-2 / Elo Rating Ladder Simulator       ")
  println("==================================================================")

  // 1. Setup Chess Grandmasters with initial Glicko-2 ratings
  let mut gm_carlsen = @glicko2.Glicko2Rating::new(2850.0, 50.0, 0.05)
  let mut gm_nakamura = @glicko2.Glicko2Rating::new(2800.0, 60.0, 0.05)
  let mut gm_ding = @glicko2.Glicko2Rating::new(2780.0, 65.0, 0.05)
  let mut im_rising = @glicko2.Glicko2Rating::new(2450.0, 150.0, 0.07)

  println("Round 1: World Championship Duel (Carlsen vs Nakamura)")
  let (c1, n1) = @glicko2.rate_1v1(
    gm_carlsen,
    gm_nakamura,
    @types.GameOutcome::Win,
  )
  gm_carlsen = c1
  gm_nakamura = n1
  println(
    "  Carlsen wins: Rating=" +
    gm_carlsen.rating.to_string() +
    " (RD=" +
    gm_carlsen.deviation.to_string() +
    ")",
  )
  println(
    "  Nakamura loses: Rating=" +
    gm_nakamura.rating.to_string() +
    " (RD=" +
    gm_nakamura.deviation.to_string() +
    ")",
  )

  println("Round 2: Upset Challenge (Rising IM vs Ding Liren)")
  let (im2, d2) = @glicko2.rate_1v1(
    im_rising,
    gm_ding,
    @types.GameOutcome::Draw,
  )
  im_rising = im2
  gm_ding = d2
  println(
    "  Rising IM draws with Ding! IM Rating=" +
    im_rising.rating.to_string() +
    ", Ding=" +
    gm_ding.rating.to_string(),
  )

  println("\nTournament Finished. All rating updates completed smoothly.")
}
