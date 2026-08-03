# 内容语言与表现配置

内容包使用两层配置控制题材语言，不允许客户端或 AI 服务根据场景 ID 猜测文案。

## `dialogue.yml`

`dialogue.yml` 只控制 AI 对话的题材语言和人物声音：

- `language`：locale、建议/硬字符限制、句数、不确定性标记和禁用自称；
- `confidence_labels`：已确认、可采信、传闻三档稳定语义的场景文本；
- `private_drives`：通用目标和秘密状态提供给模型的脱敏描述；
- `personality_guidance`：人物性格阈值对应的说话指导；
- `relations`：关系档位和态度描述；
- `actors`：人物自称、对玩家称呼、独立风格、附加指导及禁用词。

事实白名单、秘密过滤、可用行动、结构化输出、内部字段拦截、超时和空响应仍由 Go 强制执行。内容不能通过 YAML 放宽这些边界。

## `presentation.yml`

`presentation.ui` 是 CLI、Go 应用投影和 Godot 的权威术语/模板表。模板使用 `{name}`、`{claim}`、`{day}` 等命名占位符；Godot 自带 `%s`/`%d` 的局部格式化文本仍保留对应占位符。

所有运行时必需键及其占位符签名统一登记在 `internal/scenario/presentation_ui_contract.yml`。场景加载器会一次性检查完整键集、命名占位符和 `%s`/`%d` 顺序；源码契约测试还会扫描 Go 与 Godot 的调用，阻止新增调用绕过登记。`phase_` 是已登记的动态扩展前缀，内容包可以按自身阶段名称增加别名，并以 `phase_default` 作为通用显示值。

地点表现还可以声明：

- `fallback_kind`：缺少正式背景时使用的通用程序绘制类型；
- `ambient_frequency` / `ambient_air`：缺少正式环境音时的通用合成参数；
- `stage_label`：地点在场景舞台上的内容标签。

Godot 只读取这些字段，不再识别 `qinglan` 等故事专属场景键。

## 内容 Schema v6

Schema v6 要求完整的对话语言策略，以及 UI 契约登记的全部玩家可见术语和模板。

`go run ./cmd/content-migrate -data <目录> -write` 会把 v5 内容升级到 v6。迁移不会从题材名称猜测角色声音；旧内容缺少完整 UI 语义时会在写入前明确失败，作者必须补齐 `presentation.ui`，不会静默套用其他故事的默认文案。
