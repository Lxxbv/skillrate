///|
/// Predictive Rating Calibration, Rank Correlation & Anti-Cheat Telemetry Suite.
/// Provides probabilistic forecast metrics (Brier Score, Log-Loss, ECE, MCE, ROC-AUC),
/// ordinal rank correlations (Kendall's Tau, Spearman's Rho),
/// anti-cheat anomaly detectors (CUSUM Boosting, Win-Trading Collusion, Sandbagging),
/// and rating ecosystem health telemetry (Gini inequality, Skewness, Kurtosis).

// -----------------------------------------------------------------------------
// 1. Probabilistic Forecast & Calibration Metrics
// -----------------------------------------------------------------------------

///|
/// A single predicted vs actual match outcome observation.
pub(all) struct PredictionRecord {
  predicted_prob : Double
  actual_score : Double
  weight : Double
} derive(Eq, Debug)

///|
/// Construct a PredictionRecord.
pub fn PredictionRecord::new(
  predicted_prob : Double,
  actual_score : Double,
  weight~ : Double = 1.0,
) -> PredictionRecord {
  { predicted_prob, actual_score, weight, }
}

///|
/// Calculate weighted Brier Score: (1 / W) * sum w_i * (p_i - y_i)^2.
/// A perfectly calibrated deterministic oracle achieves 0.0; uniform coin-flip achieves 0.25.
pub fn brier_score(records : Array[PredictionRecord]) -> Double {
  if records.is_empty() {
    return 0.0
  }
  let mut sum_sq = 0.0
  let mut sum_w = 0.0
  for r in records {
    let w = if r.weight < 0.0 { 0.0 } else { r.weight }
    let diff = r.predicted_prob - r.actual_score
    sum_sq = sum_sq + w * diff * diff
    sum_w = sum_w + w
  }
  if sum_w <= 1.0e-12 {
    0.0
  } else {
    sum_sq / sum_w
  }
}

///|
/// Calculate weighted Binary Cross-Entropy (Log-Loss):
/// -(1 / W) * sum w_i * (y_i * ln(p_i) + (1 - y_i) * ln(1 - p_i)).
pub fn log_loss(
  records : Array[PredictionRecord],
  eps~ : Double = 1.0e-7,
) -> Double {
  if records.is_empty() {
    return 0.0
  }
  let mut total_loss = 0.0
  let mut sum_w = 0.0
  for r in records {
    let w = if r.weight < 0.0 { 0.0 } else { r.weight }
    let p = if r.predicted_prob < eps {
      eps
    } else if r.predicted_prob > 1.0 - eps {
      1.0 - eps
    } else {
      r.predicted_prob
    }
    let y = r.actual_score
    let loss = -(y * @core_math.ln(p) + (1.0 - y) * @core_math.ln(1.0 - p))
    total_loss = total_loss + w * loss
    sum_w = sum_w + w
  }
  if sum_w <= 1.0e-12 {
    0.0
  } else {
    total_loss / sum_w
  }
}

///|
/// Calibration reliability bin statistics.
pub(all) struct CalibrationBin {
  bin_index : Int32
  lower_bound : Double
  upper_bound : Double
  sample_count : Int32
  mean_predicted : Double
  mean_actual : Double
  calibration_gap : Double
} derive(Eq, Debug)

///|
/// Summary report of Expected Calibration Error (ECE) and Maximum Calibration Error (MCE).
pub(all) struct CalibrationReport {
  ece : Double
  mce : Double
  brier : Double
  logloss : Double
  bins : Array[CalibrationBin]
} derive(Eq, Debug)

