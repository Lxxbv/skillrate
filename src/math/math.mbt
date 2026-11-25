///|
/// Mathematical constants for statistical computations.
pub const PI : Double = 3.141592653589793238462643383279502884

///|
pub const SQRT_2 : Double = 1.414213562373095048801688724209698078

///|
pub const SQRT_2PI : Double = 2.506628274631000502415765284811045253

///|
/// Standard normal probability density function (PDF):
/// phi(x) = (1 / sqrt(2*pi)) * exp(-x^2 / 2)
pub fn normal_pdf(x : Double) -> Double {
  1.0 / SQRT_2PI * @core_math.exp(-0.5 * x * x)
}

///|
/// High-accuracy error function erf(x) based on Abramowitz & Stegun 7.1.26.
/// Maximum error |epsilon(x)| <= 1.5e-7.
pub fn erf(x : Double) -> Double {
  if x == 0.0 {
    return 0.0
  }
  let sign = if x < 0.0 { -1.0 } else { 1.0 }
  let abs_x = x.abs()

  // A&S formula 7.1.26 coefficients
  let p = 0.3275911
  let a1 = 0.254829592
  let a2 = -0.284496736
  let a3 = 1.421413741
  let a4 = -1.453152027
  let a5 = 1.061405429

  let t = 1.0 / (1.0 + p * abs_x)
  let poly = ((((a5 * t + a4) * t + a3) * t + a2) * t + a1) * t
  let res = 1.0 - poly * @core_math.exp(-abs_x * abs_x)
  sign * res
}

///|
/// Complementary error function erfc(x) = 1 - erf(x).
pub fn erfc(x : Double) -> Double {
  1.0 - erf(x)
}

///|
/// Standard normal cumulative distribution function (CDF):
/// Phi(x) = 0.5 * (1 + erf(x / sqrt(2)))
pub fn normal_cdf(x : Double) -> Double {
  0.5 * (1.0 + erf(x / SQRT_2))
}

