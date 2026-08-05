# B站 AI 创造公开赛视频工程

本目录保存 Narra 参赛宣传片的可复现源工程、逐句解说、Remotion 动画和发布文案。录制原片、生成配音、背景音乐、渲染中间文件与最终成片统一写入仓库已忽略的 `artifacts/`，不得进入普通源码提交。

## 权威文件

| 文件 | 职责 |
| --- | --- |
| `project.json` | 原片映射、段落边界、音频混合、字幕和输出规格 |
| `script/narration.yml` | 唯一口播与字幕文本，每句使用稳定的 `n01`～`n24` 标识 |
| `script/storyboard.md` | 每句对应的镜头意图和剪辑约束 |
| `script/sources.md` | 历史、创作、技术与发布断言依据 |
| `remotion/` | 开场和架构动画源工程 |
| `PUBLISHING.md` | B站标题、简介、标签、置顶评论和投稿检查清单 |
| `cover/` | 发布封面候选，PNG 由 Git LFS 管理 |

口播只在 `narration.yml` 维护，字幕由构建脚本生成，不另存一份可漂移的字幕文案。修改历史、技术或发布状态时，同时更新 `script/sources.md`。

## 本地依赖

- PowerShell 7；
- `mmx`，已完成 MiniMax 鉴权；
- `ffmpeg` 与 `ffprobe`；
- Node.js、npm 和 Microsoft Edge；
- 已按 `project.json` 录制的 4K 游戏原片；
- Remotion 依赖通过 `npm ci` 安装，不提交 `node_modules`。

在仓库根目录检查工具：

```powershell
mmx quota show --output json --quiet
ffmpeg -version
ffprobe -version
node --version
npm --version
```

## 原片与本地产物

`project.json` 中的 `sources` 指向本地 `artifacts/recordings/`。带时间戳的目录是经过人工确认的画面锁定版本；如果重新录制，应显式更新这些路径并重新核对每段 `in`/`out`，不能让脚本自动选择“最新文件”后静默改变剪辑内容。

当前构建还依赖：

- `artifacts/contest-video/bilibili-ai-contest-2026/music/fantu-bgm-v2.mp3`；
- `artifacts/contest-video/bilibili-ai-contest-2026/narration/lyrical-1.2x/` 下的逐句配音；
- `artifacts/contest-video/bilibili-ai-contest-2026/motion/` 下的 Remotion 输出。

这些文件均为可再生成或可重新录制的本地产物，不提交 Git。项目源文件引用它们是为了记录正式剪辑使用的确切输入，不代表仓库克隆后自带原片。

## 逐句生成配音

首次生成全部缺失句子：

```powershell
./tools/generate-contest-narration.ps1
```

只重录被修改的句子：

```powershell
./tools/generate-contest-narration.ps1 -SegmentIds n23
./tools/generate-contest-narration.ps1 -SegmentIds n14,n23
```

使用 `-SegmentIds` 时，指定句子会强制重新生成，其他句子保持不变；如果其他必需音频不存在，脚本会失败而不是悄悄扩大生成范围。`-Force` 只用于明确需要重录全部 24 句的情况。

每次生成都会重建 `generation-manifest.json`，记录实际文本、模型、音色、速度、时长、采样率和文件位置。修改 `narration.yml` 后，必须确认清单中的对应文本已经更新，再开始视频合成。

## 渲染 Remotion 动画

```powershell
Push-Location video/bilibili-ai-contest-2026/remotion
npm ci
npm run render
Pop-Location
```

这会先从锁定原片提取开场所需镜头，再生成：

- `motion/opening-4k.mp4`；
- `motion/architecture-4k.mp4`。

动画固定为 3840×2160、30 FPS。技术 Logo、官方界面和项目截图的来源与使用边界见 `remotion/public/tech/SOURCES.md`。

## 合成与对齐

```powershell
./tools/build-contest-video.ps1
```

构建顺序为：逐句配音预处理、句间与段间停顿、字幕生成、分段画面对齐、游戏音轨与《凡途》音乐混合、4K 成片编码、720p 审阅版编码。音频、字幕和画面通过 `n01`～`n24` 及段落配置关联，允许在不修改画面的情况下单独重录某句。

主要输出：

- `final/narra-bilibili-ai-contest-4k.mp4`；
- `final/narra-bilibili-ai-contest-preview-720p.mp4`；
- `timing.json`、`alignment.csv`、`subtitles.ass` 与 `subtitles.srt`。

`alignment.csv` 中任一段的视频或音频时长与目标相差超过 0.08 秒时，构建必须失败。

## 发布前验收

1. 核对 `generation-manifest.json` 与 `narration.yml` 的 24 句文本一致。
2. 检查 `alignment.csv`，确认各段没有截断音频。
3. 使用 720p 审阅版完整检查字幕错字、镜头对应和段落停顿。
4. 校验 4K 成片为 3840×2160、30 FPS、H.264/AAC、`yuv420p`、SAR 1:1，并同时包含视频流和音频流。
5. 从最终成片填写 `PUBLISHING.md` 中的真实章节时间码，不保留 `00:00` 占位。
6. 发布当天再次核对 GitHub Release、比赛规则、素材授权和首次公开要求。

## Git 边界

应提交：脚本、配置、解说、分镜、发布文档、Remotion 源码、来源说明、锁文件及明确选定的封面和参考截图。

不得提交：`artifacts/`、`node_modules/`、`remotion/public/generated/` 中的临时影片、逐句音频、音乐、最终成片、转码中间文件、日志和缓存。
