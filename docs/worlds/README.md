# 世界内容文档

运行时权威内容位于 `data/<world>/`。本目录解释设计意图、史料边界和验收历史，不替代内容 Schema、静态校验或运行数据。

| 世界 | 用途 | 文档入口 | 运行内容 |
| --- | --- | --- | --- |
| 黑风谷 | 通用模拟与玩法原型基线 | [`blackwind/README.md`](blackwind/README.md) | `data/blackwind/` |
| 天变邸抄 | 当前历史题材正式内容包 | [`tianqi/README.md`](tianqi/README.md) | `data/tianqi/` |
| Orbital | 跨题材可移植性测试 | 暂无独立设计文档 | `data/orbital/` |

新增正式世界时，应同时加入内容编译、批量模拟、Godot 可移植性门禁和本目录导航。通用 Go/GDScript 不得为新世界增加场景 ID、人物 ID、地点 ID 或故事 flag 分支。
