package report

import (
	"encoding/json"
	"fmt"
	"io"
	"sort"
	"strings"

	"fantu/internal/domain"
)

func Markdown(writer io.Writer, state *domain.WorldState, bundle domain.Bundle) error {
	if _, err := fmt.Fprintf(writer, "# %s：模拟报告\n\n", state.RunTitle); err != nil {
		return err
	}
	outcome := state.Outcome
	if outcome == "" {
		outcome = "尚未结算"
	}
	if _, err := fmt.Fprintf(writer, "- 模拟天数：%d\n- 最终阶段：%s\n- 结局：%s\n- 世界事件：%d\n- NPC 决策记录：%d\n- 世界导演决策：%d\n\n", state.Day, state.Phase, outcome, len(state.Events), len(state.Decisions), len(state.DirectorDecisions)); err != nil {
		return err
	}
	if state.Player != nil {
		playerItems := make([]string, 0)
		for itemID, amount := range state.Player.Items {
			if amount > 0 {
				playerItems = append(playerItems, fmt.Sprintf("%s×%d", itemID, amount))
			}
		}
		sort.Strings(playerItems)
		if _, err := fmt.Fprintf(writer, "- 玩家位置：%s\n- 玩家伤势：%d\n- 玩家资源：%s\n- 玩家物品：%s\n\n", locationName(bundle, state.Player.Location), state.Player.Injury, formattedResources(bundle, state.Player.Resources), strings.Join(playerItems, "、")); err != nil {
			return err
		}
		if len(state.Opportunities) > 0 {
			if _, err := fmt.Fprint(writer, "## 仍可执行的后续机会\n\n"); err != nil {
				return err
			}
			keys := make([]string, 0, len(state.Opportunities))
			for key := range state.Opportunities {
				keys = append(keys, key)
			}
			sort.Strings(keys)
			for _, key := range keys {
				if _, err := fmt.Fprintf(writer, "- `%s`：%s\n", key, state.Opportunities[key]); err != nil {
					return err
				}
			}
			if _, err := fmt.Fprintln(writer); err != nil {
				return err
			}
		}
		relationKeys := make([]string, 0)
		for key, relation := range state.Relations {
			if relation.From == state.Player.ID || relation.To == state.Player.ID {
				relationKeys = append(relationKeys, key)
			}
		}
		if len(relationKeys) > 0 {
			sort.Strings(relationKeys)
			if _, err := fmt.Fprint(writer, "## 玩家相关关系\n\n| 方向 | 信任 | 怀疑 | 畏惧 | 依赖 | 仇恨 | 人情债 |\n| --- | ---: | ---: | ---: | ---: | ---: | ---: |\n"); err != nil {
				return err
			}
			for _, key := range relationKeys {
				relation := state.Relations[key]
				if _, err := fmt.Fprintf(writer, "| %s → %s | %d | %d | %d | %d | %d | %d |\n", displayName(state, relation.From), displayName(state, relation.To), relation.Trust, relation.Suspicion, relation.Fear, relation.Dependence, relation.Hatred, relation.Debt); err != nil {
					return err
				}
			}
			if _, err := fmt.Fprintln(writer); err != nil {
				return err
			}
		}
	}

	if _, err := fmt.Fprintln(writer, "## 关键事件"); err != nil {
		return err
	}
	lastDay := 0
	for _, event := range state.Events {
		if event.Day != lastDay {
			if _, err := fmt.Fprintf(writer, "\n### 第 %d 天\n\n", event.Day); err != nil {
				return err
			}
			lastDay = event.Day
		}
		actor := displayName(state, event.ActorID)
		if actor == "" || actor == "world" {
			actor = "世界"
		}
		if _, err := fmt.Fprintf(writer, "- **%s**：%s `[%s%s]`\n", actor, event.Description, event.ID, eventAuditSuffix(event)); err != nil {
			return err
		}
	}

	if _, err := fmt.Fprint(writer, "\n## 最终角色状态\n\n"); err != nil {
		return err
	}
	if _, err := fmt.Fprintln(writer, "| 角色 | 地点 | 伤势 | 资源 | 关键物品 |"); err != nil {
		return err
	}
	if _, err := fmt.Fprintln(writer, "| --- | --- | ---: | ---: | --- |"); err != nil {
		return err
	}
	ids := make([]string, 0, len(state.NPCs))
	for id := range state.NPCs {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		npc := state.NPCs[id]
		items := make([]string, 0)
		for itemID, amount := range npc.Items {
			if amount > 0 {
				items = append(items, fmt.Sprintf("%s×%d", itemID, amount))
			}
		}
		sort.Strings(items)
		if _, err := fmt.Fprintf(writer, "| %s | %s | %d | %s | %s |\n", npc.Name, locationName(bundle, npc.Location), npc.Injury, formattedResources(bundle, npc.Resources), strings.Join(items, "、")); err != nil {
			return err
		}
	}

	if len(state.DirectorDecisions) > 0 {
		if _, err := fmt.Fprint(writer, "\n## 世界导演审计\n\n"); err != nil {
			return err
		}
		for _, decision := range state.DirectorDecisions {
			if _, err := fmt.Fprintf(writer, "- 第 %d 天：**%s**（`%s`，%d 分，%s）\n", decision.Day, decision.Description, decision.DirectiveID, decision.Score, decision.Source); err != nil {
				return err
			}
			for _, signal := range decision.Signals {
				if _, err := fmt.Fprintf(writer, "  - 信号 `%s:%s=%d`：%s\n", signal.Type, signal.SubjectID, signal.Value, signal.Description); err != nil {
					return err
				}
			}
		}
	}

	if _, err := fmt.Fprint(writer, "\n## NPC 决策审计\n\n"); err != nil {
		return err
	}
	if _, err := fmt.Fprint(writer, "每条记录保留当日最高三个合法候选，用于确认角色没有读取未知事实。\n\n"); err != nil {
		return err
	}
	for _, decision := range state.Decisions {
		if len(decision.Choices) == 0 {
			continue
		}
		choice := decision.Choices[0]
		source := ""
		if choice.Generated {
			source = " `[通用规划]`"
		}
		if _, err := fmt.Fprintf(writer, "- 第 %d 天，%s：**%s**（%d 分）%s\n", decision.Day, decision.ActorName, choice.Description, choice.Score.Total, source); err != nil {
			return err
		}
		if decision.RelationshipChangedTop {
			if _, err := fmt.Fprintf(writer, "  - 若不计关系：首选改为 `%s`\n", decision.WithoutRelationshipStrategyID); err != nil {
				return err
			}
		}
		for _, counterfactual := range decision.Counterfactuals {
			if !counterfactual.Changed {
				continue
			}
			alternative := counterfactual.AlternativeStrategyID
			if alternative == "" {
				alternative = "无合法行动"
			}
			if _, err := fmt.Fprintf(writer, "  - 若移除 %s `%s`（来源 `%s`）：首选改为 `%s`\n", counterfactual.Kind, counterfactual.RemovedKey, counterfactual.TriggerEventID, alternative); err != nil {
				return err
			}
		}
	}
	return nil
}

