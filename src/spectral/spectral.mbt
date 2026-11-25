///|
/// Algebraic, Matrix & Spectral Network Rating Systems (Langville & Meyer Formulations):
/// 1. Colley's Bias-Free Matrix Rating Method (Laplace Rule of Succession C * r = b)
/// 2. Massey's Least-Squares Margin-of-Victory Method & Offense/Defense Decomposition
/// 3. Markov Chain / PageRank Random-Walker Centrality Rating Engine
/// 4. Keener's Perron-Frobenius Nonlinear Skewed Score Rating System

// -----------------------------------------------------------------------------
// 1. Colley's Bias-Free Matrix Rating System
// -----------------------------------------------------------------------------

///|
/// Player/Team rating output from Colley's bias-free matrix method.
/// Centered around 0.500 (unplayed prior = 1 / 2 = 0.500).
pub(all) struct ColleyRating {
  participant_index : Int32
  colley_score : Double
  effective_wins : Double
  effective_games : Int32
} derive(Eq, Debug)

///|
/// Convert a Colley score (centered at 0.5) to an Elo-equivalent rating (centered at 1500.0).
pub fn ColleyRating::to_elo(
  self : ColleyRating,
  base~ : Double = 1500.0,
  scale~ : Double = 800.0,
) -> Double {
  base + (self.colley_score - 0.5) * scale
}

///|
/// Solve Colley's Bias-Free Rating System C * r = b via Gauss-Seidel relaxation with SOR:
/// C_{ii} = 2 + t_i,  C_{ij} = -n_{ij} (for i != j)
/// b_i = 1 + 0.5 * (w_i - l_i)
/// Matches is an array of `(player_i, player_j, score_for_i)` where score_for_i is in [0, 1].
pub fn solve_colley_ratings(
  num_participants : Int32,
  matches : Array[(Int32, Int32, Double)],
  iterations~ : Int32 = 60,
  tolerance~ : Double = 1.0e-7,
) -> Array[ColleyRating] {
  if num_participants <= 0 {
    return []
  }
  let n = num_participants
  let c_mat : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let row = Array::make(n, 0.0)
    row[i] = 2.0
    c_mat.push(row)
  }

  let wins = Array::make(n, 0.0)
  let losses = Array::make(n, 0.0)
  let games = Array::make(n, 0)

  for m in matches {
    let (i, j, s_i) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      let s_j = 1.0 - s_i
      c_mat[i][i] = c_mat[i][i] + 1.0
      c_mat[j][j] = c_mat[j][j] + 1.0
      c_mat[i][j] = c_mat[i][j] - 1.0
      c_mat[j][i] = c_mat[j][i] - 1.0

      wins[i] = wins[i] + s_i
      losses[i] = losses[i] + s_j
      games[i] = games[i] + 1

      wins[j] = wins[j] + s_j
      losses[j] = losses[j] + s_i
      games[j] = games[j] + 1
    }
  }

  let rhs = Array::make(n, 1.0)
  for i = 0; i < n; i = i + 1 {
    rhs[i] = 1.0 + 0.5 * (wins[i] - losses[i])
  }

  let r = Array::make(n, 0.5)
  for _it = 0; _it < iterations; _it = _it + 1 {
    let mut max_diff = 0.0
    for i = 0; i < n; i = i + 1 {
      let mut off_diag_sum = 0.0
      for j = 0; j < n; j = j + 1 {
        if i != j {
          off_diag_sum = off_diag_sum + c_mat[i][j] * r[j]
        }
      }
      let next_ri = (rhs[i] - off_diag_sum) / c_mat[i][i]
      let diff = (next_ri - r[i]).abs()
      if diff > max_diff {
        max_diff = diff
      }
      r[i] = next_ri
    }
    if max_diff <= tolerance {
      break
    }
  }

  let out : Array[ColleyRating] = []
  for i = 0; i < n; i = i + 1 {
    out.push({
      participant_index: i,
      colley_score: r[i],
      effective_wins: wins[i],
      effective_games: games[i],
    })
  }
  out
}

// -----------------------------------------------------------------------------
// 2. Massey's Least-Squares Method & Offense / Defense Decomposition
// -----------------------------------------------------------------------------

