///|
/// Bradley-Terry log-scale skill representation.
/// Skill parameter pi = exp(beta).
pub(all) struct BradleyTerryRating {
  beta : Double
} derive(Eq, Debug)

///|
/// Construct a new BradleyTerryRating.
pub fn BradleyTerryRating::new(beta~ : Double = 0.0) -> BradleyTerryRating {
  { beta, }
}

///|
/// Default BradleyTerryRating with initial log-skill 0.0 (pi = 1.0).
pub fn BradleyTerryRating::default() -> BradleyTerryRating {
  { beta: 0.0, }
}

///|
/// Return raw positive skill parameter pi = exp(beta).
pub fn BradleyTerryRating::pi(self : BradleyTerryRating) -> Double {
  @core_math.exp(self.beta)
}

///|
/// Configuration for Bradley-Terry model updates.
pub(all) struct BradleyTerryConfig {
  learning_rate : Double
  tie_margin : Double
} derive(Eq, Debug)

///|
/// Construct a BradleyTerryConfig.
pub fn BradleyTerryConfig::new(
  learning_rate~ : Double = 0.1,
  tie_margin~ : Double = 0.25,
) -> BradleyTerryConfig {
  { learning_rate, tie_margin, }
}

///|
/// Default configuration with lr=0.1.
pub fn BradleyTerryConfig::default() -> BradleyTerryConfig {
  { learning_rate: 0.1, tie_margin: 0.25, }
}

///|
/// Predict winning probability of Item A beating Item B:
/// P(A > B) = 1 / (1 + exp(-(beta_A - beta_B)))
pub fn predict_win_bt(a : BradleyTerryRating, b : BradleyTerryRating) -> Double {
  let diff = a.beta - b.beta
  1.0 / (1.0 + @core_math.exp(-diff))
}

///|
/// Online update for Bradley-Terry pair comparison using stochastic gradient step.
pub fn rate_1v1_bt(
  a : BradleyTerryRating,
  b : BradleyTerryRating,
  outcome : @types.GameOutcome,
  config~ : BradleyTerryConfig = BradleyTerryConfig::default(),
) -> (BradleyTerryRating, BradleyTerryRating) {
  let score_a = outcome.to_score()
  let prob_a = predict_win_bt(a, b)
  let delta = config.learning_rate * (score_a - prob_a)

  let new_beta_a = a.beta + delta
  let new_beta_b = b.beta - delta

  (
    BradleyTerryRating::new(beta=new_beta_a),
    BradleyTerryRating::new(beta=new_beta_b),
  )
}

///|
/// Batch Majorization-Minimization / Gradient solver for Bradley-Terry models.
/// Pairs is an array of (player_i, player_j, score_for_i).
pub fn batch_fit_bt(
  pairs : Array[(Int32, Int32, Double)],
  num_items : Int32,
  iterations~ : Int32 = 30,
  lr~ : Double = 0.05,
) -> Array[BradleyTerryRating] {
  let betas = Array::make(num_items, 0.0)

  for _it = 0; _it < iterations; _it = _it + 1 {
    let grads = Array::make(num_items, 0.0)

    for p in pairs {
      let (i, j, score) = p
      if i >= 0 && i < num_items && j >= 0 && j < num_items {
        let diff = betas[i] - betas[j]
        let prob_i = 1.0 / (1.0 + @core_math.exp(-diff))
        let error = score - prob_i

        grads[i] = grads[i] + error
        grads[j] = grads[j] - error
      }
    }

    for idx = 0; idx < num_items; idx = idx + 1 {
      betas[idx] = betas[idx] + lr * grads[idx]
    }
  }

  let result : Array[BradleyTerryRating] = []
  for idx = 0; idx < num_items; idx = idx + 1 {
    result.push(BradleyTerryRating::new(beta=betas[idx]))
  }
  result
}

// -----------------------------------------------------------------------------
// Thurstone-Mosteller Model (Case V)
// -----------------------------------------------------------------------------

///|
/// Thurstone-Mosteller Gaussian rating distribution N(mu, sigma^2).
pub(all) struct ThurstoneMostellerRating {
  mu : Double
  sigma : Double
} derive(Eq, Debug)

///|
/// Construct a ThurstoneMostellerRating.
pub fn ThurstoneMostellerRating::new(
  mu~ : Double = 25.0,
  sigma~ : Double = 25.0 / 3.0,
) -> ThurstoneMostellerRating {
  { mu, sigma, }
}

