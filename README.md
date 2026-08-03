# 凡途

## 内容开发

内容包可在不启动客户端的情况下编译、绘图和批量试玩：

```powershell
go run ./cmd/fantu-content validate data/tianqi
go run ./cmd/fantu-content graph data/tianqi
go run ./cmd/fantu-content simulate data/orbital --runs 200 --seed 1
```

当前官方移植基线包括 `blackwind`、`tianqi` 与科幻测试世界 `orbital`。完整门禁使用 `./tools/verify.ps1` 和显式关闭 AI 的 `./tools/verify-godot.ps1`。

当前仓库实现《凡途》黑风谷局势的确定性模拟内核，以及建立在同一权威规则之上的交互式 CLI。

## 项目结构

| 目录 | 职责 |
| --- | --- |
| `cmd/sim` | 运行单个场景并输出 Markdown 或 JSON |
| `cmd/batch` | 运行固定验收、参数扫描与健康指标统计 |
| `cmd/play` | 运行玩家视角的交互式终端客户端 |
| `cmd/server` | 向 Godot 暴露仅监听本机的 JSON API |
| `internal/app` | Session、玩家可见视图、动态行动目录与存档回放 |
| `internal/domain` | 场景、状态、事件和事务的领域协议 |
| `internal/engine` | 确定性逐日推进与权威规则结算 |
| `internal/scenario` | JSON 数据加载和静态校验 |
| `internal/batch` | 扰动、批量执行、覆盖和统计 |
| `internal/report` | 单次运行报告输出 |
| `data/blackwind` | 黑风谷正式场景数据 |
| `testdata` | T01～T07 验收玩家计划 |
| `docs` | PRD、架构、M0 规格与验证结果 |

完整依赖边界和扩展约束见 [架构说明](docs/ARCHITECTURE.md)。产品与验证入口分别见 [PRD](docs/PRD.md)、[M0 验收结果](docs/M0_RESULTS.md)、[CLI 玩家风格与试玩测试手册](docs/PLAYER_PERSONAS_CLI_PLAYTEST.md) 和 [30 项验证清单](docs/VALIDATION_OPTIMIZATION_BACKLOG.md)。

交互版本当前采用冻结范围开发，核心假设、明确不做的内容和完成门禁见 [交互 Demo 范围](docs/DEMO_SCOPE.md)。

运行统一质量门禁：

```powershell
./tools/verify.ps1
```

日常开发、测试和打包推荐使用统一 Make 入口：

```powershell
make
make doctor
make verify
make release-windows VERSION=0.1.0
```

完整命令说明见 [开发工作流](docs/DEVELOPMENT.md)。

## 运行交互式 CLI

```powershell
go run ./cmd/play
```

CLI 是可完整通关的正式客户端，根据当前地点、资源、物品、认知和忙碌状态生成权威行动。`wait` 只推进一天；`wait complete` 明确推进到当前持续行动完成；`wait next` 先展示风险，输入 `wait next confirm` 后才会快进到下一次需要决策的变化。底层始终逐日结算，并合并展示期间发生的公开事件。

除行动编号外，还可以使用分层浏览和人物交谈命令：

```text
选择> look
选择> people
选择> talk 2
选择> await
选择> 这条消息你准备如何核验？
选择> await
选择> context
选择> actions
选择> leave
选择> map
选择> journal
选择> actions
选择> actions 交涉
选择> actions page 2
选择> actions find 解瘴丹
选择> do 1
选择> wait
选择> wait complete
选择> wait next
选择> wait next confirm
选择> go 青岚门驻地
选择> save blackwind
选择> saves
选择> load blackwind
选择> quit
```

`actions` 每页最多显示 8 项，可按“调查、交涉、准备、出行”筛选，也可用 `actions find <关键词>` 搜索；每次世界状态变化后必须重新显示行动目录，避免旧编号误触其他行动。`map` 默认只显示当前位置的路线，`map all` 展示完整路网。

`talk <人物编号或姓名>` 使用与 Godot 相同的脱敏快照和 StepFun/Anthropic 兼容对话服务，并进入多轮会话。进入后可直接输入自然语言；`context` 查看当前语境与保留轮数，`actions` 查看该人物对应的权威交涉，`cancel` 取消当前模型请求，`retry` 重新提交被取消或失败的请求，`leave` 结束会话。`await` 会停止读取后续命令直到当前回应完成，主要用于管道脚本和自动化测试。最近 8 轮同一局势下的对话会提供给模型，完整记录随存档保存；世界行动发生后旧会话自动失效。

