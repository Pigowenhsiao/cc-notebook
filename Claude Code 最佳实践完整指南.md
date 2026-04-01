# Claude Code 最佳实践完整指南

> 基于 compound-engineering v2.59.0 + gstack v0.13.7 + 自定义 hooks 的完整配置方案
> 更新日期：2026-03-29

---

## 一、插件体系架构

### 已安装插件

| 插件 | 版本 | 作用 | 状态 |
|------|------|------|------|
| compound-engineering | v2.59.0 | 多智能体工作流引擎（brainstorm/plan/work/review/compound） | 启用 |
| gstack | v0.13.7 | 浏览器自动化 + 运维闭环（office-hours/ship/deploy/qa/cso） | 启用（skill 形式） |
| telegram | v0.0.4 | Telegram bot 集成 | 启用 |
| pyright | v1.0.0 | Python 类型检查 LSP | 启用 |

### 已卸载插件（及原因）

| 插件 | 原因 |
|------|------|
| superpowers v5.0.5 | 与 CE 完全重叠：brainstorming→ce:brainstorm, writing-plans→ce:plan, executing-plans→ce:work, code-review→ce:review |
| everything-claude-code (117K stars) | 未安装。与 CE+gstack 高度重叠（135 skills 全部有替代），会造成命名冲突和 context 膨胀。仅提取了 3 个有价值的 hook |

### 不安装 everything-claude-code 的分析

ECC 的 135 个 skills、30 个 agents、60 个 commands 几乎全被 CE+gstack 覆盖且更强。安装后会导致：
- 200+ skills 挤在注册表，严重 context 膨胀
- `/plan` 同时存在于 ECC 和 CE，产生命名冲突
- 每次会话加载大量冗余内容

ECC 唯一有价值的是 hooks 层面的创新，已单独提取（见第三节）。

---

## 二、CLAUDE.md 设计哲学

### 核心原则：只保留增量价值

Claude Code 系统 prompt 已经包含了大量默认行为指令。CLAUDE.md 不应重复这些内容，因为每个 token 在每次会话中都会被加载。

### 删除的 8 个冗余段落（~45% 体积）

| 段落 | 删除原因 |
|------|----------|
| Context Window Management | Claude Code 自动 compact，无需指示 |
| Default to Action | 系统 prompt 已有相同指令 |
| Parallel Tool Calls | 系统 prompt 已有逐字相同的指令 |
| Code Exploration and Quality | 系统 prompt 已有 "read before edit" 规则 |
| Avoid Overengineering | 系统 prompt 已有 "Don't add features beyond what was asked" |
| Clean Up | 显而易见的行为 |
| Cross-Tool Project Specification | 仅在新项目初始化时相关，非 every session |
| Context-Activated Rules | 自我引用的 meta 建议 |

### 保留的核心内容

1. **Standard Development Workflow** — 14 步流程（核心价值）
2. **CE vs gstack Tool Selection** — 工具选择表（一眼看出用哪个）
3. **Subagent Model** — 非默认行为，需要显式声明（CE 的 Haiku 豁免）
4. **Engineering Principles** — 三个独特哲学（Feature Value Gate → Boil the Lake → Search Before Building）
5. **Memory Rules** — memory-lancedb-pro MCP 的具体规则
6. **Browser Automation Rules** — 特定配置

### 新增的关键内容

1. **双层审查说明** — ce:review 广度 + codex 跨模型深度
2. **三层知识说明** — CE docs + gstack auto-learn + personal memory
3. **`/ce:ideate` 作为 Step 0** — 可选入口
4. **`/learn`** — gstack 自学习管理

### 当前完整 CLAUDE.md

