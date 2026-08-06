# Narra

Narra 是一个数据驱动的叙事模拟框架，提供 Go 权威规则内核、Godot 桌面客户端、内容编译工具和可插拔故事包。框架不绑定具体世界观；《凡途》《天变邸抄》《远星环站》都作为内容层存在。

## 获取源码

仓库使用 Git LFS 管理正式图片、音频、影片和字体资源。首次克隆前请安装并启用 [Git LFS](https://git-lfs.com/)：

```powershell
git lfs install
git clone https://github.com/gqy20/narra.git
cd narra
git lfs pull
```

录制成片、检查截图、日志、构建目录和转码中间文件属于本地产物，不进入源码历史。

Narra 采用 [MIT License](LICENSE) 开源。仓库内第三方字体继续遵循各自目录中附带的 SIL Open Font License。

## 创建自己的内容包

新故事以 `data/<world>/` 下的一组 YAML 文件声明场景、玩家、人物、地点、事实、物品、行动、剧情线、世界规则、AI 对话策略和表现映射。可以复制一个官方内容包作为结构参考，然后完全替换世界观、文案与关系；图片、音频、影片和字体是可选表现资源，缺失时使用稳定的通用视觉或声音 fallback。

最低工作流是：

```powershell
go run ./cmd/narra-content validate data/<world>
go run ./cmd/narra-content graph data/<world>
go run ./cmd/narra-content simulate data/<world> --runs 200 --seed 1
go run ./cmd/play -data data/<world>
```

符合当前 Schema 的内容包不需要增加故事专属的 Go 或 GDScript 分支。准备把新世界作为仓库内的正式内容包维护时，还应把它加入 Go 与 Godot 的可移植性门禁；字段契约和资源接入细节见 [内容架构](docs/architecture/CONTENT.md) 与 [验证指南](docs/development/VALIDATION.md)。

## 内容开发

内容包可在不启动客户端的情况下编译、绘图和批量试玩：

```powershell
go run ./cmd/narra-content validate data/tianqi
go run ./cmd/narra-content graph data/tianqi
go run ./cmd/narra-content simulate data/orbital --runs 200 --seed 1
```

当前官方移植基线包括 `blackwind`、`tianqi` 与科幻测试世界 `orbital`。完整门禁使用 `./tools/verify.ps1` 和显式关闭 AI 的 `./tools/verify-godot.ps1`。

当前仓库同时维护通用运行时与多个移植基线，用来验证新增故事只需增加内容包和可选资源，不需要增加故事专属 Go 或 GDScript 分支。

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

完整文档从 [文档中心](docs/README.md) 进入。当前权威入口包括 [产品定义](docs/product/PRODUCT.md)、[架构说明](docs/architecture/OVERVIEW.md)、[验证指南](docs/development/VALIDATION.md) 和 [当前路线图](docs/product/ROADMAP.md)；阶段验收、旧计划和试玩记录统一保存在 [历史归档](docs/archive/README.md)。

交互版本当前采用冻结范围开发，核心假设、明确不做的内容和完成门禁见 [交互 Demo 范围](docs/product/DEMO_SCOPE.md)。

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

完整命令说明见 [开发工作流](docs/development/DEVELOPMENT.md)。

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

`talk <人物编号或姓名>` 使用与 Godot 相同的脱敏快照和 StepFun/Anthropic 兼容对话服务，并选中交谈对象；仅选择人物不会请求模型或推进时间。进入后可直接输入自然语言；`context` 查看当前语境与保留轮数，`actions` 查看该人物对应的权威交涉，`cancel` 取消当前模型请求，`retry` 重新提交被取消或失败的请求，`leave` 结束会话。`await` 会停止读取后续命令直到当前回应完成，主要用于管道脚本和自动化测试。最近 8 轮对话会提供给模型，完整记录随存档保存。

模型严格返回台词、情绪、对话行为、引用事实和一个受限行动索引。玩家明确在话中执行当前交涉时，服务端会把索引映射回规则引擎行动并直接结算，不再要求第二次确认；普通问答则结算内容包定义的普通交谈行动。每次成功发言推进一次对应时长，失败、取消或失效响应不推进时间。等待期间会周期性显示耗时；终端仍可输入 `context`，输入 `cancel` 会取消当次生成，输入 `quit` 会取消并退出。模型未启用时会明确显示不可用；模型已经启用后，超时、网络错误、空响应或输出校验失败都会明确报错，不会伪造本地台词。

真实模型试玩的历史证据见 [NPC 对话试玩记录](docs/archive/playtests/NPC_DIALOGUE_PLAYTEST.md)；它记录特定版本，不作为当前行为规范。

世界推进已加入纯确定性的受限导演层：它根据局势沉寂、市场库存和地点聚集人数从场景白名单中选择环境指令，但不能直接修改角色资源、物品、关系、行动或胜负。设计与审计协议见 [世界导演系统](docs/architecture/WORLD_DIRECTOR.md)。

存档使用 `saves` 目录下的命名槽。自动存档默认开启，每次成功行动后覆盖 `autosave` 槽；手动覆盖已有槽需要追加 `confirm`：

```powershell
go run ./cmd/play -load autosave
go run ./cmd/play -saves D:\games\narra-saves -load blackwind
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

NPC 聚焦对话可选使用 Anthropic 官方 Go SDK。服务启动时会读取仓库根目录下受 Git 忽略的 `.env`，也接受已有的进程环境变量；可通过 `ANTHROPIC_API_KEY`、`ANTHROPIC_BASE_URL` 和 `ANTHROPIC_MODEL` 接入 Anthropic Messages 兼容服务。仓库提供不含密钥的 `.env.example`。未配置密钥或使用 `-ai-enabled=false` 时不启动模型；一旦启用，模型调用必须返回并通过结构化校验，否则接口返回明确错误。可通过 `-ai-model`、`-ai-base-url`、`-ai-max-tokens`、`-ai-timeout`、`-ai-max-retries` 调整运行参数。AI 生成表现文本并识别玩家是否明确执行了当前可用行动；所有状态修改仍由规则引擎校验和结算。

Godot 的开始页和游戏内都可以打开“体验设置 → 大模型”，直接启用或关闭人物对话，并配置模型、Anthropic Messages 兼容接口地址和 API Key。“测试连通性”会使用当前输入分别验证人物对话与世界导演的结构化输出，不改变游戏状态，也不保存配置；“保存并立即应用”会在不退出游戏、不重置当前进度的情况下切换服务；“清除密钥并关闭”会立即停止模型调用。密钥使用遮罩输入，保存在当前用户运行目录的 `ai-settings.json`，不会进入命令行或日志；该配置文件不会被纳入诊断包。打包服务启动时通过 `-ai-settings` 读取该文件。

当前稳定协议为 `/api/v1`：

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| `GET` | `/api/v1/health` | 就绪检查 |
| `GET` | `/api/v1/game` | 获取当前玩家视图 |
| `POST` | `/api/v1/game/new` | 新游戏，正文为 `{"player_name":"名字"}` |
| `POST` | `/api/v1/game/action` | 执行动作，正文为 `{"action_id":"..."}` |
| `POST` | `/api/v1/game/dialogue` | 提交同地人物对话；正文包含 `{"actor_id":"N04","player_message":"……"}`，成功时同时返回人物回复和推进后的玩家视图 |
| `PUT` | `/api/v1/settings/ai` | 立即启用、切换或关闭人物对话模型 |
| `POST` | `/api/v1/settings/ai/test` | 测试当前模型配置，不保存配置或替换运行中服务 |
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

默认路线由 `godot/demo/recordings/tianqi-evidence-route.json` 定义，依次展示天启片头、交割残页入手、官署登记、补造账册格式比对、周良辅自陈串证和最终裁定。脚本使用独立临时存档，自动等待服务就绪、录制游戏音轨、转码为 1080p H.264/AAC、校验时长和流信息，并将 MP4、日志及录制清单写入 `artifacts/recordings/tianqi/<yyyyMMdd-HHmmss>-<路线ID>-<档位>/`。目录时间使用本地时区，成片统一命名为 `<路线ID>-<档位>.mp4`，例如 `20260804-011557-tianqi-evidence-route-4k/tianqi-evidence-route-4k.mp4`；1080p 成片对应 `tianqi-evidence-route-1080p.mp4`。路线 ID 必须使用小写 kebab-case。可通过 `-Route` 选择其他路线配置，通过 `-OutputDirectory` 指定固定输出目录。

使用 `./tools/record-gameplay.ps1 -Profile 4k` 可录制原生 3840×2160、30 FPS 的 4K 源帧并以 H.264/AAC 输出。4K 档不仅覆盖 Movie Writer 的输出尺寸，还会把运行时内容画布锁定为 3840×2160，并以 2 倍 UI 缩放进行原生栅格化，避免把默认 1600×900 画面放大后装入 4K 容器。录制中间源使用质量 1.0 的 MJPEG，最终以 `libx264` slow、CRF 14、`yuv420p`、BT.709 编码；脚本会校验 Movie Writer 的实际源分辨率，并要求输出磁盘至少保留 15 GB 空间。

录制必须使用新的输出目录；如果目录中已有 `source.avi`，脚本会拒绝覆盖。正常退出后会自动移除临时显示覆盖、中间源、独立存档和本次启动的服务进程，并在 `manifest.json` 中记录源格式、源质量、分辨率、帧率与最终编码参数。默认 `1080p` 档同样使用原生 1920×1080 源帧。项目的默认窗口基准为 1600×900，并可在体验设置中选择 1080p、1440p、4K 或跟随显示器的全屏输出。

## 构建桌面发行包

安装与当前 Godot 版本匹配的 Windows 导出模板后运行：

```powershell
./tools/build-windows.ps1
```

构建结果使用英文文件名，输出到 `dist/narra-windows-x86_64/`，并生成 `dist/narra-windows-x86_64.zip`。完整说明见 [桌面打包与发布说明](docs/development/PACKAGING.md)。

macOS 可在 Mac 或 GitHub Actions 的 macOS Runner 上生成同时支持 Apple Silicon 与 Intel 的 Universal 应用包：

```bash
bash ./tools/build-macos.sh 0.1.0
```

推送与 `godot/project.godot` 版本一致的标签（例如 `v0.1.0`）会自动执行 CI，并把 Windows ZIP 与未签名 macOS ZIP 发布到同一个 GitHub Release；首次 Release 将在版本确认后创建。完整说明见 [桌面打包与发布说明](docs/development/PACKAGING.md)。

发行版的客户端日志、服务端日志和存档统一写入用户数据目录：Windows 为 `%APPDATA%\Narra`，macOS 为 `~/Library/Application Support/Narra`。日志轮转、故障排查和便携开发模式见 [运行日志说明](docs/development/LOGGING.md)。

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

黑风谷的原始设计与验收证据见 [黑风谷文档入口](docs/worlds/blackwind/README.md)。