///|
/// Default ThurstoneMostellerRating.
pub fn ThurstoneMostellerRating::default() -> ThurstoneMostellerRating {
  { mu: 25.0, sigma: 25.0 / 3.0, }
}

///|
/// Configuration for Thurstone-Mosteller model.
pub(all) struct ThurstoneMostellerConfig {
  beta : Double
  draw_margin : Double
} derive(Eq, Debug)

///|
/// Construct ThurstoneMostellerConfig.
pub fn ThurstoneMostellerConfig::new(
  beta~ : Double = 25.0 / 6.0,
  draw_margin~ : Double = 0.1,
) -> ThurstoneMostellerConfig {
  { beta, draw_margin, }
}

///|
/// Default ThurstoneMostellerConfig.
pub fn ThurstoneMostellerConfig::default() -> ThurstoneMostellerConfig {
  { beta: 25.0 / 6.0, draw_margin: 0.1, }
}

///|
/// Predict winning probability in Thurstone-Mosteller model:
/// P(A > B) = Phi((mu_A - mu_B) / sqrt(sigma_A^2 + sigma_B^2 + 2*beta^2))
pub fn predict_win_tm(
  a : ThurstoneMostellerRating,
  b : ThurstoneMostellerRating,
  config~ : ThurstoneMostellerConfig = ThurstoneMostellerConfig::default(),
) -> Double {
  let c = (a.sigma * a.sigma +
  b.sigma * b.sigma +
  2.0 * config.beta * config.beta).sqrt()
  let diff = a.mu - b.mu
  @smath.normal_cdf(diff / c)
}

///|
/// Rate a 1v1 contest under Thurstone-Mosteller Case V closed-form Gaussian update.
pub fn rate_1v1_tm(
  a : ThurstoneMostellerRating,
  b : ThurstoneMostellerRating,
  outcome : @types.GameOutcome,
  config~ : ThurstoneMostellerConfig = ThurstoneMostellerConfig::default(),
) -> (ThurstoneMostellerRating, ThurstoneMostellerRating) {
  let c2 = a.sigma * a.sigma +
    b.sigma * b.sigma +
    2.0 * config.beta * config.beta
  let c = c2.sqrt()
  let diff = (a.mu - b.mu) / c

  let (v, w) = match outcome {
    Win => {
      let cdf = @smath.normal_cdf(diff)
      let pdf = @smath.normal_pdf(diff)
      let v_val = if cdf < 1.0e-12 { -diff } else { pdf / cdf }
      let w_val = v_val * (v_val + diff)
      (v_val, w_val)
    }
    Loss => {
      let inv_diff = -diff
      let cdf = @smath.normal_cdf(inv_diff)
      let pdf = @smath.normal_pdf(inv_diff)
      let v_val = if cdf < 1.0e-12 { -inv_diff } else { pdf / cdf }
      let w_val = v_val * (v_val + inv_diff)
      (-v_val, w_val)
    }
    Draw => {
      let margin = config.draw_margin / c
      let cdf_plus = @smath.normal_cdf(margin - diff)
      let cdf_minus = @smath.normal_cdf(-margin - diff)
      let denom = cdf_plus - cdf_minus
      let safe_denom = if denom < 1.0e-12 { 1.0e-12 } else { denom }
      let pdf_plus = @smath.normal_pdf(margin - diff)
      let pdf_minus = @smath.normal_pdf(-margin - diff)
      let v_val = (pdf_minus - pdf_plus) / safe_denom
      let w_val = v_val * v_val +
        ((margin - diff) * pdf_plus - (-margin - diff) * pdf_minus) / safe_denom
      (v_val, w_val)
    }
  }

  let var_factor_a = 1.0 - a.sigma * a.sigma / c2 * w
  let safe_factor_a = if var_factor_a < 0.0001 { 0.0001 } else { var_factor_a }
  let new_sigma_a = a.sigma * safe_factor_a.sqrt()
  let new_mu_a = a.mu + a.sigma * a.sigma / c * v

  let var_factor_b = 1.0 - b.sigma * b.sigma / c2 * w
  let safe_factor_b = if var_factor_b < 0.0001 { 0.0001 } else { var_factor_b }
  let new_sigma_b = b.sigma * safe_factor_b.sqrt()
  let new_mu_b = b.mu - b.sigma * b.sigma / c * v

  (
    ThurstoneMostellerRating::new(mu=new_mu_a, sigma=new_sigma_a),
    ThurstoneMostellerRating::new(mu=new_mu_b, sigma=new_sigma_b),
  )
}

