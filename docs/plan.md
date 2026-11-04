# SkillRate 实施计划与架构方案 (Implementation Plan)

**项目名称**：SkillRate - 纯 MoonBit 游戏天梯、排位评分与多智能体匹配套件  
**模块标识**：`Lxxbv/skillrate`  
**开源许可**：Apache-2.0  
**作者/维护者**：Lxxbv (GitHub: [Lxxbv](https://github.com/Lxxbv))  

---

## 一、 系统架构设计

SkillRate 采用分层解耦的纯 MoonBit 工业级架构，自底向上分为四层：

```
+-------------------------------------------------------------+
| 4. 交付与应用层 (CLI Tooling, Wasm Demo & Examples)         |
|    - cmd/main (批量比赛日志重放与天梯榜导出)                   |
|    - examples/chess_ladder (国际象棋天梯模拟)                 |
|    - examples/team_brawl (4v4 MOBA / 混战天梯模拟)           |
+-------------------------------------------------------------+
                              ^
                              |
+-------------------------------------------------------------+
| 3. 编排与天梯系统层 (src/ladder & src/matchmaker)           |
|    - Leaderboard: 保守评分 (μ - 3σ) 排序、天梯分段、快照导出  |
|    - MatchQuality: 双方预期胜率预测、公平度指数评估          |
|    - Decay: 不活跃玩家评分偏差 (RD/σ) 动态衰减机制          |
+-------------------------------------------------------------+
                              ^
                              |
+-------------------------------------------------------------+
| 2. 核心竞技算法层 (src/elo, src/glicko2, src/openskill)     |
|    - Elo: 经典 1v1，动态 K 因子，预期胜率计算                |
|    - Glicko-2: 评分/偏差/波动率三元组，割线迭代，周期更新    |
|    - OpenSkill: Plackett-Luce 多队多人贝叶斯更新，支持平局    |
+-------------------------------------------------------------+
                              ^
                              |
+-------------------------------------------------------------+
| 1. 数学与基础设施层 (src/math, src/types)                   |
|    - 标准正态分布 CDF (Φ)、PDF (φ)、误差函数 erf / erfc      |
|    - 统一 Rating、Team、MatchResult、GameOutcome 域模型     |
+-------------------------------------------------------------+
```

---

## 二、 模块划分说明

| 模块路径 | 职责定位 | 核心类型与公开接口 |
| :--- | :--- | :--- |
| `src/types` | 竞技领域抽象 | `Rating`, `Player`, `Team`, `MatchResult`, `Outcome` |
| `src/math` | 纯 MoonBit 统计数学库 | `normal_cdf`, `normal_pdf`, `erf`, `erfc`, `illinois_root` |
| `src/elo` | 经典 Elo 评分系统 | `EloConfig`, `rate_1v1`, `expected_score` |
| `src/glicko2` | 工业级 1v1 Glicko-2 引擎 | `Glicko2Config`, `Glicko2Rating`, `rate_period`, `rate_match` |
| `src/openskill` | 多团队多人贝叶斯评分引擎 | `OpenSkillConfig`, `rate_teams`, `predict_win_probs` |
| `src/matchmaker` | 对局质量评估与胜率预测 | `match_quality_1v1`, `match_quality_teams` |
| `src/ladder` | 天梯排行榜与衰减系统 | `Leaderboard`, `rank_by_conservative_score`, `apply_decay` |
| `cmd/skillrate` | 命令行分析瑞士军刀 | 接收比赛对阵流，实时更新天梯榜并输出 ASCII/Markdown 榜单 |

---

## 三、 里程碑划分与交付节奏

### 里程碑 0：工程骨架与基础数学模型 (Day 1)
- [x] 初始化 Git 仓库，配置规范账号（`Lxxbv`）、Apache-2.0 协议、`.gitignore`、CI 工作流配置。
- [x] 完成生态查重报告（`docs/dedup.md`）、架构与决策记录（`docs/decisions.md`、`docs/plan.md`、`docs/tasks.md`）。
- [x] 起草官方标准五段式立项申报书（`项目申报书.md`、`PROJECT_PROPOSAL.md`）。
- [ ] 搭建 `src/types` 与 `src/math`（包含高精度正态分布累积分布、误差函数及完备单元测试）。

### 里程碑 1：经典 Elo 与 Glicko-2 核心算法引擎 (Day 1 - Day 2)
- [ ] 实现 `src/elo`：动态 K-factor、胜率期望、比赛打分更新。
- [ ] 实现 `src/glicko2`：Glickman 论文规范算例对齐（包含 rating、RD、volatility 三元组与 Illinois 根查找）。
- [ ] 针对官方论文标准算例（Example calculation）编写 100% 对应断言测试。

### 里程碑 2：OpenSkill 多团队多人贝叶斯评分引擎 (Day 2 - Day 3)
- [ ] 实现 `src/openskill`：基于 Weng-Lin / Plackett-Luce 的多队多玩家贝叶斯更新。
- [ ] 支持非平衡队伍（如 2v3）、支持不同权重分配、支持平局结算。
- [ ] 引入黄金测试集（对齐 Python/TypeScript openskill 库的基准算例）。

### 里程碑 3：天梯排行榜、对局质量评估与活跃度衰减 (Day 3 - Day 4)
- [ ] 实现 `src/matchmaker`：1v1 与多队对局质量评估（Match Quality $\in [0, 1]$）。
- [ ] 实现 `src/ladder`：天梯排行榜管理器、保守评分（$\mu - 3\sigma$）稳定排位、历史排位快照。
- [ ] 实现时间周期衰减（Rating Decay / Inactivity penalty）。

### 里程碑 4：CLI 工具、国际象棋/MOBA 样例与中英双语文档 (Day 4 - Day 5)
- [ ] 编写 `cmd/skillrate`：可执行命令行程序，支持读取对战序列并输出美观排行榜。
- [ ] 编写真实场景示例：
  - `examples/chess_ladder`：国际象棋天梯对战模拟；
  - `examples/team_brawl`：4v4 团队混战排位模拟。
- [ ] 完善中英双语 `README.md`、全流程端到端自动化测试验证、`wasm-gc` 编译验证。
