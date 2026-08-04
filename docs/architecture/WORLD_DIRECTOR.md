# 世界导演系统

> 状态：权威边界说明
> 最后核验：2026-08-04

## 目标

世界导演负责根据全局节奏产生受约束的环境变化，不代替 NPC Utility AI，也不直接操作 `WorldState`。

当前实现支持确定性导演与可选的大模型导演：

- `internal/director` 从只读快照提取信号并选择指令；
- `internal/engine` 负责应用效果、生成事件和写入审计记录；
- 场景作者通过 `scenario.yml` 的 `directives` 声明导演能力；
- `opportunity_actions` 将导演打开的机会映射为普通权威玩家行动；
- 每天最多选择一项，同分时按指令 ID 稳定排序；
- 任何错误都会使整个 `Engine.Step` 回滚；交互式会话还会把跨越多天的整项玩家行动恢复到提交前状态。

启用大模型后，`internal/director` 先生成合法候选和脱敏信号快照，模型只能返回 `directive_id`、简短 `reason` 和 `focus_signals`。模型不能返回或构造 Effect。空响应、超时、Schema 错误、非法 ID 和提供方错误都会使当日推进失败并整体回滚；不会改用确定性选择掩盖失败。关闭 AI 时继续使用稳定排序的确定性导演。

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

存档仍通过玩家行动历史重放，同时用带版本号且标记为完整的 `director_replay` 契约保存权威选择记录。即使场景尚未产生导演决策，也必须保留空的完整记录；删除决策数组、删除契约或将其标记为不完整都会导致加载失败。加载时引擎按日期重放已保存的指令 ID、来源、理由和关注信号，不会重新请求模型；记录缺失或指令在当前快照中已不合法时加载失败。内容哈希继续阻止用不同内容包重放旧选择。模拟 Markdown 报告已单独输出“世界导演审计”。

## Anthropic 兼容接入

世界导演与 NPC 对话复用 Anthropic SDK 和严格结构化输出契约，但 CLI 为两者维护独立的开关、模型、端点、超时、输出上限与重试参数。启动参数分别使用 `-ai-dialogue-*` 和 `-ai-director-*` 前缀；两组参数默认从共同的 `ANTHROPIC_MODEL`、`ANTHROPIC_BASE_URL` 和 `ANTHROPIC_API_KEY` 环境配置初始化。

CLI 运行期间可使用：

- `ai status` 查看两类服务的当前配置；
- `ai dialogue on|off`、`ai director on|off` 独立启停；
- `ai <dialogue|director> model <名称>` 独立切换模型；
- `ai <dialogue|director> <base-url|timeout|max-tokens|max-retries> <值>` 修改其他运行参数；
- `director` 查看最近一次导演决策，`director all` 查看完整审计；非调试模式不会显示内部指令 ID。

世界行动在 CLI 中异步结算。模型请求期间可以输入 `cancel`，取消完成后事务整体回滚；失败或取消后可输入 `retry`。错误会明确显示并保留当前会话，不会终止进程或改用确定性导演。