// -----------------------------------------------------------------------------
// Extended Pairwise Preference Models: Davidson Ties, Rao-Kupper, Zermelo MM & LLM Arena
// -----------------------------------------------------------------------------

///|
/// Convert Bradley-Terry log-skill beta to LMSYS Chatbot Arena Elo scale:
/// ArenaElo = base + (400 / ln(10)) * beta (default base = 1000.0).
pub fn BradleyTerryRating::to_arena_elo(
  self : BradleyTerryRating,
  base~ : Double = 1000.0,
) -> Double {
  base + 173.7177927613 * self.beta
}

///|
/// Construct a BradleyTerryRating from an LMSYS Chatbot Arena Elo score.
pub fn BradleyTerryRating::from_arena_elo(
  arena_elo : Double,
  base~ : Double = 1000.0,
) -> BradleyTerryRating {
  { beta: (arena_elo - base) / 173.7177927613, }
}

///|
/// Davidson (1970) extension of the Bradley-Terry model accounting for ties:
/// Returns (prob_a_wins, prob_b_wins, prob_draw) given tie parameter nu >= 0.
/// P(A > B) = pi_A / (pi_A + pi_B + nu * sqrt(pi_A * pi_B))
/// P(A = B) = (nu * sqrt(pi_A * pi_B)) / (pi_A + pi_B + nu * sqrt(pi_A * pi_B))
pub fn predict_outcomes_davidson(
  a : BradleyTerryRating,
  b : BradleyTerryRating,
  nu~ : Double = 0.5,
) -> (Double, Double, Double) {
  let pi_a = a.pi()
  let pi_b = b.pi()
  let safe_nu = if nu < 0.0 { 0.0 } else { nu }
  let tie_term = safe_nu * @core_math.exp(0.5 * (a.beta + b.beta))
  let denom = pi_a + pi_b + tie_term
  (pi_a / denom, pi_b / denom, tie_term / denom)
}

///|
/// Online maximum-likelihood gradient update for the Davidson tie-aware model.
pub fn rate_1v1_davidson(
  a : BradleyTerryRating,
  b : BradleyTerryRating,
  outcome : @types.GameOutcome,
  nu~ : Double = 0.5,
  lr~ : Double = 0.1,
) -> (BradleyTerryRating, BradleyTerryRating) {
  let (p_win, p_loss, p_draw) = predict_outcomes_davidson(a, b, nu~)
  let expected_a = p_win + 0.5 * p_draw
  let actual_a = outcome.to_score()
  let grad = actual_a - expected_a
  let _ = p_loss
  (
    BradleyTerryRating::new(beta=a.beta + lr * grad),
    BradleyTerryRating::new(beta=b.beta - lr * grad),
  )
}

///|
/// Rao-Kupper (1967) threshold model for paired comparisons with ties:
/// Introduces threshold parameter theta = exp(eta) >= 1.
/// P(A > B) = pi_A / (pi_A + theta * pi_B)
/// P(B > A) = pi_B / (theta * pi_A + pi_B)
/// P(A = B) = 1 - P(A > B) - P(B > A)
pub fn predict_outcomes_rao_kupper(
  a : BradleyTerryRating,
  b : BradleyTerryRating,
  theta~ : Double = 1.25,
) -> (Double, Double, Double) {
  let safe_theta = if theta < 1.0 { 1.0 } else { theta }
  let pi_a = a.pi()
  let pi_b = b.pi()
  let p_a = pi_a / (pi_a + safe_theta * pi_b)
  let p_b = pi_b / (safe_theta * pi_a + pi_b)
  let p_tie = if 1.0 - p_a - p_b < 0.0 { 0.0 } else { 1.0 - p_a - p_b }
  (p_a, p_b, p_tie)
}

