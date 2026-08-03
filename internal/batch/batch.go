package batch

import (
	"fmt"
	"path/filepath"
	"sort"

	"fantu/internal/domain"
	"fantu/internal/engine"
	"fantu/internal/scenario"
)

type Result struct {
	RunID                 string
	BaseRunID             string
	Title                 string
	Seed                  int64
	Swept                 bool
	Outcome               string
	OwnerID               string
	OwnerName             string
	EventCount            int
	DecisionCount         int
	OpenOpportunities     int
	ActionCounts          map[string]int
	ResourceFlow          map[string]int
	Investigations        int
	UsefulInvestigations  int
	FailureCount          int
	FailureFollowUps      map[string]int
	RelationshipRelevant  int
	RelationshipChanged   int
	CounterfactualTests   int
	CounterfactualChanges int
	RuleCoverage          map[string]int
	NPCDays               int
	IdleNPCDays           int
	DecisionTransitions   int
	RepeatedSelections    int
	Error                 string
}

type Summary struct {
	Title                 string
	ContestItemName       string
	Results               []Result
	OwnerDistribution     map[string]int
	ActionDistribution    map[string]int
	ResourceFlow          map[string]int
	Warnings              []string
	Sweep                 *SweepInfo
	InvalidCount          int
	Investigations        int
	UsefulInvestigations  int
	FailureCount          int
	FailureFollowUps      map[string]int
	RelationshipRelevant  int
	RelationshipChanged   int
	CounterfactualTests   int
	CounterfactualChanges int
	RuleCoverage          map[string]int
	NPCDays               int
	IdleNPCDays           int
	DecisionTransitions   int
	RepeatedSelections    int
}

type SweepInfo struct {
	Seeds             []int64
	ResourceDelta     int
	RelationshipDelta int
	CostDelta         int
	BeliefDelta       int
	WorldDelta        int
}

func LoadPlans(dir string, bundle domain.Bundle) ([]domain.RunPlan, error) {
	paths, err := filepath.Glob(filepath.Join(dir, "*.json"))
	if err != nil {
		return nil, fmt.Errorf("list plans: %w", err)
	}
	sort.Strings(paths)
	plans := make([]domain.RunPlan, 0, len(paths))
	for _, path := range paths {
		plan, err := scenario.LoadPlan(path, bundle)
		if err != nil {
			return nil, fmt.Errorf("load plan %s: %w", path, err)
		}
		plans = append(plans, plan)
	}
	return plans, nil
}

func Run(bundle domain.Bundle, plans []domain.RunPlan, includeBaseline bool) (Summary, error) {
	summary := Summary{
		Title: bundle.Scenario.Title, ContestItemName: contestItemName(bundle),
		OwnerDistribution:  make(map[string]int),
		ActionDistribution: make(map[string]int),
		ResourceFlow:       make(map[string]int),
		FailureFollowUps:   make(map[string]int),
		RuleCoverage:       make(map[string]int),
	}
	if includeBaseline {
		state, err := engine.New(bundle).Run()
		if err != nil {
			return summary, fmt.Errorf("run baseline: %w", err)
		}
		summary.add(summarize(bundle, state))
	}
	for _, plan := range plans {
		state, err := engine.NewWithPlan(bundle, plan).Run()
		if err != nil {
			return summary, fmt.Errorf("run %s: %w", plan.ID, err)
		}
		summary.add(summarize(bundle, state))
	}
	summary.buildWarnings(bundle, plans)
	return summary, nil
}

func contestItemName(bundle domain.Bundle) string {
	if item, ok := bundle.Items[bundle.Scenario.Contest.ItemID]; ok && item.Name != "" {
		return item.Name
	}
	return bundle.Scenario.Contest.ItemID
}

