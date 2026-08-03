# 《天启邸抄》正式图片资源清单

本目录包含首个完整美术资产批次，共 53 张正式 PNG。生成原稿归档于
`artifacts/imagegen/tianqi/sources/`，质检预览归档于
`artifacts/imagegen/tianqi/qc/`。

## 人物立绘（28）

| 人物 | 状态 | 正式资源 |
| --- | --- | --- |
| N01 周良辅 | neutral / alert / troubled / decisive | `characters/N01/{neutral,alert,troubled,decisive}.png` |
| N02 裴慎行 | neutral / alert / troubled / decisive | `characters/N02/{neutral,alert,troubled,decisive}.png` |
| N03 柳六安 | neutral / alert / troubled / decisive | `characters/N03/{neutral,alert,troubled,decisive}.png` |
| N04 梁进忠 | neutral | `characters/N04/neutral.png` |
| N05 郑怀朴 | neutral | `characters/N05/neutral.png` |
| N06 沈惟时 | neutral | `characters/N06/neutral.png` |
| N07 余墨林 | neutral / alert / troubled / decisive | `characters/N07/{neutral,alert,troubled,decisive}.png` |
| N08 叶春娘 | neutral / alert / troubled / decisive | `characters/N08/{neutral,alert,troubled,decisive}.png` |
| N09 罗三槐 | neutral / alert / troubled / decisive | `characters/N09/{neutral,alert,troubled,decisive}.png` |
| N10 胡彦清 | neutral | `characters/N10/neutral.png` |

## 地点背景（6）

- `locations/disaster_street/background.png`：王恭厂外街
- `locations/apothecary/background.png`：春和药铺
- `locations/inquiry_office/background.png`：联合会勘公署
- `locations/archive/background.png`：墨林书坊档库
- `locations/warehouse/background.png`：西城仓院
- `locations/study/background.png`：怀朴书斋

## 证物特写（10）

- `evidence/E01/closeup.png`：交割残页
- `evidence/E02/closeup.png`：官库清册
- `evidence/E03/closeup.png`：营房领券
- `evidence/E04/closeup.png`：工食账簿
- `evidence/E05/closeup.png`：车马门禁记录
- `evidence/E06/closeup.png`：现场伤情示意
- `evidence/E07/closeup.png`：证词异本
- `evidence/E08/closeup.png`：灾民名册
- `evidence/E09/closeup.png`：补造账册
- `evidence/E10/closeup.png`：周良辅自陈

## 剧情事件插图（5）

- `events/opening-blast.png`：王恭厂灾变开场
- `events/three-claims.png`：三方争取残页
- `events/official-draft.png`：会勘初稿形成
- `events/forged-ledger-reveal.png`：补造账册疑点显现
- `events/final-verdict.png`：结案会勘

## 地图与界面装饰（4）

- `ui/map/district-map.png`：京师西南片区示意图
- `ui/textures/archive-paper.png`：档案纸张底纹
- `ui/textures/ink-vignette.png`：水墨暗角底纹
- `ui/brand/title-seal.png`：无文字残损朱砂印记

## 使用约束

- 人物正式图为透明背景 PNG；同一人物状态图应按相同基准框对齐。
- 文书图片中的墨迹仅作视觉纹理，不承载可读正文；正文应由界面文字覆盖。
- 场景与事件图按原始宽高比使用，不拉伸、不裁掉关键证物。

## 自动接入约定

`data/tianqi/presentation.yml` 通过 `asset_root: res://assets/tianqi` 启用约定式加载：

- 地点切换自动解析 `locations/<scene_key>/background.png`。
- 人物聚焦自动解析 `characters/<actor_id>/<expression>.png`；缺少情绪态时回退到 `neutral.png`。
- 线索卷宗通过 `facts` 映射自动解析 `evidence/<evidence_id>/closeup.png`。
- 关键行动通过 `event_cues` 选择 `events/<event-key>.png`。
- 地图和通用界面纹理由注册器按固定目录自动发现。

显式 `profile.tres` 或资源路径始终拥有更高优先级，可用于覆盖自动发现结果。
