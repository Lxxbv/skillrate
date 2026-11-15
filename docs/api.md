# SkillRate Public API Reference

Comprehensive API reference and mathematical specifications for the `Lxxbv/skillrate` suite.

---

## 1. Top-Level Facade (`Lxxbv/skillrate`)

The module root provides ergonomic helper functions for common rating, prediction, matchmaking, and leaderboard lifecycle workflows.

### 1.1 Rating Constructors
```moonbit
pub fn rating(mu~ : Double = 25.0, sigma~ : Double = 25.0 / 3.0) -> @types.Rating
pub fn glicko_rating(r~ : Double = 1500.0, rd~ : Double = 350.0) -> @glicko.GlickoRating
pub fn glicko2_rating(r~ : Double = 1500.0, rd~ : Double = 350.0, vol~ : Double = 0.06) -> @glicko2.Glicko2Rating
```

### 1.2 Eight Core Rating Engines
- **Classic Elo**:
  ```moonbit
  pub fn rate_elo(rating_a : Double, rating_b : Double, outcome : @types.GameOutcome, k_factor~ : Double = 32.0) -> (Double, Double)
  ```
- **Classic Glicko-1**:
  ```moonbit
  pub fn rate_glicko(player_a : @glicko.GlickoRating, player_b : @glicko.GlickoRating, outcome : @types.GameOutcome) -> (@glicko.GlickoRating, @glicko.GlickoRating)
  ```
- **Industrial Glicko-2**:
  ```moonbit
  pub fn rate_glicko2(player_a : @glicko2.Glicko2Rating, player_b : @glicko2.Glicko2Rating, outcome : @types.GameOutcome, tau~ : Double = 0.5) -> (@glicko2.Glicko2Rating, @glicko2.Glicko2Rating)
  ```
- **Bradley-Terry (LLM & Pairwise Preference)**:
  ```moonbit
  pub fn rate_bradley_terry(player_a : @bt.BradleyTerryRating, player_b : @bt.BradleyTerryRating, outcome : @types.GameOutcome) -> (@bt.BradleyTerryRating, @bt.BradleyTerryRating)
  ```
- **Thurstone-Mosteller (Case V Closed-Form Gaussian)**:
  ```moonbit
  pub fn rate_thurstone_mosteller(player_a : @bt.ThurstoneMostellerRating, player_b : @bt.ThurstoneMostellerRating, outcome : @types.GameOutcome) -> (@bt.ThurstoneMostellerRating, @bt.ThurstoneMostellerRating)
  ```
- **DWZ (Deutsche Wertungszahl Federation System)**:
  ```moonbit
  pub fn rate_dwz(player_a : @elo.DWZRating, player_b : @elo.DWZRating, outcome : @types.GameOutcome) -> (@elo.DWZRating, @elo.DWZRating)
  ```
- **ECF (English Chess Federation Grading System)**:
  ```moonbit
  pub fn rate_ecf(player_a : @elo.ECFRating, player_b : @elo.ECFRating, outcome : @types.GameOutcome) -> (@elo.ECFRating, @elo.ECFRating)
  ```
- **OpenSkill (Multi-Team Multi-Player Bayesian)**:
  ```moonbit
  pub fn rate_openskill(teams : Array[Array[@types.Rating]], ranks~ : Array[Int32] = [], weights~ : Array[Array[Double]] = []) -> Array[Array[@types.Rating]]
  ```

### 1.3 Unified Rating Interface & Match Typologies
```moonbit
pub fn rate_unified_1v1(algo : @unified.AlgorithmKind, player_a : @types.Rating, player_b : @types.Rating, outcome : @types.GameOutcome) -> (@types.Rating, @types.Rating)
pub fn rate_topology(algo : @unified.AlgorithmKind, topology : @unified.MatchTopology, teams : Array[Array[@types.Rating]], ranks : Array[Int32]) -> Array[Array[@types.Rating]]
pub fn rate_ffa(players : Array[@types.Rating], ranks : Array[Int32], algo~ : @unified.AlgorithmKind = @unified.AlgorithmKind::OpenSkill) -> Array[@types.Rating]
pub fn performance_rating(opponent_ratings : Array[Double], total_score : Double) -> Double
```

