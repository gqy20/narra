# 凡途

当前仓库实现《凡途》黑风谷局势的确定性模拟内核，以及建立在同一权威规则之上的交互式 CLI。

## 项目结构

| 目录 | 职责 |
| --- | --- |
| `cmd/sim` | 运行单个场景并输出 Markdown 或 JSON |
| `cmd/batch` | 运行固定验收、参数扫描与健康指标统计 |
| `cmd/play` | 运行玩家视角的交互式终端客户端 |
| `internal/app` | Session、玩家可见视图、动态行动目录与存档回放 |
| `internal/domain` | 场景、状态、事件和事务的领域协议 |
| `internal/engine` | 确定性逐日推进与权威规则结算 |
| `internal/scenario` | JSON 数据加载和静态校验 |
| `internal/batch` | 扰动、批量执行、覆盖和统计 |
| `internal/report` | 单次运行报告输出 |
| `data/blackwind` | 黑风谷正式场景数据 |
| `testdata` | T01～T07 验收玩家计划 |
| `docs` | PRD、架构、M0 规格与验证结果 |

完整依赖边界和扩展约束见 [架构说明](docs/ARCHITECTURE.md)。产品与验证入口分别见 [PRD](docs/PRD.md)、[M0 验收结果](docs/M0_RESULTS.md) 和 [30 项验证清单](docs/VALIDATION_OPTIMIZATION_BACKLOG.md)。

交互版本当前采用冻结范围开发，核心假设、明确不做的内容和完成门禁见 [交互 Demo 范围](docs/DEMO_SCOPE.md)。

运行统一质量门禁：

```powershell
./tools/verify.ps1
```

## 运行交互式 CLI

```powershell
go run ./cmd/play
```

CLI 根据当前地点、资源、物品、认知和忙碌状态生成可用行动。忙碌时可以直接推进到行动完成，空闲时可以推进到下一次需要决策的变化；底层仍逐日结算，并合并展示期间发生的公开事件。输入行动编号即可执行，输入 `save [文件]` 保存，输入 `quit` 退出。

```text
选择> 1
选择> save saves/blackwind.json
选择> quit
```

继续已有存档，或让每回合自动保存：

```powershell
go run ./cmd/play -load saves/blackwind.json
go run ./cmd/play -autosave saves/autosave.json
```

默认界面只显示玩家术语；需要复现测试或查看稳定事实、行动 ID 时使用：

```powershell
go run ./cmd/play -debug
```

交互流程会在青髓芝归属确定时立即生成结局。底层引擎仍保留完整 30 天模拟能力。

存档只记录初始玩家和已选择的行动历史；读取时由确定性引擎重新回放。CLI 不读取事实真值、NPC 私有认知、策略评分或世界内部标记。

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
