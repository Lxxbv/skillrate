# SkillRate

**纯 MoonBit 现代竞技评分、全历史轨迹优化、赛事编排与反作弊匹配套件**  
*(Comprehensive Skill Rating, Whole-History Optimization, Tournament Bracket & Anti-Cheat Matchmaking Engine in Pure MoonBit)*

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-purple)](https://www.moonbitlang.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Target](https://img.shields.io/badge/Target-Wasm--GC%20%7C%20Native-brightgreen)]()
[![Tests](https://img.shields.io/badge/Tests-66%20Passed%20(100%25)-brightgreen)]()
[![LOC](https://img.shields.io/badge/Core%20MoonBit-9%2C500%2B%20LOC-orange)]()
[![Docs](https://img.shields.io/badge/API-Reference-blue)](docs/api.md)

---

## 一、 项目定位 (Overview)

**SkillRate** (`Lxxbv/skillrate`) 是专为竞技游戏、棋类对弈、电子竞技天梯、锦标赛编排以及 AI 多智能体竞技场（LLM Chatbot Arena / RLHF 偏好学习）打造的工业级竞技评分与撮合基础设施。全仓拥有 **9,500+ 行纯 MoonBit 核心实现代码（总 `.mbt` 代码逾 11,100 行）**，零任何外部二进制或 C/Rust FFI 依赖，原生极速编译支持 `wasm` 与 `wasm-gc`。

深度对标并全面超越 Rust `skillratings` 等成熟工业库，SkillRate 不仅提供统一抽象评分接口与四大对局拓扑支持（1v1 单挑、Two-Team 双队对抗、Multi-Team 多队争霸、Free-For-All 个人大乱斗），更全景集成了 **15 种统一增量/贝叶斯/棋协评分模型**、**Whole-History Rating (WHR) 全历史维纳过程轨迹优化器**、**6 种代数矩阵与谱图中心性评级系统**（Colley、Massey 攻防分解、Markov PageRank、Keener、HITS、HodgeRank 循环三元组分解），以及完整的**淘汰赛/双败/瑞士轮/循环赛锦标赛引擎**与**概率校准/反作弊风控套件**。

---

## 二、 对标成熟生态库横向对比 (Feature Matrix)

| 核心维度 | Rust `skillratings` | Python `openskill` | 微软 TrueSkill™ | **SkillRate (MoonBit)** |
| :--- | :---: | :---: | :---: | :---: |
| **语言特性与规模** | Rust (系统语言) | Python (动态解释型) | C# / 专有二进制 | **100% 纯 MoonBit (9,500+ 行核心源码，0 FFI)** |
| **增量与贝叶斯算法**| Elo, Glicko, G2, Weng-Lin, TM, BT, DWZ, ECF, Ingo, USCF | 仅限 OpenSkill / Weng-Lin | 仅限 TrueSkill | **15 种统一模型：Elo / FIDE / USCF / DWZ / ECF / Ingo / Glicko-1 / Glicko-2 / BT / Davidson / Rao-Kupper / TM / OpenSkill 三变体** |
| **全历史与谱代数模型**| 无 | 无 | 无 (仅限 TrueSkill Through Time) | **内置 WHR 全历史牛顿优化 + Colley / Massey 攻防分解 / Markov PageRank / Keener / HITS / HodgeRank** |
| **对局拓扑支持** | 1v1, Two-Team, Multi-Team, FFA | 仅限多队 | 1v1, Multi-team | **全对局拓扑统一分发：1v1 / TwoTeam / MultiTeam / FFA + KDA 局内贡献加权** |
| **撮合匹配治理** | 仅基础计算 | 仅评分结算 | 基础排位 | **动态时间窗口排队池 + 5v5 分路位置队列 + 2-Opt 局部搜索平衡分队 + 组队协同补偿** |
| **天梯与锦标赛引擎**| 无 | 无 | 部分内置 | **LP 胜点弹性追赶 + 晋级赛/保级盾 + 单败/双败(含重置)/瑞士轮(Buchholz)/Berger 循环赛 + 蒙特卡洛夺冠预测** |
| **校准与反作弊风控**| 无 | 无 | 无 | **Brier / Log-Loss / ECE / ROC-AUC + CUSUM 代练检测 + 演员刷分图检测 + 生态基尼系数** |

---

## 三、 系统架构与模块设计 (Architecture)

```
skillrate (11,100+ lines of Pure MoonBit)
├── src
│   ├── types         # 核心领域模型 (Rating, ConfidenceInterval, TacticalRole, MatchPerformance, HistoricalMatch)
│   ├── math          # 统计数学与数值代数库 (正态/Logistic CDF/PDF/Probit, 截断高斯矩, KL/Hellinger/Wasserstein 散度, Thomas 三对角求解器, Brent/Illinois 根求解器, 确定性 PRNG)
│   ├── elo           # 经典 Elo (含胜分差 MoV、主客场优势、BoN 级数胜率) 及四大官方棋协体系 (DWZ, ECF, Ingo, USCF, FIDE)
│   ├── glicko        # 经典 Glicko-1 引擎 (1995 规范、置信区间、可靠度指数、方差加权团队归因与批量周期结算)
│   ├── glicko2       # 工业级 Glicko-2 引擎 (2001 论文 8 步闭环、波动率异常检测、双队/FFA 与锦标赛周期处理)
│   ├── bradley_terry # 成对偏好与大模型竞技场引擎 (Bradley-Terry, Davidson 平局模型, Rao-Kupper 阈值模型, Zermelo MM 求解器, Fisher 信息主动学习选对, Thurstone-Mosteller Case V)
│   ├── openskill     # OpenSkill 多队多人贝叶斯引擎 (Weng-Lin Gaussian, Bradley-Terry Full, Plackett-Luce 及 KDA/MVP 表现加权)
│   ├── whr           # Whole-History Rating (WHR) 全历史维纳过程轨迹优化器 (三对角 Hessian 牛顿法与布朗桥任意时刻插值)
│   ├── spectral      # 代数矩阵与谱网络评分系统 (Colley, Massey 攻防分解, Markov PageRank, Keener, HITS 巨人杀手, HodgeRank 循环非传递性分解)
│   ├── matchmaker    # 赛前对局质量分析、动态时间窗口排队池、5v5 MOBA 分路位置撮合、2-Opt 局部搜索平衡分队与连胜炸鱼加速
│   ├── ladder        # 天梯排位与段位系统 (保守评分 μ-3σ、LP 胜点弹性追赶与保级盾、赛季软重置、定级赛、Bo3/Bo5 晋级赛与快照涨跌对比)
│   ├── tournament    # 电子竞技锦标赛编排引擎 (单败淘汰、双败淘汰含总决赛重置、Berger 圆桌循环赛、Swiss 瑞士轮 Buchholz 破平与蒙特卡洛夺冠模拟)
│   ├── analytics     # 预测校准与反作弊风控套件 (Brier, Log-Loss, ECE/MCE, ROC-AUC, Kendall/Spearman 秩相关, CUSUM 代练检测, 演员刷分与控分检测, 基尼系数)
│   └── unified       # 15 大算法与 4 大对局拓扑统一调度门面及历史回测基准对比器 (AlgorithmBacktestResult)
├── skillrate.mbt     # 顶级统一门面 API
├── cmd/skillrate     # 全功能命令行演示工具
├── examples          # 国际象棋天梯 (chess_ladder) 与 4v4 团队对抗 (team_brawl) 实战模拟器
├── web/index.html    # 交互式 Web 可视化竞技场与高斯分布曲线
└── docs              # 完整 API 规范 (api.md)、生态查重 (dedup.md) 与架构决策 (decisions.md)
```

---

## 四、 快速上手 (Quick Start)

### 1. 15 种算法与四大对局拓扑统一分发 (`src/unified`)
```moonbit
let p1 = @skillrate.rating(mu=30.0, sigma=4.0)
let p2 = @skillrate.rating(mu=25.0, sigma=4.0)

// 一键切换 15 种底层算法 (Elo / Glicko / Glicko2 / OpenSkill / OpenSkillBT / OpenSkillPL / ThurstoneMosteller / BradleyTerry / Davidson / RaoKupper / DWZ / ECF / Ingo / USCF / FIDE)
let (new_a, new_b) = @skillrate.rate_unified_1v1(
  @unified.AlgorithmKind::Davidson,
  p1,
  p2,
  @types.GameOutcome::Win,
)

// 在同一历史对局日志上横向回测全部 15 种算法的 Brier 预测误差
let benchmark_ranking = @skillrate.benchmark_all_algorithms(history)
```

### 2. Whole-History Rating (WHR) 全历史维纳过程轨迹优化 (`src/whr`)
```moonbit
let whr = @skillrate.new_whr_engine()
whr.record_match("AlphaGo", "LeeSedol", @types.GameOutcome::Win, day_epoch=1)
whr.record_match("AlphaGo", "KeJie", @types.GameOutcome::Win, day_epoch=30)
let _ = whr.run_iterations(iterations=20)

// 基于布朗桥插值查询任意历史时刻的精确 Elo 与不确定性标准差
let state_day15 = whr.query_rating_at_day("AlphaGo", 15)
```

### 3. 代数矩阵与谱图中心性评级 (`src/spectral`)
```moonbit
// Colley 无偏矩阵法、Massey 攻防分解与 Markov PageRank 随机游走评级
let colley = @skillrate.solve_colley(4, matches)
let massey = @skillrate.solve_massey(4, score_matches)
let markov = @skillrate.solve_markov_pagerank(4, matches)
```

### 4. 锦标赛编排、蒙特卡洛夺冠预测与反作弊风控 (`src/tournament` & `src/analytics`)
```moonbit
// 构建双败淘汰赛（含败者组冠军逆袭触发的 Grand Finals Bracket Reset）或瑞士轮
let de_tourney = @skillrate.new_double_elimination_tournament(players)
let forecasts = @skillrate.forecast_tournament(players, simulations=500)

// Page's CUSUM 序列变点检测识别代练/炸鱼号
let anomaly = @skillrate.detect_account_boosting("player_1", match_observations)
```

---

## 五、 运行与测试验证 (Run & Test)

```bash
# 运行全量自动化测试 (66 项测试 100% 全绿通过)
moon test

# 检查代码格式与静态类型
moon fmt --check
moon check

# 运行演示命令行与场景案例
moon run cmd/skillrate
moon run examples/chess_ladder
moon run examples/team_brawl

# 编译为 WebAssembly (wasm-gc)
moon build --target wasm-gc
```

---

## 六、 开源许可与专利声明 (License & Patent Clearance)

- 本项目基于 **[Apache-2.0 License](LICENSE)** 许可开源。
- **专利合规说明**：本项目严格规避微软 TrueSkill™ 专有算法专利（Patent US7090582B2 等），全部算法均基于公有学术文献发表的开放模型实现，可自由用于开源或商业系统。