///|
/// Massey rating record decomposing overall strength into Offensive and Defensive ratings:
/// overall_rating = offensive_rating + defensive_rating, with population mean 0.0.
pub(all) struct MasseyRating {
  participant_index : Int32
  overall_rating : Double
  offensive_rating : Double
  defensive_rating : Double
  points_for : Double
  points_against : Double
  games_played : Int32
} derive(Eq, Debug)

///|
/// Convert Massey overall point-spread rating to Elo scale (centered at 1500.0).
pub fn MasseyRating::to_elo(
  self : MasseyRating,
  base~ : Double = 1500.0,
  points_to_elo~ : Double = 25.0,
) -> Double {
  base + self.overall_rating * points_to_elo
}

///|
/// Predict expected point differential (score_A - score_B) between two Massey-rated teams.
pub fn predict_massey_spread(a : MasseyRating, b : MasseyRating) -> Double {
  a.overall_rating - b.overall_rating
}

///|
/// Predict expected match score `(points_A, points_B)` using Massey offensive and defensive decomposition.
pub fn predict_massey_scores(
  a : MasseyRating,
  b : MasseyRating,
  league_avg_score~ : Double = 50.0,
) -> (Double, Double) {
  let score_a = 0.5 * league_avg_score + a.offensive_rating - b.defensive_rating
  let score_b = 0.5 * league_avg_score + b.offensive_rating - a.defensive_rating
  (
    if score_a < 0.0 {
      0.0
    } else {
      score_a
    },
    if score_b < 0.0 {
      0.0
    } else {
      score_b
    },
  )
}

///|
/// Solve Massey's Least-Squares Rating System M * r = p with zero-sum constraint sum(r_i) = 0,
/// and decompose each participant's overall rating into Offensive and Defensive components:
/// (T + P) * d = T * r - f,  o = r - d.
/// Each tuple in `score_matches` is `(team_i, team_j, points_scored_by_i, points_scored_by_j)`.
pub fn solve_massey_ratings(
  num_participants : Int32,
  score_matches : Array[(Int32, Int32, Double, Double)],
  iterations~ : Int32 = 80,
  ridge_reg~ : Double = 0.5,
) -> Array[MasseyRating] {
  if num_participants <= 0 {
    return []
  }
  let n = num_participants
  let m_mat : Array[Array[Double]] = []
  let p_adj : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let row_m = Array::make(n, 0.0)
    row_m[i] = ridge_reg
    m_mat.push(row_m)
    p_adj.push(Array::make(n, 0.0))
  }

  let pts_for = Array::make(n, 0.0)
  let pts_against = Array::make(n, 0.0)
  let games = Array::make(n, 0)

  for m in score_matches {
    let (i, j, pf_i, pf_j) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      m_mat[i][i] = m_mat[i][i] + 1.0
      m_mat[j][j] = m_mat[j][j] + 1.0
      m_mat[i][j] = m_mat[i][j] - 1.0
      m_mat[j][i] = m_mat[j][i] - 1.0

      p_adj[i][j] = p_adj[i][j] + 1.0
      p_adj[j][i] = p_adj[j][i] + 1.0

      pts_for[i] = pts_for[i] + pf_i
      pts_against[i] = pts_against[i] + pf_j
      games[i] = games[i] + 1

      pts_for[j] = pts_for[j] + pf_j
      pts_against[j] = pts_against[j] + pf_i
      games[j] = games[j] + 1
    }
  }

  let diff_vec = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    diff_vec[i] = pts_for[i] - pts_against[i]
  }

  // Step 1: Solve M * r = diff_vec with zero-mean projection at each sweep
  let r = Array::make(n, 0.0)
  let nf = n.to_double()
  for _it = 0; _it < iterations; _it = _it + 1 {
    let mut sum_r = 0.0
    for i = 0; i < n; i = i + 1 {
      let mut off = 0.0
      for j = 0; j < n; j = j + 1 {
        if i != j {
          off = off + m_mat[i][j] * r[j]
        }
      }
      let denom = if m_mat[i][i] < 1.0e-6 { 1.0 } else { m_mat[i][i] }
      r[i] = (diff_vec[i] - off) / denom
      sum_r = sum_r + r[i]
    }
    let mean_r = sum_r / nf
    for i = 0; i < n; i = i + 1 {
      r[i] = r[i] - mean_r
    }
  }

  // Step 2: Solve (T + P) * d = T * r - pts_for for Defensive ratings d, then o = r - d
  let def_rhs = Array::make(n, 0.0)
  for i = 0; i < n; i = i + 1 {
    let t_i = games[i].to_double() + ridge_reg
    def_rhs[i] = t_i * r[i] - pts_for[i]
  }

  let d_vec = Array::make(n, 0.0)
  for _it = 0; _it < iterations; _it = _it + 1 {
    for i = 0; i < n; i = i + 1 {
      let mut off = 0.0
      for j = 0; j < n; j = j + 1 {
        if i != j {
          off = off + p_adj[i][j] * d_vec[j]
        }
      }
      let t_i = games[i].to_double() + ridge_reg
      let denom = if t_i < 1.0e-6 { 1.0 } else { t_i }
      d_vec[i] = (def_rhs[i] - off) / denom
    }
  }

  let out : Array[MasseyRating] = []
  for i = 0; i < n; i = i + 1 {
    let o_i = r[i] - d_vec[i]
    out.push({
      participant_index: i,
      overall_rating: r[i],
      offensive_rating: o_i,
      defensive_rating: d_vec[i],
      points_for: pts_for[i],
      points_against: pts_against[i],
      games_played: games[i],
    })
  }
  out
}

