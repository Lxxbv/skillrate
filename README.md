# SkillRate

**纯 MoonBit 现代竞技评分、天梯排位与多智能体对战匹配套件**  
*(Modern Skill Rating, Matchmaking, and Leaderboard Engine in Pure MoonBit)*

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-purple)](https://www.moonbitlang.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Target](https://img.shields.io/badge/Target-Wasm--GC%20%7C%20Native-brightgreen)]()
[![Tests](https://img.shields.io/badge/Tests-48%20Passed%20(100%25)-brightgreen)]()
[![Docs](https://img.shields.io/badge/API-Reference-blue)](docs/api.md)

---

## 一、 项目定位 (Overview)

**SkillRate** (`Lxxbv/skillrate`) 是专为竞技游戏、棋类对弈、排位天梯以及 AI 多智能体竞技场（LLM Agent Arena / RLHF 偏好打分）打造的工业级竞技评分套件。100% 纯 MoonBit 原生开发，零任何外部二进制或 C/Rust FFI 依赖，原生极速编译支持 `wasm` 与 `wasm-gc`。

对标 Rust `skillratings` 等成熟工业库，SkillRate 建立了统一抽象评分接口与全对局拓扑支持（1v1 单挑、Two-Team 双队对抗、Multi-Team 多队争霸、Free-For-All 个人大乱斗），全景集成了 **Elo**、**Glicko-1**、**Glicko-2**、**Bradley-Terry**、**Thurstone-Mosteller**、**OpenSkill (Weng-Lin)**、**DWZ (德国棋协评分)** 以及 **ECF (英国棋协评分)** 八大核心评分模型，同时内置动态时间窗口排队池、批量大厅配对、连胜炸鱼检测、贪心平衡分队器、瑞士轮赛事编排、晋级赛状态机与赛季软重置。

---

## 二、 对标成熟生态库横向对比 (Feature Matrix)

| 核心维度 | Rust `skillratings` | Python `openskill` | 微软 TrueSkill™ | **SkillRate (MoonBit)** |
| :--- | :---: | :---: | :---: | :---: |
| **语言特性** | Rust (成熟系统语言) | Python (动态解释型) | C# / 专有二进制 | **100% 纯 MoonBit (强类型 + Wasm-GC 原生)** |
| **外部依赖** | 依赖第三方 crate | 依赖 NumPy / SciPy | 专有依赖 | **0 FFI / 0 外部依赖** |
| **算法覆盖** | Elo, Glicko, G2, Weng-Lin, TM, BT, DWZ, ECF | 仅限 OpenSkill / Weng-Lin | 仅限 TrueSkill | **八大算法全覆盖：Elo + Glicko + G2 + BT + TM + OpenSkill + DWZ + ECF** |
| **对局类型** | 1v1, Two-Team, Multi-Team, FFA | 仅限多队 | 1v1, Multi-team | **全对局拓扑统一分发：1v1 / TwoTeam / MultiTeam / FFA** |
| **匹配治理** | 仅基础计算 | 仅评分结算 | 基础排位 | **动态时间窗口排队池 + 批量大厅撮合 + 平衡分队 + 连胜加速** |
| **天梯生命周期** | 无 | 无 | 部分内置 | **赛季软重置 + 定级赛跟踪 + Bo3/Bo5 晋级赛 + 瑞士轮编排** |
| **WebAssembly** | 编译体积偏大 | 无法轻量 Wasm 运行 | 无法 Wasm | **原生 `wasm-gc` 极小体积，毫秒冷启动** |

---

## 三、 系统架构与模块设计 (Architecture)

```
skillrate
├── src
│   ├── types         # 核心领域模型 (Rating, Player, Team, GameOutcome)
│   ├── math          # 高精度统计数学库 (正态分布 CDF/PDF, erf, Probit, Illinois 根求解器)
│   ├── elo           # 经典 Elo、德国棋协 DWZ 与英国棋协 ECF 评分引擎
│   ├── glicko        # 经典 Glicko-1 引擎 (Mark Glickman 1995 规范)
│   ├── glicko2       # 工业级 Glicko-2 引擎 (Glickman 论文 8 步闭环，含自然方差发散)
│   ├── bradley_terry # Bradley-Terry 与 Thurstone-Mosteller 成对比较与偏好学习模型
│   ├── openskill     # OpenSkill 多团队多人贝叶斯评分引擎 (Weng-Lin / Plackett-Luce)
│   ├── matchmaker    # 赛前对局平衡度分析、动态排队池、贪心平衡分队器与连胜炸鱼检测
│   ├── ladder        # 天梯排行榜系统 (保守评分 μ-3σ、赛季软重置、定级赛、晋级赛与瑞士轮)
│   └── unified       # 八大算法与四大对局拓扑统一调度门面 (1v1 / 两队 / 多队 / FFA / 表现分)
├── skillrate.mbt     # 顶级统一门面 API
├── cmd
│   └── skillrate     # 演示与交互命令行工具
├── examples
│   ├── chess_ladder  # 国际象棋特级大师天梯演进模拟
│   └── team_brawl    # 4v4 MOBA 团队战队天梯模拟
├── web
│   └── index.html    # 交互式 Web 可视化竞技场与高斯分布曲线
└── docs
    ├── api.md        # 完整 API 与数学公理规范文档
    ├── dedup.md      # 生态查重与独占性分析报告
    └── decisions.md  # 关键技术与专利规避架构决策
```

---

## 四、 快速上手 (Quick Start)

### 1. 统一评分接口与四大对局拓扑 (Unified Interface & Topologies)
```moonbit
let p1 = @skillrate.rating(mu=30.0, sigma=4.0)
let p2 = @skillrate.rating(mu=25.0, sigma=4.0)

// 一键切换底层算法（Elo / Glicko / Glicko2 / OpenSkill / ThurstoneMosteller / BradleyTerry / DWZ / ECF）
let (new_a, new_b) = @skillrate.rate_unified_1v1(
  @unified.AlgorithmKind::ThurstoneMosteller,
  p1,
  p2,
  @types.GameOutcome::Win,
)

// 4 人大乱斗 (Free-For-All) 按名次结算
let ffa_updated = @skillrate.rate_ffa([p1, p2, @skillrate.rating(), @skillrate.rating()], [1, 2, 3, 4])
```

### 2. Glicko-2 评级周期结算 (含偏差与波动率)
```moonbit
let player = @glicko2.Glicko2Rating::new(1500.0, 200.0, 0.06)
let matches = [
  @glicko2.OpponentMatch::new(@glicko2.Glicko2Rating::new(1400.0, 30.0, 0.06), 1.0), // 胜
  @glicko2.OpponentMatch::new(@glicko2.Glicko2Rating::new(1550.0, 100.0, 0.06), 0.0), // 负
]
let updated = @glicko2.rate_period(player, matches)
```

### 3. Bradley-Terry / LLM Arena 偏好对决与批量拟合
```moonbit
let gpt4 = @bt.BradleyTerryRating::new(beta=0.8)
let claude = @bt.BradleyTerryRating::new(beta=0.6)
let (up_a, up_b) = @bt.rate_1v1_bt(gpt4, claude, @types.GameOutcome::Win)
```

### 4. 动态匹配排队池、自动平衡组队与天梯赛季治理
```moonbit
// 1. 自动将玩家池划分为实力最均衡的两支队伍
let (team_a, team_b, quality) = @skillrate.balance_teams(players)

// 2. 天梯排行榜、瑞士轮配对与赛季软重置
let board = @skillrate.new_leaderboard()
board.register_player("p1", name="Alice")
board.register_player("p2", name="Bob")
let _ = board.record_match("p1", "p2", @types.GameOutcome::Win)
let swiss_pairs = board.swiss_pair_round()
board.soft_reset_season(alpha=0.75)
```

---

## 五、 运行与测试验证 (Run & Test)

```bash
# 运行全量自动化测试 (48 项全绿通过)
moon test

# 检查代码格式与静态类型
moon fmt --check
moon check

# 运行演示命令行
moon run cmd/skillrate

# 运行场景案例
moon run examples/chess_ladder
moon run examples/team_brawl

# 编译为 WebAssembly (wasm-gc)
moon build --target wasm-gc
```

---

## 六、 开源许可与专利声明 (License & Patent Clearance)

- 本项目基于 **[Apache-2.0 License](LICENSE)** 许可开源。
- **专利合规说明**：本项目严格规避微软 TrueSkill™ 专有算法专利（Patent US7090582B2 等），全部算法均基于公有学术文献发表的开放模型实现，可自由用于开源或商业系统。