```markdown
# Global Claude Code Configuration

## Standard Development Workflow (compound-engineering + gstack)

When implementing a non-trivial feature (3+ files changed), follow this pipeline:

 0. /ce:ideate (optional)   — Surface high-impact ideas worth exploring (CE)
 1. /office-hours            — Validate the idea is worth building (gstack)
 2. /ce:brainstorm           — Explore requirements + auto document-review (CE)
 3. /ce:plan                 — Research-backed implementation plan (CE)
 4. /autoplan                — CEO + Eng + Design triple review on the plan (gstack)
 5. /ce:work                 — Execute plan with parallel subagents (CE)
 6. /ce:review               — Multi-agent code review, 27+ reviewers (CE)
 7. /codex review            — Cross-model second opinion (gstack)
 8. Fix all review findings before proceeding
 9. /ship                    — Bump version, create PR (gstack)
10. Check CI green (gh pr checks)
11. /land-and-deploy         — Merge + verify production + canary (gstack)
12. /ce:compound             — Document learnings to docs/solutions/ (CE)
13. /lessons-learned         — Save non-obvious knowledge to memory (gstack)

Small changes: skip 0, 1, 3, 4, 11, 12. Use /ce:review + /ship.

Dual-layer review: ce:review (breadth, 27+ agents) + codex review (cross-model depth).

Triple-layer knowledge:
- ce:compound → docs/solutions/ (CE agents auto-search)
- gstack auto-learns → learnings.jsonl (auto-applied with confidence scoring)
- /lessons-learned → personal memory (cross-project)

## CE vs gstack Tool Selection (表略)

## Subagent Model
All subagents use opus, except CE skills (ce:review uses Haiku for cost control).

## Engineering Principles
Feature Value Gate first, then Boil the Lake.
Search Before Building (three layers).
LLM System Testing (prompt > code, E2E > unit).

## Memory Rules (memory-lancedb-pro) (规则略)
## Browser Automation Rules (规则略)
```

---

## 三、Hooks 配置

### 来源

从 everything-claude-code (117K stars) 项目中提取的 3 个有独立价值的 hook，重写为零依赖 shell 脚本。

### 已配置的 Hooks

| Hook | 触发时机 | 作用 | 文件 |
|------|----------|------|------|
| kill-port | PreToolUse:Bash | 自动杀占用端口的进程 | `~/.claude/kill-port.sh` |
| block-no-verify | PreToolUse:Bash | 阻止 `--no-verify` / `--no-gpg-sign`，防止 AI 绕过 git hooks | `~/.claude/hooks/block-no-verify.sh` |
| format | PreToolUse:Write\|Edit | 编辑前自动格式化 | `bun run format` |
| config-protection | PreToolUse:Write\|Edit | 阻止修改 linter/formatter 配置文件（.eslintrc, .prettierrc, biome.json 等） | `~/.claude/hooks/config-protection.sh` |
| desktop-notify | Stop | macOS 桌面通知，Claude 完成响应时弹出 | `~/.claude/hooks/desktop-notify.sh` |

### Hook 设计原则

- **零依赖**：仅用 bash + python3 + osascript，不需要 Node.js 或 npm 包
- **快速**：所有 hook 5 秒 timeout
- **安全退出码**：exit 0 = 允许，exit 2 = 阻止

### config-protection 保护的文件清单

```
.eslintrc*  eslint.config.*  .prettierrc*  prettier.config.*
biome.json  biome.jsonc  .ruff.toml  ruff.toml
.shellcheckrc  .stylelintrc*  .markdownlint*
```

**为什么保护这些文件？** AI agent 经常通过放宽 linter 规则来"解决"代码质量问题，而不是修复源代码。这个 hook 强制 AI 修代码而非弱化规则。

---

## 四、CE vs gstack 定位差异

### 能力矩阵

| 维度 | compound-engineering (CE) | gstack |
|------|---------------------------|--------|
| 核心能力 | 多智能体深度分析（35+ agents, 40+ skills） | 浏览器自动化 + 运维闭环（Playwright daemon） |
| 审查方式 | 并行多人格审查（27+ persona agents，用 Haiku 降本） | 结构化单 pass + 跨模型对比（Claude + Codex） |
| 知识沉淀 | 项目级文档 `docs/solutions/`（ce:compound） | 自学习 `learnings.jsonl`（auto-captured） + 个人记忆 |
| 计划评审 | 自动 document-review（7 个 persona agents） | 三视角评审 CEO/Eng/Design |
| 浏览器 | 无 | 核心能力：QA、canary、benchmark、design-review |
| 安全 | review agents 中有 security-reviewer | 独立 /cso（OWASP + STRIDE + secrets + supply chain） |
| 执行策略 | 4 种（inline, serial, parallel, swarm） | 无独立执行引擎 |
| 发布 | git-commit-push-pr（基础） | /ship（VERSION + CHANGELOG + Dashboard + Triage） |
| 部署 | 无 | /land-and-deploy + /canary |

### 工具选择决策树