// -----------------------------------------------------------------------------
// 3. Markov Chain / PageRank Random-Walker Centrality Rating System
// -----------------------------------------------------------------------------

///|
/// Markov PageRank spectral centrality rating record.
pub(all) struct MarkovRating {
  participant_index : Int32
  stationary_prob : Double
  elo_equivalent : Double
} derive(Eq, Debug)

///|
/// Solve the Markov Chain / PageRank Random-Walker Rating System via Power Iteration:
/// Each loss or margin deficit transfers "skill vote" from the loser to the winner.
/// Damping factor `damping` (default 0.85) ensures ergodicity even on disconnected match graphs.
pub fn solve_markov_pagerank_ratings(
  num_participants : Int32,
  matches : Array[(Int32, Int32, Double)],
  damping~ : Double = 0.85,
  iterations~ : Int32 = 60,
  tolerance~ : Double = 1.0e-8,
) -> Array[MarkovRating] {
  if num_participants <= 0 {
    return []
  }
  let n = num_participants
  let nf = n.to_double()

  // out_weights[loser][winner] accumulates loss weight from loser -> winner
  let adj : Array[Array[Double]] = []
  for _ in 0..<n {
    adj.push(Array::make(n, 0.0))
  }
  let out_sum = Array::make(n, 0.0)

  for m in matches {
    let (i, j, s_i) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      let s_j = 1.0 - s_i
      if s_i > 0.0 {
        // j lost (or drew) to i -> vote flows from j to i
        adj[j][i] = adj[j][i] + s_i
        out_sum[j] = out_sum[j] + s_i
      }
      if s_j > 0.0 {
        // i lost (or drew) to j -> vote flows from i to j
        adj[i][j] = adj[i][j] + s_j
        out_sum[i] = out_sum[i] + s_j
      }
    }
  }

  let mut pi = Array::make(n, 1.0 / nf)
  let teleport = (1.0 - damping) / nf

  for _it = 0; _it < iterations; _it = _it + 1 {
    let next_pi = Array::make(n, teleport)

    for src = 0; src < n; src = src + 1 {
      if out_sum[src] <= 1.0e-12 {
        // Unbeaten player keeps self-loop / redistributes mass with positive bias
        next_pi[src] = next_pi[src] + damping * pi[src]
      } else {
        for dst = 0; dst < n; dst = dst + 1 {
          if adj[src][dst] > 0.0 {
            next_pi[dst] = next_pi[dst] +
              damping * pi[src] * (adj[src][dst] / out_sum[src])
          }
        }
      }
    }

    // Normalize sum(next_pi) == 1.0
    let mut total_mass = 0.0
    for v in next_pi {
      total_mass = total_mass + v
    }
    let safe_mass = if total_mass < 1.0e-12 { 1.0 } else { total_mass }

    let mut max_delta = 0.0
    for idx = 0; idx < n; idx = idx + 1 {
      next_pi[idx] = next_pi[idx] / safe_mass
      let d = (next_pi[idx] - pi[idx]).abs()
      if d > max_delta {
        max_delta = d
      }
    }
    pi = next_pi
    if max_delta <= tolerance {
      break
    }
  }

  let uniform = 1.0 / nf
  let out : Array[MarkovRating] = []
  for i = 0; i < n; i = i + 1 {
    let ratio = if pi[i] < 1.0e-6 { 1.0e-6 } else { pi[i] / uniform }
    let elo_eq = 1500.0 + 173.7177927613 * @core_math.ln(ratio)
    out.push({
      participant_index: i,
      stationary_prob: pi[i],
      elo_equivalent: elo_eq,
    })
  }
  out
}

