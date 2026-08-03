# 高收益架构重构方案

- 状态：主要迁移完成，持续优化
- 适用范围：黑风谷场景、Go 模拟内核、应用层与 Godot 客户端
- 目标阶段：在继续扩写人物和故事线之前，建立可持续的内容生产架构

## 当前实施进度

截至 2026-08-03，高收益改造已经完成以下可运行切片：

- 内容加载支持版本化 YAML、严格字段检查、跨文件引用校验、清单与内容指纹；
- 黑风谷静态内容和默认玩家已迁移为 YAML 作者源；
- 存档已绑定当前格式版本与内容指纹，版本或内容哈希不同会被明确拒绝；
- 青岚路线从日期核实、中期分支到后期兑现的完整行动链已迁入故事内容，路线进度由同一份内容规则投影；
- 苏晚照换丹与亲自入谷路线恢复已迁入第二条故事弧，行动目录不再为该流程注册专属行动；
- 青岚路线的结局后果由 `arc state + 通用条件` 内容规则投影，动态关系值通过受校验的占位声明读取；
- 故事选择的即时消息、日志条目与演出提示由内容定义并统一投影，不再依赖行动 ID 推测表现；
- 可观察人物、公开目标、策略显示名和 Flag 玩家文案均由 NPC/Flag 内容配置提供，`actor_plans.go` 不再注册场景 ID；
- 效果类型改为受限类型，角色与世界 Flag 通过注册表声明，未知效果和未声明 Flag 会在加载阶段失败；
- 条件类型也已收敛为受限枚举，并校验字段组合、引用目标和 Flag 作用域；
- 竞争结算的场景专属结果和奖励已移出通用 Engine；
- 内容 Schema 已升级到 v6，加载器只接受当前版本并在启动前完成严格校验；
- API v1 响应契约可生成并验证，Godot 通过独立适配器严格校验版本、错误与 PlayerView 必需字段；
- Godot 的本地服务进程启动、关闭和兜底终止已从 `main.gd` 抽取为独立节点；
- Godot 人物、地点资源及地图标记已集中到表现清单，地图和注册表不再维护人物/地点 ID 分支；
- Godot 的 HTTP 客户端、设置存储、ViewModel 和诊断导出已从 `main.gd` 拆出；
- Go 验证与 Godot 端到端验证保持通过。

本轮列出的六项高收益迁移已经完成。后续剩余工作以次级结构优化为主：拆分 `main.gd` 中仍然集中的日志与主要 UI 面板；把音频、场景舞台等仍以主题键分派的资源也并入统一表现清单；为 Godot 表现清单增加构建期静态校验；继续清理应用层少量场景专属引导文案。它们不再阻塞通过 YAML 调整现有主线、选择、反馈和结局。

## 1. 背景

项目已经具备数据驱动基础：场景、人物、事实、地点、物品和基础行动最初分别存放在 `data/blackwind/*.json`，由 `internal/scenario` 加载、校验并转换为 `domain.Bundle`。重构实施后，正式作者源将迁移为版本化 YAML。模拟内核负责确定性的时间推进、NPC 决策、移动、市场、交易和竞争；Godot 只消费应用层提供的玩家可见视图。

当前主要瓶颈不是底层规则不足，而是场景专属内容仍分散在多个程序层：

- `internal/app/catalog.go` 同时包含通用行动目录和青岚路线的专属选择、文案、条件与效果；
- `internal/app/route_progress.go` 再次用标记组合解释同一条路线的阶段、期限和下一步；
- `internal/app/feedback.go` 单独维护路线后果、结局总结与人物反馈；
- `internal/engine/engine.go` 包含针对黑风谷人物和标记的特殊胜利文案与奖励；
- `godot/scripts/main.gd` 同时承担进程、网络、设置、日志、界面构建、状态选择、渲染和演出调度；
- Godot 的人物及地点资源仍有少量按具体 ID 注册或分支处理的逻辑。

这使一条剧情变更可能需要同时修改内容文件、Go 应用层、Go 引擎和 Godot。随着场景数量增长，重复表达会增加遗漏、行为漂移和回归成本。

