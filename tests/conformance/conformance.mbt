///|
/// Helper for running the full statistical conformance suite.
pub fn is_conformance_suite_available() -> Bool {
  let r = @types.Rating::default()
  let g = @glicko2.Glicko2Rating::default()
  let t = @openskill.rate_teams([[r]], ranks=[1])
  t.length() > 0 && g.rating > 0.0
}
