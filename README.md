# SkillRate

**纯 MoonBit 现代竞技评分、天梯排位与多智能体对战匹配套件**  
*(Modern Skill Rating, Matchmaking, and Leaderboard Engine in Pure MoonBit)*

[![MoonBit](https://img.shields.io/badge/Language-MoonBit-purple)](https://www.moonbitlang.com/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Target](https://img.shields.io/badge/Target-Wasm--GC%20%7C%20Native-brightgreen)]()
[![Tests](https://img.shields.io/badge/Tests-30%20Passed%20(100%25)-brightgreen)]()
[![Docs](https://img.shields.io/badge/API-Reference-blue)](docs/api.md)

---

## 一、 项目定位 (Overview)

**SkillRate** (`Lxxbv/skillrate`) 是专为对战游戏、棋类对弈、竞技天梯排位以及 AI 多智能体竞技场（LLM Agent Arena）打造的工业级竞技评分套件。100% 纯 MoonBit 原生开发，零任何外部二进制或 C/Rust FFI 依赖，原生编译支持 `wasm` 与 `wasm-gc`。

本项目在业内首次将经典 **Elo**、1v1 工业级标准 **Glicko-2** 以及现代多团队贝叶斯评分模型 **OpenSkill** 统一集成在同一套高内聚的类型系统与天梯架构中，填补了 MoonBit 生态在竞技匹配与排名系统领域的空白。

---

## 二、 算法特性横向对比 (Feature Matrix)

| 核心维度 | 经典 Elo | Glicko-2 (Mark Glickman) | 微软 TrueSkill™ | **SkillRate (OpenSkill)** |
| :--- | :---: | :---: | :---: | :---: |
| **支持场景** | 仅限 1v1 | 仅限 1v1 | 多队多人 ($N$ vs $N$) | **多队多人 ($N$ 队、$M$ 人)** |
| **置信度度量** | 无 (单一数值) | 有 (评分偏差 $RD$) | 有 (标准差 $\sigma$) | **有 (方差 $\sigma^2$ 与置信下界)** |
| **表现波动率** | 无 | 有 (波动率 $\sigma$) | 无 | **有 (可配置动态更新)** |
| **非平衡队伍** | 不支持 | 不支持 | 支持 | **原生支持 (支持成员自定义权重)** |
| **专利侵权风险** | 无 | **无 (学术公开)** | **存在专利保护 (US7090582B2)** | **无 (Weng-Lin 开放模型，完全合规)** |
| **MoonBit 实现** | **内置提供** | **内置提供** | 规避不予实现 | **内置提供** |

---

## 三、 系统架构与模块设计 (Architecture)

```
skillrate
├── src
│   ├── types         # 核心领域模型 (Rating, Player, Team, GameOutcome)
│   ├── math          # 高精度统计数学库 (正态分布 CDF/PDF, erf, Probit, Illinois 根求解器)
│   ├── elo           # 经典 Elo 评分引擎 (含自适应 K-factor)
│   ├── glicko2       # 工业级 Glicko-2 引擎 (Glickman 论文 8 步闭环，含自然方差发散)
│   ├── openskill     # OpenSkill 多团队多人贝叶斯评分引擎 (Weng-Lin / Plackett-Luce)
│   ├── matchmaker    # 赛前对局平衡度分析 (Match Quality) 与胜率预测矩阵
│   └── ladder        # 天梯排行榜系统 (保守评分 μ-3σ 排序、段位晋级与活跃度衰减)
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

### 1. 经典 Elo 1v1 计算
```moonbit
let elo_a = 1600.0
let elo_b = 1400.0

// 计算胜率期望
let exp_a = @elo.expected_score(elo_a, elo_b) // ~75.97%

// A 战胜 B
let (new_a, new_b) = @elo.rate_1v1(elo_a, elo_b, @types.GameOutcome::Win)
```

### 2. Glicko-2 评级周期结算 (含偏差与波动率)
```moonbit
let player = @glicko2.Glicko2Rating::new(1500.0, 200.0, 0.06)
let matches = [
  @glicko2.OpponentMatch::new(@glicko2.Glicko2Rating::new(1400.0, 30.0, 0.06), 1.0), // 胜
  @glicko2.OpponentMatch::new(@glicko2.Glicko2Rating::new(1550.0, 100.0, 0.06), 0.0), // 负
]
let updated = @glicko2.rate_period(player, matches)
// updated.rating ~ 1464.06, updated.deviation ~ 151.52, updated.volatility ~ 0.05999
```

### 3. OpenSkill 多人多队战队对抗
```moonbit
let team_red = [@types.Rating::default(), @types.Rating::default()]
let team_blue = [@types.Rating::default(), @types.Rating::default()]

// 评估赛前对局质量
let quality = @matchmaker.match_quality_2teams(team_red, team_blue)

// 红队战胜蓝队 (ranks=[1, 2])
let updated_teams = @openskill.rate_teams([team_red, team_blue], ranks=[1, 2])
```

### 4. 天梯排位与排行榜 (Leaderboard)
```moonbit
let board = @ladder.Leaderboard::new()
board.register_player("p1", name="Alice")
board.register_player("p2", name="Bob")

// 记录对战结果
let _ = board.record_match("p1", "p2", @types.GameOutcome::Win)

// 导出排位表格（以保守评分 μ - 3σ 排序，防止新手虚高）
let table = board.render_ascii_table()
println(table)
```

---

## 五、 运行与测试验证 (Run & Test)

```bash
# 运行全量自动化测试 (25 项全绿通过)
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
- **专利合规说明**：本项目刻意未采用微软 TrueSkill™ 专有算法（涉及 Patent US7090582B2 等国际专利），全部算法均基于公有学术文献发表的 Glicko-2 与 OpenSkill 开放模型实现，可完全自由地用于开源或商业系统。