## 2. 重构目标

本轮重构追求以下结果：

1. 人物、故事线、选择、文案、结局和表现映射可主要通过内容文件调整；
2. 同一条故事线只有一个权威定义，行动、进度、提醒、反馈和结局由它派生；
3. 内容错误在启动或构建阶段失败，而不是在玩家进入特定分支后才暴露；
4. 通用引擎不再认识 `N03`、`qinglan_*` 或“青髓芝”等具体场景概念；
5. 修改内容后仍能判断旧存档是否可以安全回放；
6. Godot 客户端的网络、状态和 UI 组件具有清晰边界；
7. 新增一个人物或故事线时，不需要在多个程序文件中登记相同信息。

## 3. 非目标

本轮不计划：

- 将模拟规则全部迁入 YAML 或引入可执行脚本；
- 让 Godot 复制并执行后端剧情规则；
- 引入 ECS、数据库或分布式多 Session 架构；
- 为拆文件而机械拆分 `domain/types.go`；
- 重写已经稳定的移动、市场、关系、情报和竞争算法；
- 在重构期间同时大规模扩写新场景内容。

原则是：内容文件描述“发生什么”，Go 代码保证“如何可靠执行”。

## 4. 目标架构

```text
content/<scenario>/
  manifest.yml
  scenario.yml
  player.yml
  characters/*.yml
  world/*.yml
  arcs/*.yml
  presentation.yml
  dialogue.yml
          │
          ▼
内容编译器
  严格解析 → 规范化 → 引用校验 → 图校验 → 内容指纹
          │
          ▼
CompiledContent
  domain.Bundle + StoryGraph + PresentationManifest
          │
          ├──────────────┐
          ▼              ▼
通用 Engine         Story Runtime
规则与结算          节点、选择、路线状态
          └──────┬───────┘
                 ▼
            App Projections
  PlayerView / 反馈 / 路线进度 / 结局 / 演出提示
                 ▼
       API Contract + Godot ViewModel
                 ▼
              UI 组件
```

运行时继续保持单向权威链：Godot 只提交后端返回的行动 ID，不自行判断行动合法性，也不读取隐藏世界状态。

## 5. 工作流一：内容模型与剧情状态机

### 5.1 目标

将现有 JSON 内容和程序中的场景专属逻辑整理为版本化 YAML 内容包，并用剧情状态机或故事图表达主线与支线。

故事线不是固定章节序列，而是由条件驱动的有向图。每条 `arc` 至少包含：

- 稳定 ID、标题与可选说明；
- 状态或节点；
- 开放条件与时间窗口；
- 玩家选择及其公开语义；
- 结算效果；
- 状态转换；
- 期限、进度提示和错过后的状态；
- 结局或余波规则；
- 可选表现提示。

示意结构：

```yaml
schema_version: 1

id: qinglan_intel
title: 青岚情报路线
initial_state: undiscovered

states:
  - id: date_verified
    actions:
      - id: deliver_to_shen
        window: { from_day: 1, to_day: 9 }
        when:
          - belief: { fact: F01, min_confidence: 3 }
          - colocated: { actor: N03 }
        choices:
          - id: trust
            title: 无偿告知沈砚秋
            effects:
              - relation: { from: N03, to: player, trust: 2 }
              - set_flag: { flag: qinglan.trust_route, value: true }
            transition_to: review_pending

  - id: review_pending
    deadline_day: 12
    progress:
      status: 等待宗门审核
      next_step: 第 10 日起回到青岚门驻地回应质疑
    actions:
      - id: vouch
        window: { from_day: 10, to_day: 12 }
        effects:
          - set_flag: { flag: qinglan.trust_vouched, value: true }
        transition_to: vouched
```

### 5.2 内容目录建议

```text
content/blackwind/
  manifest.yml
  scenario.yml
  player.yml
  characters/
    n01-li-changye.yml
    n02-chen-qingshan.yml
    n03-shen-yanqiu.yml
  world/
    facts.yml
    items.yml
    locations.yml
    markets.yml
  arcs/
    qinglan-intel.yml
    chen-family.yml
    blackwater-ambush.yml
    final-contest.yml
  presentation.yml
```