func summarize(bundle domain.Bundle, state *domain.WorldState) Result {
	ownerID := state.Items[bundle.Scenario.Contest.ItemID]
	result := Result{
		RunID: state.RunID, BaseRunID: state.RunID, Title: state.RunTitle, Outcome: state.Outcome,
		OwnerID: ownerID, OwnerName: actorName(bundle, state, ownerID),
		EventCount: len(state.Events), DecisionCount: len(state.Decisions),
		OpenOpportunities: len(state.Opportunities),
		ActionCounts:      make(map[string]int), ResourceFlow: make(map[string]int),
		FailureFollowUps: make(map[string]int), RuleCoverage: make(map[string]int),
	}
	for _, event := range state.Events {
		if event.ActionID != "" && (event.Type == "action" || event.Type == "player_action") {
			result.ActionCounts[event.ActionID]++
		}
		for _, effect := range event.Effects {
			result.RuleCoverage["effect:"+string(effect.Type)]++
			if effect.Type == "adjust_resource" {
				result.ResourceFlow[effect.Key] += effect.Amount
			}
		}
		for _, condition := range event.Conditions {
			result.RuleCoverage["condition:"+string(condition.Type)]++
		}
		if event.Type == "action_failed" || event.Type == "action_interrupted" || event.Type == "player_command_skipped" || event.Type == "debt_defaulted" {
			result.RuleCoverage["failure:"+event.Type]++
		}
	}
	result.Investigations, result.UsefulInvestigations = investigationEfficacy(state.Events, bundle.Rules.Investigation.ActionID, bundle.Rules.Player.Investigation.ActionID)
	result.FailureCount, result.FailureFollowUps = failureDiversity(state.Events)
	result.NPCDays, result.IdleNPCDays = idleNPCDays(state)
	result.DecisionTransitions, result.RepeatedSelections = decisionRepetition(state.Decisions)
	for _, decision := range state.Decisions {
		if decision.RelationshipRelevant {
			result.RelationshipRelevant++
		}
		if decision.RelationshipChangedTop {
			result.RelationshipChanged++
		}
		for _, counterfactual := range decision.Counterfactuals {
			result.CounterfactualTests++
			if counterfactual.Changed {
				result.CounterfactualChanges++
			}
		}
	}
	return result
}

func investigationEfficacy(events []domain.WorldEvent, actionIDs ...string) (int, int) {
	trackedActions := make(map[string]bool, len(actionIDs))
	for _, actionID := range actionIDs {
		if actionID != "" {
			trackedActions[actionID] = true
		}
	}
	investigations := make(map[string]bool)
	useful := make(map[string]bool)
	for _, event := range events {
		if trackedActions[event.ActionID] && (event.Type == "action" || event.Type == "player_action") {
			investigations[event.ID] = true
		}
		for _, triggerID := range event.TriggerEventIDs {
			if investigations[triggerID] {
				useful[triggerID] = true
			}
		}
	}
	return len(investigations), len(useful)
}

func failureDiversity(events []domain.WorldEvent) (int, map[string]int) {
	followUps := make(map[string]int)
	failures := 0
	for i, event := range events {
		if event.Type != "action_failed" && event.Type != "action_interrupted" {
			continue
		}
		failures++
		followUp := "none"
		for _, later := range events[i+1:] {
			if later.ActorID != event.ActorID || (later.Type != "action" && later.Type != "player_action" && later.Type != "action_start") {
				continue
			}
			followUp = later.ActionID
			if followUp == "" {
				followUp = later.StrategyID
			}
			break
		}
		followUps[followUp]++
	}
	return failures, followUps
}

func (s *Summary) add(result Result) {
	s.Results = append(s.Results, result)
	if result.Error != "" {
		s.InvalidCount++
		return
	}
	s.OwnerDistribution[result.OwnerName]++
	for action, count := range result.ActionCounts {
		s.ActionDistribution[action] += count
	}
	for resource, amount := range result.ResourceFlow {
		s.ResourceFlow[resource] += amount
	}
	s.Investigations += result.Investigations
	s.UsefulInvestigations += result.UsefulInvestigations
	s.FailureCount += result.FailureCount
	if s.FailureFollowUps == nil {
		s.FailureFollowUps = make(map[string]int)
	}
	for actionID, count := range result.FailureFollowUps {
		s.FailureFollowUps[actionID] += count
	}
	if s.RuleCoverage == nil {
		s.RuleCoverage = make(map[string]int)
	}
	for rule, count := range result.RuleCoverage {
		s.RuleCoverage[rule] += count
	}
	s.NPCDays += result.NPCDays
	s.IdleNPCDays += result.IdleNPCDays
	s.DecisionTransitions += result.DecisionTransitions
	s.RepeatedSelections += result.RepeatedSelections
	s.RelationshipRelevant += result.RelationshipRelevant
	s.RelationshipChanged += result.RelationshipChanged
	s.CounterfactualTests += result.CounterfactualTests
	s.CounterfactualChanges += result.CounterfactualChanges
}

