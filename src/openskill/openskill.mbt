///|
/// Configuration for OpenSkill Bayesian rating calculations.
pub(all) struct OpenSkillConfig {
  mu : Double
  sigma : Double
  beta : Double
  gamma : Double
  draw_margin : Double
  z : Double
} derive(Eq, Debug)

///|
/// Create an OpenSkillConfig with customizable parameters.
pub fn OpenSkillConfig::new(
  mu~ : Double = 25.0,
  sigma~ : Double = 25.0 / 3.0,
  beta~ : Double = 25.0 / 6.0,
  gamma~ : Double = 0.0,
  draw_margin~ : Double = 0.1,
  z~ : Double = 3.0,
) -> OpenSkillConfig {
  { mu, sigma, beta, gamma, draw_margin, z, }
}

///|
/// Default OpenSkill configuration aligned with the Weng-Lin specification.
pub fn OpenSkillConfig::default() -> OpenSkillConfig {
  {
    mu: 25.0,
    sigma: 25.0 / 3.0,
    beta: 25.0 / 6.0,
    gamma: 0.0,
    draw_margin: 0.1,
    z: 3.0,
  }
}

///|
/// Predict the win probability of Team A against Team B:
/// P(Team A wins) = Phi((mu_A - mu_B) / sqrt(sigma_A^2 + sigma_B^2 + 2*beta^2))
pub fn predict_win(
  team_a : Array[@types.Rating],
  team_b : Array[@types.Rating],
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
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

  let beta_sq = config.beta * config.beta
  let c = (var_a + var_b + 2.0 * beta_sq).sqrt()
  let diff = (mu_a - mu_b) / c
  @smath.normal_cdf(diff)
}

///|
/// Predict draw probability between Team A and Team B given draw_margin.
pub fn predict_draw(
  team_a : Array[@types.Rating],
  team_b : Array[@types.Rating],
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
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

  let beta_sq = config.beta * config.beta
  let c = (var_a + var_b + 2.0 * beta_sq).sqrt()
  let diff = (mu_a - mu_b) / c
  let t = config.draw_margin / c

  let prob_high = @smath.normal_cdf(t - diff)
  let prob_low = @smath.normal_cdf(-t - diff)
  (prob_high - prob_low).abs()
}