模型严格返回台词、情绪、对话行为、引用事实和最多 3 个建议行动。建议只能来自当前规则引擎已经公开的交涉选项，仍需玩家用 `do <编号>` 执行；自然语言本身不推进天数，也不修改关系、物品或世界状态。等待期间会周期性显示耗时；终端仍可输入 `context`，输入 `cancel` 会取消当次生成，输入 `quit` 会取消并退出。模型未启用时会明确显示不可用；模型已经启用后，取消、超时、网络错误、空响应或输出校验失败都会明确报错，不会伪造本地台词。

真实模型的五类玩家试玩、发现的问题与修复记录见 [`docs/NPC_DIALOGUE_PLAYTEST.md`](docs/NPC_DIALOGUE_PLAYTEST.md)。

世界推进已加入纯确定性的受限导演层：它根据局势沉寂、市场库存和地点聚集人数从场景白名单中选择环境指令，但不能直接修改角色资源、物品、关系、行动或胜负。设计与审计协议见 [`docs/WORLD_DIRECTOR.md`](docs/WORLD_DIRECTOR.md)。

存档使用 `saves` 目录下的命名槽。自动存档默认开启，每次成功行动后覆盖 `autosave` 槽；手动覆盖已有槽需要追加 `confirm`：

```powershell
go run ./cmd/play -load autosave
go run ./cmd/play -saves D:\games\fantu-saves -load blackwind
go run ./cmd/play -autosave=false
```

游戏内可用 `autosave on|off` 切换自动存档。自动存档关闭时，读取槽位需要输入 `load <槽位> confirm`，防止未保存进度被无意覆盖。

默认界面只显示玩家术语；需要诊断数据时可以使用 `-debug` 查看稳定事实和行动 ID，但调试 ID 不再作为玩家命令接受：

```powershell
go run ./cmd/play -debug
```

交互流程会在青髓芝归属确定时立即生成结局。底层引擎仍保留完整 30 天模拟能力。

存档只记录初始玩家和已选择的行动历史；读取时由确定性引擎重新回放。CLI 不读取事实真值、NPC 私有认知、策略评分或世界内部标记。

## 运行本地游戏服务

Godot 和其他图形客户端通过本地 HTTP 服务复用同一套 Session、可见性过滤与行动合法性：

```powershell
go run ./cmd/server
```

服务默认监听 `127.0.0.1:8787`，存档写入 `saves/`。它只接受固定存档槽名，不接受客户端文件路径。可用 `-addr`、`-data` 和 `-saves` 覆盖开发配置。

NPC 聚焦对话可选使用 Anthropic 官方 Go SDK。服务启动时会读取仓库根目录下受 Git 忽略的 `.env`，也接受已有的进程环境变量；可通过 `ANTHROPIC_API_KEY`、`ANTHROPIC_BASE_URL` 和 `ANTHROPIC_MODEL` 接入 Anthropic Messages 兼容服务。仓库提供不含密钥的 `.env.example`。未配置密钥或使用 `-ai-enabled=false` 时不启动模型；一旦启用，模型调用必须返回并通过结构化校验，否则接口返回明确错误。可通过 `-ai-model`、`-ai-base-url`、`-ai-max-tokens`、`-ai-timeout`、`-ai-max-retries` 调整运行参数。AI 只生成表现文本，不能修改存档或裁定游戏规则。

Godot 的开始页和游戏内都可以打开“体验设置 → 大模型”，直接启用或关闭人物对话，并配置模型、Anthropic Messages 兼容接口地址和 API Key。“保存并立即应用”会在不退出游戏、不重置当前进度的情况下切换服务；“清除密钥并关闭”会立即停止模型调用。密钥使用遮罩输入，保存在当前用户运行目录的 `ai-settings.json`，不会进入命令行或日志；该配置文件不会被纳入诊断包。打包服务启动时通过 `-ai-settings` 读取该文件。

当前稳定协议为 `/api/v1`：

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| `GET` | `/api/v1/health` | 就绪检查 |
| `GET` | `/api/v1/game` | 获取当前玩家视图 |
| `POST` | `/api/v1/game/new` | 新游戏，正文为 `{"player_name":"名字"}` |
| `POST` | `/api/v1/game/action` | 执行动作，正文为 `{"action_id":"..."}` |
| `POST` | `/api/v1/game/dialogue` | 开始或继续同地人物对话；开场正文为 `{"actor_id":"N04","situation":"focus"}`，追问增加 `"player_message":"……"` |
| `PUT` | `/api/v1/settings/ai` | 立即启用、切换或关闭人物对话模型 |
| `POST` | `/api/v1/game/save` | 原子保存，正文为 `{"slot":"autosave"}` |
| `POST` | `/api/v1/game/load` | 读取存档槽 |
| `POST` | `/api/v1/game/quit` | 清除服务内的当前 Session |

成功响应返回经过裁剪的 `view`；失败响应返回稳定的 `error.code` 和玩家可读的 `error.message`。动作同时包含 `kind`、目标与线索元数据，客户端无需解析动作 ID 或拼接人物×线索组合。

