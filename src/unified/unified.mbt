///|
/// Supported skill rating algorithms in the unified rating suite.
pub(all) enum AlgorithmKind {
  Elo
  Glicko
  Glicko2
  OpenSkill
  ThurstoneMosteller
  BradleyTerry
  DWZ
  ECF
} derive(Eq, Debug)

///|
/// Match topology describing the structure and participant grouping of a contest.
pub(all) enum MatchTopology {
  OneVsOne
  TwoTeam
  MultiTeam
  FreeForAll
} derive(Eq, Debug)

///|
/// Convert a generic Rating to GlickoRating.
fn to_glicko(r : @types.Rating) -> @glicko.GlickoRating {
  let scale = 173.7178
  let dev = if r.sigma * scale > 350.0 { 350.0 } else { r.sigma * scale }
  @glicko.GlickoRating::new(rating=r.mu * 60.0, deviation=dev)
}

///|
/// Convert a GlickoRating back to generic Rating.
fn from_glicko(g : @glicko.GlickoRating) -> @types.Rating {
  let scale = 173.7178
  @types.Rating::new(g.rating / 60.0, g.deviation / scale)
}

///|
/// Convert a generic Rating to Glicko2Rating.
fn to_glicko2(r : @types.Rating) -> @glicko2.Glicko2Rating {
  let scale = 173.7178
  let dev = if r.sigma * scale > 350.0 { 350.0 } else { r.sigma * scale }
  @glicko2.Glicko2Rating::new(r.mu * 60.0, dev, 0.06)
}

///|
/// Convert a Glicko2Rating back to generic Rating.
fn from_glicko2(g : @glicko2.Glicko2Rating) -> @types.Rating {
  let scale = 173.7178
  @types.Rating::new(g.rating / 60.0, g.deviation / scale)
}

///|
/// Compute composite average rating for a team.
fn average_team_rating(team : Array[@types.Rating]) -> @types.Rating {
  let n = team.length()
  if n == 0 {
    return @types.Rating::default()
  }
  let mut sum_mu = 0.0
  let mut sum_var = 0.0
  for r in team {
    sum_mu = sum_mu + r.mu
    sum_var = sum_var + r.sigma * r.sigma
  }
  let nf = n.to_double()
  @types.Rating::new(sum_mu / nf, (sum_var / nf).sqrt())
}

///|
/// Apply composite team rating shift back to individual players.
fn apply_team_delta(
  team : Array[@types.Rating],
  old_avg : @types.Rating,
  new_avg : @types.Rating,
) -> Array[@types.Rating] {
  let delta_mu = new_avg.mu - old_avg.mu
  let sigma_ratio = if old_avg.sigma > 1.0e-6 {
    new_avg.sigma / old_avg.sigma
  } else {
    1.0
  }
  let updated : Array[@types.Rating] = []
  for r in team {
    updated.push(@types.Rating::new(r.mu + delta_mu, r.sigma * sigma_ratio))
  }
  updated
}

///|
/// Unified 1v1 rating dispatch across all 8 algorithms.
pub fn rate_1v1(
  algo : AlgorithmKind,
  player_a : @types.Rating,
  player_b : @types.Rating,
  outcome : @types.GameOutcome,
) -> (@types.Rating, @types.Rating) {
  match algo {
    Elo => {
      let r_a = player_a.mu * 60.0
      let r_b = player_b.mu * 60.0
      let (new_a, new_b) = @elo.rate_1v1(r_a, r_b, outcome)
      (
        @types.Rating::new(new_a / 60.0, player_a.sigma * 0.98),
        @types.Rating::new(new_b / 60.0, player_b.sigma * 0.98),
      )
    }
    Glicko => {
      let g_a = to_glicko(player_a)
      let g_b = to_glicko(player_b)
      let (new_a, new_b) = @glicko.rate_1v1(g_a, g_b, outcome)
      (from_glicko(new_a), from_glicko(new_b))
    }
    Glicko2 => {
      let g_a = to_glicko2(player_a)
      let g_b = to_glicko2(player_b)
      let (new_a, new_b) = @glicko2.rate_1v1(g_a, g_b, outcome)
      (from_glicko2(new_a), from_glicko2(new_b))
    }
    OpenSkill => {
      let teams = [[player_a], [player_b]]
      let ranks = match outcome {
        Win => [1, 2]
        Loss => [2, 1]
        Draw => [1, 1]
      }
      let res = @openskill.rate_teams(teams, ranks~)
      (res[0][0], res[1][0])
    }
    ThurstoneMosteller => {
      let tm_a = @bt.ThurstoneMostellerRating::new(
        mu=player_a.mu,
        sigma=player_a.sigma,
      )
      let tm_b = @bt.ThurstoneMostellerRating::new(
        mu=player_b.mu,
        sigma=player_b.sigma,
      )
      let (new_a, new_b) = @bt.rate_1v1_tm(tm_a, tm_b, outcome)
      (
        @types.Rating::new(new_a.mu, new_a.sigma),
        @types.Rating::new(new_b.mu, new_b.sigma),
      )
    }
    BradleyTerry => {
      let bt_a = @bt.BradleyTerryRating::new(beta=player_a.mu / 10.0)
      let bt_b = @bt.BradleyTerryRating::new(beta=player_b.mu / 10.0)
      let (new_a, new_b) = @bt.rate_1v1_bt(bt_a, bt_b, outcome)
      (
        @types.Rating::new(new_a.beta * 10.0, player_a.sigma * 0.98),
        @types.Rating::new(new_b.beta * 10.0, player_b.sigma * 0.98),
      )
    }
    DWZ => {
      let dwz_a = @elo.DWZRating::new(rating=player_a.mu * 60.0, index=5)
      let dwz_b = @elo.DWZRating::new(rating=player_b.mu * 60.0, index=5)
      let (new_a, new_b) = @elo.rate_dwz_1v1(dwz_a, dwz_b, outcome)
      (
        @types.Rating::new(new_a.rating / 60.0, player_a.sigma * 0.98),
        @types.Rating::new(new_b.rating / 60.0, player_b.sigma * 0.98),
      )
    }
    ECF => {
      let ecf_a = @elo.ECFRating::from_elo(player_a.mu * 60.0)
      let ecf_b = @elo.ECFRating::from_elo(player_b.mu * 60.0)
      let (new_a, new_b) = @elo.rate_ecf_1v1(ecf_a, ecf_b, outcome)
      (
        @types.Rating::new(new_a.to_elo() / 60.0, player_a.sigma * 0.98),
        @types.Rating::new(new_b.to_elo() / 60.0, player_b.sigma * 0.98),
      )
    }
  }
}

