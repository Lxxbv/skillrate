# SkillRate

**纯 MoonBit 现代竞技评分、天梯排位与多智能体对战匹配套件**  
*(Modern Skill Rating, Matchmaking, and Leaderboard Engine in Pure MoonBit)*

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-purple)](https://www.moonbitlang.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Target](https://img.shields.io/badge/Target-Wasm--GC%20%7C%20Native-brightgreen)]()

---

## 一、 项目定位与特性 (Overview & Features)

**SkillRate** (`Lxxbv/skillrate`) 是专为竞技游戏、棋类对弈、排位天梯及 AI 多智能体竞技场（LLM Agent Arena）打造的现代化全功能评分套件。100% 采用纯 MoonBit 编写，零外部依赖，原生支持编译至 WebAssembly。

- **三合一全能算法引擎**：
  - **Elo**：经典 1v1 对战基准，支持动态 K-factor 衰减与胜率期望计算；
  - **Glicko-2**：工业级 1v1 评分体系（引入评分 $r$、评分偏差 $RD$、波动率 $\sigma$ 三元组），内置高精度 Illinois 根迭代求解器；
  - **OpenSkill**：基于 Weng-Lin / Plackett-Luce 的贝叶斯多团队多人算法，支持任意队伍数量、非平衡组队（如 3v2、4v5）、权重加权与平局结算。
- **天梯与匹配工程编排**：
  - **对局质量评估（Match Quality）**：赛前评估对战双方实力均衡度（$\in [0, 1]$）与爆头预期；
  - **保守评分排位（Conservative Rating）**：以 $\mu - 3\sigma$（99.7% 置信下限）进行天梯排序，彻底根除新玩家方差虚高霸榜问题；
  - **活跃度衰减（Rating Decay）**：长期不活跃玩家的偏差值自然发散机制。
- **开源合规与专利规避**：
  - 主动规避微软 TrueSkill™ 算法专利（US Patent US7090582B2 等），选用学术公开无专利争议的 Glicko-2 与 OpenSkill 开放算法模型。

---

## 二、 算法特性横向对比 (Comparison)

| 特性维度 | 经典 Elo | Glicko-2 | 微软 TrueSkill™ | **SkillRate (OpenSkill)** |
| :--- | :---: | :---: | :---: | :---: |
| **支持场景** | 仅限 1v1 | 仅限 1v1 | 多队多人 ($N$ vs $N$) | **多队多人 ($N$ 队、$M$ 人)** |
| **置信度度量** | 无 (单一数值) | 有 (评分偏差 $RD$) | 有 (标准差 $\sigma$) | **有 (方差 $\sigma^2$ 与置信下界)** |
| **表现波动率** | 无 | 有 (波动率 $\sigma$) | 无 | **有 (可配置动态更新)** |
| **非平衡队伍** | 不支持 | 不支持 | 支持 | **原生支持 (支持成员权重)** |
| **专利风险** | 无 | **无 (学术公有)** | 存在专利保护 (US7090582B2) | **无 (Weng-Lin 开放模型)** |
| **MoonBit 实现** | **内置提供** | **内置提供** | 规避不予实现 | **内置提供** |

---

## 三、 系统架构与模块划分 (Architecture)

```
skillrate
├── src
│   ├── types         # 领域模型 (Rating, Player, Team, GameOutcome)
│   ├── math          # 纯统计数学库 (正态分布 CDF/PDF, erf, erfc, Illinois 迭代)
│   ├── elo           # 经典 Elo 算法引擎
│   ├── glicko2       # Glicko-2 工业级 1v1 引擎 (含周期更新与自然发散)
│   ├── openskill     # OpenSkill 多团队多人贝叶斯评分引擎
│   ├── matchmaker    # 赛前对局质量分析与胜率矩阵
│   └── ladder        # 天梯排行榜、保守排位、段位划分与时间衰减
├── cmd
│   └── skillrate     # 命令行工具 (批量重放比赛日志流并生成榜单)
└── examples
    ├── chess_ladder  # 国际象棋 1v1 天梯演进实战模拟
    └── team_brawl    # 4v4 战队排位与多人对抗模拟
```

---

## 四、 快速上手 (Quick Start)

```moonbit
// 示例：使用 OpenSkill 结算一场 2v2 团队比赛
let team_a = Team::new("Alpha", [alice, bob])
let team_b = Team::new("Bravo", [charlie, david])

// 计算赛前比赛质量 (Match Quality)
let quality = match_quality_teams([team_a, team_b])

// 比赛结算：Alpha 胜利 (Rank 1), Bravo 战败 (Rank 2)
let updated_teams = rate_teams([team_a, team_b], ranks=[1, 2])
```

---

## 五、 开源许可 (License)

本项目基于 [Apache-2.0 License](LICENSE) 协议开源。