```
需要探索需求？           → /ce:brainstorm（自动 document-review）
需要写实施计划？         → /ce:plan（research agents）
需要评审计划？           → /autoplan（CEO + Eng + Design）
需要写代码？             → /ce:work（4 种执行策略）
需要审代码？             → /ce:review + /codex review（双层）
需要浏览器测试？         → /qa, /design-review, /browse（gstack 独有）
需要安全审计？           → /cso（gstack 独有）
需要性能基线？           → /benchmark（gstack 独有）
需要部署验证？           → /land-and-deploy + /canary（gstack 独有）
需要调试 Bug？           → /investigate（gstack 独有，freeze boundary）
需要发 PR？              → /ship（gstack 独有，完整发布流程）
需要管理项目知识？       → /learn（gstack v0.13.4+）
```

---

## 五、14 步标准工作流（实战详解）

### Step 0 — /ce:ideate（可选：有想法但不确定做什么）

**输入：** `/ce:ideate`

**过程：**
1. 派 4-6 个 subagent 用不同思维框架（用户痛点、假设挑战、极端场景、杠杆点、反向思考、未满足需求）各生成 ~8 个想法
2. 对抗 agent 过滤——逐个攻击，弱想法被淘汰
3. 存活者按 groundedness、value、novelty、pragmatism、leverage、burden 打分
4. 呈现 5-7 个存活想法

**产出：** `docs/ideation/YYYY-MM-DD-<topic>-ideation.md`

**你做什么：** 选一个想法。自动交给 ce:brainstorm。

**跳过条件：** 已明确知道要做什么。

---

### Step 1 — /office-hours（验证值不值得做）

**输入：** `/office-hours`

**过程：** 问你 "你的目标是什么？" 然后分流：

- **Startup 模式** → YC 六问拷打：
  1. 谁在痛？（Demand Reality）
  2. 现在怎么解决？（Status Quo）
  3. 有多绝望？（Desperate Specificity）
  4. 最小切入点？（Narrowest Wedge）
  5. 观察到什么反常？（Observation & Surprise）
  6. 未来适配吗？（Future-Fit）
  - 不是所有 6 个都问——根据产品阶段智能选择
- **Builder 模式** → 协作设计伙伴，不审问

**产出：** 设计文档 `~/.gstack/projects/$SLUG/`。**后续所有 skill 自动发现此文件。**

**隐藏能力：**
- 中途升级：Builder 模式中提到客户/收入，自动切换到 Startup 模式
- 逃逸舱：说 "just do it" 只问最关键的 2 个问题
- 跨模型第二意见：可选调 Codex 做独立 cold read

---

### Step 2 — /ce:brainstorm（探索需求）

**输入：** `/ce:brainstorm`

**过程：**
1. 扫描仓库找相关代码和已有工作
2. 产品压力测试——挑战需求合理性
3. 一次一个问题和你对话（偏好单选题）
4. 提出 2-3 个实现方案（含高风险高回报挑战者）
5. 写需求文档（带 R1, R2, R3 稳定 ID + scope boundary + success criteria）
6. **自动调 document-review** — 7 个 persona agent 审查需求文档

**产出：** `docs/brainstorms/YYYY-MM-DD-<topic>-requirements.md`

**智能分流：** 自动分类 Lightweight/Standard/Deep，清晰需求跳过深度对话。

---

### Step 3 — /ce:plan（写实施计划）

**输入：** `/ce:plan`

**过程：**
1. 自动发现 Step 2 的需求文档
2. 派 `repo-research-analyst` 分析仓库架构和模式
3. 派 `learnings-researcher` 搜索 `docs/solutions/` 找历史经验
4. 可选派 `best-practices-researcher` + `framework-docs-researcher` 查外部最佳实践
5. 可选派 `spec-flow-analyzer` 分析用户流和边界情况
6. 整合研究，拆分实现单元，标注文件路径、测试场景、依赖关系

**产出：** `docs/plans/YYYY-MM-DD-NNN-<type>-<name>-plan.md`

**高级用法：** 对已有计划说 "deepen the plan" 触发交互式深化。

---

### Step 4 — /autoplan（三方自动评审计划）

**输入：** `/autoplan`

**过程：** 从磁盘读取 CEO、Design、Eng 三个评审 skill，全深度执行：

```
CEO 评审 → Design 评审（如果有 UI）→ Eng 评审
```

