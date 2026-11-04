///|
/// Default beta for match quality calculation (half of standard deviation 25/3).
pub const DEFAULT_BETA : Double = 4.166666666666667

///|
/// Calculate match quality between two participants (1v1).
/// Returns a value in (0.0, 1.0], where 1.0 represents a perfectly balanced match.
pub fn match_quality_1v1(
  player_a : @types.Rating,
  player_b : @types.Rating,
  beta~ : Double = DEFAULT_BETA,
) -> Double {
  let delta_mu = player_a.mu - player_b.mu
  let beta_sq = beta * beta
  let denom_var = player_a.variance() + player_b.variance() + 2.0 * beta_sq

  let exponent = -(delta_mu * delta_mu) / (2.0 * denom_var)
  let exp_term = @core_math.exp(exponent)
  let scale_term = (2.0 * beta_sq / denom_var).sqrt()

  exp_term * scale_term
}

///|
/// Calculate match quality between two multi-player teams.
pub fn match_quality_2teams(
  team_a : Array[@types.Rating],
  team_b : Array[@types.Rating],
  beta~ : Double = DEFAULT_BETA,
) -> Double {
  let mut mu_a = 0.0
  let mut var_a = 0.0
  for r in team_a {
    mu_a = mu_a + r.mu
    var_a = var_a + r.variance()
  }

  let mut mu_b = 0.0
  let mut var_b = 0.0
  for r in team_b {
    mu_b = mu_b + r.mu
    var_b = var_b + r.variance()
  }

  let delta_mu = mu_a - mu_b
  let beta_sq = beta * beta
  let denom_var = var_a + var_b + 2.0 * beta_sq

  let exponent = -(delta_mu * delta_mu) / (2.0 * denom_var)
  let exp_term = @core_math.exp(exponent)
  let scale_term = (2.0 * beta_sq / denom_var).sqrt()

  exp_term * scale_term
}

///|
/// Calculate overall match quality for multi-team games (N teams)
/// by computing the geometric mean of all pairwise match qualities.
pub fn match_quality_teams(
  teams : Array[Array[@types.Rating]],
  beta~ : Double = DEFAULT_BETA,
) -> Double {
  let k = teams.length()
  if k < 2 {
    return 1.0
  }
  if k == 2 {
    return match_quality_2teams(teams[0], teams[1], beta~)
  }

  let mut log_sum = 0.0
  let mut pairs_count = 0.0

  for i in 0..<k {
    for j in (i + 1)..<k {
      let q = match_quality_2teams(teams[i], teams[j], beta~)
      let safe_q = if q < 1.0e-12 { 1.0e-12 } else { q }
      log_sum = log_sum + @core_math.ln(safe_q)
      pairs_count = pairs_count + 1.0
    }
  }

  if pairs_count == 0.0 {
    1.0
  } else {
    @core_math.exp(log_sum / pairs_count)
  }
}

///|
/// Check if a match is considered fair given a minimum quality threshold (default 0.5).
pub fn is_fair_match(
  teams : Array[Array[@types.Rating]],
  min_quality~ : Double = 0.5,
  beta~ : Double = DEFAULT_BETA,
) -> Bool {
  match_quality_teams(teams, beta~) >= min_quality
}

///|
/// Compute a full win probability matrix between all teams.
/// matrix[i][j] gives the probability that Team i beats Team j.
pub fn win_probability_matrix(
  teams : Array[Array[@types.Rating]],
  beta~ : Double = DEFAULT_BETA,
) -> Array[Array[Double]] {
  let k = teams.length()
  let matrix = []

  let team_means = []
  let team_vars = []
  for t in teams {
    let mut m = 0.0
    let mut v = 0.0
    for r in t {
      m = m + r.mu
      v = v + r.variance()
    }
    team_means.push(m)
    team_vars.push(v)
  }

  let beta_sq = beta * beta

  for i in 0..<k {
    let row = []
    for j in 0..<k {
      if i == j {
        row.push(0.5)
      } else {
        let diff = team_means[i] - team_means[j]
        let c = (team_vars[i] + team_vars[j] + 2.0 * beta_sq).sqrt()
        let prob = @smath.normal_cdf(diff / c)
        row.push(prob)
      }
    }
    matrix.push(row)
  }

  matrix
}
