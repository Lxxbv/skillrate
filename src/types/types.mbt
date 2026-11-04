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