**6 个决策原则：**
1. 完整性（完整方案优先）
2. 煮沸湖（blast radius 内全修）
3. 务实（更干净的方案赢）
4. DRY（拒绝重复）
5. 显式优于聪明（10 行明确 > 200 行抽象）
6. 行动偏好（合并 > 评审循环 > 陈旧讨论）

**决策分类：**
- **机械决策**（明显正确）→ 自动决定，不打扰
- **品味决策**（合理分歧）→ 自动决定但在最终门控展示给你

**产出：** 计划文件追加决策审计表 + Review Readiness Dashboard 标记 CLEARED

---

### Step 5 — /ce:work（执行实施）

**输入：** `/ce:work`

**过程：**
1. 读取计划，创建分支/worktree
2. 提取实现单元，创建 task list
3. 自动选择执行策略：
   - **Inline**：1-2 小任务（默认）
   - **Serial subagents**：3+ 有依赖的任务
   - **Parallel subagents**：3+ 独立任务，不同 agent 改不同文件
   - **Swarm Mode**：10+ 任务需要 agent 间通信（需手动 opt-in）
4. 每完成一个单元：测试 → 增量 commit
5. 全量测试 → 自动调 ce:review mode:autofix → 修复安全问题

**系统级测试检查（每个任务完成前）：**
- 这个改动会触发什么？（callback, middleware, observer）
- 测试是否覆盖了真实链路？（不只是 mock）
- 失败是否会留下孤立状态？（DB rows before external calls）
- 有没有其他接口暴露这个？（mixin, 替代入口）
- 错误策略是否跨层一致？

**产出：** 功能代码 + 测试 + 多个增量 commit

---

### Step 6 — /ce:review（多维代码审查）

**输入：** `/ce:review plan:docs/plans/YYYY-MM-DD-NNN-plan.md`

**审查团队（并行运行，Haiku 模型降本）：**

| 类型 | 审查者 |
|------|--------|
| 常驻（6个） | correctness, testing, maintainability, project-standards, agent-native, learnings-researcher |
| 条件触发 | security, performance, api-contract, data-migrations, reliability, adversarial, previous-comments |
| 语言特定 | kieran-rails, kieran-python, kieran-typescript, julik-frontend-races |
| CE 特有 | schema-drift-detector, deployment-verification-agent |

**合并管道：**
- 置信度 < 0.60 的发现被压制（P0 除外，0.50+ 即保留）
- 跨 reviewer 一致的发现 +0.10 置信度提升
- 指纹去重（file + line_bucket(+/-3) + title）
- `safe_auto` → 自动修复，`gated_auto` → 需确认，`manual` → 手动修

**带 plan 参数的额外能力：** 检查每个 R1/R2/R3 需求是否在 diff 中体现，缺失变 P1 finding。

**四种模式：**

| 模式 | 用途 |
|------|------|
| Interactive（默认） | 正常审查，用户决定 |
| `mode:autofix` | ce:work 流水线中，自动修复 |
| `mode:report-only` | 只读，安全并行 |
| `mode:headless` | skill-to-skill 调用，结构化输出 |

---

### Step 7 — /codex review（跨模型交叉验证）

**输入：** `/codex review`

**过程：**
1. 调用 OpenAI Codex CLI 审查 diff
2. P1 = FAIL，P2-only = PASS
3. 自动对比 Step 6 结果：

```
CROSS-MODEL ANALYSIS:
  Both found: [两个模型都发现 — 高置信度]
  Only Codex found: [Claude 盲点]
  Only Claude found: [Codex 盲点]
  Agreement rate: 73%
```

**其他模式：**
- `/codex challenge` — 对抗模式，主动尝试破坏代码
- `/codex challenge security` — 聚焦安全漏洞
- `/codex <prompt>` — 咨询模式，带会话记忆

---

### Step 8 — 修复所有发现

根据 Step 6 + Step 7 的发现修代码。`safe_auto` 已自动修好，关注 `gated_auto` 和 `manual`。

---

### Step 9 — /ship（发布 PR）

**输入：** `/ship`

**过程（全自动，仅在关键点停下）：**
1. 检查 Review Readiness Dashboard
2. Merge base branch
3. 跑测试 — Test Failure Ownership Triage：
   - in-branch 失败 → 必须修
   - pre-existing 失败 → 提供：修 / blame+assign issue / 加 TODO / skip
4. 测试覆盖率审计（ASCII coverage 图）
5. 计划项验证（每个 item DONE/PARTIAL/NOT DONE）
6. 内联运行 `/review`（如已跑过则跳过）
7. Bump VERSION + 更新 CHANGELOG
8. Commit + Push + 创建 PR

