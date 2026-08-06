# 内容语言与表现配置

> 状态：权威内容契约说明
> 最后核验：2026-08-04
> 可执行事实来源：内容 Schema、`internal/scenario` 校验器与官方内容包

## 内容编译器

所有正式内容包在启动游戏前应通过统一入口：

```text
go run ./cmd/narra-content validate data/tianqi
go run ./cmd/narra-content graph data/tianqi
go run ./cmd/narra-content test data/tianqi
go run ./cmd/narra-content simulate data/tianqi --runs 200 --seed 1
```

`validate`/`test` 组合运行结构解码、字段契约、引用、剧情状态图、时间窗口、Flag 使用和表现资源检查；诊断尽可能带 YAML 文件与行号。`graph` 输出 Mermaid 状态图。`simulate` 使用可复现随机种子完整游玩并输出行动、剧情选择和结局覆盖率。

`tools/verify.ps1` 会验证 `blackwind`、`tianqi` 和 `orbital` 三个正式内容包。新增正式世界必须加入该列表，并在只新增 `data/<world>` 的前提下通过 CLI、存档重放、模拟和 Godot 移植测试。

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

## 内容 Schema v7

Schema v7 在完整的对话语言策略与 UI 术语契约之外，要求 `rules.yml` 为玩家声明 `conversation` 能力。该能力引用一个内容包行动，其时长就是一次成功自然语言交谈消耗的世界时间；通用代码不硬编码“拜访”“交谈”等题材文案，也不自行猜测时长。

加载器只接受 Schema v7，不提供旧内容自动迁移。旧内容必须由作者在仓库外显式升级并补齐 `dialogue.yml`、`presentation.ui` 与 `rules.player.conversation`，再通过 `narra-content validate` 验证；运行时不会推断或补写故事语义。
