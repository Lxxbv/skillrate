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
