# 验证与质量门禁

> 状态：操作指南
> 最后核验：2026-08-04
> 命令事实来源：`tools/` 与仓库根 `AGENTS.md`

## 日常验证顺序

1. 运行格式、解析、内容引用和资源路径检查。
2. 运行与修改范围对应的定向测试。
3. 运行目标场景快速烟测。
4. 准备提交时运行完整 Go 与 Godot 门禁。
5. 正式录制前运行快速路线预检，录制后校验音视频流和输出格式。

## 常用入口

```powershell
./tools/verify.ps1
./tools/verify-godot.ps1 -Mode fast
./tools/verify-godot.ps1 -Mode full
./tools/verify-tianqi.ps1 -Mode fast
./tools/capture-ui-states.ps1 -DataDirectory data/tianqi -Resolutions @('1280x800','1920x1080')
./tools/record-gameplay.ps1
```

内容包可以独立验证：

```powershell
go run ./cmd/fantu-content validate data/tianqi
go run ./cmd/fantu-content graph data/tianqi
go run ./cmd/fantu-content simulate data/tianqi --runs 200 --seed 1
```

## AI 模式

确定性门禁必须显式关闭 AI，并确保 `.env`、用户设置和开发者机器上的密钥不会重新启用模型。真实模型测试使用独立入口和独立报告，不得把网络失败混入普通回归结果。

模型启用后，超时、取消、空响应、结构错误、内容校验失败和提供方错误必须原样失败；不得用模板、本地规则、旧缓存或另一模型结果替代本次调用。

## 文档检查

```powershell
./tools/verify-docs.ps1
```

该检查覆盖仓库 Markdown 的本地链接。历史文档允许描述旧行为，但必须位于 `docs/archive/`，并通过当前文档中心明确标记为非权威来源。