///|
/// Unified two-team match rating dispatch supporting any of the 8 algorithms.
pub fn rate_two_teams(
  team_a : Array[@types.Rating],
  team_b : Array[@types.Rating],
  outcome : @types.GameOutcome,
  algo~ : AlgorithmKind = OpenSkill,
) -> (Array[@types.Rating], Array[@types.Rating]) {
  match algo {
    OpenSkill => {
      let ranks = match outcome {
        Win => [1, 2]
        Loss => [2, 1]
        Draw => [1, 1]
      }
      let res = @openskill.rate_teams([team_a, team_b], ranks~)
      (res[0], res[1])
    }
    _ => {
      let avg_a = average_team_rating(team_a)
      let avg_b = average_team_rating(team_b)
      let (new_avg_a, new_avg_b) = rate_1v1(algo, avg_a, avg_b, outcome)
      (
        apply_team_delta(team_a, avg_a, new_avg_a),
        apply_team_delta(team_b, avg_b, new_avg_b),
      )
    }
  }
}

///|
/// Unified multi-team tournament match rating supporting any of the 8 algorithms.
pub fn rate_multi_teams(
  teams : Array[Array[@types.Rating]],
  ranks : Array[Int32],
  algo~ : AlgorithmKind = OpenSkill,
) -> Array[Array[@types.Rating]] {
  let k = teams.length()
  if k == 0 {
    return []
  }
  match algo {
    OpenSkill => @openskill.rate_teams(teams, ranks~)
    _ => {
      let avgs : Array[@types.Rating] = []
      for t in teams {
        avgs.push(average_team_rating(t))
      }
      let updated_teams : Array[Array[@types.Rating]] = []
      let denom = if k > 1 { (k - 1).to_double() } else { 1.0 }
      for i = 0; i < k; i = i + 1 {
        let mut total_delta_mu = 0.0
        let mut total_sigma_ratio = 0.0
        let r_i = if i < ranks.length() { ranks[i] } else { i + 1 }
        for j = 0; j < k; j = j + 1 {
          if i != j {
            let r_j = if j < ranks.length() { ranks[j] } else { j + 1 }
            let outcome = if r_i < r_j {
              @types.GameOutcome::Win
            } else if r_i > r_j {
              @types.GameOutcome::Loss
            } else {
              @types.GameOutcome::Draw
            }
            let (new_i, _) = rate_1v1(algo, avgs[i], avgs[j], outcome)
            total_delta_mu = total_delta_mu + (new_i.mu - avgs[i].mu)
            let s_ratio = if avgs[i].sigma > 1.0e-6 {
              new_i.sigma / avgs[i].sigma
            } else {
              1.0
            }
            total_sigma_ratio = total_sigma_ratio + s_ratio
          }
        }
        let avg_delta = total_delta_mu / denom
        let avg_sigma_ratio = if k > 1 {
          total_sigma_ratio / denom
        } else {
          1.0
        }
        let target_avg = @types.Rating::new(
          avgs[i].mu + avg_delta,
          avgs[i].sigma * avg_sigma_ratio,
        )
        updated_teams.push(apply_team_delta(teams[i], avgs[i], target_avg))
      }
      updated_teams
    }
  }
}