**对抗审查自动伸缩：**
- <50 行：跳过
- 50-199 行：跨模型审查
- 200+ 行：全 4 轮对抗

---

### Step 10 — CI 检查

```
gh pr checks
```

等绿灯。CI 挂了根据错误修复。

---

### Step 11 — /land-and-deploy（部署到生产）

**输入：** `/land-and-deploy`

**过程：**
1. 检查 PR 状态
2. Merge PR
3. 等部署完成（自动检测 Fly.io / Vercel / Netlify / Heroku）
4. Canary 检查：console errors、性能回退、页面失败
5. 通过 → 部署成功 / 失败 → 提供回滚方案

**提前准备：** 部署前跑 `/benchmark <url> --baseline` 和 `/canary <url> --baseline`

---

### Step 12 — /ce:compound（沉淀项目知识）

**输入：** `/ce:compound`（或自动触发："it's fixed", "that worked", "problem solved"）

**过程：**
1. 3 个 subagent 并行：Context Analyzer + Solution Extractor + Related Docs Finder
2. 高重叠 → 更新已有文档而非创建重复
3. 自动选择 Bug 模板或 Knowledge 模板
4. 可选调专业 agent 增强（性能→performance-oracle，安全→security-sentinel）

**产出：** `docs/solutions/<category>/<filename>.md`

**知识闭环：** 未来的 ce:plan 和 ce:review 自动搜索到这些文档（通过 learnings-researcher agent）。

---

### Step 13 — /lessons-learned（沉淀个人记忆）

**输入：** `/lessons-learned`

总结非显而易见的教训，存到 `~/.claude/memory/`。跨项目、跨会话可用。

---

## 六、场景速查

### A. 全功能开发（3+ files）
全 14 步，不跳过。

### B. 小改动（1-2 files）
```
code → /ce:review → /codex review → /ship
```

### C. Bug 修复
```
/investigate → fix → /ce:review → /ship → /ce:compound（如果非显而易见）
```

### D. Hotfix（生产事故）
```
/investigate → fix → /ce:review mode:autofix → /ship → /land-and-deploy → /canary
```

### E. 安全审计
```
/cso                    — 日常（8/10 置信度，零噪声）
/cso --comprehensive    — 月度（2/10 置信度）
/cso --diff             — 仅当前分支改动
/cso --skills           — 扫描已安装 skills
```

### F. QA / Dogfooding
```
/benchmark <url> --baseline → /qa <url> → /design-review <url> → /benchmark <url>
```

### G. 绿地项目
```
/office-hours → /design-consultation → /ce:brainstorm → /ce:plan → /autoplan → /ce:work
```

### H. 重构
```
/ce:brainstorm → /ce:plan → /ce:work → /ce:review → /codex review → /ship
```

### I. 全自动（最少人工干预）
```
/lfg    — plan → work → review → todo-resolve → test-browser → feature-video
/slfg   — 同上 + swarm mode + parallel review+test
```

### J. 周回顾
```
/retro              — 本仓库 7 天
/retro global       — 跨项目跨工具
/retro compare      — 对比上个同周期
```

---

## 七、数据流全景图

```
/office-hours
  └─> ~/.gstack/projects/$SLUG/*-design-*.md
       ├─> /autoplan（自动发现）
       ├─> /review（Scope Drift Detection）
       └─> /design-consultation（pre-check）

/ce:brainstorm
  └─> docs/brainstorms/YYYY-MM-DD-*-requirements.md
       └─> /ce:plan（发现上游需求）

/ce:plan
  └─> docs/plans/YYYY-MM-DD-NNN-*-plan.md
       ├─> /autoplan（评审计划）
       ├─> /ce:work（读取 Execution notes）
       ├─> /ce:review plan:<path>（需求验证）
       └─> /review（Plan Completion Audit）

/autoplan, /review, /codex
  └─> ~/.gstack/projects/$SLUG/*-reviews.jsonl
       └─> /ship（Review Readiness Dashboard）

/ce:compound
  └─> docs/solutions/<category>/<filename>.md
       └─> learnings-researcher agent（未来 ce:plan + ce:review 搜索）

/review, /ship, /investigate（gstack 自动学习）
  └─> ~/.gstack/projects/{slug}/learnings.jsonl
       └─> 未来 gstack reviews（置信度打分 + "Learning applied" 标注）

/learn
  └─> 搜索、修剪、导出 gstack learnings

/lessons-learned
  └─> ~/.claude/memory/（个人跨项目记忆）

/benchmark --baseline, /canary --baseline
  └─> .gstack/ baseline files
       └─> 部署后回归比对

/qa, /design-review
  └─> 原子 git commit + before/after 截图
```