///|
/// High-accuracy inverse of the standard normal CDF (probit function) Phi^{-1}(p).
/// Uses Acklam's rational approximation (absolute error < 1.15e-9).
pub fn normal_cdf_inv(p : Double) -> Double {
  if p <= 0.0 {
    return -1.0e100
  }
  if p >= 1.0 {
    return 1.0e100
  }

  // Coefficients in rational approximations
  let a1 = -3.969683028665376e1
  let a2 = 2.209460984245205e2
  let a3 = -2.759285104469687e2
  let a4 = 1.383577518672690e2
  let a5 = -3.066479806614716e1
  let a6 = 2.506628277459239e0

  let b1 = -5.447609879822406e1
  let b2 = 1.615858368580409e2
  let b3 = -1.556989798598866e2
  let b4 = 6.680131188771972e1
  let b5 = -1.328068155288572e1

  let c1 = -7.784894002430293e-3
  let c2 = -3.223964580411365e-1
  let c3 = -2.400758277161838e0
  let c4 = -2.549732539343734e0
  let c5 = 4.374664141464968e0
  let c6 = 2.938163982698783e0

  let d1 = 7.784695709041462e-3
  let d2 = 3.224671290700398e-1
  let d3 = 2.445134137142996e0
  let d4 = 3.754408661907416e0

  let p_low = 0.02425
  let p_high = 1.0 - p_low

  if p < p_low {
    // Rational approximation for lower region
    let q = (-2.0 * @core_math.ln(p)).sqrt()
    ((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q +
    c6 / ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0)
  } else if p <= p_high {
    // Rational approximation for central region
    let q = p - 0.5
    let r = q * q
    (((((a1 * r + a2) * r + a3) * r + a4) * r + a5) * r + a6) *
    q /
    (((((b1 * r + b2) * r + b3) * r + b4) * r + b5) * r + 1.0)
  } else {
    // Rational approximation for upper region
    let q = (-2.0 * @core_math.ln(1.0 - p)).sqrt()
    -(((((c1 * q + c2) * q + c3) * q + c4) * q + c5) * q + c6) /
    ((((d1 * q + d2) * q + d3) * q + d4) * q + 1.0)
  }
}

///|
/// High-accuracy inverse error function erfinv(x).
pub fn erfinv(x : Double) -> Double {
  1.0 / SQRT_2 * normal_cdf_inv(0.5 * (x + 1.0))
}

///|
/// Illinois method (modified secant method with guaranteed bracketing convergence)
/// for finding roots of f(x) = 0.
pub fn illinois_solve(
  f : (Double) -> Double,
  a_init : Double,
  b_init : Double,
  tolerance~ : Double = 1.0e-6,
  max_iterations~ : Int32 = 30,
) -> Double {
  let mut a = a_init
  let mut b = b_init
  let mut fa = f(a)
  let mut fb = f(b)

  for _ in 0..<max_iterations {
    if (b - a).abs() <= tolerance {
      return (a + b) / 2.0
    }
    // Secant step
    let denominator = fb - fa
    let c = if denominator.abs() < 1.0e-14 {
      (a + b) / 2.0
    } else {
      b - fb * (b - a) / denominator
    }
    let fc = f(c)
    if fc.abs() <= tolerance {
      return c
    }
    if fa * fc < 0.0 {
      b = c
      fb = fc
      fa = fa * 0.5 // Illinois modification
    } else {
      a = c
      fa = fc
      fb = fb * 0.5 // Illinois modification
    }
  }
  (a + b) / 2.0
}

// -----------------------------------------------------------------------------
// Logistic Distribution & Logit Transformations
// -----------------------------------------------------------------------------

///|
/// Standard logistic cumulative distribution function:
/// F(x; s) = 1 / (1 + exp(-x / s))
pub fn logistic_cdf(x : Double, scale~ : Double = 1.0) -> Double {
  let safe_s = if scale.abs() < 1.0e-12 { 1.0 } else { scale }
  let z = x / safe_s
  if z > 40.0 {
    1.0
  } else if z < -40.0 {
    0.0
  } else {
    1.0 / (1.0 + @core_math.exp(-z))
  }
}

///|
/// Standard logistic probability density function:
/// f(x; s) = F(x)(1 - F(x)) / s
pub fn logistic_pdf(x : Double, scale~ : Double = 1.0) -> Double {
  let safe_s = if scale.abs() < 1.0e-12 { 1.0 } else { scale }
  let p = logistic_cdf(x, scale=safe_s)
  p * (1.0 - p) / safe_s
}

///|
/// Logit quantile function (inverse of logistic CDF):
/// logit(p) = ln(p / (1 - p))
pub fn logit(p : Double, scale~ : Double = 1.0) -> Double {
  let clamped = if p <= 1.0e-12 {
    1.0e-12
  } else if p >= 1.0 - 1.0e-12 {
    1.0 - 1.0e-12
  } else {
    p
  }
  scale * @core_math.ln(clamped / (1.0 - clamped))
}

// -----------------------------------------------------------------------------
// Truncated Gaussian Moments for Bayesian Skill Updates
// -----------------------------------------------------------------------------

///|
/// Additive truncated Gaussian correction factor v(t, epsilon) for decisive outcomes:
/// v(t) = phi(t - eps) / Phi(t - eps)
pub fn truncated_normal_win_v(t : Double, margin~ : Double = 0.0) -> Double {
  let x = t - margin
  let denom = normal_cdf(x)
  if denom < 1.0e-12 {
    -x
  } else {
    normal_pdf(x) / denom
  }
}

///|
/// Multiplicative variance reduction factor w(t, epsilon) for decisive outcomes:
/// w(t) = v(t) * (v(t) + t - eps)
pub fn truncated_normal_win_w(t : Double, margin~ : Double = 0.0) -> Double {
  let x = t - margin
  let v = truncated_normal_win_v(t, margin~)
  let w = v * (v + x)
  if w < 0.0 {
    0.0
  } else if w >= 1.0 {
    0.9999
  } else {
    w
  }
}

///|
/// Additive truncated Gaussian correction factor v_draw(t, epsilon) for drawn outcomes.
pub fn truncated_normal_draw_v(t : Double, margin : Double) -> Double {
  let a = -margin - t
  let b = margin - t
  let denom = normal_cdf(b) - normal_cdf(a)
  if denom.abs() < 1.0e-12 {
    0.0
  } else {
    (normal_pdf(a) - normal_pdf(b)) / denom
  }
}

///|
/// Multiplicative variance reduction factor w_draw(t, epsilon) for drawn outcomes.
pub fn truncated_normal_draw_w(t : Double, margin : Double) -> Double {
  let a = -margin - t
  let b = margin - t
  let denom = normal_cdf(b) - normal_cdf(a)
  if denom.abs() < 1.0e-12 {
    0.0
  } else {
    let v = (normal_pdf(a) - normal_pdf(b)) / denom
    let term = (a * normal_pdf(a) - b * normal_pdf(b)) / denom
    let w = v * v + term
    if w < 0.0 {
      0.0
    } else if w >= 1.0 {
      0.9999
    } else {
      w
    }
  }
}

// -----------------------------------------------------------------------------
// Information Theory & Gaussian Distribution Divergences
// -----------------------------------------------------------------------------

///|
/// Kullback-Leibler divergence KL(N(mu1, sigma1^2) || N(mu2, sigma2^2))
/// between two univariate Gaussian skill distributions.
pub fn gaussian_kl_divergence(
  mu1 : Double,
  sigma1 : Double,
  mu2 : Double,
  sigma2 : Double,
) -> Double {
  let s1 = if sigma1 < 1.0e-9 { 1.0e-9 } else { sigma1 }
  let s2 = if sigma2 < 1.0e-9 { 1.0e-9 } else { sigma2 }
  let var1 = s1 * s1
  let var2 = s2 * s2
  let diff = mu1 - mu2
  @core_math.ln(s2 / s1) + (var1 + diff * diff) / (2.0 * var2) - 0.5
}

///|
/// Symmetric Jeffreys divergence J(P, Q) = 0.5 * (KL(P || Q) + KL(Q || P)).
pub fn gaussian_jeffreys_divergence(
  mu1 : Double,
  sigma1 : Double,
  mu2 : Double,
  sigma2 : Double,
) -> Double {
  0.5 *
  (
    gaussian_kl_divergence(mu1, sigma1, mu2, sigma2) +
    gaussian_kl_divergence(mu2, sigma2, mu1, sigma1)
  )
}

///|
/// Bhattacharyya distance between two Gaussian skill distributions:
/// D_B = (1/4) * ln((1/4)*(s1^2/s2^2 + s2^2/s1^2 + 2)) + (1/4)*((mu1 - mu2)^2 / (s1^2 + s2^2))
pub fn bhattacharyya_distance(
  mu1 : Double,
  sigma1 : Double,
  mu2 : Double,
  sigma2 : Double,
) -> Double {
  let s1 = if sigma1 < 1.0e-9 { 1.0e-9 } else { sigma1 }
  let s2 = if sigma2 < 1.0e-9 { 1.0e-9 } else { sigma2 }
  let var1 = s1 * s1
  let var2 = s2 * s2
  let var_term = 0.25 * @core_math.ln(0.25 * (var1 / var2 + var2 / var1 + 2.0))
  let diff = mu1 - mu2
  let mean_term = 0.25 * (diff * diff) / (var1 + var2)
  var_term + mean_term
}

///|
/// Bhattacharyya coefficient BC(P, Q) = exp(-D_B(P, Q)) in (0, 1],
/// measuring distribution overlap between two players' skills.
pub fn bhattacharyya_coefficient(
  mu1 : Double,
  sigma1 : Double,
  mu2 : Double,
  sigma2 : Double,
) -> Double {
  @core_math.exp(-bhattacharyya_distance(mu1, sigma1, mu2, sigma2))
}

///|
/// Hellinger distance H(P, Q) = sqrt(1 - BC(P, Q)) in [0, 1].
pub fn hellinger_distance(
  mu1 : Double,
  sigma1 : Double,
  mu2 : Double,
  sigma2 : Double,
) -> Double {
  let bc = bhattacharyya_coefficient(mu1, sigma1, mu2, sigma2)
  let diff = if 1.0 - bc < 0.0 { 0.0 } else { 1.0 - bc }
  diff.sqrt()
}

///|
/// 2-Wasserstein (Earth Mover's) distance between two Gaussian skill distributions:
/// W_2 = sqrt((mu1 - mu2)^2 + (sigma1 - sigma2)^2)
pub fn wasserstein2_distance(
  mu1 : Double,
  sigma1 : Double,
  mu2 : Double,
  sigma2 : Double,
) -> Double {
  let d_mu = mu1 - mu2
  let d_sigma = sigma1 - sigma2
  (d_mu * d_mu + d_sigma * d_sigma).sqrt()
}

// -----------------------------------------------------------------------------
// Numerical Solvers, Quadrature & Tridiagonal Matrix Algebra
// -----------------------------------------------------------------------------

///|
/// Newton-Raphson 1D root solver with derivative safeguard and damping.
pub fn newton_raphson_solve(
  f : (Double) -> Double,
  df : (Double) -> Double,
  x0 : Double,
  tolerance~ : Double = 1.0e-7,
  max_iterations~ : Int32 = 30,
) -> Double {
  let mut x = x0
  for _ in 0..<max_iterations {
    let fx = f(x)
    if fx.abs() <= tolerance {
      return x
    }
    let dfx = df(x)
    if dfx.abs() < 1.0e-14 {
      return x
    }
    let step = fx / dfx
    // Clamp step magnitude to avoid divergence
    let safe_step = if step > 10.0 {
      10.0
    } else if step < -10.0 {
      -10.0
    } else {
      step
    }
    x = x - safe_step
  }
  x
}

///|
/// Brent-Dekker hybrid root solver combining bisection, secant, and inverse quadratic interpolation.
pub fn brent_solve(
  f : (Double) -> Double,
  a_init : Double,
  b_init : Double,
  tolerance~ : Double = 1.0e-7,
  max_iterations~ : Int32 = 50,
) -> Double {
  let mut a = a_init
  let mut b = b_init
  let mut fa = f(a)
  let mut fb = f(b)

  if fa.abs() < fb.abs() {
    let tmp = a
    a = b
    b = tmp
    let ftmp = fa
    fa = fb
    fb = ftmp
  }

  let mut c = a
  let mut fc = fa
  let mut mflag = true
  let mut d = 0.0

  for _ in 0..<max_iterations {
    if fb.abs() <= tolerance || (b - a).abs() <= tolerance {
      return b
    }
    let mut s = if (fa - fc).abs() > 1.0e-14 && (fb - fc).abs() > 1.0e-14 {
      // Inverse quadratic interpolation
      a * fb * fc / ((fa - fb) * (fa - fc)) +
      b * fa * fc / ((fb - fa) * (fb - fc)) +
      c * fa * fb / ((fc - fa) * (fc - fb))
    } else {
      // Secant method
      b - fb * (b - a) / (fb - fa)
    }

    let cond1 = (s < (3.0 * a + b) / 4.0 && s < b) ||
      (s > (3.0 * a + b) / 4.0 && s > b)
    let cond2 = mflag && (s - b).abs() >= (b - c).abs() / 2.0
    let cond3 = !mflag && (s - b).abs() >= (c - d).abs() / 2.0
    if cond1 || cond2 || cond3 {
      s = (a + b) / 2.0
      mflag = true
    } else {
      mflag = false
    }

    let fs = f(s)
    d = c
    c = b
    fc = fb

    if fa * fs < 0.0 {
      b = s
      fb = fs
    } else {
      a = s
      fa = fs
    }

    if fa.abs() < fb.abs() {
      let tmp = a
      a = b
      b = tmp
      let ftmp = fa
      fa = fb
      fb = ftmp
    }
  }
  b
}

///|
/// Composite Simpson's 1/3 numerical quadrature over [a, b].
pub fn simpson_integrate(
  f : (Double) -> Double,
  a : Double,
  b : Double,
  intervals~ : Int32 = 64,
) -> Double {
  let n = if intervals <= 2 {
    2
  } else if intervals % 2 != 0 {
    intervals + 1
  } else {
    intervals
  }
  let h = (b - a) / n.to_double()
  let mut sum = f(a) + f(b)
  for i = 1; i < n; i = i + 1 {
    let x = a + i.to_double() * h
    let coeff = if i % 2 == 1 { 4.0 } else { 2.0 }
    sum = sum + coeff * f(x)
  }
  sum * h / 3.0
}

///|
/// Thomas algorithm O(N) solver for tridiagonal linear systems A * x = rhs:
/// sub[i] * x[i-1] + diag[i] * x[i] + sup[i] * x[i+1] = rhs[i].
/// Used by Whole-History Rating (WHR) to invert the Hessian matrix of Wiener-process priors.
pub fn solve_tridiagonal(
  sub : Array[Double],
  diag : Array[Double],
  sup : Array[Double],
  rhs : Array[Double],
) -> Array[Double] {
  let n = diag.length()
  if n == 0 {
    return []
  }
  if n == 1 {
    let d0 = if diag[0].abs() < 1.0e-12 { 1.0e-12 } else { diag[0] }
    return [rhs[0] / d0]
  }

  let c_prime = Array::make(n, 0.0)
  let d_prime = Array::make(n, 0.0)

  let b0 = if diag[0].abs() < 1.0e-12 { 1.0e-12 } else { diag[0] }
  c_prime[0] = sup[0] / b0
  d_prime[0] = rhs[0] / b0

  for i = 1; i < n; i = i + 1 {
    let a_i = if i < sub.length() { sub[i] } else { 0.0 }
    let c_i = if i < sup.length() { sup[i] } else { 0.0 }
    let denom = diag[i] - a_i * c_prime[i - 1]
    let safe_denom = if denom.abs() < 1.0e-12 { 1.0e-12 } else { denom }
    c_prime[i] = if i < n - 1 { c_i / safe_denom } else { 0.0 }
    d_prime[i] = (rhs[i] - a_i * d_prime[i - 1]) / safe_denom
  }

  let x = Array::make(n, 0.0)
  x[n - 1] = d_prime[n - 1]
  let mut idx = n - 2
  while idx >= 0 {
    x[idx] = d_prime[idx] - c_prime[idx] * x[idx + 1]
    idx = idx - 1
  }
  x
}

// -----------------------------------------------------------------------------
// Deterministic PRNG for Monte Carlo Tournament & Matchmaking Simulations
// -----------------------------------------------------------------------------

///|
/// Deterministic Linear Congruential / XorShift hybrid PRNG state.
pub(all) struct DeterministicRng {
  mut state : Int64
} derive(Eq, Debug)

///|
/// Initialize a deterministic PRNG with a non-zero seed.
pub fn DeterministicRng::new(seed~ : Int64 = 1337) -> DeterministicRng {
  let s = if seed == 0 { 1337L } else { seed }
  { state: s, }
}

///|
/// Advance PRNG state and return a pseudo-random positive 31-bit integer.
pub fn DeterministicRng::next_int(self : DeterministicRng) -> Int32 {
  // LCG with Knuth multiplier
  self.state = self.state * 6364136223846793005L + 1442695040888963407L
  let shifted = (self.state >> 32).to_int()
  if shifted < 0 {
    -shifted
  } else {
    shifted
  }
}

///|
/// Generate a uniform pseudo-random Double in [0.0, 1.0).
pub fn DeterministicRng::next_double(self : DeterministicRng) -> Double {
  let v = self.next_int() % 10000000
  v.to_double() / 10000000.0
}

///|
/// Generate a pseudo-random standard normal variable N(0, 1) via inverse CDF.
pub fn DeterministicRng::next_gaussian(
  self : DeterministicRng,
  mean~ : Double = 0.0,
  std_dev~ : Double = 1.0,
) -> Double {
  let u = self.next_double()
  let safe_u = if u < 1.0e-6 {
    1.0e-6
  } else if u > 1.0 - 1.0e-6 {
    1.0 - 1.0e-6
  } else {
    u
  }
  mean + std_dev * normal_cdf_inv(safe_u)
}