文件可以拆分，但 ID 必须在整个内容包内保持稳定且唯一。文件名只服务于作者，不作为运行时引用。

### 5.3 单一事实来源

剧情状态机应同时驱动：

- 当前可用行动；
- 路线状态和下一步；
- 即将错过的期限提醒；
- 行动确认信息；
- 玩家后果和结局余波；
- 演出提示。

不再分别根据一组 `qinglan_*` 标记手写五份判断。底层 Flag 可以继续存在，但路线的公开阶段应由明确的 `arc_id + state_id` 表达。

### 5.4 完成标准

- [x] YAML 内容包可完整加载当前黑风谷场景；
- [x] 当前 JSON 内容迁移后，T00～T07 的权威结果保持一致；
- [x] 青岚情报路线不再由 `catalog.go` 和 `route_progress.go` 分别维护；
- [x] 新增一个路线选择不需要修改 Go 代码；
- [ ] 通用引擎中不存在黑风谷人物 ID、专属 Flag 或专属文案；
- [x] 同一剧情状态能够派生行动、进度、提醒和结局信息。

## 6. 工作流二：类型化条件、效果与状态注册表

### 6.1 问题

当前 `Condition` 和 `Effect` 依靠 `type` 字符串与一组通用可选字段表达不同语义。世界和角色状态也通过自由字符串 Flag 关联。该方案原型期灵活，但内容规模扩大后存在以下风险：

- Flag 或类型拼写错误；
- 效果携带无意义或相互冲突的字段；
- 世界 Flag 与角色 Flag 作用域混用；
- 删除内容时遗留无法发现的引用；
- 编辑器和自动补全无法判断每种规则需要哪些字段。

### 6.2 目标模型

内容语法采用带标签的类型结构：

```yaml
when:
  - day_range: { from: 10, to: 12 }
  - at_location: { actor: player, location: L02 }
  - flag_is: { flag: qinglan.review_open, value: true }
  - belief: { actor: player, fact: F01, min_confidence: 3 }

effects:
  - adjust_relation: { from: N03, to: player, trust: 1 }
  - transfer_item: { item: antidote, from: N03, to: player, amount: 1 }
  - set_flag: { flag: qinglan.trust_vouched, value: true }
```

内容包显式声明状态键：

```yaml
flags:
  qinglan.review_open:
    scope: world
    type: boolean
    default: false

  qinglan.trust_vouched:
    scope: player
    type: boolean
    default: false
```

Flag 使用命名空间，避免不同故事线互相污染。人物、地点、事实、物品、行动、故事线和状态都使用独立 ID 类型或至少在校验阶段区分引用类别。

### 6.3 Go 端实现原则

- 规则能力由代码注册，内容只能选择已注册能力；
- 每种条件和效果拥有独立解析、校验和执行器；
- 不允许 YAML 执行任意表达式、函数或 Go 代码；
- 未知字段、重复键、未知类型和错误作用域必须直接失败；
- 所有效果继续经过现有原子结算、成本、合法性和回滚机制；
- 状态转换与效果提交属于同一事务，不能出现效果成功但路线状态未推进。

### 6.4 完成标准

- [x] 所有条件、效果和 Flag 在加载阶段完成类型及作用域校验；
- [x] 未知字段和重复 YAML 键会导致加载失败；
- [ ] 未声明 Flag、未知引用和无效字段组合具有文件及行号错误；
- [x] 当前引擎支持的规则均有处理器和单元测试；
- [x] 内容层无法绕开资源检查、路线检查、唯一物品和状态不变量。

## 7. 工作流三：内容编译器、验证与内容测试

### 7.1 目标

把 YAML 定位为作者源文件，不让运行时直接承担所有内容错误发现工作。新增独立内容编译流程：

```text
解析 YAML
  → 严格字段校验
  → ID 与引用解析
  → 默认值规范化
  → 剧情图和时间窗口校验
  → 生成规范化内容
  → 计算内容指纹
```

建议提供命令：