## 运行 Godot MVP

已安装 Godot 4.7+ 时，在仓库根目录运行：

```powershell
./tools/run-godot.ps1
```

启动脚本会构建本地服务、以隐藏进程运行它并打开 `godot/` 项目；退出客户端时一并关闭该服务。界面按自身、线索、局势、本回合回响、同地人物、可行之事划分六区，每次行动成功后写入 `autosave` 存档槽。

执行 Godot 与真实 Go 服务之间的无头集成验证；它同时覆盖开局烟测与“核验—传播—影响—结局”完整路线：

```powershell
./tools/verify-godot.ps1
```

录制一段由真实 Godot 客户端与本地规则服务共同驱动的完整玩法演示：

```powershell
./tools/record-gameplay.ps1
```

默认路线由 `godot/demo/recordings/tianqi-evidence-route.json` 定义，依次展示天启片头、交割残页入手、官署登记、补造账册格式比对、周良辅自陈串证和最终裁定。脚本使用独立临时存档，自动等待服务就绪、录制游戏音轨、转码为 1080p H.264/AAC、校验时长和流信息，并将 MP4、日志及录制清单写入 `artifacts/recordings/tianqi/<时间-路线-规格>/`。可通过 `-Route` 选择其他路线配置，通过 `-OutputDirectory` 指定固定输出目录。

使用 `./tools/record-gameplay.ps1 -Profile 4k` 可录制原生 3840×2160、30 FPS 的 4K 源帧并以 H.264/AAC 输出。4K 档会临时覆盖 Godot 录制视口、校验 Movie Writer 的实际源分辨率，并要求输出磁盘至少保留 15 GB 空间；正常退出后会自动移除临时覆盖。默认 `1080p` 档同样使用原生 1920×1080 源帧。项目的默认窗口基准为 1600×900，并可在体验设置中选择 1080p、1440p、4K或跟随显示器的全屏输出。

## 构建 Windows 发行包

安装与当前 Godot 版本匹配的 Windows 导出模板后运行：

```powershell
./tools/build-windows.ps1
```

构建结果使用英文文件名，输出到 `dist/fantu-windows-x86_64/`，并生成 `dist/fantu-windows-x86_64.zip`。完整说明见 [Windows 打包说明](docs/PACKAGING.md)。

发行版的客户端日志、服务端日志和存档统一写入 `%APPDATA%\Fantu`；日志轮转、故障排查和便携开发模式见 [运行日志说明](docs/LOGGING.md)。

## 运行 T00

```powershell
go run ./cmd/sim -data data/blackwind -out output/T00.md
```

输出 JSON 状态：

```powershell
go run ./cmd/sim -data data/blackwind -format json -out output/T00.json
```

只推进到指定日期并输出状态快照：

```powershell
go run ./cmd/sim -data data/blackwind -until 10 -out output/day10.md
```

## 逐日驱动 API

世界内核可以由客户端逐日推进。`Step` 接收当天玩家命令并返回不可修改内部状态的快照；任何结算错误都会回滚到日初。

持续多日的行动会进入 `PendingAction`，效果只在完成日提交；忙碌角色不能同时开始其他行动。完成日会重新检查非资源条件，条件变化会生成 `action_failed` 并取消效果。调用 `Engine.Interrupt(actorID, reason)` 可以从外部中断进行中的行动。

策略和玩家命令可以用 `costs` 声明真实资源成本。成本在行动开始时原子预留，成功后最终消费，完成失败或外部中断时全额退还；余额不足的玩家命令会回滚当天。`Score.Cost` 只参与效用评分，不直接扣除资源。

角色关系是方向性的多维状态，包含信任、怀疑、畏惧、利益依赖、仇恨和人情债，并会修正针对特定角色的 Utility 评分。

NPC 每天先评估场景作者提供的策略；没有合法策略时，通用规划器会依据伤势、资源、认知、兴趣主题、性格和未来行动窗口生成治疗、修炼、补给、调查、探索或撤退计划。地点使用带耗时、危险度、开放标记和必需物品的有向路线图；NPC 只会沿当前可行的最短路径移动。调查只能由角色已知的低可信信念触发，完成后才会写入可调查事实和关联线索，并记录调查来源与学习日期。非紧急生成计划不会占用即将到来的场景策略窗口，并会在决策审计中标记为“通用规划”。

所有玩家、NPC 和场景 `move` 效果都经过同一条路线校验；没有直连路线、耗时不足、缺少必需物品或路线未开放都会失败。确需提前潜入的场景必须显式声明 `bypass_route_flag`。

```go
simulation := engine.NewWithPlayer(bundle, player)

day1, err := simulation.Step(day1Commands)
day2, err := simulation.Step(day2Commands)
current := simulation.State()
```