func idleNPCDays(state *domain.WorldState) (int, int) {
	total := len(state.NPCs) * state.Day
	active := make(map[string]bool)
	for _, decision := range state.Decisions {
		active[fmt.Sprintf("%s:%d", decision.ActorID, decision.Day)] = true
	}
	starts := make(map[string]domain.WorldEvent)
	for _, event := range state.Events {
		if _, npc := state.NPCs[event.ActorID]; !npc {
			continue
		}
		if event.Type == "action_start" {
			starts[event.ID] = event
		}
		if event.Type == "action" || event.Type == "action_failed" || event.Type == "action_interrupted" {
			active[fmt.Sprintf("%s:%d", event.ActorID, event.Day)] = true
			if start, ok := starts[event.ParentEventID]; ok {
				for day := start.Day; day <= event.Day; day++ {
					active[fmt.Sprintf("%s:%d", event.ActorID, day)] = true
				}
			}
		}
	}
	idle := total - len(active)
	if idle < 0 {
		idle = 0
	}
	return total, idle
}

func decisionRepetition(decisions []domain.DecisionRecord) (int, int) {
	last := make(map[string]string)
	transitions, repeated := 0, 0
	for _, decision := range decisions {
		if len(decision.Choices) == 0 {
			continue
		}
		actionID := decision.Choices[0].ActionID
		if previous, ok := last[decision.ActorID]; ok {
			transitions++
			if previous == actionID {
				repeated++
			}
		}
		last[decision.ActorID] = actionID
	}
	return transitions, repeated
}

func (s *Summary) buildWarnings(bundle domain.Bundle, plans []domain.RunPlan) {
	if len(s.Results) == 0 {
		s.Warnings = append(s.Warnings, "没有可用的模拟结果")
		return
	}
	if s.InvalidCount > 0 {
		s.Warnings = append(s.Warnings, fmt.Sprintf("%d/%d 个参数变体因预定玩家命令不再满足条件而中止", s.InvalidCount, len(s.Results)))
	}
	maxOwner, maxCount := "", 0
	for owner, count := range s.OwnerDistribution {
		if count > maxCount || (count == maxCount && owner < maxOwner) {
			maxOwner, maxCount = owner, count
		}
	}
	validCount := len(s.Results) - s.InvalidCount
	if validCount > 0 && maxCount*2 > validCount {
		s.Warnings = append(s.Warnings, fmt.Sprintf("%s 占据 %d/%d 个有效结局，可能存在单一归属偏置", maxOwner, maxCount, validCount))
	}
	for _, result := range s.Results {
		if result.Outcome == "" {
			s.Warnings = append(s.Warnings, fmt.Sprintf("%s 没有生成结局", result.RunID))
		}
		if result.EventCount == 0 {
			s.Warnings = append(s.Warnings, fmt.Sprintf("%s 没有生成世界事件", result.RunID))
		}
	}
	actionIDs := make([]string, 0, len(bundle.Actions))
	referenced := make(map[string]bool)
	for _, npc := range bundle.NPCs {
		for _, strategy := range npc.Strategies {
			referenced[strategy.ActionID] = true
		}
	}
	for _, plan := range plans {
		for _, command := range plan.Commands {
			markReferencedCommand(referenced, command)
		}
	}
	for actionID := range bundle.Actions {
		actionIDs = append(actionIDs, actionID)
	}
	sort.Strings(actionIDs)
	for _, actionID := range actionIDs {
		if s.ActionDistribution[actionID] == 0 {
			if !referenced[actionID] {
				s.Warnings = append(s.Warnings, fmt.Sprintf("行动 %s 未被场景策略、玩家命令或通用规划器覆盖", actionID))
			} else {
				s.Warnings = append(s.Warnings, fmt.Sprintf("行动 %s 在所有批量场景中从未完成", actionID))
			}
		}
	}
}

func markReferencedCommand(referenced map[string]bool, command domain.PlayerCommand) {
	referenced[command.ActionID] = true
	if command.Fallback != nil {
		markReferencedCommand(referenced, *command.Fallback)
	}
}

func actorName(bundle domain.Bundle, state *domain.WorldState, id string) string {
	if state.Player != nil && state.Player.ID == id {
		return state.Player.Name
	}
	if npc, ok := state.NPCs[id]; ok {
		return npc.Name
	}
	if location, ok := bundle.Locations[id]; ok {
		return location.Name
	}
	if id == "" {
		return "无归属"
	}
	return id
}
