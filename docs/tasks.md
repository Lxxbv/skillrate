# 任务清单与完成进度 (Tasks Checklist)

- [x] **阶段 0：工程配置、查重调研与立项申报**
  - [x] 配置本地 Git 账号为 `Lxxbv` 与对应 noreply 邮箱
  - [x] 完成官方 mooncakes.io 全面查重检索并沉淀 `docs/dedup.md`
  - [x] 确立架构设计与技术选型文档 `docs/plan.md`、`docs/decisions.md`
  - [x] 编制符合官方标准的五段式项目申报书（`项目申报书.md`、`PROJECT_PROPOSAL.md`，本地保留不入版本库）
  - [x] 初始化 `moon.mod` 与 CI 工作流配置（`moon check`、`moon test`、`moon fmt`、`moon build --target wasm-gc`）
  - [x] 添加 Apache-2.0 许可证文件

- [x] **阶段 1：数学核心库与基础领域模型 (src/math & src/types)**
  - [x] 定义 `Rating`、`GameOutcome`、`Player`、`Team` 等核心领域模型
  - [x] 实现基础常量与高精度浮点工具
  - [x] 实现标准正态分布累积分布函数 $\Phi(x)$ 与概率密度函数 $\phi(x)$
  - [x] 实现高精度误差函数 $\text{erf}(x)$ 与互补误差函数 $\text{erfc}(x)$
  - [x] 实现针对非线性方程的 Illinois 迭代求解器
  - [x] 编写数学库白盒测试（`src/math/math_wbtest.mbt`），验证精度达到 $10^{-7}$ 以上，7/7 测试全绿通过

- [x] **阶段 2：经典 Elo 与 Glicko-2 核心评分引擎**
  - [x] 实现 `src/elo` 模块：标准胜率期望、动态 K 因子自适应调整
  - [x] 编写 Elo 单测与极端分差测试（`src/elo/elo_wbtest.mbt`）
  - [x] 实现 `src/glicko2` 模块：原始尺度与 Glicko-2 尺度的来回映射
  - [x] 实现 Glicko-2 辅助函数 $g(\phi)$ 与 $E(\mu, \mu_j, \phi_j)$
  - [x] 实现 Glicko-2 方差 $v$ 与差异量 $\Delta$ 计算
  - [x] 实现 Glicko-2 波动率 $\sigma'$ 的 Illinois 割线法收敛迭代
  - [x] 实现未参赛周期的偏差自然发散更新
  - [x] 严格对齐 Mark Glickman 官方论文中的 3 场比赛完整数值样例，实现 100% 精度断言测试（13/13 测试全绿通过）

- [ ] **阶段 3：OpenSkill 多团队多人贝叶斯评分引擎**
  - [ ] 实现 `src/openskill` 模块：多元高斯先验表示与团队聚合
  - [ ] 实现 Plackett-Luce 模型下的似然逼近与边缘更新
  - [ ] 支持多队伍对抗（2 队、3 队、Free-for-All 自由混战）
  - [ ] 支持非平衡人数队伍（如 3v2、4v5）及权重加权
  - [ ] 支持比赛平局结算（Draw Margin）
  - [ ] 引入标准黄金测试集（对齐主流 openskill 实现基准），编写白盒测试套件

- [ ] **阶段 4：对局质量、天梯系统与活跃度衰减**
  - [ ] 实现 `src/matchmaker` 模块：1v1 与多队匹配质量（Match Quality）计算
  - [ ] 实现胜率预测矩阵（Win Probability Matrix）
  - [ ] 实现 `src/ladder` 模块：天梯排行榜（Leaderboard）数据结构
  - [ ] 实现基于保守评分（Conservative Rating: $\mu - 3\sigma$）的公平排位算法
  - [ ] 实现天梯段位（Tier & Division）划分规则
  - [ ] 实现长时间不活跃玩家的 RD 逐渐衰减机制（Rating Decay）

- [ ] **阶段 5：命令行应用、场景案例与工程验证**
  - [ ] 实现 `cmd/skillrate`：支持接收对局流、更新排行榜并输出格式化表格
  - [ ] 编写案例一：`examples/chess_ladder`（国际象棋 1v1 天梯演进模拟）
  - [ ] 编写案例二：`examples/team_brawl`（MOBA / 4v4 战队积分排位模拟）
  - [ ] 编写专业中英双语 `README.md`
  - [ ] 执行全量自动化测试套件与 `wasm-gc` 跨平台编译，确保 100% 绿灯通过