```powershell
fantu-content validate content/blackwind
fantu-content build content/blackwind
fantu-content graph content/blackwind
fantu-content simulate content/blackwind --runs 200
```

### 7.2 静态校验

至少覆盖：

- 重复 ID、未知引用、未使用声明；
- 未声明 Flag 和作用域不匹配；
- 不可达节点和没有出口的非终态节点；
- 路线状态转换指向不存在的状态；
- 时间窗口超出场景范围或前后矛盾；
- 必然互斥的条件同时出现；
- 互斥选择缺少共同关闭条件；
- 结局规则重叠但没有优先级；
- 唯一物品来源、市场库存、路线和地点不合法；
- 文案引用缺失；
- 表现资源路径缺失；
- 稳定行动 ID 被无迁移声明地删除。

### 7.3 内容验收测试

把现有 `testdata/T01...T07` 扩展为面向故事线的验收用例：

```yaml
id: qinglan_trust_route
given:
  player:
    location: L02
    beliefs:
      F01: { confidence: 3 }

steps:
  - choose: qinglan_intel.deliver_to_shen.trust
  - advance_to: 10
  - choose: qinglan_intel.review.vouch

expect:
  arc_state: { qinglan_intel: vouched }
  flags: { qinglan.trust_vouched: true }
  relation:
    N03: { trust_at_least: 1 }
```

测试分三层：

1. Schema 测试：单个条件、效果和引用是否合法；
2. 路线测试：指定选择序列是否到达预期状态；
3. 模拟测试：批量运行后的结局分布、空闲率和内容覆盖是否异常。

### 7.4 完成标准

- [ ] `tools/verify.ps1` 包含内容校验；
- [ ] 所有故事节点和效果类型进入覆盖报告；
- [ ] 可以生成完整剧情图；
- [ ] 无法到达的内容默认阻断构建；
- [ ] 内容变更能明确列出受影响的验收路线；
- [ ] 当前批量模拟基线可与重构后结果自动比较。

## 8. 工作流四：内容版本、存档边界与确定性

### 8.1 问题

当前存档通过初始玩家和行动历史进行确定性回放。内容数据化后，即使行动历史不变，修改策略、效果、日期、路线或竞争参数也可能产生不同世界状态。

因此不能只维护 `save_version`，还必须识别生成该存档的内容版本。

### 8.2 版本信息

每个编译内容包生成：

```yaml
scenario_id: blackwind
schema_version: 6
content_version: 1.0.0
content_hash: sha256:...
```

存档至少记录：

- 存档格式版本；
- 场景 ID；
- 内容版本与内容哈希；
- 初始玩家配置；
- 稳定行动历史；
- 必要时记录编译内容快照或内容包定位信息。

### 8.3 加载策略

| 情况 | 行为 |
| --- | --- |
| 内容哈希一致 | 正常确定性回放 |
| 存档格式版本不同 | 拒绝加载，明确报告期望版本 |
| 内容哈希不同 | 拒绝加载，禁止在不同规则上重放 |
| 内容 Schema 版本不同 | 拒绝加载，由作者在仓库外升级内容包 |

新游戏创建时固定一份 `CompiledContent`。开发期热重载只影响之后创建的新 Session，不修改正在运行的世界。

### 8.4 内容 Schema 边界

运行时和仓库工具只接受当前 Schema，不维护逐版本兼容链，也不会生成默认故事文案。作者完成显式升级后必须运行：

```powershell
go run ./cmd/fantu-content validate data/blackwind
go run ./cmd/fantu-content test data/blackwind
```

低于或高于当前 Schema 的内容都会被拒绝。存档同样只接受当前格式版本和完全一致的内容哈希。

### 8.5 完成标准

- [x] 存档包含内容版本和规则内容哈希；
- [ ] 文案变化与规则变化使用不同指纹或变更分类；
- [x] 不兼容内容不会被静默重放；
- [x] 不提供行动 ID、Flag ID 和状态 ID 的隐式迁移；
- [x] 非当前格式存档具有拒绝回归测试；
- [x] 同一内容哈希和行动历史始终产生相同结果。

## 9. 工作流五：应用投影、API 契约与 Godot 拆分

### 9.1 统一应用投影