///|
/// Online gradient step for the Rao-Kupper paired comparison model.
pub fn rate_1v1_rao_kupper(
  a : BradleyTerryRating,
  b : BradleyTerryRating,
  outcome : @types.GameOutcome,
  theta~ : Double = 1.25,
  lr~ : Double = 0.1,
) -> (BradleyTerryRating, BradleyTerryRating) {
  let (p_a, _, p_tie) = predict_outcomes_rao_kupper(a, b, theta~)
  let exp_a = p_a + 0.5 * p_tie
  let score_a = outcome.to_score()
  let delta = lr * (score_a - exp_a)
  (
    BradleyTerryRating::new(beta=a.beta + delta),
    BradleyTerryRating::new(beta=b.beta - delta),
  )
}

///|
/// Zermelo (1929) / Hunter (2004) Minorization-Maximization (MM) fixed-point solver
/// for batch Bradley-Terry parameter estimation with L2 prior regularization:
/// pi_i^{(t+1)} = W_i / sum_{j != i} (N_{ij} / (pi_i^{(t)} + pi_j^{(t)}))
/// Mean log-skill beta is centered to 0.0 at every iteration for identifiability.
pub fn fit_bradley_terry_mm(
  pairs : Array[(Int32, Int32, Double)],
  num_items : Int32,
  iterations~ : Int32 = 40,
  l2_prior~ : Double = 0.01,
) -> Array[BradleyTerryRating] {
  if num_items <= 0 {
    return []
  }
  let pis = Array::make(num_items, 1.0)
  let wins = Array::make(num_items, l2_prior)

  for p in pairs {
    let (i, j, score_i) = p
    if i >= 0 && i < num_items && j >= 0 && j < num_items && i != j {
      wins[i] = wins[i] + score_i
      wins[j] = wins[j] + (1.0 - score_i)
    }
  }

  for _it = 0; _it < iterations; _it = _it + 1 {
    let denom_sums = Array::make(num_items, l2_prior)
    for p in pairs {
      let (i, j, _) = p
      if i >= 0 && i < num_items && j >= 0 && j < num_items && i != j {
        let inv_sum = 1.0 / (pis[i] + pis[j])
        denom_sums[i] = denom_sums[i] + inv_sum
        denom_sums[j] = denom_sums[j] + inv_sum
      }
    }

    let mut log_mean = 0.0
    for idx = 0; idx < num_items; idx = idx + 1 {
      let safe_d = if denom_sums[idx] < 1.0e-12 {
        1.0e-12
      } else {
        denom_sums[idx]
      }
      let next_pi = wins[idx] / safe_d
      pis[idx] = if next_pi < 1.0e-6 { 1.0e-6 } else { next_pi }
      log_mean = log_mean + @core_math.ln(pis[idx])
    }
    log_mean = log_mean / num_items.to_double()
    let scale = @core_math.exp(-log_mean)
    for idx = 0; idx < num_items; idx = idx + 1 {
      pis[idx] = pis[idx] * scale
    }
  }

  let out : Array[BradleyTerryRating] = []
  for idx = 0; idx < num_items; idx = idx + 1 {
    out.push(BradleyTerryRating::new(beta=@core_math.ln(pis[idx])))
  }
  out
}

///|
/// Calculate Fisher information I(beta_A, beta_B) = P(A > B) * (1 - P(A > B))
/// for an upcoming paired comparison. Maximized at 0.25 when beta_A == beta_B.
pub fn fisher_information_pair(
  a : BradleyTerryRating,
  b : BradleyTerryRating,
) -> Double {
  let p = predict_win_bt(a, b)
  p * (1.0 - p)
}

///|
/// Active Learning Pair Selector for LLM Chatbot Arena:
/// Selects the top_k pairs (i, j, fisher_info) that maximize expected information gain.
pub fn select_informative_arena_pairs(
  models : Array[BradleyTerryRating],
  top_k~ : Int32 = 5,
) -> Array[(Int32, Int32, Double)] {
  let n = models.length()
  let candidates : Array[(Int32, Int32, Double)] = []
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      let info = fisher_information_pair(models[i], models[j])
      candidates.push((i, j, info))
    }
  }

  // Sort descending by Fisher information
  let m = candidates.length()
  for i = 0; i < m; i = i + 1 {
    for j = 0; j < m - 1 - i; j = j + 1 {
      if candidates[j].2 < candidates[j + 1].2 {
        let tmp = candidates[j]
        candidates[j] = candidates[j + 1]
        candidates[j + 1] = tmp
      }
    }
  }

  let limit = if top_k < m { top_k } else { m }
  let selected : Array[(Int32, Int32, Double)] = []
  for i = 0; i < limit; i = i + 1 {
    selected.push(candidates[i])
  }
  selected
}