// -----------------------------------------------------------------------------
// 4. Keener's Nonlinear Skewed Perron-Frobenius Rating System
// -----------------------------------------------------------------------------

///|
/// Keener's nonlinear skewing function h(x) = 0.5 + 0.5 * sgn(x - 0.5) * sqrt(|2x - 1|)
/// which dampens blowout scores while preserving competitive dominance.
pub fn keener_skew(x : Double) -> Double {
  let clamped = if x < 0.0 { 0.0 } else if x > 1.0 { 1.0 } else { x }
  let raw = (2.0 * clamped - 1.0).abs().sqrt()
  if clamped >= 0.5 {
    0.5 + 0.5 * raw
  } else {
    0.5 - 0.5 * raw
  }
}

///|
/// Compute Keener's Perron-Frobenius dominant eigenvector ratings from match score tuples
/// `(player_i, player_j, points_i, points_j)` using Laplace-smoothed ratios
/// s_{ij} = (S_{ij} + 1) / (S_{ij} + S_{ji} + 2) passed through `keener_skew`.
pub fn solve_keener_ratings(
  num_participants : Int32,
  score_matches : Array[(Int32, Int32, Double, Double)],
  iterations~ : Int32 = 50,
  eps~ : Double = 0.01,
) -> Array[Double] {
  if num_participants <= 0 {
    return []
  }
  let n = num_participants
  let nf = n.to_double()
  let a_mat : Array[Array[Double]] = []
  for _ in 0..<n {
    a_mat.push(Array::make(n, 0.0))
  }
  let games = Array::make(n, 0)

  for m in score_matches {
    let (i, j, s_i, s_j) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      let denom = s_i + s_j + 2.0
      let r_ij = keener_skew((s_i + 1.0) / denom)
      let r_ji = keener_skew((s_j + 1.0) / denom)
      a_mat[i][j] = a_mat[i][j] + r_ij
      a_mat[j][i] = a_mat[j][i] + r_ji
      games[i] = games[i] + 1
      games[j] = games[j] + 1
    }
  }

  for i = 0; i < n; i = i + 1 {
    if games[i] > 0 {
      let gf = games[i].to_double()
      for j = 0; j < n; j = j + 1 {
        a_mat[i][j] = a_mat[i][j] / gf
      }
    }
  }

  let mut r = Array::make(n, 1.0 / nf)
  for _it = 0; _it < iterations; _it = _it + 1 {
    let next_r = Array::make(n, eps / nf)
    let mut sum_next = 0.0
    for i = 0; i < n; i = i + 1 {
      let mut dot = 0.0
      for j = 0; j < n; j = j + 1 {
        dot = dot + a_mat[i][j] * r[j]
      }
      next_r[i] = next_r[i] + dot
      sum_next = sum_next + next_r[i]
    }
    let safe_sum = if sum_next < 1.0e-12 { 1.0 } else { sum_next }
    for i = 0; i < n; i = i + 1 {
      next_r[i] = next_r[i] / safe_sum
    }
    r = next_r
  }
  r
}

// -----------------------------------------------------------------------------
// 5. HITS (Kleinberg Authority & Hub) Giant-Killer Network Rating System
// -----------------------------------------------------------------------------