运行玩家提前出售情报的 T01：

```powershell
go run ./cmd/sim -data data/blackwind -plan testdata/T01_sell_intel.json -out output/T01.md
```

运行合作提前移植的 T02：

```powershell
go run ./cmd/sim -data data/blackwind -plan testdata/T02_transplant.json -out output/T02.md
```

运行公开陈青山伤势的 T03：

```powershell
go run ./cmd/sim -data data/blackwind -plan testdata/T03_reveal_injury.json -out output/T03.md
```

运行强化错误成熟日期的 T04：

```powershell
go run ./cmd/sim -data data/blackwind -plan testdata/T04_false_date.json -out output/T04.md
```

运行揭露密约并保护陈氏队伍的 T05：

```powershell
go run ./cmd/sim -data data/blackwind -plan testdata/T05_expose_betrayal.json -out output/T05.md
```

运行与李玄合作后违约的 T06：

```powershell
go run ./cmd/sim -data data/blackwind -plan testdata/T06_betray_li.json -out output/T06.md
```

运行伏击失败并恢复的 T07：

```powershell
go run ./cmd/sim -data data/blackwind -plan testdata/T07_failed_ambush.json -out output/T07.md
```

运行测试：

```powershell
go test ./...
```

批量运行 T00～T07 并生成分布报告：

```powershell
go run ./cmd/batch -data data/blackwind -plans testdata -out output/batch.md
```

使用 25 个可复现种子扰动初始资源、定向关系和行动成本，共运行 200 次参数扫描：

```powershell
go run ./cmd/batch -data data/blackwind -plans testdata -sweep 25 -seed-start 1 -resource-delta 2 -relationship-delta 2 -cost-delta 2 -out output/sweep.md
```

扫描 NPC 初始已知事实、置信度和来源：

```powershell
go run ./cmd/batch -data data/blackwind -plans testdata -sweep 10 -belief-delta 1 -resource-delta 0 -relationship-delta 0 -cost-delta 0 -out output/sweep_cognition.md
```

扫描唯一物品持有者、市场库存和地图路线：

```powershell
go run ./cmd/batch -data data/blackwind -plans testdata -sweep 10 -world-delta 1 -resource-delta 0 -relationship-delta 0 -cost-delta 0 -out output/sweep_world.md
```

运行模糊测试和容量基准：

```powershell
go test ./internal/engine -fuzz FuzzClampRelationAlwaysStaysWithinBounds -fuzztime 10s
go test ./internal/engine -run ^$ -bench BenchmarkEngineScale -benchmem
```

种子只生成输入变体，不改变引擎的确定性结算；相同配置和种子会生成完全相同的报告。

预设玩家命令可以声明前置条件失败策略：`error`（默认，终止并回滚当天）、`skip`（记录跳过事件）或 `fallback`（在同一天尝试替代命令）。替代命令也可以继续声明失败策略，但最多嵌套 8 层。

事件报告中的审计标签会显示稳定事件 ID，并在适用时附带 `strategy`、`parent` 与 `triggers`。因此可以从一次行动回查它采用的策略、跨日开始事件，以及触发该决策的信念、标记、物品或机会来源。

场景的 `planning_mode` 可设为 `authored_priority`（默认）或 `unified_score`。后者让场景编写策略和运行时生成策略使用同一候选池。情报效果还可声明 `propagation`、`delay_days`、`distortion` 与 `secrecy`，用于控制传播范围、延迟和失真。

主题必须在场景 `topics` 词表中声明。NPC 可使用结构化 `goals` 表达获取、保护、获利、地位和避险优先级；生成策略会读取这些优先级。通用补给与导航会形成持久计划链，事件审计标签以 `plan=<PlanID>/<StepID>` 展示所属步骤。

决策记录包含关系清零和单信息移除的反事实结果。外部交互可调用通用情报事务处理出售、互换、免费告知和隐瞒。场景 `markets` 定义地点库存、基础价、涨价步长和封锁标记，`market_buy` 统一执行价格与稀缺库存结算。

社会事务 API 还包括债务、动态联盟与协议结算。唯一物品的实际保管者始终唯一，但协议可以另行记录多人收益份额。

批量报告同时输出规则覆盖矩阵、结局熵、NPC 空闲率、连续决策重复率、调查有效率、关系影响率和单信息反事实改变率。

```json
{
  "id": "take-herb",
  "day": 22,
  "action_id": "sell",
  "conditions": [{"type": "has_item", "key": "qingsuizhi"}],
  "on_failure": "fallback",
  "fallback": {
    "id": "trace-herb",
    "action_id": "track",
    "conditions": [{"type": "missing_item", "key": "qingsuizhi"}]
  }
}
```

设计规格见 [M0 黑风谷局势纸面与数据原型](docs/M0_BLACKWIND_SPEC.md)。