///|
/// Update ratings of multiple teams after a match.
/// teams: Array of teams, each containing an Array of Rating.
/// ranks: Optional ranks from 1 (1st place) upwards. Ties have the same rank (e.g. [1, 2] or [1, 1]).
/// weights: Optional per-player weights. If empty, all weights default to 1.0.
pub fn rate_teams(
  teams : Array[Array[@types.Rating]],
  ranks~ : Array[Int32] = [],
  weights~ : Array[Array[Double]] = [],
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
) -> Array[Array[@types.Rating]] {
  let k = teams.length()
  if k == 0 {
    return []
  }

  // Resolve ranks: default to [1, 2, ..., k]
  let effective_ranks : Array[Int32] = if ranks.length() == k {
    ranks
  } else {
    let r = []
    for i in 0..<k {
      r.push(i + 1)
    }
    r
  }

  // Resolve weights
  let effective_weights : Array[Array[Double]] = if weights.length() == k {
    weights
  } else {
    let w = []
    for team in teams {
      let team_w = []
      for _ in team {
        team_w.push(1.0)
      }
      w.push(team_w)
    }
    w
  }

  // Step 1: Compute aggregated team means and variances
  let team_means = []
  let team_vars = []

  for i in 0..<k {
    let team = teams[i]
    let team_w = effective_weights[i]
    let mut t_mean = 0.0
    let mut t_var = 0.0
    for j in 0..<team.length() {
      let w = team_w[j]
      let r = team[j]
      t_mean = t_mean + w * r.mu
      t_var = t_var + w * w * r.variance()
    }
    team_means.push(t_mean)
    team_vars.push(t_var)
  }

  // Step 2: Compute pairwise omega and delta gradients for each team
  let beta_sq = config.beta * config.beta
  let omegas = []
  let deltas = []

  for i in 0..<k {
    let mut omega_i = 0.0
    let mut delta_i = 0.0

    for q in 0..<k {
      if i == q {
        continue
      }
      let c_iq = (team_vars[i] + team_vars[q] + 2.0 * beta_sq).sqrt()
      let c_iq_sq = c_iq * c_iq
      let d_iq = (team_means[i] - team_means[q]) / c_iq
      let t = config.draw_margin / c_iq

      if effective_ranks[i] == effective_ranks[q] {
        // Tie between team i and team q
        let diff_high = t - d_iq
        let diff_low = -t - d_iq
        let denom = @smath.normal_cdf(diff_high) - @smath.normal_cdf(diff_low)
        let safe_denom = if denom.abs() < 1.0e-12 { 1.0e-12 } else { denom }

        let v_iq = (@smath.normal_pdf(diff_low) - @smath.normal_pdf(diff_high)) /
          safe_denom
        let w_iq = v_iq * v_iq +
          (
            diff_high * @smath.normal_pdf(diff_high) -
            diff_low * @smath.normal_pdf(diff_low)
          ) /
          safe_denom

        omega_i = omega_i + 1.0 / c_iq * v_iq
        delta_i = delta_i + 1.0 / c_iq_sq * w_iq
      } else if effective_ranks[i] < effective_ranks[q] {
        // Team i beat team q
        let diff = d_iq - t
        let denom = @smath.normal_cdf(diff)
        let safe_denom = if denom < 1.0e-12 { 1.0e-12 } else { denom }

        let v_iq = @smath.normal_pdf(diff) / safe_denom
        let w_iq = v_iq * (v_iq + diff)

        omega_i = omega_i + 1.0 / c_iq * v_iq
        delta_i = delta_i + 1.0 / c_iq_sq * w_iq
      } else {
        // Team i lost to team q (symmetric w_iq to team q beating team i)
        let diff = -d_iq - t
        let denom = @smath.normal_cdf(diff)
        let safe_denom = if denom < 1.0e-12 { 1.0e-12 } else { denom }

        let v_base = @smath.normal_pdf(diff) / safe_denom
        let v_iq = -v_base
        let w_iq = v_base * (v_base + diff)

        omega_i = omega_i + 1.0 / c_iq * v_iq
        delta_i = delta_i + 1.0 / c_iq_sq * w_iq
      }
    }

    omegas.push(omega_i)
    deltas.push(delta_i)
  }

  // Step 3: Update individual ratings
  let updated_teams = []

  for i in 0..<k {
    let team = teams[i]
    let team_w = effective_weights[i]
    let omega_i = omegas[i]
    let delta_i = deltas[i]
    let updated_team = []

    for j in 0..<team.length() {
      let r = team[j]
      let w = team_w[j]
      let var_r = r.variance()

      // Mean update
      let new_mu = r.mu + w * var_r * omega_i

      // Variance shrinkage with variance multiplier cap
      let factor = 1.0 - w * w * var_r * delta_i
      let safe_factor = if factor < 0.0001 { 0.0001 } else { factor }
      let new_var = var_r * safe_factor
      let new_sigma = new_var.sqrt()

      updated_team.push(@types.Rating::new(new_mu, new_sigma))
    }

    updated_teams.push(updated_team)
  }

  updated_teams
}

///|
/// Update ratings for a 2-team match based on GameOutcome (Win, Loss, Draw).
pub fn rate_2teams(
  team_a : Array[@types.Rating],
  team_b : Array[@types.Rating],
  outcome : @types.GameOutcome,
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
) -> (Array[@types.Rating], Array[@types.Rating]) {
  let ranks = match outcome {
    Win => [1, 2]
    Loss => [2, 1]
    Draw => [1, 1]
  }
  let res = rate_teams([team_a, team_b], ranks~, config~)
  (res[0], res[1])
}
