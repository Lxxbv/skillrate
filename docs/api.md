# SkillRate Public API Reference

Comprehensive API reference and mathematical specifications for the `Lxxbv/skillrate` suite.

---

## 1. Top-Level Facade (`Lxxbv/skillrate`)

The module root provides ergonomic helper functions for common rating, prediction, and matchmaking workflows.

### `rating`
```moonbit
pub fn rating(mu~ : Double = 25.0, sigma~ : Double = 25.0 / 3.0) -> @types.Rating
```
Creates a new Bayesian skill rating distribution $N(\mu, \sigma^2)$.

### `glicko2_rating`
```moonbit
pub fn glicko2_rating(
  r~ : Double = 1500.0,
  rd~ : Double = 350.0,
  vol~ : Double = 0.06
) -> @glicko2.Glicko2Rating
```
Creates a new Glicko-2 rating profile $(r, RD, \sigma)$.

### `rate_elo`
```moonbit
pub fn rate_elo(
  rating_a : Double,
  rating_b : Double,
  outcome : @types.GameOutcome,
  k_factor~ : Double = 32.0
) -> (Double, Double)
```
Settles a 1v1 match using classical Elo rating update.

### `rate_glicko2`
```moonbit
pub fn rate_glicko2(
  player_a : @glicko2.Glicko2Rating,
  player_b : @glicko2.Glicko2Rating,
  outcome : @types.GameOutcome,
  tau~ : Double = 0.5
) -> (@glicko2.Glicko2Rating, @glicko2.Glicko2Rating)
```
Settles a 1v1 match using industrial Glicko-2 with rating deviation and volatility adjustments.

### `rate_openskill`
```moonbit
pub fn rate_openskill(
  teams : Array[Array[@types.Rating]],
  ranks~ : Array[Int] = [],
  weights~ : Array[Array[Double]] = []
) -> Array[Array[@types.Rating]]
```
Settles an $N$-team, $M$-player match using Weng-Lin / Plackett-Luce Bayesian posterior updates.

### `match_quality`
```moonbit
pub fn match_quality(player_a : @types.Rating, player_b : @types.Rating) -> Double
```
Computes matchmaking balance quality $q \in (0, 1]$. A value of $1.0$ indicates an ideally fair contest.

### `win_probability`
```moonbit
pub fn win_probability(team_a : Array[@types.Rating], team_b : Array[@types.Rating]) -> Double
```
Predicts Team A's win probability against Team B based on Gaussian skill difference distributions.

---

## 2. Core Modules

### 2.1 Classical Elo (`@elo`)

- Expected score formula:
  $$E_A = \frac{1}{1 + 10^{(R_B - R_A) / 400}}$$
- Rating update formula:
  $$R'_A = R_A + K \cdot (S_A - E_A)$$
- Dynamic $K$-factor adaptive strategy:
  - Placement / Novice ($N < 30$): $K = 40$
  - Intermediate ($R < 2400$): $K = 32$
  - Master / Grandmaster ($R \ge 2400$): $K = 16$

### 2.2 Glicko-2 (`@glicko2`)

- Conforms strictly to Mark E. Glickman's 8-step specification:
  1. Scale conversion: $\mu = (r - 1500) / 173.7178$, $\phi = RD / 173.7178$
  2. Volatility update via Illinois secant root solver on $f(x)$
  3. Variance reduction on match results: $\phi' = 1 / \sqrt{1/\phi^{*2} + 1/v}$
  4. Inactivity inflation: $\phi' = \sqrt{\phi^2 + \sigma^2}$ when player is idle

### 2.3 OpenSkill Bayesian Multi-Team (`@openskill`)

- Plackett-Luce model with logistic approximation:
  $$\beta = \sigma_0 / 2 = 4.1667, \quad c^2 = 2\beta^2 + \sum \sigma_i^2$$
- Symmetric variance reduction guarantees:
  $$w_{base} = v \cdot (v + d - t), \quad \sigma_{new}^2 = \sigma^2 \cdot (1 - \frac{\sigma^2}{c^2} \cdot w_{base})$$
- Native support for arbitrary team counts, player weights, and draw margins.

### 2.4 Leaderboard & Ladder (`@ladder`)

- Conservative Rating sorting:
  $$R_{conservative} = \mu - 3\sigma$$
- Tier divisions:
  - Master / Grandmaster ($R_{cons} \ge 35.0$)
  - Diamond ($R_{cons} \ge 28.0$)
  - Platinum ($R_{cons} \ge 22.0$)
  - Gold ($R_{cons} \ge 16.0$)
  - Silver ($R_{cons} \ge 10.0$)
  - Bronze ($R_{cons} < 10.0$)
- Inactivity decay:
  $$\sigma_{decayed} = \sqrt{\sigma^2 + \Delta_{weeks} \cdot \gamma^2}$$