///|
/// Kleinberg HITS competitive rating decomposing player performance into:
/// - `authority_score`: strength proven by defeating strong "hub" losers
/// - `hub_score`: "schedule difficulty / donor weight" (losing to high-authority winners)
/// - `giant_killer_index`: ratio of authority to raw win rate, highlighting players who beat top seeds.
pub(all) struct HitsCompetitiveRating {
  participant_index : Int32
  authority_score : Double
  hub_score : Double
  giant_killer_index : Double
} derive(Eq, Debug)

///|
/// Solve the HITS (Hyperlink-Induced Topic Search) Authority and Hub ratings
/// on a directed match outcome graph where an edge `j -> i` has weight `score_i_against_j`:
/// authority = A^T * hub,  hub = A * authority (L2 normalized at each power step).
pub fn solve_hits_authority_hub_ratings(
  num_participants : Int32,
  matches : Array[(Int32, Int32, Double)],
  iterations~ : Int32 = 40,
) -> Array[HitsCompetitiveRating] {
  if num_participants <= 0 {
    return []
  }
  let n = num_participants
  let nf = n.to_double()

  // win_matrix[winner][loser] = accumulated win weight of winner over loser
  let win_matrix : Array[Array[Double]] = []
  for i = 0; i < n; i = i + 1 {
    let row = Array::make(n, 0.01) // Small smoothing to guarantee primitivity
    row[i] = 0.0
    win_matrix.push(row)
  }

  let wins = Array::make(n, 0.0)
  let games = Array::make(n, 0)

  for m in matches {
    let (i, j, s_i) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      let s_j = 1.0 - s_i
      win_matrix[i][j] = win_matrix[i][j] + s_i
      win_matrix[j][i] = win_matrix[j][i] + s_j
      wins[i] = wins[i] + s_i
      wins[j] = wins[j] + s_j
      games[i] = games[i] + 1
      games[j] = games[j] + 1
    }
  }

  let mut auth = Array::make(n, 1.0 / nf.sqrt())
  let mut hub = Array::make(n, 1.0 / nf.sqrt())

  for _it = 0; _it < iterations; _it = _it + 1 {
    // Authority update: auth[i] = sum_j win_matrix[i][j] * hub[j]
    let next_auth = Array::make(n, 0.0)
    let mut norm_a = 0.0
    for i = 0; i < n; i = i + 1 {
      let mut s = 0.0
      for j = 0; j < n; j = j + 1 {
        s = s + win_matrix[i][j] * hub[j]
      }
      next_auth[i] = s
      norm_a = norm_a + s * s
    }
    let scale_a = if norm_a <= 1.0e-12 { 1.0 } else { norm_a.sqrt() }
    for i = 0; i < n; i = i + 1 {
      next_auth[i] = next_auth[i] / scale_a
    }

    // Hub update: hub[j] = sum_i win_matrix[i][j] * next_auth[i]
    let next_hub = Array::make(n, 0.0)
    let mut norm_h = 0.0
    for j = 0; j < n; j = j + 1 {
      let mut s = 0.0
      for i = 0; i < n; i = i + 1 {
        s = s + win_matrix[i][j] * next_auth[i]
      }
      next_hub[j] = s
      norm_h = norm_h + s * s
    }
    let scale_h = if norm_h <= 1.0e-12 { 1.0 } else { norm_h.sqrt() }
    for j = 0; j < n; j = j + 1 {
      next_hub[j] = next_hub[j] / scale_h
    }

    auth = next_auth
    hub = next_hub
  }

  let out : Array[HitsCompetitiveRating] = []
  for i = 0; i < n; i = i + 1 {
    let raw_wr = if games[i] > 0 { wins[i] / games[i].to_double() } else { 0.5 }
    let safe_wr = if raw_wr < 0.1 { 0.1 } else { raw_wr }
    out.push({
      participant_index: i,
      authority_score: auth[i],
      hub_score: hub[i],
      giant_killer_index: auth[i] / safe_wr,
    })
  }
  out
}

// -----------------------------------------------------------------------------
// 6. HodgeRank Combinatorial Pairwise Inconsistency & Cyclic Triad Analysis
// -----------------------------------------------------------------------------

