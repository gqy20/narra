# 凡途文档中心

> 状态：权威导航
> 最后核验：2026-08-04
> 维护原则：代码与内容包是运行事实，文档负责解释边界、流程和设计意图。

这里是仓库文档的唯一入口。阅读文档前先确认它的状态：

- **权威规范**：描述当前有效的产品、架构或内容边界，修改实现时应同步更新。
- **操作指南**：描述可复现的开发、验证、打包和诊断流程。
- **当前计划**：只在 [`product/ROADMAP.md`](product/ROADMAP.md) 维护。
- **世界文档**：只对对应内容包生效，不得被通用代码当作默认规则。
- **历史记录**：保存在 [`archive/`](archive/README.md)，用于追溯决策，不代表当前实现。

## 推荐阅读路线

### 了解产品

1. [`product/PRODUCT.md`](product/PRODUCT.md) — 产品愿景、玩法原则和长期范围。
2. [`product/DEMO_SCOPE.md`](product/DEMO_SCOPE.md) — 当前交互 Demo 的冻结范围与完成线。
3. [`product/ROADMAP.md`](product/ROADMAP.md) — 唯一有效的后续工作优先级。

### 修改系统

1. [`architecture/OVERVIEW.md`](architecture/OVERVIEW.md) — 模块边界、依赖方向和运行数据流。
2. [`architecture/CONTENT.md`](architecture/CONTENT.md) — 内容编译、语言与表现配置契约。
3. [`architecture/WORLD_RULES.md`](architecture/WORLD_RULES.md) — YAML 规则与通用 Go 算法的边界。
4. [`architecture/WORLD_DIRECTOR.md`](architecture/WORLD_DIRECTOR.md) — 世界导演权限、审计与重放。
5. [`design/UI_DIRECTION.md`](design/UI_DIRECTION.md) — Godot 信息层级和视觉验收目标。

### 开发和发布

1. [`development/DEVELOPMENT.md`](development/DEVELOPMENT.md) — 环境与日常工作流。
2. [`development/VALIDATION.md`](development/VALIDATION.md) — 分层验证入口和 AI 模式要求。
3. [`development/PACKAGING.md`](development/PACKAGING.md) — Windows 构建和产物。
4. [`development/LOGGING.md`](development/LOGGING.md) — 日志、诊断和隐私边界。

### 修改内容包

- [`worlds/README.md`](worlds/README.md) — 内容包与文档的对应关系。
- [`worlds/blackwind/README.md`](worlds/blackwind/README.md) — 黑风谷原型基线与验收历史。
- [`worlds/tianqi/README.md`](worlds/tianqi/README.md) — 《天变邸抄》的叙事、研究与美术入口。

## 权威性速查

| 主题 | 当前权威来源 | 说明 |
| --- | --- | --- |
| 产品方向 | `product/PRODUCT.md` | 稳定意图；当前优先级以路线图为准 |
| 当前范围 | `product/DEMO_SCOPE.md` | 冻结范围和完成门禁 |
| 后续计划 | `product/ROADMAP.md` | 不在其他文档维护第二份待办 |
| 运行架构 | `architecture/OVERVIEW.md` | 代码边界与数据流 |
| 内容契约 | `architecture/CONTENT.md` + Schema/校验器 | 代码和 Schema 冲突时以可执行校验为准 |
| 开发命令 | `development/DEVELOPMENT.md` | 验证细节由 `development/VALIDATION.md` 补充 |
| 世界事实 | `data/<world>/` | 世界文档解释设计，不覆盖运行内容 |
| 历史结论 | `archive/` | 只用于追溯，不作为当前需求 |

新增文档前先判断能否补充现有权威文档。阶段报告、一次性审计和已完成计划应直接进入 `archive/`，避免根目录重新变成待办堆栈。
