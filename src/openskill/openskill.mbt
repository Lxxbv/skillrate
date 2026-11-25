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

// -----------------------------------------------------------------------------
// Extended OpenSkill Models: Weng-Lin BT-Full, TM-Full, Telemetry MVP & Podium
// -----------------------------------------------------------------------------

///|
/// Weng-Lin (2011) Algorithm 1: Bradley-Terry Full Pairwise Multi-Team Bayesian Model.
/// Uses logistic link function P(Team i > Team q) = 1 / (1 + exp(-(mu_i - mu_q) / c_iq))
/// instead of Gaussian probit, providing heavier tails for upset-prone esports and battle royales.
pub fn rate_teams_bradley_terry_full(
  teams : Array[Array[@types.Rating]],
  ranks~ : Array[Int32] = [],
  tau~ : Double = 0.0833333,
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
) -> Array[Array[@types.Rating]] {
  let k = teams.length()
  if k == 0 {
    return []
  }

  let effective_ranks : Array[Int32] = if ranks.length() == k {
    ranks
  } else {
    let r = []
    for i in 0..<k {
      r.push(i + 1)
    }
    r
  }

  // Apply additive prior dynamics tau^2 before match evaluation
  let prior_teams : Array[Array[@types.Rating]] = []
  let team_means : Array[Double] = []
  let team_vars : Array[Double] = []

  for i in 0..<k {
    let pt : Array[@types.Rating] = []
    let mut tm = 0.0
    let mut tv = 0.0
    for r in teams[i] {
      let new_var = r.variance() + tau * tau
      let pr = @types.Rating::new(r.mu, new_var.sqrt())
      pt.push(pr)
      tm = tm + pr.mu
      tv = tv + new_var
    }
    prior_teams.push(pt)
    team_means.push(tm)
    team_vars.push(tv)
  }

  let beta_sq = config.beta * config.beta
  let updated_teams : Array[Array[@types.Rating]] = []

  for i in 0..<k {
    let mut omega_i = 0.0
    let mut delta_i = 0.0

    for q in 0..<k {
      if i == q {
        continue
      }
      let c_iq = (team_vars[i] + team_vars[q] + 2.0 * beta_sq).sqrt()
      let p_iq = 1.0 /
        (1.0 + @core_math.exp(-(team_means[i] - team_means[q]) / c_iq))
      let s_iq = if effective_ranks[i] < effective_ranks[q] {
        1.0
      } else if effective_ranks[i] > effective_ranks[q] {
        0.0
      } else {
        0.5
      }

      let gamma_iq = if config.gamma > 0.0 {
        config.gamma
      } else {
        team_vars[i].sqrt() / c_iq
      }

      omega_i = omega_i + team_vars[i] / c_iq * (s_iq - p_iq)
      delta_i = delta_i +
        gamma_iq * (team_vars[i] / (c_iq * c_iq)) * p_iq * (1.0 - p_iq)
    }

    let out_team : Array[@types.Rating] = []
    let tv_i = if team_vars[i] < 1.0e-9 { 1.0e-9 } else { team_vars[i] }
    for r in prior_teams[i] {
      let var_r = r.variance()
      let share = var_r / tv_i
      let new_mu = r.mu + share * omega_i
      let shrink = 1.0 - share * delta_i
      let safe_shrink = if shrink < 0.0001 { 0.0001 } else { shrink }
      let new_sigma = (var_r * safe_shrink).sqrt()
      out_team.push(@types.Rating::new(new_mu, new_sigma))
    }
    updated_teams.push(out_team)
  }

  updated_teams
}

