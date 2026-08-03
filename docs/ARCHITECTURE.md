# 凡途模拟内核架构

## 1. 当前边界

仓库采用单 Go module、多个内部包的结构。Go 模拟内核是世界状态与规则的唯一权威来源；场景 YAML 只描述数据，不承载隐式逻辑。

```text
cmd/                 可执行程序入口
  sim/               单场景运行与状态报告
  batch/             固定验收和参数扫描
  play/              玩家视角的交互式终端客户端
  server/            Godot 使用的本机 HTTP 服务入口
  schema/            生成版本化 API JSON Schema
internal/
  app/               Session、玩家视图、行动目录和存档回放
  server/            /api/v1 协议、存档槽与并发边界
  domain/            领域数据、状态和跨包协议
  engine/            逐日决策、行动与事务结算
  scenario/          YAML/JSON 严格加载、内容版本与静态校验
  batch/             批量运行、扰动和统计
  report/            单次运行报告适配器
data/blackwind/      黑风谷正式 YAML 内容包（含人物、世界与剧情线）
api/                  Godot 与服务端共享的版本化 JSON 契约
godot/               只消费 PlayerView 的 2D 场景化桌面客户端
testdata/            Go 工具自动忽略的验收玩家计划
docs/                产品、架构、规格和验收文档
tools/               本地开发与持续集成脚本
output/              可重新生成的报告，不进入 Git
```

## 2. 依赖方向

允许的主要依赖方向为：

```text
cmd ───────> app / scenario / engine / batch / report
server ────> app / domain
app ───────> engine / domain
batch ─────> scenario / engine / domain
report ────> domain
scenario ──> domain
engine ────> domain
domain ────> 标准库
```

规则：

- `domain` 不依赖其他项目包，避免领域协议被基础设施反向控制。
- `engine` 不读取文件、不解析命令行、不写报告，只处理已经校验的 `domain.Bundle` 和命令。
- `scenario` 负责输入边界；无效引用、枚举、市场、路线和策略配置必须在这里失败。
- 剧情线由内容包中的 `arcs.yml` 声明；应用层把当前剧情状态投影成玩家行动，引擎只原子提交通用效果与状态转换。
- `report` 与 `batch` 只读取引擎快照，不修改世界状态。
- `app` 将完整世界状态裁剪成玩家可见视图，并把动态行动 ID 转译为玩家命令；它不直接修改 `WorldState`。
- `server` 只管理单个 Session、请求校验和命名存档槽；它不解释动作 ID，也不暴露任意文件路径。
- `cmd` 只做参数解析、依赖组装和错误输出，不放业务规则。

## 3. 引擎生命周期

单日推进顺序保持稳定：

1. 开始阶段固定事件；
2. 到期情报送达；
3. 世界导演从场景声明的受限指令中选择最多一项，经权威效果管线生成审计事件；
4. 基于更新后的统一日初快照生成 NPC 与玩家意图；
5. 原子预留成本并启动行动；
6. 按阶段完成到期行动并结算稀缺资源冲突；
7. 结束阶段固定事件与核心争夺；
8. 债务到期处理；
9. 全量状态不变量校验；
10. 返回不可修改内部状态的深拷贝快照。

任何步骤返回错误时，`Step` 回滚到日初状态及事件 ID 计数器。

## 4. 领域模型组织原则

`internal/domain` 是跨包契约，不包含决策算法。模型按用途分为：

- 场景定义：事实、角色配置、策略、条件、效果、地图、市场、`rules.yml` 世界规则和世界导演指令；
- 运行状态：玩家、NPC、物品、认知、关系、计划、债务、联盟、协议和导演冷却；
- 审计协议：意图、PendingAction、事件、NPC 决策、导演决策与反事实记录。

确定性世界导演位于 `internal/director`。它只读取 `WorldState` 快照，根据阶段切换、公开局势沉寂天数、市场库存和地点聚集人数等结构化信号，从 `Scenario.directives` 中稳定选择一项。导演包不修改状态；`internal/engine` 负责将指令展开为 `WorldEvent`、应用效果并写入 `DirectorDecision`。当前指令效果白名单仅允许世界级 flag 与 opportunity，明确禁止直接修改角色资源、关系、物品、行动或结局。`Scenario.opportunity_actions` 可将打开的机会映射为普通 `PlayerCommand`，因此机会的消耗和收益仍经过完整条件、结算与回放管线。详见 [世界导演系统](WORLD_DIRECTOR.md)。

