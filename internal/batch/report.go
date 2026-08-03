package batch

import (
	"fmt"
	"io"
	"math"
	"sort"
)

func Markdown(writer io.Writer, summary Summary) error {
	title := summary.Title
	if title == "" {
		title = "场景"
	}
	contestItem := summary.ContestItemName
	if contestItem == "" {
		contestItem = "核心资源"
	}
	mode := "固定验收场景"
	if summary.Sweep != nil {
		mode = "参数扫描"
	}
	validCount := len(summary.Results) - summary.InvalidCount
	efficacy := 0.0
	if summary.Investigations > 0 {
		efficacy = float64(summary.UsefulInvestigations) * 100 / float64(summary.Investigations)
	}
	concentration := 0.0
	for _, count := range summary.FailureFollowUps {
		if summary.FailureCount > 0 && float64(count)*100/float64(summary.FailureCount) > concentration {
			concentration = float64(count) * 100 / float64(summary.FailureCount)
		}
	}
	relationshipRate := ratio(summary.RelationshipChanged, summary.RelationshipRelevant)
	counterfactualRate := ratio(summary.CounterfactualChanges, summary.CounterfactualTests)
	entropy := ownerEntropy(summary.OwnerDistribution)
	idleRate := ratio(summary.IdleNPCDays, summary.NPCDays)
	repeatRate := ratio(summary.RepeatedSelections, summary.DecisionTransitions)
	if _, err := fmt.Fprintf(writer, "# %s批量模拟报告\n\n- 模式：%s\n- 运行数量：%d\n- 有效运行：%d\n- 无效变体：%d\n- 不同归属：%d\n- 结局熵：%.3f bits\n- NPC 空闲率：%d/%d（%.1f%%）\n- 连续决策重复率：%d/%d（%.1f%%）\n- 调查有效率：%d/%d（%.1f%%）\n- 关系改变首选：%d/%d（%.1f%%）\n- 单信息反事实改变首选：%d/%d（%.1f%%）\n- 失败后续分支：%d 种，最高集中度 %.1f%%\n- 警告数量：%d\n", title, mode, len(summary.Results), validCount, summary.InvalidCount, len(summary.OwnerDistribution), entropy, summary.IdleNPCDays, summary.NPCDays, idleRate, summary.RepeatedSelections, summary.DecisionTransitions, repeatRate, summary.UsefulInvestigations, summary.Investigations, efficacy, summary.RelationshipChanged, summary.RelationshipRelevant, relationshipRate, summary.CounterfactualChanges, summary.CounterfactualTests, counterfactualRate, len(summary.FailureFollowUps), concentration, len(summary.Warnings)); err != nil {
		return err
	}
	if summary.Sweep != nil {
		if _, err := fmt.Fprintf(writer, "- 种子数量：%d\n- 资源扰动：±%d\n- 关系扰动：±%d\n- 行动成本扰动：±%d\n- 初始认知扰动：±%d\n- 世界结构扰动：±%d\n\n", len(summary.Sweep.Seeds), summary.Sweep.ResourceDelta, summary.Sweep.RelationshipDelta, summary.Sweep.CostDelta, summary.Sweep.BeliefDelta, summary.Sweep.WorldDelta); err != nil {
			return err
		}
		if err := writeScenarioStability(writer, summary); err != nil {
			return err
		}
	} else {
		if _, err := fmt.Fprintf(writer, "\n## 场景结果\n\n| 场景 | %s归属 | 世界事件 | 决策记录 | 有效调查/调查 | 开放机会 | 结局 |\n| --- | --- | ---: | ---: | ---: | ---: | --- |\n", contestItem); err != nil {
			return err
		}
		for _, result := range summary.Results {
			if _, err := fmt.Fprintf(writer, "| %s | %s | %d | %d | %d/%d | %d | %s |\n", result.RunID, result.OwnerName, result.EventCount, result.DecisionCount, result.UsefulInvestigations, result.Investigations, result.OpenOpportunities, result.Outcome); err != nil {
				return err
			}
		}
	}

	if _, err := fmt.Fprint(writer, "\n## 归属分布\n\n| 持有者 | 次数 | 占比 |\n| --- | ---: | ---: |\n"); err != nil {
		return err
	}
	for _, entry := range sortedCounts(summary.OwnerDistribution) {
		percentage := 0.0
		if validCount > 0 {
			percentage = float64(entry.Count) * 100 / float64(validCount)
		}
		if _, err := fmt.Fprintf(writer, "| %s | %d | %.1f%% |\n", entry.Name, entry.Count, percentage); err != nil {
			return err
		}
	}

	if _, err := fmt.Fprint(writer, "\n## 行动分布\n\n| 行动 | 完成次数 |\n| --- | ---: |\n"); err != nil {
		return err
	}
	for _, entry := range sortedCounts(summary.ActionDistribution) {
		if _, err := fmt.Fprintf(writer, "| %s | %d |\n", entry.Name, entry.Count); err != nil {
			return err
		}
	}

	if _, err := fmt.Fprint(writer, "\n## 失败后续分布\n\n| 后续行动 | 次数 |\n| --- | ---: |\n"); err != nil {
		return err
	}
	for _, entry := range sortedCounts(summary.FailureFollowUps) {
		if _, err := fmt.Fprintf(writer, "| %s | %d |\n", entry.Name, entry.Count); err != nil {
			return err
		}
	}

	if _, err := fmt.Fprint(writer, "\n## 规则覆盖矩阵\n\n| 规则 | 命中次数 |\n| --- | ---: |\n"); err != nil {
		return err
	}
	for _, entry := range sortedCounts(summary.RuleCoverage) {
		if _, err := fmt.Fprintf(writer, "| %s | %d |\n", entry.Name, entry.Count); err != nil {
			return err
		}
	}

	if _, err := fmt.Fprint(writer, "\n## 资源净流\n\n| 资源 | 净变化 |\n| --- | ---: |\n"); err != nil {
		return err
	}
	resourceNames := make([]string, 0, len(summary.ResourceFlow))
	for name := range summary.ResourceFlow {
		resourceNames = append(resourceNames, name)
	}
	sort.Strings(resourceNames)
	for _, name := range resourceNames {
		if _, err := fmt.Fprintf(writer, "| %s | %+d |\n", name, summary.ResourceFlow[name]); err != nil {
			return err
		}

	}

	if _, err := fmt.Fprint(writer, "\n## 警告\n\n"); err != nil {
		return err
	}
	if len(summary.Warnings) == 0 {
		_, err := fmt.Fprintln(writer, "- 无")
		return err
	}
	for _, warning := range summary.Warnings {
		if _, err := fmt.Fprintf(writer, "- %s\n", warning); err != nil {
			return err
		}
	}
	return nil
}