///|
/// Weng-Lin (2011) Plackett-Luce Rank-Ordered Multi-Team Model.
/// Directly models the sequential probability of team rankings:
/// P(pi) = prod_{q=1}^k (exp(mu_q / c) / sum_{j >= q} exp(mu_j / c))
pub fn rate_teams_plackett_luce(
  teams : Array[Array[@types.Rating]],
  ranks~ : Array[Int32] = [],
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
) -> Array[Array[@types.Rating]] {
  let k = teams.length()
  if k == 0 {
    return []
  }

  let effective_ranks : Array[Int32] = if ranks.length() == k {
    ranks
  } else {
    let r = []
    for i in 0..<k {
      r.push(i + 1)
    }
    r
  }

  let team_means : Array[Double] = []
  let team_vars : Array[Double] = []
  let mut total_var = 0.0

  for i in 0..<k {
    let mut tm = 0.0
    let mut tv = 0.0
    for r in teams[i] {
      tm = tm + r.mu
      tv = tv + r.variance()
    }
    team_means.push(tm)
    team_vars.push(tv)
    total_var = total_var + tv
  }

  let c = (total_var + k.to_double() * config.beta * config.beta).sqrt()
  let scaled_exps : Array[Double] = []
  for i in 0..<k {
    scaled_exps.push(@core_math.exp(team_means[i] / c))
  }

  // For each rank stage q, compute denominator sum_{j : rank[j] >= rank[q]} exp(mu_j / c)
  let stage_denoms : Array[Double] = []
  for q in 0..<k {
    let mut d = 0.0
    for j in 0..<k {
      if effective_ranks[j] >= effective_ranks[q] {
        d = d + scaled_exps[j]
      }
    }
    stage_denoms.push(if d < 1.0e-12 { 1.0e-12 } else { d })
  }

  let updated_teams : Array[Array[@types.Rating]] = []
  for i in 0..<k {
    let mut omega_sum = 0.0
    let mut delta_sum = 0.0
    for q in 0..<k {
      if effective_ranks[q] <= effective_ranks[i] {
        let p_iq = scaled_exps[i] / stage_denoms[q]
        let indicator = if i == q { 1.0 } else { 0.0 }
        omega_sum = omega_sum + (indicator - p_iq) / c
        delta_sum = delta_sum + p_iq * (1.0 - p_iq) / (c * c)
      }
    }

    let gamma_i = if config.gamma > 0.0 {
      config.gamma
    } else {
      team_vars[i].sqrt() / c
    }

    let out_team : Array[@types.Rating] = []
    for r in teams[i] {
      let var_r = r.variance()
      let new_mu = r.mu + var_r * omega_sum
      let factor = 1.0 - gamma_i * var_r * delta_sum
      let safe_factor = if factor < 0.0001 { 0.0001 } else { factor }
      out_team.push(@types.Rating::new(new_mu, (var_r * safe_factor).sqrt()))
    }
    updated_teams.push(out_team)
  }

  updated_teams
}

///|
/// Rate a multi-team match with in-game KDA / MVP telemetry performance weighting.
/// Winning players with higher MatchPerformance contribution gain extra mu;
/// losing players with high MatchPerformance contribution have their rating loss cushioned.
pub fn rate_teams_with_telemetry(
  teams : Array[Array[@types.Rating]],
  performances : Array[Array[@types.MatchPerformance]],
  ranks : Array[Int32],
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
) -> Array[Array[@types.Rating]] {
  let k = teams.length()
  if k == 0 {
    return []
  }

  // First compute standard unweighted update to distinguish winners vs losers
  let base_updated = rate_teams(teams, ranks~, config~)
  if performances.length() != k {
    return base_updated
  }

  let final_teams : Array[Array[@types.Rating]] = []
  for i in 0..<k {
    let team_orig = teams[i]
    let team_base = base_updated[i]
    let team_perf = performances[i]
    let m = team_orig.length()
    if team_perf.length() != m || m == 0 {
      final_teams.push(team_base)
      continue
    }

    // Normalize contribution weights around mean 1.0 within team i
    let raw_weights : Array[Double] = []
    let mut sum_w = 0.0
    for p in team_perf {
      let w = p.contribution_weight()
      raw_weights.push(w)
      sum_w = sum_w + w
    }
    let avg_w = if sum_w > 1.0e-6 { sum_w / m.to_double() } else { 1.0 }

    let adjusted_team : Array[@types.Rating] = []
    for j in 0..<m {
      let orig = team_orig[j]
      let base = team_base[j]
      let delta_mu = base.mu - orig.mu
      let norm_w = raw_weights[j] / avg_w

      // If player gained rating (delta_mu >= 0), scale by norm_w;
      // If player lost rating (delta_mu < 0), scale by (2.0 - norm_w) bounded to [0.4, 1.6]
      let mult = if delta_mu >= 0.0 {
        norm_w
      } else {
        let inv = 2.0 - norm_w
        if inv < 0.4 {
          0.4
        } else if inv > 1.6 {
          1.6
        } else {
          inv
        }
      }

      adjusted_team.push(
        @types.Rating::new(orig.mu + delta_mu * mult, base.sigma),
      )
    }
    final_teams.push(adjusted_team)
  }

  final_teams
}

///|
/// Predict 1st-place win probabilities for all k teams in a multi-team / Battle Royale lobby
/// using Plackett-Luce softmax over variance-discounted team ratings.
pub fn predict_multi_team_win_probabilities(
  teams : Array[Array[@types.Rating]],
  config~ : OpenSkillConfig = OpenSkillConfig::default(),
) -> Array[Double] {
  let k = teams.length()
  if k == 0 {
    return []
  }
  let means : Array[Double] = []
  let mut total_var = 0.0
  for t in teams {
    let mut m = 0.0
    let mut v = 0.0
    for r in t {
      m = m + r.mu
      v = v + r.variance()
    }
    means.push(m)
    total_var = total_var + v
  }
  let c = (total_var + k.to_double() * config.beta * config.beta).sqrt()
  let exps : Array[Double] = []
  let mut sum_exp = 0.0
  for m in means {
    let e = @core_math.exp(m / c)
    exps.push(e)
    sum_exp = sum_exp + e
  }
  let safe_sum = if sum_exp < 1.0e-12 { 1.0e-12 } else { sum_exp }
  let probs : Array[Double] = []
  for e in exps {
    probs.push(e / safe_sum)
  }
  probs
}