///|
/// Compute reliability diagram bins, Expected Calibration Error (ECE),
/// and Maximum Calibration Error (MCE) across `num_bins` uniform probability intervals in [0, 1].
pub fn evaluate_calibration(
  records : Array[PredictionRecord],
  num_bins~ : Int32 = 10,
) -> CalibrationReport {
  let k = if num_bins < 2 { 2 } else { num_bins }
  let kf = k.to_double()
  let counts = Array::make(k, 0)
  let sum_pred = Array::make(k, 0.0)
  let sum_act = Array::make(k, 0.0)

  let total_n = records.length()
  for r in records {
    let p = if r.predicted_prob < 0.0 {
      0.0
    } else if r.predicted_prob > 1.0 {
      1.0
    } else {
      r.predicted_prob
    }
    let raw_idx = (p * kf).to_int()
    let idx = if raw_idx >= k {
      k - 1
    } else if raw_idx < 0 {
      0
    } else {
      raw_idx
    }
    counts[idx] = counts[idx] + 1
    sum_pred[idx] = sum_pred[idx] + p
    sum_act[idx] = sum_act[idx] + r.actual_score
  }

  let bins : Array[CalibrationBin] = []
  let mut ece = 0.0
  let mut mce = 0.0
  let total_nf = if total_n > 0 { total_n.to_double() } else { 1.0 }

  for i = 0; i < k; i = i + 1 {
    let lower = i.to_double() / kf
    let upper = (i + 1).to_double() / kf
    let c = counts[i]
    if c > 0 {
      let cf = c.to_double()
      let mp = sum_pred[i] / cf
      let ma = sum_act[i] / cf
      let gap = (mp - ma).abs()
      ece = ece + cf / total_nf * gap
      if gap > mce {
        mce = gap
      }
      bins.push({
        bin_index: i,
        lower_bound: lower,
        upper_bound: upper,
        sample_count: c,
        mean_predicted: mp,
        mean_actual: ma,
        calibration_gap: gap,
      })
    } else {
      bins.push({
        bin_index: i,
        lower_bound: lower,
        upper_bound: upper,
        sample_count: 0,
        mean_predicted: 0.5 * (lower + upper),
        mean_actual: 0.0,
        calibration_gap: 0.0,
      })
    }
  }

  { ece, mce, brier: brier_score(records), logloss: log_loss(records), bins, }
}

///|
/// Compute Area Under the ROC Curve (AUC-ROC) using the exact pairwise Mann-Whitney U statistic.
/// Treats `actual_score > 0.5` as positive class and `actual_score < 0.5` as negative class.
pub fn roc_auc_score(records : Array[PredictionRecord]) -> Double {
  let pos_probs : Array[Double] = []
  let neg_probs : Array[Double] = []
  for r in records {
    if r.actual_score > 0.5 {
      pos_probs.push(r.predicted_prob)
    } else if r.actual_score < 0.5 {
      neg_probs.push(r.predicted_prob)
    }
  }
  let n_pos = pos_probs.length()
  let n_neg = neg_probs.length()
  if n_pos == 0 || n_neg == 0 {
    return 0.5
  }

  let mut concordant = 0.0
  for p_pos in pos_probs {
    for p_neg in neg_probs {
      if p_pos > p_neg {
        concordant = concordant + 1.0
      } else if (p_pos - p_neg).abs() <= 1.0e-12 {
        concordant = concordant + 0.5
      }
    }
  }
  concordant / (n_pos.to_double() * n_neg.to_double())
}

// -----------------------------------------------------------------------------
// 2. Ordinal Rank Correlation Metrics (Kendall's Tau & Spearman's Rho)
// -----------------------------------------------------------------------------

///|
/// Calculate Kendall's Tau rank correlation coefficient in [-1.0, 1.0]
/// between two ranking vectors `ranks_a` and `ranks_b` of equal length:
/// tau = (C - D) / (n * (n - 1) / 2)
pub fn kendall_tau_correlation(
  ranks_a : Array[Double],
  ranks_b : Array[Double],
) -> Double {
  let n = ranks_a.length()
  if n <= 1 || ranks_b.length() != n {
    return 1.0
  }
  let mut concordant = 0.0
  let mut discordant = 0.0
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      let da = ranks_a[i] - ranks_a[j]
      let db = ranks_b[i] - ranks_b[j]
      let prod = da * db
      if prod > 1.0e-12 {
        concordant = concordant + 1.0
      } else if prod < -1.0e-12 {
        discordant = discordant + 1.0
      }
    }
  }
  let total_pairs = n.to_double() * (n - 1).to_double() / 2.0
  (concordant - discordant) / total_pairs
}