引擎和故事运行时只产生权威状态与事件。应用层根据玩家可见性生成不同投影：

```text
WorldEvent / ArcTransition
  ├─ AvailableActions
  ├─ RouteProgress
  ├─ TurnFeedback
  ├─ CausalThreads
  ├─ EndingSummary
  └─ PresentationCue
```

这些投影共享同一故事定义和事件来源，不再各自重新猜测 Flag 组合。隐藏认知、内部评分和未公开事件继续由应用层过滤。

### 9.2 API 契约

为 `/api/v1` 的请求、响应和关键枚举生成或维护版本化 JSON Schema：

- 服务端测试校验真实响应符合 Schema；
- Godot 只通过一个 `PlayerViewAdapter` 读取动态 JSON；
- Adapter 负责 API 版本检查与严格类型校验；
- UI 组件不直接散布读取原始 `Dictionary` 的字段名；
- `action.kind`、`category`、`presentation.type` 等枚举集中定义。

### 9.3 Godot 职责拆分

建议从 `main.gd` 拆出以下边界：

```text
app/
  app_controller.gd
  game_client.gd
  server_process.gd
  settings_store.gd
  diagnostics.gd

state/
  player_view_adapter.gd
  game_view_model.gd
  selection_state.gd

screens/
  start_screen.gd
  game_screen.gd
  ending_screen.gd
  settings_screen.gd

panels/
  journal_panel.gd
  action_panel.gd
  actor_panel.gd
  clue_panel.gd
  travel_panel.gd
```

拆分顺序以行为边界为准，不要求一次性移动全部代码。优先抽取独立性最高的进程管理、HTTP、设置、日志和响应适配，再拆屏幕与面板。

### 9.4 表现资源清单

`presentation.yml` 统一声明人物和地点的表现资源：

```yaml
characters:
  N03:
    profile: res://assets/characters/N03/profile.tres
    map_token:
      color: "#8ca7a0"
      offset: [-8, -12]

locations:
  L02:
    profile: res://assets/locations/qinglan/profile.tres
    ambient: qinglan_camp
```

Godot 保留资源加载、动画和 fallback 逻辑，但不再为每个新人物手写注册项或 ID 分支。

### 9.5 AI 对话配置

`dialogue.yml` 声明当前场景的世界语境、玩家称呼和语言风格：

```yaml
context: 灾变后的京师正在争夺证据及其解释权
player_address: 先生
style: 克制、清晰的历史调查叙事口吻，不使用仙侠称谓
```

事实白名单、私密状态隔离、AI 不参与规则结算及结构化输出约束仍由引擎维护。场景作者可以改变叙事题材和措辞，但不能通过内容配置绕过规则安全边界。当前 Schema v6 将 `dialogue.yml` 纳入内容指纹，旧 Schema 不在运行时迁移。

### 9.6 完成标准

- [x] 场景专属结果不再写在通用 Engine 中；
- [x] 路线进度、反馈和结局可追溯到同一个状态转换事件；
- [x] API 响应具有自动契约测试；
- [x] Godot 只有适配层直接读取原始响应字典；
- [ ] `main.gd` 不再负责 HTTP、日志、设置和全部 UI 渲染；
- [x] 新人物和新地点的正式资源可以通过清单接入；
- [x] 缺失表现资源时仍能使用稳定 fallback。

## 10. 推荐实施顺序

### 阶段 A：建立护栏

1. 固化当前 T00～T07、批量模拟指标和关键 API 响应作为基线；
2. 定义内容 `schema_version`、稳定 ID 规则和内容变更分类；
3. 建立 YAML 严格加载、内容指纹和最小 Schema 校验；
4. 给现有存档增加内容版本字段，但暂不改变回放行为。

### 阶段 B：迁移静态内容

1. JSON 与 YAML 双加载；
2. 迁移场景、人物、事实、地点、物品、市场和默认玩家；
3. 引入 Flag 注册表和命名空间；
4. 保持生成的 `domain.Bundle` 与当前行为一致；
5. 当全部测试通过后，停止把 JSON 作为正式作者源。

### 阶段 C：迁移一条垂直故事线