///|
/// Report of HodgeRank combinatorial decomposition on a pairwise comparison graph:
/// Decomposes pairwise flows Y_{ij} into a transitive gradient ranking potential s_i - s_j
/// and a harmonic / curl cyclic residual (measuring rock-paper-scissors non-transitivity).
pub(all) struct HodgeRankReport {
  potentials : Array[Double]
  residual_l2_error : Double
  cyclicity_ratio : Double
  cyclic_triads_count : Int32
} derive(Eq, Debug)

///|
/// Perform HodgeRank least-squares potential extraction and cyclic triad detection
/// on pairwise match outcomes `(player_i, player_j, score_for_i)`.
pub fn analyze_hodgerank_intransitivity(
  num_participants : Int32,
  matches : Array[(Int32, Int32, Double)],
  iterations~ : Int32 = 60,
) -> HodgeRankReport {
  if num_participants <= 0 {
    return {
      potentials: [],
      residual_l2_error: 0.0,
      cyclicity_ratio: 0.0,
      cyclic_triads_count: 0,
    }
  }
  let n = num_participants
  let nf = n.to_double()

  // Build skew-symmetric flow matrix Y[i][j] = 2 * score_ij - 1 in [-1, 1]
  let flow : Array[Array[Double]] = []
  let weight : Array[Array[Double]] = []
  for _ in 0..<n {
    flow.push(Array::make(n, 0.0))
    weight.push(Array::make(n, 0.0))
  }

  for m in matches {
    let (i, j, s_i) = m
    if i >= 0 && i < n && j >= 0 && j < n && i != j {
      let y_ij = 2.0 * s_i - 1.0
      flow[i][j] = flow[i][j] + y_ij
      flow[j][i] = flow[j][i] - y_ij
      weight[i][j] = weight[i][j] + 1.0
      weight[j][i] = weight[j][i] + 1.0
    }
  }

  for i = 0; i < n; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      if weight[i][j] > 0.0 {
        flow[i][j] = flow[i][j] / weight[i][j]
      }
    }
  }

  // Solve graph Laplacian L * s = div(Y) via Jacobi/Gauss-Seidel with zero-sum centering
  let s = Array::make(n, 0.0)
  for _it = 0; _it < iterations; _it = _it + 1 {
    let mut sum_s = 0.0
    for i = 0; i < n; i = i + 1 {
      let mut num = 0.0
      let mut deg = 0.0
      for j = 0; j < n; j = j + 1 {
        if i != j && weight[i][j] > 0.0 {
          let w = weight[i][j]
          num = num + w * (s[j] + flow[i][j])
          deg = deg + w
        }
      }
      if deg > 0.0 {
        s[i] = num / deg
      }
      sum_s = sum_s + s[i]
    }
    let mean_s = sum_s / nf
    for i = 0; i < n; i = i + 1 {
      s[i] = s[i] - mean_s
    }
  }

  // Measure total flow norm vs cyclic residual norm ||Y - grad(s)||^2
  let mut total_flow_sq = 0.0
  let mut residual_sq = 0.0
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      if weight[i][j] > 0.0 {
        let w = weight[i][j]
        let y = flow[i][j]
        let grad = s[i] - s[j]
        total_flow_sq = total_flow_sq + w * y * y
        let r = y - grad
        residual_sq = residual_sq + w * r * r
      }
    }
  }

  // Count directed cyclic triads (i beats j, j beats k, k beats i)
  let mut triads = 0
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      for k = j + 1; k < n; k = k + 1 {
        let ij = flow[i][j] > 0.0
        let jk = flow[j][k] > 0.0
        let ki = flow[k][i] > 0.0
        let ji = flow[j][i] > 0.0
        let kj = flow[k][j] > 0.0
        let ik = flow[i][k] > 0.0
        if (ij && jk && ki) || (ji && ik && kj) {
          triads = triads + 1
        }
      }
    }
  }

  let ratio = if total_flow_sq > 1.0e-12 {
    residual_sq / total_flow_sq
  } else {
    0.0
  }

  {
    potentials: s,
    residual_l2_error: residual_sq.sqrt(),
    cyclicity_ratio: ratio,
    cyclic_triads_count: triads,
  }
}