///|
/// Calculate Spearman's rank correlation coefficient rho in [-1.0, 1.0]
/// between two rank-order arrays `order_a` and `order_b`:
/// rho = 1 - (6 * sum d_i^2) / (n * (n^2 - 1))
pub fn spearman_rank_correlation(
  order_a : Array[Int32],
  order_b : Array[Int32],
) -> Double {
  let n = order_a.length()
  if n <= 1 || order_b.length() != n {
    return 1.0
  }
  let mut sum_d2 = 0.0
  for i = 0; i < n; i = i + 1 {
    let d = (order_a[i] - order_b[i]).to_double()
    sum_d2 = sum_d2 + d * d
  }
  let nf = n.to_double()
  1.0 - 6.0 * sum_d2 / (nf * (nf * nf - 1.0))
}

// -----------------------------------------------------------------------------
// 3. Anti-Cheat, Account Boosting, Collusion & Sandbagging Detectors
// -----------------------------------------------------------------------------

///|
/// Output diagnosis of Page's CUSUM regime-shift detector on a player's match history.
pub(all) struct CusumAnomalyReport {
  player_id : String
  peak_positive_cusum : Double
  peak_negative_cusum : Double
  change_point_match_index : Int32
  is_boosting_suspected : Bool
  is_deranking_suspected : Bool
} derive(Eq, Debug)

///|
/// Run Page's Two-Sided Cumulative Sum (CUSUM) sequential change-point detection
/// over a player's sequence of `(expected_win_prob, actual_score)` observations:
/// S_t^+ = max(0, S_{t-1}^+ + (y_t - p_t - drift))
/// S_t^- = max(0, S_{t-1}^- + (p_t - y_t - drift))
/// Flags account boosting (sudden upward skill jump) or intentional deranking (sudden downward collapse).
pub fn detect_cusum_regime_shift(
  player_id : String,
  observations : Array[(Double, Double)],
  drift~ : Double = 0.12,
  threshold~ : Double = 2.8,
) -> CusumAnomalyReport {
  let mut s_pos = 0.0
  let mut s_neg = 0.0
  let mut max_pos = 0.0
  let mut max_neg = 0.0
  let mut change_idx = -1

  let n = observations.length()
  for i = 0; i < n; i = i + 1 {
    let (exp_p, act_s) = observations[i]
    let residual = act_s - exp_p
    let next_pos = s_pos + residual - drift
    s_pos = if next_pos > 0.0 { next_pos } else { 0.0 }

    let next_neg = s_neg - residual - drift
    s_neg = if next_neg > 0.0 { next_neg } else { 0.0 }

    if s_pos > max_pos {
      max_pos = s_pos
      if s_pos >= threshold && change_idx == -1 {
        change_idx = i
      }
    }
    if s_neg > max_neg {
      max_neg = s_neg
      if s_neg >= threshold && change_idx == -1 {
        change_idx = i
      }
    }
  }

  {
    player_id,
    peak_positive_cusum: max_pos,
    peak_negative_cusum: max_neg,
    change_point_match_index: change_idx,
    is_boosting_suspected: max_pos >= threshold,
    is_deranking_suspected: max_neg >= threshold,
  }
}

///|
/// Suspicious win-trading / collusion edge between two accounts.
pub(all) struct CollusionPairReport {
  beneficiary_id : String
  donor_id : String
  encounters : Int32
  beneficiary_wins : Int32
  cumulative_surprise : Double
  suspicion_score : Double
} derive(Eq, Debug)

