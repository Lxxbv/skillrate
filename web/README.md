# SkillRate Web Visualizer Arena

An interactive, zero-dependency HTML5 Canvas visualization dashboard for the SkillRate rating and matchmaking suite.

## Features

- **Live Gaussian Skill Density Curves**: Dynamically renders Bayesian rating distributions $N(\mu, \sigma^2)$ for 1v1 and team matchups.
- **Real-Time Dynamic Match Settlement**:
  - Simulates Elo, Glicko-2, and OpenSkill Bayesian updates in real time.
  - Visually demonstrates mean shifting ($\mu$) and variance reduction ($\sigma$).
- **Interactive Multi-Team Battle Simulator**:
  - Configure 2, 3, or 4 teams with variable team sizes and handicaps.
  - Calculates Match Quality index ($q \in (0, 1]$) and win probability matrices before execution.
- **Conservative Rating Ladder**:
  - Live sorting using the conservative rating formula: $R_{cons} = \mu - 3\sigma$.
  - Tier divisions from Bronze to Grandmaster with color badges.

## Getting Started

Simply open `index.html` in any modern web browser:

```bash
# macOS / Linux
open index.html

# Windows
start index.html
```