NPC 的通用兜底策略、调查策略和导航资格，以及玩家恢复行动、风险阈值和经济结算资源，都由每个内容包的 `rules.yml` 声明。Go 引擎只保留条件求值、评分、寻路、动态市场报价与事务结算算法，不包含具体故事的物品、资源、事实 ID 或文案。详见 [世界规则内容层](WORLD_RULES.md)。

当前模型仍集中在一个文件中，以减少早期协议频繁变化时的跨文件跳转。进入稳定 API 阶段后，可在不改变 `domain` 包路径的前提下按上述三类机械拆分。

## 5. 应用层与客户端边界

M1 应用层位于 `internal/app`，负责 Session、玩家可见视图、动态行动目录、存档和回放。玩家视图明确排除事实真值、NPC 私有认知、策略评分、内部因果 ID 和世界标记。

交互式 CLI 已通过 `cmd/play` 接入应用层。存档采用“初始玩家 + 行动历史”的版本化格式，加载时通过权威引擎确定性回放，因此不会把内部状态结构固化成外部协议。

Godot 本地服务由 `cmd/server` 和 `internal/server` 提供，协议固定在 `/api/v1`。服务仅监听回环地址，通过互斥锁串行修改单个 Session；Godot 只渲染 `PlayerView` 并提交服务端给出的动作 ID，不复制行动合法性、视图过滤或结算规则。`api/v1-response.schema.json` 由服务端 Go 响应类型生成；契约测试会阻止未同步 Schema 的字段变更，Godot 应只在响应适配层读取原始 JSON 字典。

Godot 客户端按如下单向数据流工作：

```text
Godot 控件 ──动作 ID──> /api/v1 ──> app.Session ──> engine
Godot 地图/场景/行动视图 <── PlayerView <─────────┘
```

可选 AI 对话是这条权威链路旁边的非权威表现支路：`internal/app` 先从当前 Session 构造不可变的 `DialogueSnapshot`，仅包含同地人物的公开资料、玩家已经获知或亲自告知的说法、抽象化动机、公开事件与当前可见交涉；`internal/ai` 再通过 Anthropic 官方 Go SDK 请求受 JSON Schema 约束的多轮回应。每次最多注入同一局势 revision 下最近 8 轮历史，模型只能建议当前公开行动，不能执行行动。对话记录随存档保存，但不参与世界回放和规则结算。服务不会把 `WorldState`、事实真值、秘密认知、策略评分或内部标记交给模型。模型调用不持有 Session 锁，返回时若局势 revision 已变化则丢弃旧结果；取消、超时、网络错误、越权事实或行动引用、空响应及格式错误都会作为失败返回，不生成替代台词。

`cmd/play` 与 `cmd/server` 通过 `internal/aiconfig` 共享 `.env` 加载、模型参数和 provider 构建。终端的 `talk` 命令直接读取同一个 Session 的脱敏快照，不经过本地 HTTP；Godot 则通过独立 HTTP 通道访问。两条路径最终复用同一个 `internal/ai.Service`，并遵守相同的结构化输出校验和显式错误规则。未启用模型时 provider 不会被构造，对话能力明确标记为不可用。

CLI 将终端读取和模型生成拆为两个并发事件源。当模型请求处于 pending 状态时，主循环同时处理返回结果、等待进度和玩家命令：`context` 只读取语境，`cancel` 取消 context 并清空尚未执行的排队输入，`retry` 在 revision 未变时重提原快照，`await` 暂停读取后续管道命令。取消后到达的旧结果没有可写入路径，不会记录为对话或触发自动存档。

Godot 的模型设置写入用户运行目录中的独立 `ai-settings.json`；密钥不会进入进程参数或日志，该配置文件也不会被纳入诊断包。打包服务启动时读取该文件，运行期间则通过回环地址上的 `PUT /api/v1/settings/ai` 原子替换对话服务，因此切换或关闭模型不会销毁 Session。响应只返回启用状态和模式，不回传密钥。