///|
/// Scan historical matches `(winner_id, loser_id, winner_expected_prob)` for win-trading / collusion:
/// Identifies pairs `(beneficiary, donor)` with repeated abnormal wins and high cumulative surprise.
pub fn detect_wintrading_collusion(
  match_logs : Array[(String, String, Double)],
  min_encounters~ : Int32 = 3,
  surprise_threshold~ : Double = 1.8,
) -> Array[CollusionPairReport] {
  // Aggregate directed pair statistics (winner, loser) -> (wins, total_games, surprise_sum)
  let pair_keys : Array[(String, String)] = []
  let pair_wins : Array[Int32] = []
  let pair_games : Array[Int32] = []
  let pair_surprise : Array[Double] = []

  for log in match_logs {
    let (w_id, l_id, exp_w) = log
    let surprise = 1.0 - exp_w
    let mut found_dir = -1
    let mut found_rev = -1

    for i = 0; i < pair_keys.length(); i = i + 1 {
      let (k1, k2) = pair_keys[i]
      if k1 == w_id && k2 == l_id {
        found_dir = i
      } else if k1 == l_id && k2 == w_id {
        found_rev = i
      }
    }

    if found_dir != -1 {
      pair_wins[found_dir] = pair_wins[found_dir] + 1
      pair_games[found_dir] = pair_games[found_dir] + 1
      pair_surprise[found_dir] = pair_surprise[found_dir] + surprise
    } else {
      pair_keys.push((w_id, l_id))
      pair_wins.push(1)
      pair_games.push(1)
      pair_surprise.push(surprise)
    }

    if found_rev != -1 {
      pair_games[found_rev] = pair_games[found_rev] + 1
    }
  }

  let reports : Array[CollusionPairReport] = []
  for i = 0; i < pair_keys.length(); i = i + 1 {
    let games = pair_games[i]
    let wins = pair_wins[i]
    let surp = pair_surprise[i]
    if games >= min_encounters && surp >= surprise_threshold {
      let win_rate = wins.to_double() / games.to_double()
      let susp = surp * win_rate
      reports.push({
        beneficiary_id: pair_keys[i].0,
        donor_id: pair_keys[i].1,
        encounters: games,
        beneficiary_wins: wins,
        cumulative_surprise: surp,
        suspicion_score: susp,
      })
    }
  }

  // Sort descending by suspicion_score
  let m = reports.length()
  for i = 0; i < m; i = i + 1 {
    for j = 0; j < m - 1 - i; j = j + 1 {
      if reports[j].suspicion_score < reports[j + 1].suspicion_score {
        let tmp = reports[j]
        reports[j] = reports[j + 1]
        reports[j + 1] = tmp
      }
    }
  }
  reports
}

///|
/// Detect "sandbagging" (deliberate throwing followed by smurf stomping) from a sequence
/// of `(won_match, match_performance_kda)`.
/// Measures bimodal separation between KDA in wins vs KDA in losses, plus streak alternation.
pub fn detect_sandbagging_score(
  history : Array[(Bool, Double)],
) -> (Double, Bool) {
  let n = history.length()
  if n < 4 {
    return (0.0, false)
  }
  let mut win_kda_sum = 0.0
  let mut win_count = 0
  let mut loss_kda_sum = 0.0
  let mut loss_count = 0

  for item in history {
    let (won, kda) = item
    if won {
      win_kda_sum = win_kda_sum + kda
      win_count = win_count + 1
    } else {
      loss_kda_sum = loss_kda_sum + kda
      loss_count = loss_count + 1
    }
  }

  if win_count == 0 || loss_count == 0 {
    return (0.0, false)
  }

  let avg_win_kda = win_kda_sum / win_count.to_double()
  let avg_loss_kda = loss_kda_sum / loss_count.to_double()
  let safe_loss_kda = if avg_loss_kda < 0.25 { 0.25 } else { avg_loss_kda }
  let ratio = avg_win_kda / safe_loss_kda

  // Sandbaggers typically have very high KDA in wins (> 5.0) and near-zero KDA in deliberate losses (< 0.6)
  let score = if avg_loss_kda < 0.8 && avg_win_kda > 4.0 {
    ratio
  } else {
    ratio * 0.35
  }
  (score, score >= 5.0)
}

