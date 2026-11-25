///|
/// Core Rating model representing a participant's skill distribution:
/// N(mu, sigma^2).
pub(all) struct Rating {
  mu : Double
  sigma : Double
} derive(Eq, Debug)

///|
/// Construct a new Rating with explicit mu and sigma.
pub fn Rating::new(mu : Double, sigma : Double) -> Rating {
  { mu, sigma, }
}

///|
/// Default rating in Bayesian systems (mu = 25.0, sigma = 25.0 / 3.0 ~ 8.333).
pub fn Rating::default() -> Rating {
  { mu: 25.0, sigma: 25.0 / 3.0, }
}

///|
/// Conservative ordinal score: mu - z * sigma.
/// Default z is 3.0 (99.7% confidence lower bound).
pub fn Rating::ordinal(self : Rating, z~ : Double = 3.0) -> Double {
  self.mu - z * self.sigma
}

///|
/// Return the variance (sigma^2) of the rating.
pub fn Rating::variance(self : Rating) -> Double {
  self.sigma * self.sigma
}

///|
/// Outcome of a match between two participants.
pub(all) enum GameOutcome {
  Win
  Loss
  Draw
} derive(Eq, Debug)

///|
/// Convert GameOutcome to standard numerical score: Win=1.0, Loss=0.0, Draw=0.5.
pub fn GameOutcome::to_score(self : GameOutcome) -> Double {
  match self {
    Win => 1.0
    Loss => 0.0
    Draw => 0.5
  }
}

///|
/// Create GameOutcome from floating score.
pub fn GameOutcome::from_score(score : Double) -> GameOutcome {
  if score >= 0.75 {
    Win
  } else if score <= 0.25 {
    Loss
  } else {
    Draw
  }
}

///|
/// Invert the outcome from the opponent's perspective.
pub fn GameOutcome::reverse(self : GameOutcome) -> GameOutcome {
  match self {
    Win => Loss
    Loss => Win
    Draw => Draw
  }
}

///|
/// A competitive player with identifier, current rating, and display name.
pub(all) struct Player {
  id : String
  rating : Rating
  name : String
} derive(Eq, Debug)

///|
/// Construct a new player.
pub fn Player::new(
  id : String,
  rating~ : Rating = Rating::default(),
  name~ : String = "",
) -> Player {
  let display_name = if name == "" { id } else { name }
  { id, rating, name: display_name, }
}

///|
/// A competitive team consisting of one or more players, with an optional team weight.
pub(all) struct Team {
  id : String
  players : Array[Player]
  weight : Double
} derive(Eq, Debug)

///|
/// Construct a team with multiple players and optional weight.
pub fn Team::new(
  id : String,
  players : Array[Player],
  weight~ : Double = 1.0,
) -> Team {
  { id, players, weight, }
}

///|
/// Construct a single-player team (for 1v1 duels).
pub fn Team::single(player : Player, weight~ : Double = 1.0) -> Team {
  { id: player.id, players: [player], weight, }
}

// -----------------------------------------------------------------------------
// Extended Domain Models: Confidence Intervals, Roles, Telemetry & Match Logs
// -----------------------------------------------------------------------------

///|
/// Statistical confidence interval [lower, upper] for a player's skill estimate.
pub(all) struct ConfidenceInterval {
  mean : Double
  lower : Double
  upper : Double
  z_score : Double
} derive(Eq, Debug)

///|
/// Construct a ConfidenceInterval around a mean and standard deviation.
pub fn ConfidenceInterval::from_gaussian(
  mean : Double,
  sigma : Double,
  z_score~ : Double = 1.959963984540054,
) -> ConfidenceInterval {
  let half = z_score * sigma
  { mean, lower: mean - half, upper: mean + half, z_score, }
}

///|
/// Total span (upper - lower) of the confidence interval.
pub fn ConfidenceInterval::width(self : ConfidenceInterval) -> Double {
  self.upper - self.lower
}