```text
app.Session ──脱敏快照 + 会话历史──> internal/ai ──> Anthropic Messages API
     │                                  │
     ├──权威规则与行动回放               └──结构化 Dialogue + 受限行动建议──> CLI / Godot
     └──持久化非权威对话记录
```

结构化输出使用官方 SDK 的稳定 `OutputConfig` 和 JSON Schema，响应解码使用 Go 标准库 `encoding/json`，并在应用侧再次校验枚举、长度和 `referenced_fact_ids` 白名单。Godot 为对话使用独立 `HTTPRequest`，不会占用动作、存档和读取视图的请求通道。

人物公开资料和动作语义元数据都由应用层生成。每个可见行动将已满足条件、仍未知项、不可逆性、公开代价和预期结果分开返回；Godot 只负责按层级展示。Godot 可折叠“人物 × 线索”组合，但不会自行决定哪些组合合法。所有写操作在服务端串行完成，行动成功后客户端再发起自动存档。

`PlayerView.preparation` 只汇总玩家自己的争夺准备来源与公开条件，用于在结算前解释“战力、助力、行装和位置”分别处于什么状态；它不返回 NPC 分数、胜率或隐藏策略。`TurnFeedback.stop_reason` 则说明自动推进为何在此刻停下，让客户端可以把“新选择出现”与普通经过事件分开呈现。

`PlayerView.causal_threads` 是玩家已经送出情报的持续公开记录。应用层只把线程推进到“已送达”或“已改变公开行动”，并附带能够由反事实审计证明的变化；没有公开变化时明确显示等待，不泄露 NPC 的私有思考和策略评分。

2D 表现层由三个可替换组件组成：

- `world_map.gd` 只绘制 `PlayerView.world_map` 中的公开地点、路线和当前可走状态；
- `location_stage.gd` 根据地点的 `scene_key` 绘制当前地点舞台，人物交互仍来自 `KnownActors`；
- `presentation_director.gd` 将 `LastTurn` 中已经公开的结果按人物、查证、获得、伤势和时间归类，并压缩成一次场景内回响；人物回应贴近人物区，其余普通反馈停靠在场景边缘，完整证据仍由卷宗保存。它不读取或推演世界状态，也不会把后端的解释性消息逐条做成弹窗。

正式表现资源通过 `LocationVisualProfile`、`ActorVisualProfile` 和 `presentation_registry.gd` 注册。已注册地点使用位图背景，未注册地点继续使用 `location_stage.gd` 的程序化 fallback。`audio_director.gd` 建立 Music、Ambient、Event、UI 总线，地点环境声按 `scene_key` 交叉淡入。

应用层通过 `TurnFeedback.presentation` 返回公开表现提示（例如 `travel`、`reveal`、`actor_focus`、`acquire`）。提示只描述已经结算的表现类型、强度和公开主体，不包含概率、隐藏目标或未发生结果。地图移动动画结束前客户端暂时阻止提交下一行动，但不会延迟或重复执行后端结算。

地图坐标、场景键、地点描述和氛围文本属于场景公开表现数据，保存在 `data/blackwind/locations.yml`。远处 NPC 的实时位置、数量、目标和路线不进入 `PlayerView`；地图只在当前位置显示实际可见人物数量。路线按钮只提交应用层提供的 `move:*` 动作 ID，Godot 不复刻物品、开放时间或期限规则。

Godot 对应用层返回的行动维持可达性契约：移动行动必须有地点入口，告知与恢复行动必须有对应人物入口，其余行动必须进入当前地点的普通行动区。集成测试会遍历可见行动验证这一契约，避免出现“后端已经开放恢复路线，但界面没有按钮”的断链。

存档写入同目录临时文件，完成刷盘与确定性回放校验后再替换目标文件。API 只接受受限槽名并映射到服务端 `saveDir`，避免 UI 传入路径。玩家可见动作附带稳定的语义字段（类型、目标、事实），用于图形界面分组而不依赖字符串解析。

## 6. 质量门禁

统一运行：

```powershell
./tools/verify.ps1
```

门禁包括 `gofmt`、`go test ./...` 和 `go vet ./...`。容量 benchmark 与较长 fuzz 作为发布前检查按需执行。