---

## 八、三层知识体系

### 架构

```
Layer 1 (CE)      /ce:compound     → docs/solutions/     → learnings-researcher 在未来 ce:plan/ce:review 中搜索
Layer 2 (gstack)  自动捕获          → learnings.jsonl     → 未来 gstack review 中 "Learning applied" 标注
Layer 3 (个人)    /lessons-learned  → ~/.claude/memory/   → 跨项目跨会话可用
```

### Layer 1：CE 项目文档

- **写入时机：** `/ce:compound`（或自动触发）
- **存储位置：** `docs/solutions/<category>/<filename>.md`
- **消费者：** CE 的 `learnings-researcher` agent，在 ce:plan 和 ce:review 中自动搜索
- **维护：** `/ce:compound-refresh` — 五种结果（Keep/Update/Consolidate/Replace/Delete）
- **特点：** 团队共享，版本控制

### Layer 2：gstack 自学习

- **写入时机：** 自动——/review, /ship, /investigate 过程中 gstack 自动捕获模式和陷阱
- **存储位置：** `~/.gstack/projects/{slug}/learnings.jsonl`
- **消费者：** 未来 gstack review 显示 "Learning applied: [pattern] (confidence 8/10, from 2026-03-15)"
- **置信度：** 1-10 分，7+ 正常显示，5-6 带 caveat，<5 压制
- **衰减：** 观察到的模式每 30 天衰减 1 分，用户声明的偏好永不衰减
- **管理：** `/learn` (review), `/learn search <keyword>`, `/learn prune`, `/learn export`, `/learn stats`
- **跨项目：** 可搜索其他项目的 learnings（opt-in，一次性同意，本地）

### Layer 3：个人记忆

- **写入时机：** `/lessons-learned`
- **存储位置：** `~/.claude/memory/`
- **消费者：** 所有未来会话（跨项目、跨工具）
- **特点：** 个人级，不与团队共享

### 知识闭环

```
解决问题 → /ce:compound → docs/solutions/ → 未来 ce:plan/ce:review 自动发现
                                                ↑
gstack 观察模式 → learnings.jsonl → 未来 gstack review 自动标注
                                                ↑
学到非显而易见的东西 → /lessons-learned → 所有未来会话
```

---

## 九、高级技巧

### 1. 给 ce:review 传 plan 路径
```
/ce:review plan:docs/plans/2026-03-29-001-feature-plan.md
```
启用需求完整性验证——审查检查每个 R1/R2/R3 是否在 diff 中体现。

### 2. gstack 置信度校准（v0.13.4+）
- 7+：正常显示
- 5-6：带 "medium confidence" 标注
- <5：压制（不 cry wolf）
- 匹配历史 learning 时显示来源和日期

### 3. ce:work 的 Swarm Mode
10+ 任务需要 agent 间持续通信时使用 Agent Teams。需手动 opt-in：
```
/ce:work（然后选 swarm 策略）
```

### 4. 全自动流水线
```
/lfg    — plan → work → review → todo-resolve → test-browser → feature-video
/slfg   — 同上但 ce:work 用 swarm + review/test 并行
```

### 5. Freeze + Investigate 联动
`/investigate` 自动激活 freeze boundary，调试期间 Edit/Write 被锁定在受影响目录。

### 6. QA 回归模式
```
/qa <url> --regression <baseline>
```
对比上次 QA 报告：哪些问题修了？哪些是新的？健康分数变化？

### 7. 性能趋势分析
```
/benchmark --trend
```
跨 5 次 benchmark 的历史趋势，捕捉 "LCP 8 天翻倍" 或 "JS bundle 每周增长 50KB"。

### 8. /cso 组合用法
```
/cso --infra --diff    — 仅基础设施变更的安全审计
/cso --skills          — 扫描已安装 skills 是否有恶意模式（curl, API key 窃取, prompt injection）
```

### 9. /codex 推理强度覆盖
```
/codex review --xhigh    — 最大推理强度
```