///|
/// Check whether a candidate rating falls inside this confidence interval.
pub fn ConfidenceInterval::contains(
  self : ConfidenceInterval,
  value : Double,
) -> Bool {
  value >= self.lower && value <= self.upper
}

///|
/// Check whether two confidence intervals overlap (indicating statistically indistinguishable skill).
pub fn ConfidenceInterval::overlaps(
  self : ConfidenceInterval,
  other : ConfidenceInterval,
) -> Bool {
  self.lower <= other.upper && other.lower <= self.upper
}

///|
/// Compute a 95% (or custom z) confidence interval for a Rating.
pub fn Rating::confidence_interval(
  self : Rating,
  z~ : Double = 1.959963984540054,
) -> ConfidenceInterval {
  ConfidenceInterval::from_gaussian(self.mu, self.sigma, z_score=z)
}

///|
/// Signal-to-noise ratio (mu / sigma) measuring calibration certainty.
pub fn Rating::snr(self : Rating) -> Double {
  if self.sigma <= 1.0e-9 {
    1.0e9
  } else {
    self.mu / self.sigma
  }
}

///|
/// Precision (inverse variance: 1 / sigma^2) of the Gaussian belief.
pub fn Rating::precision(self : Rating) -> Double {
  let v = self.variance()
  if v <= 1.0e-12 {
    1.0e12
  } else {
    1.0 / v
  }
}

///|
/// Precision-weighted mean (mu / sigma^2) for Gaussian message passing.
pub fn Rating::precision_adjusted_mean(self : Rating) -> Double {
  self.mu * self.precision()
}

///|
/// Multiply two independent Gaussian skill beliefs N(mu1, s1^2) * N(mu2, s2^2)
/// via precision addition (used in belief propagation and prior fusion).
pub fn Rating::fuse_belief(self : Rating, other : Rating) -> Rating {
  let p1 = self.precision()
  let p2 = other.precision()
  let total_p = p1 + p2
  let fused_mu = (self.mu * p1 + other.mu * p2) / total_p
  let fused_sigma = (1.0 / total_p).sqrt()
  { mu: fused_mu, sigma: fused_sigma, }
}

///|
/// Apply additive dynamics variance (time decay tau^2) capped at max_sigma.
pub fn Rating::apply_dynamics(
  self : Rating,
  tau : Double,
  max_sigma~ : Double = 25.0 / 3.0,
) -> Rating {
  let raw_sigma = (self.sigma * self.sigma + tau * tau).sqrt()
  let bounded = if raw_sigma > max_sigma { max_sigma } else { raw_sigma }
  { mu: self.mu, sigma: bounded, }
}

///|
/// Convert Bayesian Rating (mu=25, sigma=8.333) to display MMR scale (center=1500).
pub fn Rating::to_mmr(
  self : Rating,
  base~ : Double = 1500.0,
  scale~ : Double = 60.0,
) -> Double {
  base + (self.mu - 25.0) * scale
}

///|
/// Construct a Bayesian Rating from a display MMR value.
pub fn Rating::from_mmr(
  mmr : Double,
  sigma~ : Double = 25.0 / 3.0,
  base~ : Double = 1500.0,
  scale~ : Double = 60.0,
) -> Rating {
  let safe_scale = if scale.abs() < 1.0e-9 { 60.0 } else { scale }
  { mu: 25.0 + (mmr - base) / safe_scale, sigma, }
}

///|
/// Tactical position or role in role-queued team matchmaking (MOBA / Tactical Shooters).
pub(all) enum TacticalRole {
  Top
  Jungle
  Mid
  Bot
  Support
  Flex
} derive(Eq, Debug)

///|
/// Convert TacticalRole to canonical string label.
pub fn TacticalRole::to_label(self : TacticalRole) -> String {
  match self {
    Top => "Top"
    Jungle => "Jungle"
    Mid => "Mid"
    Bot => "Bot"
    Support => "Support"
    Flex => "Flex"
  }
}

