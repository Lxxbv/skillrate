///|
test "Brier score, log-loss, calibration ECE, and ROC-AUC" {
  let records = [
    PredictionRecord::new(0.85, 1.0),
    PredictionRecord::new(0.75, 1.0),
    PredictionRecord::new(0.20, 0.0),
    PredictionRecord::new(0.15, 0.0),
  ]

  let bs = brier_score(records)
  assert_true(bs > 0.0 && bs < 0.06)

  let ll = log_loss(records)
  assert_true(ll > 0.0 && ll < 0.3)

  let report = evaluate_calibration(records, num_bins=5)
  assert_true(report.ece >= 0.0 && report.ece < 0.25)

  let auc = roc_auc_score(records)
  assert_eq(auc, 1.0)
}

///|
test "Kendall Tau, Spearman rank correlation, CUSUM boosting, and wintrading detection" {
  let tau = kendall_tau_correlation([40.0, 30.0, 20.0], [42.0, 31.0, 19.0])
  assert_eq(tau, 1.0)

  let rho = spearman_rank_correlation([1, 2, 3, 4], [1, 2, 3, 4])
  assert_eq(rho, 1.0)

  // Simulate an account suddenly winning 6 consecutive matches where expected win prob was only 0.20
  let obs = [
    (0.5, 0.0),
    (0.2, 1.0),
    (0.2, 1.0),
    (0.2, 1.0),
    (0.2, 1.0),
    (0.2, 1.0),
  ]
  let cusum = detect_cusum_regime_shift(
    "boosted_acc",
    obs,
    drift=0.1,
    threshold=2.0,
  )
  assert_true(cusum.is_boosting_suspected)

  // Simulate win-trading pair where Donor feeds 4 unlikely wins to Beneficiary
  let logs = [
    ("Beneficiary", "Donor", 0.25),
    ("Beneficiary", "Donor", 0.20),
    ("Beneficiary", "Donor", 0.20),
    ("Beneficiary", "Donor", 0.20),
  ]
  let collusion = detect_wintrading_collusion(
    logs,
    min_encounters=3,
    surprise_threshold=1.5,
  )
  assert_eq(collusion.length(), 1)
  assert_eq(collusion[0].beneficiary_id, "Beneficiary")

  let (_, is_sandbag) = detect_sandbagging_score([
    (false, 0.2),
    (false, 0.3),
    (true, 8.5),
    (true, 9.0),
  ])
  assert_true(is_sandbag)
}