### 10. /learn 跨项目搜索
```
/learn search auth       — 搜索当前项目的 auth 相关 learnings
```
首次跨项目搜索时需一次性同意（本地，不上传）。

---

## 十、常见陷阱

1. **跳过 /office-hours 做产品功能** — 设计文档流向 autoplan、review、design-consultation。缺了它下游 skills 缺乏产品上下文。

2. **ce:review 不传 plan 路径** — 失去需求完整性验证，审查无法检查计划的功能是否全部实现。

3. **用 CE 的 git-commit-push-pr 代替 /ship** — /ship 有 VERSION/CHANGELOG/test bootstrap/Review Readiness Dashboard/Test Failure Ownership Triage。

4. **先跑 /codex review 再跑 /ce:review** — 反过来。先 CE 再 codex，codex 才能自动对比。

5. **忘记三层知识** — ce:compound（项目文档）+ gstack 自动学习（自动）+ /lessons-learned（个人记忆）。Layer 2 自动但需定期 `/learn prune`。

6. **部署前不捕基线** — `/benchmark --baseline` + `/canary --baseline` 必须在部署前跑。

7. **日常用 /cso --comprehensive** — 日常 = 8/10 置信度（零噪声）。--comprehensive 留给月度深扫。

8. **覆盖 CE review 的 Haiku 选择** — CE 故意用便宜模型跑 reviewer agents。CLAUDE.md 已正确豁免。

---

## 十一、速查卡

| 需要 | 命令 |
|------|------|
| 验证想法 | `/office-hours` |
| 探索需求 | `/ce:brainstorm` |
| 写计划 | `/ce:plan` |
| 评审计划（自动） | `/autoplan` |
| 执行计划 | `/ce:work` |
| 代码审查（广度） | `/ce:review` |
| 代码审查（跨模型） | `/codex review` |
| 代码审查（对抗） | `/codex challenge` |
| 发 PR | `/ship` |
| 部署 + 验证 | `/land-and-deploy` |
| 沉淀项目知识 | `/ce:compound` |
| 保存个人记忆 | `/lessons-learned` |
| 管理项目 learnings | `/learn` |
| 搜索历史模式 | `/learn search <keyword>` |
| 修剪过期 learnings | `/learn prune` |
| 系统化调试 | `/investigate` |
| 安全审计 | `/cso` |
| QA + 修 bug | `/qa <url>` |
| 视觉 QA + 修 | `/design-review <url>` |
| 性能基线 | `/benchmark <url> --baseline` |
| 部署后监控 | `/canary <url>` |
| 设计系统 | `/design-consultation` |
| 周回顾 | `/retro` |
| 跨项目回顾 | `/retro global` |
| PR 反馈处理 | `/resolve-pr-feedback` |
| Bug 复现 | `/reproduce-bug` |
| 代码库新人文档 | `/onboarding` |
| 全自动流水线 | `/lfg` 或 `/slfg` |
| 扫描 skills 安全 | `/cso --skills` |

---

## 十二、文件位置索引

| 文件 | 路径 | 用途 |
|------|------|------|
| 全局 CLAUDE.md | `~/.claude/CLAUDE.md` | Claude Code 全局配置 |
| 项目 CLAUDE.md | `~/CLAUDE.md` | 项目级覆盖（浏览器规则、环境） |
| settings.json | `~/.claude/settings.json` | Hooks、插件、权限配置 |
| Playbook | `~/.claude/ce-gstack-playbook.md` | CE+gstack 协同参考 |
| block-no-verify hook | `~/.claude/hooks/block-no-verify.sh` | 阻止绕过 git hooks |
| config-protection hook | `~/.claude/hooks/config-protection.sh` | 保护 linter 配置 |
| desktop-notify hook | `~/.claude/hooks/desktop-notify.sh` | macOS 完成通知 |
| CE 插件 | `~/.claude/plugins/marketplaces/compound-engineering-plugin/` | CE 源码 |
| gstack skills | `~/gstack/` (symlink `~/.claude/skills/gstack/`) | gstack 源码 |
| 自动记忆 | `~/.claude/projects/-Users-charlesqin/memory/` | 持久化记忆 |
| gstack 项目数据 | `~/.gstack/projects/{slug}/` | 设计文档、review 日志、learnings |
| CE 项目文档 | `docs/brainstorms/`, `docs/plans/`, `docs/solutions/` | 需求、计划、知识沉淀 |
