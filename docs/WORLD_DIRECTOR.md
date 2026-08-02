# 世界导演系统

## 目标

世界导演负责根据全局节奏产生受约束的环境变化，不代替 NPC Utility AI，也不直接操作 `WorldState`。

当前实现是纯确定性第一阶段：

- `internal/director` 从只读快照提取信号并选择指令；
- `internal/engine` 负责应用效果、生成事件和写入审计记录；
- 场景作者通过 `scenario.json` 的 `directives` 声明导演能力；
- `opportunity_actions` 将导演打开的机会映射为普通权威玩家行动；
- 每天最多选择一项，同分时按指令 ID 稳定排序；
- 任何错误都会使整个 `Engine.Step` 回滚。

## 当前信号

| Trigger | 含义 | 关键参数 |
| --- | --- | --- |
| `phase_entered` | 局势阶段刚发生切换 | `phase` |
| `quiet_days` | 公开世界事件沉寂达到阈值 | `min_quiet_days` |
| `market_stock_at_most` | 指定市场物品库存低于阈值 | `target_id` / `key` / `min_value` |
| `actors_at_location_at_least` | 指定地点聚集人数达到阈值 | `target_id` / `min_value` |

指令还可声明日期窗口、阶段、优先级、冷却天数和最大使用次数。

## 权限边界

目前仅允许三类效果：

- `set_flag`，且必须是 world scope；
- `open_opportunity`；
- `close_opportunity`。

场景校验会拒绝导演使用 `adjust_resource`、`adjust_relation`、`transfer_unique`、`set_outcome` 等权威效果。NPC 仍在导演事件应用后，基于各自的认知、目标、关系和资源自主选择行动。

## 黑风谷初始指令

| ID | 信号 | 结果 |
| --- | --- | --- |
| `quiet-broker-arrival` | 公开局势连续沉寂 | 开放可由玩家选择的游商打听行动 |
| `antidote-demand-visible` | 解瘴丹库存降至 28 或以下 | 标记市场需求已公开可见 |
| `outer-valley-crowding` | 外围聚集至少 3 名行动者 | 标记外围竞争压力 |

这些指令只提供环境状态和公开事件，不直接指定任何 NPC 的行动。游商机会出现后，玩家可在行动目录中选择“向短暂停留的游商打听消息”；执行后通过正常 `PlayerCommand` 结算、获得一条低置信消息并关闭机会。

## 审计与回放

`WorldState.DirectorDecisions` 保留：

- 日期和指令 ID；
- 触发类型与结构化信号；
- 确定性分数和来源；
- 对应的 `WorldEvent` ID。

存档仍通过玩家行动历史重放。因为当前导演只使用稳定排序和确定性信号，相同场景数据与行动历史会重建相同的导演决策。模拟 Markdown 报告已单独输出“世界导演审计”。

## 后续大模型接入点

后续可将 Anthropic SDK 规划器接在 `internal/director.Choose` 之前，但模型只能从当前通过校验的指令 ID 中选择，不能返回任意 Effect。启用模型后若请求失败，当次日推进必须显式失败并回滚，不会悄然改用确定性选择。
