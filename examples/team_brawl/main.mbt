///|
/// Team Brawl Simulator: Simulating a 4v4 MOBA clash and 3-team Free-For-All.
fn main {
  println("==================================================================")
  println("  MOBA Team Brawl & 4v4 League Rating Simulator (OpenSkill)       ")
  println("==================================================================")

  // 1. Setup 4v4 Teams
  let team_red = [
    @types.Rating::new(30.0, 5.0),
    @types.Rating::new(28.0, 5.0),
    @types.Rating::new(27.0, 5.0),
    @types.Rating::new(25.0, 5.0),
  ]
  let team_blue = [
    @types.Rating::new(29.0, 5.0),
    @types.Rating::new(28.0, 5.0),
    @types.Rating::new(26.0, 5.0),
    @types.Rating::new(25.0, 5.0),
  ]

  let quality = @matchmaker.match_quality_2teams(team_red, team_blue)
  let p_red_win = @openskill.predict_win(team_red, team_blue)
  println("Match: Red Team (Avg mu=27.5) vs Blue Team (Avg mu=27.0)")
  println("  Fair Match Quality: " + (quality * 100.0).to_string() + "%")
  println("  Red Win Expectancy: " + (p_red_win * 100.0).to_string() + "%")

  let updated = @openskill.rate_teams([team_red, team_blue], ranks=[1, 2])
  println("Result: Red Team Victory!")
  println(
    "  Red Carry New Rating: mu=" +
    updated[0][0].mu.to_string() +
    ", sigma=" +
    updated[0][0].sigma.to_string(),
  )
  println(
    "  Blue Carry New Rating: mu=" +
    updated[1][0].mu.to_string() +
    ", sigma=" +
    updated[1][0].sigma.to_string(),
  )

  println("\n3-Team Free-for-All (FFA) Showdown:")
  let t_gold = [@types.Rating::default()]
  let t_silver = [@types.Rating::default()]
  let t_bronze = [@types.Rating::default()]
  let ffa_updated = @openskill.rate_teams([t_gold, t_silver, t_bronze], ranks=[
    1, 2, 3,
  ])
  println("  1st Place Gold Team: mu=" + ffa_updated[0][0].mu.to_string())
  println("  2nd Place Silver Team: mu=" + ffa_updated[1][0].mu.to_string())
  println("  3rd Place Bronze Team: mu=" + ffa_updated[2][0].mu.to_string())
  println("Simulation finished.")
}
