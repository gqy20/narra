# 凡途模拟内核架构

## 1. 当前边界

仓库采用单 Go module、多个内部包的结构。Go 模拟内核是世界状态与规则的唯一权威来源；场景 JSON 只描述数据，不承载隐式逻辑。

```text
cmd/                 可执行程序入口
  sim/               单场景运行与状态报告
  batch/             固定验收和参数扫描
  play/              玩家视角的交互式终端客户端
  server/            Godot 使用的本机 HTTP 服务入口
internal/
  app/               Session、玩家视图、行动目录和存档回放
  server/            /api/v1 协议、存档槽与并发边界
  domain/            领域数据、状态和跨包协议
  engine/            逐日决策、行动与事务结算
  scenario/          JSON 加载与静态校验
  batch/             批量运行、扰动和统计
  report/            单次运行报告适配器
data/blackwind/      黑风谷正式场景数据
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
- `report` 与 `batch` 只读取引擎快照，不修改世界状态。
- `app` 将完整世界状态裁剪成玩家可见视图，并把动态行动 ID 转译为玩家命令；它不直接修改 `WorldState`。
- `server` 只管理单个 Session、请求校验和命名存档槽；它不解释动作 ID，也不暴露任意文件路径。
- `cmd` 只做参数解析、依赖组装和错误输出，不放业务规则。

## 3. 引擎生命周期

单日推进顺序保持稳定：

1. 开始阶段固定事件；
2. 到期情报送达；
3. 基于日初快照生成 NPC 与玩家意图；
4. 原子预留成本并启动行动；
5. 按阶段完成到期行动并结算稀缺资源冲突；
6. 结束阶段固定事件与核心争夺；
7. 债务到期处理；
8. 全量状态不变量校验；
9. 返回不可修改内部状态的深拷贝快照。

任何步骤返回错误时，`Step` 回滚到日初状态及事件 ID 计数器。

## 4. 领域模型组织原则

`internal/domain` 是跨包契约，不包含决策算法。模型按用途分为：

- 场景定义：事实、角色配置、策略、条件、效果、地图和市场；
- 运行状态：玩家、NPC、物品、认知、关系、计划、债务、联盟和协议；
- 审计协议：意图、PendingAction、事件、决策与反事实记录。

当前模型仍集中在一个文件中，以减少早期协议频繁变化时的跨文件跳转。进入稳定 API 阶段后，可在不改变 `domain` 包路径的前提下按上述三类机械拆分。

## 5. 应用层与客户端边界

M1 应用层位于 `internal/app`，负责 Session、玩家可见视图、动态行动目录、存档和回放。玩家视图明确排除事实真值、NPC 私有认知、策略评分、内部因果 ID 和世界标记。

交互式 CLI 已通过 `cmd/play` 接入应用层。存档采用“初始玩家 + 行动历史”的版本化格式，加载时通过权威引擎确定性回放，因此不会把内部状态结构固化成外部协议。

Godot 本地服务由 `cmd/server` 和 `internal/server` 提供，协议固定在 `/api/v1`。服务仅监听回环地址，通过互斥锁串行修改单个 Session；Godot 只渲染 `PlayerView` 并提交服务端给出的动作 ID，不复制行动合法性、视图过滤或结算规则。

Godot 客户端按如下单向数据流工作：

```text
Godot 控件 ──动作 ID──> /api/v1 ──> app.Session ──> engine
Godot 地图/场景/行动视图 <── PlayerView <─────────┘
```

人物公开资料和动作语义元数据都由应用层生成。Godot 可折叠“人物 × 线索”组合，但不会自行决定哪些组合合法。所有写操作在服务端串行完成，行动成功后客户端再发起自动存档。

2D 表现层由三个可替换组件组成：

- `world_map.gd` 只绘制 `PlayerView.world_map` 中的公开地点、路线和当前可走状态；
- `location_stage.gd` 根据地点的 `scene_key` 绘制当前地点舞台，人物交互仍来自 `KnownActors`；
- `presentation_director.gd` 顺序播放 `LastTurn` 中已经公开的结果，不读取或推演世界状态。

地图坐标、场景键、地点描述和氛围文本属于场景公开表现数据，保存在 `data/blackwind/locations.json`。远处 NPC 的实时位置、数量、目标和路线不进入 `PlayerView`；地图只在当前位置显示实际可见人物数量。路线按钮只提交应用层提供的 `move:*` 动作 ID，Godot 不复刻物品、开放时间或期限规则。

存档写入同目录临时文件，完成刷盘与确定性回放校验后再替换目标文件。API 只接受受限槽名并映射到服务端 `saveDir`，避免 UI 传入路径。玩家可见动作附带稳定的语义字段（类型、目标、事实），用于图形界面分组而不依赖字符串解析。

## 6. 质量门禁

统一运行：

```powershell
./tools/verify.ps1
```

门禁包括 `gofmt`、`go test ./...` 和 `go vet ./...`。容量 benchmark 与较长 fuzz 作为发布前检查按需执行。