///|
/// Unified Free-For-All (FFA) rating where each player competes individually.
/// ranks[i] indicates the final placement of player i (1 = 1st place).
pub fn rate_ffa(
  players : Array[@types.Rating],
  ranks : Array[Int32],
  algo~ : AlgorithmKind = OpenSkill,
) -> Array[@types.Rating] {
  let teams = Array::make(0, [@types.Rating::default()])
  for p in players {
    teams.push([p])
  }
  let updated_teams = rate_multi_teams(teams, ranks, algo~)
  let res = Array::make(0, @types.Rating::default())
  for t in updated_teams {
    res.push(t[0])
  }
  res
}

///|
/// Unified topology-driven match rating entry point.
/// Dispatches 1v1, Two-Team, Multi-Team, and Free-For-All contests across any of the 8 algorithms.
pub fn rate_topology(
  algo : AlgorithmKind,
  topology : MatchTopology,
  teams : Array[Array[@types.Rating]],
  ranks : Array[Int32],
) -> Array[Array[@types.Rating]] {
  match topology {
    OneVsOne => {
      if teams.length() < 2 || teams[0].is_empty() || teams[1].is_empty() {
        return teams
      }
      let r0 = if ranks.length() > 0 { ranks[0] } else { 1 }
      let r1 = if ranks.length() > 1 { ranks[1] } else { 2 }
      let outcome = if r0 < r1 {
        @types.GameOutcome::Win
      } else if r0 > r1 {
        @types.GameOutcome::Loss
      } else {
        @types.GameOutcome::Draw
      }
      let (new_a, new_b) = rate_1v1(algo, teams[0][0], teams[1][0], outcome)
      [[new_a], [new_b]]
    }
    TwoTeam => {
      if teams.length() < 2 {
        return teams
      }
      let r0 = if ranks.length() > 0 { ranks[0] } else { 1 }
      let r1 = if ranks.length() > 1 { ranks[1] } else { 2 }
      let outcome = if r0 < r1 {
        @types.GameOutcome::Win
      } else if r0 > r1 {
        @types.GameOutcome::Loss
      } else {
        @types.GameOutcome::Draw
      }
      let (new_a, new_b) = rate_two_teams(teams[0], teams[1], outcome, algo~)
      [new_a, new_b]
    }
    MultiTeam | FreeForAll => rate_multi_teams(teams, ranks, algo~)
  }
}

///|
/// Unified win prediction dispatch between two ratings across all 8 algorithms.
pub fn predict_win(
  algo : AlgorithmKind,
  player_a : @types.Rating,
  player_b : @types.Rating,
) -> Double {
  match algo {
    Elo => @elo.expected_score(player_a.mu * 60.0, player_b.mu * 60.0)
    Glicko => @glicko.predict_win(to_glicko(player_a), to_glicko(player_b))
    Glicko2 => @glicko2.predict_win(to_glicko2(player_a), to_glicko2(player_b))
    OpenSkill => @openskill.predict_win([player_a], [player_b])
    ThurstoneMosteller => {
      let tm_a = @bt.ThurstoneMostellerRating::new(
        mu=player_a.mu,
        sigma=player_a.sigma,
      )
      let tm_b = @bt.ThurstoneMostellerRating::new(
        mu=player_b.mu,
        sigma=player_b.sigma,
      )
      @bt.predict_win_tm(tm_a, tm_b)
    }
    BradleyTerry => {
      let bt_a = @bt.BradleyTerryRating::new(beta=player_a.mu / 10.0)
      let bt_b = @bt.BradleyTerryRating::new(beta=player_b.mu / 10.0)
      @bt.predict_win_bt(bt_a, bt_b)
    }
    DWZ => {
      let dwz_a = @elo.DWZRating::new(rating=player_a.mu * 60.0)
      let dwz_b = @elo.DWZRating::new(rating=player_b.mu * 60.0)
      @elo.predict_win_dwz(dwz_a, dwz_b)
    }
    ECF => {
      let ecf_a = @elo.ECFRating::from_elo(player_a.mu * 60.0)
      let ecf_b = @elo.ECFRating::from_elo(player_b.mu * 60.0)
      @elo.predict_win_ecf(ecf_a, ecf_b)
    }
  }
}

///|
/// FIDE / USCF standard performance rating calculation based on the 400-point rule.
/// Given an array of opponent ratings and total score achieved, computes the performance rating.
pub fn performance_rating(
  opponent_ratings : Array[Double],
  total_score : Double,
) -> Double {
  let n = opponent_ratings.length()
  if n == 0 {
    return 1500.0
  }

  let mut sum_r = 0.0
  for r in opponent_ratings {
    sum_r = sum_r + r
  }
  let avg_r = sum_r / n.to_double()
  let p = total_score / n.to_double()

  // Clamp percentage to avoid +/- infinity
  let safe_p = if p >= 1.0 { 0.999 } else if p <= 0.0 { 0.001 } else { p }

  // Logistic FIDE conversion: dp = -400 * log10(1/p - 1)
  let ratio = (1.0 - safe_p) / safe_p
  let dp = -400.0 * (@core_math.ln(ratio) / 2.302585092994046)
  avg_r + dp
}