### 1.4 Matchmaking & Team Balancing
```moonbit
pub fn match_quality(player_a : @types.Rating, player_b : @types.Rating) -> Double
pub fn win_probability(team_a : Array[@types.Rating], team_b : Array[@types.Rating]) -> Double
pub fn balance_teams(players : Array[@types.Player]) -> (Array[@types.Player], Array[@types.Player], Double)
pub fn new_matchmaking_queue() -> @matchmaker.MatchmakingQueue
```

### 1.5 Competitive Ladder & Season Lifecycle
```moonbit
pub fn new_leaderboard() -> @ladder.Leaderboard
pub fn new_placement_tracker(threshold~ : Int32 = 5) -> @ladder.PlacementTracker
```

---

## 2. Mathematical Formulations

### 2.1 Classical Elo, DWZ, ECF & FIDE Performance
- Logistic expected score:
  $$E_A = \frac{1}{1 + 10^{(R_B - R_A) / 400}}$$
- DWZ normal expected score & development coefficient:
  $$P(D) = \Phi\left(\frac{R_A - R_B}{200\sqrt{2}}\right), \quad R' = R + \frac{800}{E + n}(W - W_e)$$
- ECF 40-point cap / 50-point rolling grade:
  $$\text{Perf}_A = \text{clamp}(R_B, R_A - 40, R_A + 40) + 50 \cdot (2S_A - 1), \quad R'_A = R_A + \frac{\text{Perf}_A - R_A}{30}$$
- FIDE performance rating (400-point algorithm):
  $$R_p = \bar{R}_c - 400 \cdot \log_{10}\left(\frac{1 - P}{P}\right)$$

### 2.2 Classic Glicko-1 (Glickman 1995)
- Impact weight:
  $$g(RD) = \frac{1}{\sqrt{1 + 3 q^2 RD^2 / \pi^2}}, \quad q = \frac{\ln 10}{400}$$
- Variance reduction and rating step:
  $$d^2 = \left( q^2 \sum g(RD_j)^2 E_j (1 - E_j) \right)^{-1}$$
  $$r' = r + \frac{q}{\frac{1}{RD^2} + \frac{1}{d^2}} \sum g(RD_j) (s_j - E_j), \quad RD' = \sqrt{\left( \frac{1}{RD^2} + \frac{1}{d^2} \right)^{-1}}$$

### 2.3 Glicko-2 (Glickman 2001)
- 8-step iterative algorithm with Illinois root finding on volatility $f(x)$.
- Scale conversion: $\mu = (r - 1500) / 173.7178$, $\phi = RD / 173.7178$.

### 2.4 Bradley-Terry & Thurstone-Mosteller
- Bradley-Terry probability:
  $$P(i > j) = \frac{e^{\beta_i}}{e^{\beta_i} + e^{\beta_j}} = \frac{1}{1 + e^{-(\beta_i - \beta_j)}}$$
- Thurstone-Mosteller Case V:
  $$c = \sqrt{\sigma_i^2 + \sigma_j^2 + 2\beta^2}, \quad t = \frac{\mu_i - \mu_j}{c}, \quad v(t) = \frac{\phi(t)}{\Phi(t)}$$
  $$\mu_i' = \mu_i + \frac{\sigma_i^2}{c} v(t), \quad \sigma_i'^2 = \sigma_i^2 \left(1 - \frac{\sigma_i^2}{c^2} v(t)(v(t) + t)\right)$$

### 2.5 OpenSkill (Weng-Lin Plackett-Luce)
- Full multi-team Bayesian updates with symmetric variance reduction and custom draw margins.