///|
/// Individual in-game telemetry metrics for performance-weighted rating updates (MVP / KDA adjustment).
pub(all) struct MatchPerformance {
  player_id : String
  kills : Int32
  deaths : Int32
  assists : Int32
  damage_share : Double
  objective_score : Double
} derive(Eq, Debug)

///|
/// Construct a MatchPerformance record.
pub fn MatchPerformance::new(
  player_id : String,
  kills~ : Int32 = 0,
  deaths~ : Int32 = 0,
  assists~ : Int32 = 0,
  damage_share~ : Double = 0.2,
  objective_score~ : Double = 50.0,
) -> MatchPerformance {
  { player_id, kills, deaths, assists, damage_share, objective_score, }
}

///|
/// Compute KDA ratio: (Kills + Assists) / max(1, Deaths).
pub fn MatchPerformance::kda_ratio(self : MatchPerformance) -> Double {
  let d = if self.deaths <= 0 { 1.0 } else { self.deaths.to_double() }
  (self.kills + self.assists).to_double() / d
}

///|
/// Compute normalized contribution weight in [0.5, 1.75] for team rating attribution.
pub fn MatchPerformance::contribution_weight(self : MatchPerformance) -> Double {
  let kda_term = self.kda_ratio() / 3.0
  let clamped_kda = if kda_term > 1.5 { 1.5 } else { kda_term }
  let dmg_term = self.damage_share / 0.2
  let obj_term = self.objective_score / 50.0
  let raw = 0.4 * clamped_kda + 0.35 * dmg_term + 0.25 * obj_term
  if raw < 0.5 {
    0.5
  } else if raw > 1.75 {
    1.75
  } else {
    raw
  }
}

///|
/// Historical match record for batch rating solvers, Whole-History Rating, and calibration analytics.
pub(all) struct HistoricalMatch {
  match_id : Int32
  player_a : String
  player_b : String
  outcome : GameOutcome
  day_epoch : Int32
  handicap_a : Double
  weight : Double
} derive(Eq, Debug)

///|
/// Construct a HistoricalMatch entry.
pub fn HistoricalMatch::new(
  match_id : Int32,
  player_a : String,
  player_b : String,
  outcome : GameOutcome,
  day_epoch~ : Int32 = 0,
  handicap_a~ : Double = 0.0,
  weight~ : Double = 1.0,
) -> HistoricalMatch {
  { match_id, player_a, player_b, outcome, day_epoch, handicap_a, weight, }
}

///|
/// Calculate additive composite rating of a Team (sum of mu, root-sum-square of sigma).
pub fn Team::composite_rating(self : Team) -> Rating {
  let mut sum_mu = 0.0
  let mut sum_var = 0.0
  for p in self.players {
    sum_mu = sum_mu + p.rating.mu * self.weight
    sum_var = sum_var + p.rating.variance() * self.weight * self.weight
  }
  { mu: sum_mu, sigma: sum_var.sqrt(), }
}

///|
/// Calculate average player rating within a Team.
pub fn Team::average_rating(self : Team) -> Rating {
  let n = self.players.length()
  if n == 0 {
    return Rating::default()
  }
  let comp = self.composite_rating()
  let nf = n.to_double()
  { mu: comp.mu / nf, sigma: comp.sigma / nf.sqrt(), }
}

///|
/// Calculate internal skill spread (standard deviation of player mu values) inside a Team.
pub fn Team::internal_skill_spread(self : Team) -> Double {
  let n = self.players.length()
  if n <= 1 {
    return 0.0
  }
  let avg = self.average_rating().mu
  let mut sq_diff = 0.0
  for p in self.players {
    let d = p.rating.mu - avg
    sq_diff = sq_diff + d * d
  }
  (sq_diff / n.to_double()).sqrt()
}
