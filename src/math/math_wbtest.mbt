///|
test "Normal PDF and CDF properties" {
  // Center of normal distribution
  let pdf_0 = normal_pdf(0.0)
  assert_true((pdf_0 - 0.3989422804014327).abs() < 1.0e-7)

  let cdf_0 = normal_cdf(0.0)
  assert_true((cdf_0 - 0.5).abs() < 1.0e-7)

  // Symmetry: CDF(-x) + CDF(x) == 1
  let cdf_pos = normal_cdf(1.95996) // approx 97.5%
  let cdf_neg = normal_cdf(-1.95996)
  assert_true((cdf_pos + cdf_neg - 1.0).abs() < 1.0e-6)
  assert_true((cdf_pos - 0.975).abs() < 1.0e-3)

  // 1 sigma, 2 sigma, 3 sigma bounds
  let cdf_1 = normal_cdf(1.0)
  assert_true((cdf_1 - 0.8413447).abs() < 1.0e-4)

  let cdf_3 = normal_cdf(3.0)
  assert_true((cdf_3 - 0.9986501).abs() < 1.0e-4)
}

///|
test "Error function erf and erfc" {
  assert_true(erf(0.0).abs() < 1.0e-10)
  assert_true((erf(1.0) - 0.84270079).abs() < 1.0e-5)
  assert_true((erf(-1.0) - -0.84270079).abs() < 1.0e-5)
  assert_true((erf(2.0) - 0.99532226).abs() < 1.0e-5)

  // erfc(x) = 1 - erf(x)
  assert_true((erfc(1.0) - (1.0 - erf(1.0))).abs() < 1.0e-10)
}

///|
test "Inverse CDF (probit) and erfinv" {
  let inv_half = normal_cdf_inv(0.5)
  assert_true(inv_half.abs() < 1.0e-7)

  let p = 0.975
  let z = normal_cdf_inv(p)
  assert_true((z - 1.95996).abs() < 1.0e-3)

  // Roundtrip: normal_cdf(normal_cdf_inv(p)) approx p
  for i in 1..<10 {
    let prob = i.to_double() / 10.0
    let x = normal_cdf_inv(prob)
    let roundtrip = normal_cdf(x)
    assert_true((roundtrip - prob).abs() < 1.0e-5)
  }

  // erfinv roundtrip
  let y = erf(0.5)
  let recovered = erfinv(y)
  assert_true((recovered - 0.5).abs() < 1.0e-5)
}

///|
test "Illinois numerical solver" {
  // Test root of x^3 - x - 2 = 0, root is approx 1.5213797
  let f = fn(x : Double) -> Double { x * x * x - x - 2.0 }
  let root = illinois_solve(f, 1.0, 2.0, tolerance=1.0e-7)
  assert_true((root - 1.5213797).abs() < 1.0e-5)
  assert_true(f(root).abs() < 1.0e-6)

  // Test root of exp(x) - 3 = 0, root is ln(3) approx 1.098612
  let f2 = fn(x : Double) -> Double { @core_math.exp(x) - 3.0 }
  let root2 = illinois_solve(f2, 0.0, 2.0, tolerance=1.0e-7)
  assert_true((root2 - 1.098612).abs() < 1.0e-5)
}

///|
test "Gaussian divergences, Brent solver, Simpson quadrature, and Thomas tridiagonal solver" {
  // Identical distributions have 0 KL, Bhattacharyya, Hellinger, and Wasserstein-2 distance
  assert_true(gaussian_kl_divergence(25.0, 5.0, 25.0, 5.0).abs() < 1.0e-9)
  assert_true(bhattacharyya_distance(25.0, 5.0, 25.0, 5.0).abs() < 1.0e-9)
  assert_true(
    (bhattacharyya_coefficient(25.0, 5.0, 25.0, 5.0) - 1.0).abs() < 1.0e-9,
  )
  assert_true(hellinger_distance(25.0, 5.0, 25.0, 5.0).abs() < 1.0e-9)
  assert_true(wasserstein2_distance(25.0, 5.0, 25.0, 5.0).abs() < 1.0e-9)

  // Brent solver on x^2 - 4 = 0 in [0, 5] -> 2.0
  let root = brent_solve(fn(x) { x * x - 4.0 }, 0.0, 5.0)
  assert_true((root - 2.0).abs() < 1.0e-6)

  // Simpson integration of x^2 over [0, 3] == 9.0
  let integral = simpson_integrate(fn(x) { x * x }, 0.0, 3.0, intervals=32)
  assert_true((integral - 9.0).abs() < 1.0e-7)

  // Tridiagonal system: [2 -1; -1 2] * [x0; x1] = [1; 1] -> x0=1, x1=1
  let sol = solve_tridiagonal([0.0, -1.0], [2.0, 2.0], [-1.0, 0.0], [1.0, 1.0])
  assert_eq(sol.length(), 2)
  assert_true((sol[0] - 1.0).abs() < 1.0e-7)
  assert_true((sol[1] - 1.0).abs() < 1.0e-7)
}