func formattedResources(bundle domain.Bundle, resources map[string]int) string {
	labels := make(map[string]string, len(bundle.Presentation.Resources))
	for _, definition := range bundle.Presentation.Resources {
		labels[definition.ID] = definition.Label
	}
	keys := make([]string, 0, len(resources))
	for key := range resources {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	parts := make([]string, 0, len(keys))
	for _, key := range keys {
		label := labels[key]
		if label == "" {
			label = key
		}
		parts = append(parts, fmt.Sprintf("%s=%d", label, resources[key]))
	}
	return strings.Join(parts, "、")
}

func eventAuditSuffix(event domain.WorldEvent) string {
	parts := make([]string, 0, 3)
	if event.StrategyID != "" {
		parts = append(parts, "strategy="+event.StrategyID)
	}
	if event.ParentEventID != "" {
		parts = append(parts, "parent="+event.ParentEventID)
	}
	if len(event.TriggerEventIDs) > 0 {
		parts = append(parts, "triggers="+strings.Join(event.TriggerEventIDs, ","))
	}
	if event.PlanID != "" {
		parts = append(parts, "plan="+event.PlanID+"/"+event.PlanStepID)
	}
	if len(parts) == 0 {
		return ""
	}
	return "; " + strings.Join(parts, "; ")
}

func JSON(writer io.Writer, state *domain.WorldState) error {
	encoder := json.NewEncoder(writer)
	encoder.SetIndent("", "  ")
	return encoder.Encode(state)
}

func displayName(state *domain.WorldState, id string) string {
	if state.Player != nil && state.Player.ID == id {
		return state.Player.Name
	}
	if npc, ok := state.NPCs[id]; ok {
		return npc.Name
	}
	return id
}

func locationName(bundle domain.Bundle, id string) string {
	if location, ok := bundle.Locations[id]; ok {
		return location.Name
	}
	return id
}