///|
/// Rate a Two-Team match under Thurstone-Mosteller Case V with variance-weighted team attribution.
pub fn rate_two_teams_tm(
  team_a : Array[ThurstoneMostellerRating],
  team_b : Array[ThurstoneMostellerRating],
  outcome : @types.GameOutcome,
  config~ : ThurstoneMostellerConfig = ThurstoneMostellerConfig::default(),
) -> (Array[ThurstoneMostellerRating], Array[ThurstoneMostellerRating]) {
  if team_a.is_empty() || team_b.is_empty() {
    return (team_a, team_b)
  }
  let mut mu_a = 0.0
  let mut var_a = 0.0
  for p in team_a {
    mu_a = mu_a + p.mu
    var_a = var_a + p.sigma * p.sigma
  }
  let mut mu_b = 0.0
  let mut var_b = 0.0
  for p in team_b {
    mu_b = mu_b + p.mu
    var_b = var_b + p.sigma * p.sigma
  }

  let comp_a = ThurstoneMostellerRating::new(mu=mu_a, sigma=var_a.sqrt())
  let comp_b = ThurstoneMostellerRating::new(mu=mu_b, sigma=var_b.sqrt())
  let (new_a, new_b) = rate_1v1_tm(comp_a, comp_b, outcome, config~)

  let delta_mu_a = new_a.mu - comp_a.mu
  let var_ratio_a = if var_a > 1.0e-9 {
    new_a.sigma * new_a.sigma / var_a
  } else {
    1.0
  }

  let out_a : Array[ThurstoneMostellerRating] = []
  for p in team_a {
    let w = if var_a > 1.0e-9 { p.sigma * p.sigma / var_a } else { 1.0 }
    out_a.push(
      ThurstoneMostellerRating::new(
        mu=p.mu + delta_mu_a * w,
        sigma=p.sigma * var_ratio_a.sqrt(),
      ),
    )
  }

  let delta_mu_b = new_b.mu - comp_b.mu
  let var_ratio_b = if var_b > 1.0e-9 {
    new_b.sigma * new_b.sigma / var_b
  } else {
    1.0
  }

  let out_b : Array[ThurstoneMostellerRating] = []
  for p in team_b {
    let w = if var_b > 1.0e-9 { p.sigma * p.sigma / var_b } else { 1.0 }
    out_b.push(
      ThurstoneMostellerRating::new(
        mu=p.mu + delta_mu_b * w,
        sigma=p.sigma * var_ratio_b.sqrt(),
      ),
    )
  }

  (out_a, out_b)
}

///|
/// Rate a Free-For-All (FFA) multi-player contest under Thurstone-Mosteller Case V.
pub fn rate_ffa_tm(
  players : Array[ThurstoneMostellerRating],
  ranks : Array[Int32],
  config~ : ThurstoneMostellerConfig = ThurstoneMostellerConfig::default(),
) -> Array[ThurstoneMostellerRating] {
  let n = players.length()
  if n <= 1 {
    return players
  }
  let denom = (n - 1).to_double()
  let updated : Array[ThurstoneMostellerRating] = []

  for i = 0; i < n; i = i + 1 {
    let r_i = if i < ranks.length() { ranks[i] } else { i + 1 }
    let mut sum_delta_mu = 0.0
    let mut sum_sigma = 0.0
    for j = 0; j < n; j = j + 1 {
      if i != j {
        let r_j = if j < ranks.length() { ranks[j] } else { j + 1 }
        let outcome = if r_i < r_j {
          @types.GameOutcome::Win
        } else if r_i > r_j {
          @types.GameOutcome::Loss
        } else {
          @types.GameOutcome::Draw
        }
        let (up_i, _) = rate_1v1_tm(players[i], players[j], outcome, config~)
        sum_delta_mu = sum_delta_mu + (up_i.mu - players[i].mu)
        sum_sigma = sum_sigma + up_i.sigma
      }
    }
    updated.push(
      ThurstoneMostellerRating::new(
        mu=players[i].mu + sum_delta_mu / denom,
        sigma=sum_sigma / denom,
      ),
    )
  }
  updated
}