以青岚情报路线作为首个完整样板：

1. 建立 `StoryArc`、状态转换和通用行动生成器；
2. 迁移交付情报、公开审核、借丹/独行、同行集结和后期兑现；
3. 让路线进度、提醒、反馈和结局从同一状态机派生；
4. 删除对应的应用层专属分支；
5. 使用现有测试和新增路线验收证明等价。

完成这一阶段后再决定其余故事线的最终 Schema，避免先设计一个未经真实内容验证的过度通用模型。

### 阶段 D：净化通用引擎

1. 把特殊胜利文案和奖励迁入场景结局规则；
2. 让 Engine 只输出通用竞争结果和事件；
3. 建立事件到玩家反馈、因果线和结局的统一投影；
4. 扫描生产代码，确保通用包不再引用场景专属 ID。

### 阶段 E：客户端边界

1. 建立 API Schema 和 `PlayerViewAdapter`；
2. 从 `main.gd` 抽取 HTTP、服务进程、设置和诊断；
3. 拆分 GameViewModel、选择状态和主要面板；
4. 接入表现资源清单；
5. 保持现有截图、诊断和集成测试通过。

## 11. 风险与控制

### Schema 过度设计

风险：为了支持未来所有故事类型，提前造出复杂脚本语言。

控制：以青岚路线为首个垂直样板；只有第二个真实用例出现后才抽象新能力。YAML 不允许任意表达式。

### 一次性迁移范围过大

风险：数据格式、剧情行为、存档和 UI 同时变化，无法定位回归。

控制：JSON/YAML 短期双加载；每次只迁移一个内容类别或一条故事线；每阶段都保持可运行。

### 内容与运行时行为不等价

风险：字段迁移成功，但时间边界、结算顺序或失败策略变化。

控制：保留现有行动计划、事件序列和最终状态快照；比较的不只是结局归属，还包括关键事件日、资源、认知和关系。

### 存档静默漂移

风险：旧存档可以打开，却得到不同结果。

控制：规则内容指纹与严格版本门禁；禁止跨格式或跨规则哈希回放。

### 客户端拆分造成视觉回归

风险：移动代码时改变节点生命周期、信号绑定或状态恢复。

控制：先抽取无 UI 的服务，再拆视觉组件；保留现有 Godot 集成、诊断与截图审查入口。

## 12. 总体验收标准

本轮高收益重构完成时，应满足：

- [x] 黑风谷正式内容以版本化 YAML 为唯一作者源；
- [x] 至少一条完整主线由通用故事状态机运行；
- [x] 新增普通人物、地点、事实、物品和剧情选择无需修改 Go/Godot 注册代码；
- [ ] 通用 Engine、Server 和基础 UI 不包含黑风谷专属人物或剧情 Flag；
- [ ] 所有内容引用、状态转换、时间窗口和表现资源可静态校验；
- [x] 存档可以识别内容兼容性，确定性回放具有自动测试；
- [x] API 契约变化能在 CI 中发现；
- [ ] Godot `main.gd` 收敛为应用编排入口，而不是所有功能的实现位置；
- [x] T00～T07、批量模拟、Go 测试和 Godot 集成测试全部通过；
- [x] 修改一条路线的条件、收益、文案和截止日期时，只需要修改对应内容包及其验收用例。

## 13. 建议的首个交付切片

第一批不要直接迁移全部内容，建议交付一个可验证的垂直切片：

1. `content/blackwind/manifest.yml` 与 `schema_version`；
2. YAML 严格加载器、内容指纹和 `validate` 命令；
3. Flag 注册表；
4. 青岚情报路线中“核实日期 → 向沈砚秋提出三种条件 → 进入后续状态”这一段；
5. 由该状态同时生成行动、路线进度和玩家反馈；
6. 对应的内容验收测试与旧实现等价测试；
7. 暂时保留其余 JSON 和旧路线分支。

这个切片能够最早验证三个关键假设：YAML 是否好编辑、状态机是否足以表达真实剧情、单一事实来源是否确实减少应用层重复。验证通过后，再迁移其余路线和客户端表现层。
