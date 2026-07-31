# Godot MVP

这是 `internal/app.PlayerView` 的薄客户端，不包含规则、隐藏状态或行动合法性判断。

在仓库根目录运行：

```powershell
./tools/run-godot.ps1
```

脚本会构建并启动仅监听 `127.0.0.1:8787` 的 Go 服务，再启动 Godot 项目；退出 Godot 后会关闭本次启动的服务。也可以分别运行 `go run ./cmd/server` 与：

```powershell
godot --path godot
```

客户端固定使用 `autosave` 存档槽，每次成功行动后自动保存。当前界面包括自身、线索、局势、回合反馈、同地人物和可行行动六区；“告知”动作按人物折叠，避免人物与线索组合挤满行动列表。跨日推进和传播行动会展示应用层提供的机会、期限与可信度警告；结局态由完整传播路线集成测试覆盖。
