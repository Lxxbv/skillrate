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