// -----------------------------------------------------------------------------
// 4. Ecosystem Population Distribution & Inequality Telemetry
// -----------------------------------------------------------------------------

///|
/// Macro-level statistical telemetry of a competitive rating ecosystem.
pub(all) struct EcosystemTelemetry {
  population_size : Int32
  mean_mu : Double
  std_dev_mu : Double
  mean_sigma : Double
  skewness : Double
  excess_kurtosis : Double
  gini_coefficient : Double
  calibrated_ratio : Double
} derive(Eq, Debug)

///|
/// Compute comprehensive ecosystem health telemetry across an array of player ratings.
pub fn compute_ecosystem_telemetry(
  ratings : Array[@types.Rating],
  calibration_sigma_threshold~ : Double = 5.0,
) -> EcosystemTelemetry {
  let n = ratings.length()
  if n == 0 {
    return {
      population_size: 0,
      mean_mu: 25.0,
      std_dev_mu: 0.0,
      mean_sigma: 8.333,
      skewness: 0.0,
      excess_kurtosis: 0.0,
      gini_coefficient: 0.0,
      calibrated_ratio: 0.0,
    }
  }

  let nf = n.to_double()
  let mut sum_mu = 0.0
  let mut sum_sigma = 0.0
  let mut calibrated_count = 0
  let mus : Array[Double] = []

  for r in ratings {
    let pos_mu = if r.mu < 0.1 { 0.1 } else { r.mu }
    mus.push(pos_mu)
    sum_mu = sum_mu + r.mu
    sum_sigma = sum_sigma + r.sigma
    if r.sigma <= calibration_sigma_threshold {
      calibrated_count = calibrated_count + 1
    }
  }

  let mean_mu = sum_mu / nf
  let mean_sigma = sum_sigma / nf

  let mut m2 = 0.0
  let mut m3 = 0.0
  let mut m4 = 0.0
  for r in ratings {
    let d = r.mu - mean_mu
    let d2 = d * d
    m2 = m2 + d2
    m3 = m3 + d2 * d
    m4 = m4 + d2 * d2
  }
  let var_mu = m2 / nf
  let std_mu = var_mu.sqrt()
  let skewness = if std_mu > 1.0e-9 {
    m3 / nf / (std_mu * std_mu * std_mu)
  } else {
    0.0
  }
  let kurtosis = if var_mu > 1.0e-9 {
    m4 / nf / (var_mu * var_mu) - 3.0
  } else {
    0.0
  }

  // Sort mus ascending to compute Gini coefficient:
  // G = (2 * sum_{i=1}^n i * y_i) / (n * sum y_i) - (n + 1) / n
  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n - 1 - i; j = j + 1 {
      if mus[j] > mus[j + 1] {
        let tmp = mus[j]
        mus[j] = mus[j + 1]
        mus[j + 1] = tmp
      }
    }
  }

  let mut weighted_sum = 0.0
  let mut total_pos_mu = 0.0
  for i = 0; i < n; i = i + 1 {
    weighted_sum = weighted_sum + (i + 1).to_double() * mus[i]
    total_pos_mu = total_pos_mu + mus[i]
  }
  let gini = if total_pos_mu > 1.0e-9 && n > 1 {
    2.0 * weighted_sum / (nf * total_pos_mu) - (nf + 1.0) / nf
  } else {
    0.0
  }

  {
    population_size: n,
    mean_mu,
    std_dev_mu: std_mu,
    mean_sigma,
    skewness,
    excess_kurtosis: kurtosis,
    gini_coefficient: if gini < 0.0 {
      0.0
    } else {
      gini
    },
    calibrated_ratio: calibrated_count.to_double() / nf,
  }
}
