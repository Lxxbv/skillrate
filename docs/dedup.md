# MoonBit 生态查重与独创性分析报告 (Deduplication Report)

**项目名称**：`skillrate` (纯 MoonBit 游戏天梯与多智能体竞技评分引擎)  
**模块标识**：`Lxxbv/skillrate`  
**开源许可**：Apache-2.0  
**检索日期**：2026-11-04  

---

## 一、 官方中心仓库 (mooncakes.io) 全面检索实测

在终端对 MoonBit 官方包注册中心 `mooncakes.io` 针对竞技评分、游戏排名、匹配算法进行全面关键词检索，实测结果如下：

### 1. 核心算法关键词检索
```bash
$ moon search "glicko"
No modules found.

$ moon search "openskill"
1 module found:
  gmlewis/step@0.1.25 (matched OpenShell - STEP 3D CAD 拓扑几何实体，完全无关)

$ moon search "trueskill"
No modules found.

$ moon search "elo"
1 module found:
  weidekais/moonbit-adsorption@0.2.1 (matched Elovich 吸附等温动力学模型，完全无关)
```

### 2. 领域关键词检索
```bash
$ moon search "matchmaking"
No modules found.

$ moon search "rating"
8 modules found:
  - lyyjavastudy/moonbit-freight-calculator (物流运费阶梯计费)
  - xvkong834/moonbit-freight-calculator (物流运费计费)
  - zbhzs1/moonbit-phonetic (语音相似度 Match Rating 算法)
  - wjcoomk/moonbit-relief (安全阀法兰承压等级 rating)
  - 均与竞技天梯/玩家评分无任何关联。

$ moon search "ranking"
7 modules found:
  - bobzhang/loop_invariants_graph (稳定婚姻匹配 Gale-Shapley)
  - bobzhang/loop_invariants_techniques (字典序排列秩 rank)
  - Juwan-Hwang/moon-certified (PageRank 图连通迭代、后缀平衡树)
  - Lfan-ke/moonkoog (RAG 向量余弦相似度检索排序)
  - zhaoyuanjuns/moonbit_extractor (化工液液萃取级数 ranking)
  - 均无游戏/竞技选手排位模型。

$ moon search "leaderboard"
1 module found:
  - JIA2JIA2/moonbitdb/examples/leaderboard (仅为数据库样例中的空 Player 结构，无任何排位积分算法)
```

---

## 二、 查重结论与独创性边界

1. **绝对首创性（0 重复度）**：
   - 当前 MoonBit 生态在竞技对战评分、天梯天梯排位、多队多玩家匹配领域**完全空白**。
   - `Lxxbv/skillrate` 将是 MoonBit 生态中首个工业级评分与天梯排位算法库。

2. **与社区既有项目的协同互补**：
   - 社区现有 `L76148/moonchess`（国际象棋）、`wbgxiaosu/xiangqi`（中国象棋）、`bobzhang/games`（射箭/物理小游戏）等，目前均缺乏比赛结算与排位天梯机制。
   - `skillrate` 为零依赖纯库，可直接作为这些对战游戏和未来 AI Agent 竞技场的官方推荐底层评分插件。

3. **专利规避与开源合规性**：
   - 微软 TrueSkill 算法受到 Patent US7090582B2 等国际专利保护，商业使用存在侵权风险。
   - 本项目严格规避 TrueSkill 专有公式，选择学术公开的 **Glicko-2**（Mark E. Glickman）与 **OpenSkill**（基于 Weng-Lin 贝叶斯近似模型与 Plackett-Luce 模型），并在 Apache-2.0 协议下完全自由开源。