func ownerEntropy(distribution map[string]int) float64 {
	total := 0
	for _, count := range distribution {
		total += count
	}
	if total == 0 {
		return 0
	}
	entropy := 0.0
	for _, count := range distribution {
		probability := float64(count) / float64(total)
		entropy -= probability * math.Log2(probability)
	}
	return entropy
}

func ratio(numerator, denominator int) float64 {
	if denominator == 0 {
		return 0
	}
	return float64(numerator) * 100 / float64(denominator)
}

func writeScenarioStability(writer io.Writer, summary Summary) error {
	byScenario := make(map[string]map[string]int)
	invalid := make(map[string]int)
	for _, result := range summary.Results {
		if byScenario[result.BaseRunID] == nil {
			byScenario[result.BaseRunID] = make(map[string]int)
		}
		if result.Error != "" {
			invalid[result.BaseRunID]++
			continue
		}
		byScenario[result.BaseRunID][result.OwnerName]++
	}
	ids := make([]string, 0, len(byScenario))
	for id := range byScenario {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	if _, err := fmt.Fprint(writer, "## 场景稳定性\n\n| 场景 | 最常见归属 | 次数 | 有效运行稳定率 | 不同归属 | 无效变体 |\n| --- | --- | ---: | ---: | ---: | ---: |\n"); err != nil {
		return err
	}
	for _, id := range ids {
		entries := sortedCounts(byScenario[id])
		if len(entries) == 0 {
			if _, err := fmt.Fprintf(writer, "| %s | — | 0 | 0.0%% | 0 | %d |\n", id, invalid[id]); err != nil {
				return err
			}
			continue
		}
		top := entries[0]
		total := 0
		for _, entry := range entries {
			total += entry.Count
		}
		if _, err := fmt.Fprintf(writer, "| %s | %s | %d | %.1f%% | %d | %d |\n", id, top.Name, top.Count, float64(top.Count)*100/float64(total), len(entries), invalid[id]); err != nil {
			return err
		}
	}
	return nil
}

type countEntry struct {
	Name  string
	Count int
}

func sortedCounts(counts map[string]int) []countEntry {
	entries := make([]countEntry, 0, len(counts))
	for name, count := range counts {
		entries = append(entries, countEntry{Name: name, Count: count})
	}
	sort.Slice(entries, func(i, j int) bool {
		if entries[i].Count != entries[j].Count {
			return entries[i].Count > entries[j].Count
		}
		return entries[i].Name < entries[j].Name
	})
	return entries
}
