# 世界规则内容层

世界规则采用“YAML 声明策略，Go 执行通用算法”的边界。内容包当前使用 schema v6，并且必须提供 `rules.yml`。

## 文件职责

`rules.yml` 负责声明 NPC 世界模拟中的可选政策：

- `fallback_strategies`：没有可执行作者策略时使用的治疗、成长、补给等候选策略；
- `investigation`：是否自动核验低可信且与人物兴趣相关的事实，以及使用的行动、评分和文案；
- `navigation.retreat`：受伤角色从危险地点撤离的阈值、行动与评分；
- `navigation.contest`：角色接近核心目标所需的知识、阻断知识、野心和伤势边界。
- `player`：玩家核验、市场、移动、分享入口，以及由内容生成的恢复/成长行动；
- `player.resource_warnings`：资源跨越阈值时的可见风险提示，不再由客户端识别具体旗标；
- `economy`：情报出售和唯一物品买断使用的结算资源。

规则可以引用场景自己的 action、fact、item、resource、flag 和文案。加载阶段会拒绝未知行动、事实、物品、条件、效果和目标类型。

市场在 `scenario.yml` 中显式声明 `currency`。动态采购规则只声明物品与数量；引擎根据角色当前位置、实时库存、封锁状态和当前价格生成具体成本与效果。因此故事可以使用自己的货币资源，公共市场结算不再假定 `spirit_stones`。

玩家重复行动可以通过 `repeat_cost.amounts` 声明逐次成本。数组下标对应此前完成次数，超过数组范围后持续使用最后一个数值；说明和警告文案支持 `{stage}`、`{cost}`、`{cumulative}`、`{cost_resource}` 与 `{effect_resource}` 占位符。

## 执行边界

Go 引擎仍然负责：

- 条件与效果原语的类型化解释；
- NPC 候选评分和确定性排序；
- 地图寻路及路线限制；
- 市场报价、库存竞争和原子结算；
- 行动失败回滚、事件审计、存档与重放。

YAML 不支持任意脚本或表达式。新增复杂机制时，应先实现一个可验证、可复用的 Go 原语，再由场景规则提供参数。

## 最小示例

```yaml
fallback_strategies:
- strategy:
    id: recover-from-injury
    action_id: heal
    description: "{actor}暂停原计划并处理伤势"
    conditions:
    - {type: injury_at_least, min_confidence: 2}
    goal_types: [avoid]
    score: {goal: 4, urgency: 5, probability: 5}
    effects:
    - {type: adjust_injury, amount: -1}

investigation:
  enabled: false

navigation:
  retreat: {enabled: false}
  contest: {enabled: false}
```

老版本内容包可以通过 `go run ./cmd/content-migrate -data <目录> -write` 升级。v4 到 v5 的迁移会创建一份全部关闭的显式规则文件；v5 到 v6 会增加类型化对话语言策略与基础 UI 术语，不会擅自推断人物声音或故事行为。
