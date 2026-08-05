# 宣传片素材来源与使用边界

> 最后核验：2026-08-05
> 用途：记录进入 Remotion 动画和发布封面的外部素材、项目截图与生成素材。来源记录不替代原作者许可和商标规则。

## 外部技术素材

| 本地文件 | 来源 | 许可与使用边界 |
| --- | --- | --- |
| `godot.svg` | [Godot 官方仓库 `misc/logo/logo_outlined.svg`](https://github.com/godotengine/godot/blob/master/misc/logo/logo_outlined.svg) | Godot Press Kit 将 Logo 标为 [CC BY 4.0](https://godotengine.org/press/)。本视频不修改比例，只用于说明项目采用 Godot，不暗示 Godot Foundation 背书。 |
| `godot.png` | 由上述 Godot SVG 转成的栅格备用图 | 沿用上述署名与商标使用边界；当前动画优先使用 SVG。 |
| `godot-editor.jpg` | [Godot Design `screenshots/editor_tps_demo_1920x1080.jpg`](https://github.com/godotengine/godot-design/blob/master/screenshots/editor_tps_demo_1920x1080.jpg) | `godot-design` 仓库声明为 [CC BY 4.0](https://github.com/godotengine/godot-design/blob/master/LICENSE)，用于展示 Godot 官方编辑器界面。 |
| `go.svg` | [Go 官方白色 Logo](https://go.dev/images/go-logo-white.svg) | Go Logo 是 Google 的商标，使用遵循 [Go Brand and Trademark Usage Guidelines](https://go.dev/brand)：保持原样，仅用于如实说明技术栈，不暗示官方认可。 |
| `github.svg` | [Primer Octicons `mark-github-24.svg`](https://github.com/primer/octicons/blob/main/icons/mark-github-24.svg) | Octicons 代码以 [MIT License](https://github.com/primer/octicons/blob/main/LICENSE) 提供；GitHub 标识仅用于指向本项目仓库与 Release，不作为 Narra 品牌或暗示 GitHub 背书。 |

YAML 官方站点当前没有提供适合本片且稳定的独立 SVG 标识，因此动画只使用 `YAML 1.2` 文字，不伪造“官方 Logo”。

## 项目自产素材

| 本地文件 | 来源与处理 |
| --- | --- |
| `ai-dialogue.png` | 从本项目《天变邸抄》真实 AI NPC 4K 录制约 58 秒处截取，只用于展示实际运行界面。 |
| `fantu-gameplay.jpg` | 从本项目《凡途》4K 框架展示录制约 14 秒处截取，只用于证明同一客户端可运行第二个内容包。 |
| `../../../cover/bilibili-cover-v1.png` | 2026-08-05 使用 OpenAI 内置 imagegen 生成，输入参考为上述 `ai-dialogue.png`；人物、灾后街巷与对话构图来自项目画面，文字为宣传片自有文案。 |

截图中的人物立绘、背景、字体和界面资源继续遵循 Narra 仓库内各自的资源清单与许可证。生成封面不得被描述为游戏实机截图；发布简介和视频正文应同时展示真实运行画面。
