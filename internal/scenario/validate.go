package scenario

import (
	"fmt"
	"reflect"
	"sort"
	"strings"

	"fantu/internal/domain"
)

func Validate(bundle domain.Bundle) error {
	if bundle.Scenario.ID == "" || bundle.Scenario.Duration <= 0 {
		return fmt.Errorf("scenario requires id and positive duration")
	}
	if mode := bundle.Scenario.PlanningMode; mode != "" && mode != "authored_priority" && mode != "unified_score" {
		return fmt.Errorf("scenario has invalid planning mode %q", mode)
	}
	if err := validateTopics(bundle); err != nil {
		return err
	}
	if err := validateDefaultPlayer(bundle); err != nil {
		return err
	}
	if err := validateFlagRegistry(bundle); err != nil {
		return err
	}
	if err := validateStoryArcs(bundle); err != nil {
		return err
	}
	seenMarkets := make(map[string]bool)
	for _, market := range bundle.Scenario.Markets {
		if market.ID == "" || seenMarkets[market.ID] || market.PriceStep < 0 {
			return fmt.Errorf("scenario has invalid or duplicate market %q", market.ID)
		}
		seenMarkets[market.ID] = true
		if _, ok := bundle.Locations[market.LocationID]; !ok {
			return fmt.Errorf("market %s references unknown location %s", market.ID, market.LocationID)
		}
		for itemID, stock := range market.Stock {
			if _, ok := bundle.Items[itemID]; !ok || stock < 0 || market.BasePrices[itemID] <= 0 {
				return fmt.Errorf("market %s has invalid stock or price for %s", market.ID, itemID)
			}
		}
	}
	if err := validateWorldDirectives(bundle); err != nil {
		return err
	}
	if err := validateOpportunityActions(bundle); err != nil {
		return err
	}
	if len(bundle.NPCs) == 0 {
		return fmt.Errorf("scenario has no NPCs")
	}
	for factID, fact := range bundle.Facts {
		seenLeads := make(map[string]bool)
		for _, lead := range fact.Leads {
			if lead.FactID == factID || seenLeads[lead.FactID] {
				return fmt.Errorf("fact %s has invalid or duplicate investigation lead %s", factID, lead.FactID)
			}
			seenLeads[lead.FactID] = true
			if _, ok := bundle.Facts[lead.FactID]; !ok {
				return fmt.Errorf("fact %s investigation references unknown fact %s", factID, lead.FactID)
			}
			if lead.Confidence < 1 || lead.Confidence > 3 {
				return fmt.Errorf("fact %s investigation lead %s has invalid confidence %d", factID, lead.FactID, lead.Confidence)
			}
		}
	}
	seenNPC := map[string]bool{}
	for _, npc := range bundle.NPCs {
		if npc.ID == "" || seenNPC[npc.ID] {
			return fmt.Errorf("invalid or duplicate NPC id %q", npc.ID)
		}
		seenNPC[npc.ID] = true
		if len(npc.PublicInterests) > 0 && (npc.PublicRole == "" || npc.PublicRisk == "") {
			return fmt.Errorf("NPC %s public context requires role and risk", npc.ID)
		}
		if npc.TrackPublicPlan && npc.PublicGoal == "" {
			return fmt.Errorf("NPC %s tracked public plan requires public goal", npc.ID)
		}
		if _, ok := bundle.Locations[npc.Location]; !ok {
			return fmt.Errorf("NPC %s references unknown location %s", npc.ID, npc.Location)
		}
		for _, belief := range npc.Beliefs {
			if _, ok := bundle.Facts[belief.FactID]; !ok {
				return fmt.Errorf("NPC %s references unknown fact %s", npc.ID, belief.FactID)
			}
		}
		seenGoals := make(map[string]bool)
		for _, goal := range npc.Goals {
			key := goal.Type + ":" + goal.TargetID
			if !validGoalType(goal.Type) || goal.Priority < 1 || goal.Priority > 5 || seenGoals[key] {
				return fmt.Errorf("NPC %s has invalid or duplicate goal %s", npc.ID, key)
			}
			seenGoals[key] = true
		}
		for _, strategy := range npc.Strategies {
			action, ok := bundle.Actions[strategy.ActionID]
			if !ok {
				return fmt.Errorf("NPC %s strategy %s references unknown action %s", npc.ID, strategy.ID, strategy.ActionID)
			}
			if err := validateStaticMovement(action.Duration, strategy.Duration, strategy.Conditions, strategy.Effects, npc.ID, bundle); err != nil {
				return fmt.Errorf("NPC %s strategy %s: %w", npc.ID, strategy.ID, err)
			}
			if err := validateCosts(strategy.Costs); err != nil {
				return fmt.Errorf("NPC %s strategy %s: %w", npc.ID, strategy.ID, err)
			}
			if err := validateConditionsAndEffects(strategy.Conditions, strategy.CompletionConditions, strategy.Effects, bundle); err != nil {
				return fmt.Errorf("NPC %s strategy %s: %w", npc.ID, strategy.ID, err)
			}
			seenGoalTypes := make(map[string]bool)
			for _, goalType := range strategy.GoalTypes {
				if !validGoalType(goalType) || seenGoalTypes[goalType] {
					return fmt.Errorf("NPC %s strategy %s has invalid or duplicate goal type %s", npc.ID, strategy.ID, goalType)
				}
				seenGoalTypes[goalType] = true
			}
		}
	}
	for _, fixed := range bundle.Scenario.FixedEvents {
		if err := validateConditionsAndEffects(nil, nil, fixed.Effects, bundle); err != nil {
			return fmt.Errorf("fixed event %s: %w", fixed.ID, err)
		}
	}
	if _, ok := bundle.Items[bundle.Scenario.Contest.ItemID]; !ok {
		return fmt.Errorf("contest references unknown item %s", bundle.Scenario.Contest.ItemID)
	}
	if _, ok := bundle.Locations[bundle.Scenario.Contest.LocationID]; !ok {
		return fmt.Errorf("contest references unknown location %s", bundle.Scenario.Contest.LocationID)
	}
	if err := validateContestRules(bundle); err != nil {
		return err
	}
	for id, location := range bundle.Locations {
		seenRoutes := make(map[string]bool)
		for _, route := range location.Routes {
			if route.To == id || seenRoutes[route.To] {
				return fmt.Errorf("location %s has invalid or duplicate route to %s", id, route.To)
			}
			seenRoutes[route.To] = true
			if _, ok := bundle.Locations[route.To]; !ok {
				return fmt.Errorf("location %s route references unknown destination %s", id, route.To)
			}
			if route.Duration <= 0 || route.Danger < 0 {
				return fmt.Errorf("location %s route to %s requires positive duration and non-negative danger", id, route.To)
			}
			if route.RequiredItem != "" {
				if _, ok := bundle.Items[route.RequiredItem]; !ok {
					return fmt.Errorf("location %s route to %s requires unknown item %s", id, route.To, route.RequiredItem)
				}
			}
		}
	}
	return nil
}

func validateFlagRegistry(bundle domain.Bundle) error {
	for key, flag := range bundle.Flags {
		if flag.ID == "" || flag.Description == "" || flag.Scope != "world" && flag.Scope != "actor" || key != flag.Scope+":"+flag.ID {
			return fmt.Errorf("invalid flag declaration %q", key)
		}
	}
	references := make(map[string]bool)
	collectFlagReferences(reflect.ValueOf(bundle.Scenario), references)
	collectFlagReferences(reflect.ValueOf(bundle.StoryArcs), references)
	collectFlagReferences(reflect.ValueOf(bundle.NPCs), references)
	for _, location := range bundle.Locations {
		for _, route := range location.Routes {
			addFlagReference(references, "world", route.RequiredFlag)
		}
	}
	for _, market := range bundle.Scenario.Markets {
		addFlagReference(references, "world", market.BlockadeFlag)
	}
	addFlagReference(references, "actor", bundle.Scenario.Contest.PreparationFlag)
	contestRules := append([]domain.ContestOutcomeRule(nil), bundle.Scenario.Contest.OutcomeRules...)
	contestRules = append(contestRules, bundle.Scenario.Contest.RewardRules...)
	for _, rule := range contestRules {
		for _, id := range rule.RequiredWorldFlags {
			addFlagReference(references, "world", id)
		}
		for _, id := range rule.RequiredPlayerFlags {
			addFlagReference(references, "actor", id)
		}
	}
	missing := make([]string, 0)
	for key := range references {
		if _, ok := bundle.Flags[key]; !ok {
			missing = append(missing, key)
		}
	}
	sort.Strings(missing)
	if len(missing) > 0 {
		return fmt.Errorf("undeclared flags: %v", missing)
	}
	return nil
}

var conditionType = reflect.TypeOf(domain.Condition{})
var effectType = reflect.TypeOf(domain.Effect{})

func collectFlagReferences(value reflect.Value, references map[string]bool) {
	if !value.IsValid() {
		return
	}
	if value.Kind() == reflect.Interface || value.Kind() == reflect.Pointer {
		if !value.IsNil() {
			collectFlagReferences(value.Elem(), references)
		}
		return
	}
	if value.Type() == conditionType {
		condition := value.Interface().(domain.Condition)
		if condition.Type == "flag" || condition.Type == "missing_flag" {
			scope := condition.Scope
			if scope != "actor" {
				scope = "world"
			}
			addFlagReference(references, scope, condition.Key)
		}
		return
	}
	if value.Type() == effectType {
		effect := value.Interface().(domain.Effect)
		if effect.Type == "set_flag" {
			scope := effect.Scope
			if scope != "world" && effect.TargetID != "world" {
				scope = "actor"
			} else {
				scope = "world"
			}
			addFlagReference(references, scope, effect.Key)
		}
		return
	}
	switch value.Kind() {
	case reflect.Struct:
		for index := 0; index < value.NumField(); index++ {
			collectFlagReferences(value.Field(index), references)
		}
	case reflect.Slice, reflect.Array:
		for index := 0; index < value.Len(); index++ {
			collectFlagReferences(value.Index(index), references)
		}
	case reflect.Map:
		iterator := value.MapRange()
		for iterator.Next() {
			collectFlagReferences(iterator.Value(), references)
		}
	}
}

func addFlagReference(references map[string]bool, scope, id string) {
	if id != "" {
		references[scope+":"+id] = true
	}
}

func validateContestRules(bundle domain.Bundle) error {
	contest := bundle.Scenario.Contest
	if contest.DefaultOutcome == "" || contest.EarlyOutcome == "" || contest.CancelledOutcome == "" || contest.NoWinnerOutcome == "" {
		return fmt.Errorf("contest requires all outcome templates")
	}
	actors := map[string]bool{"": true, "player": true, "winner": true, "world": true}
	for _, npc := range bundle.NPCs {
		actors[npc.ID] = true
	}
	seen := make(map[string]bool)
	validate := func(kind string, rule domain.ContestOutcomeRule) error {
		if rule.ID == "" || seen[rule.ID] || !actors[rule.WinnerID] || rule.MinWinnerTrust < 0 || rule.MinWinnerTrust > 5 {
			return fmt.Errorf("contest has invalid or duplicate %s rule %q", kind, rule.ID)
		}
		seen[rule.ID] = true
		if kind == "outcome" && rule.Template == "" {
			return fmt.Errorf("contest outcome rule %s requires template", rule.ID)
		}
		if kind == "reward" && rule.Suffix == "" && len(rule.Effects) == 0 {
			return fmt.Errorf("contest reward rule %s has no result", rule.ID)
		}
		for _, flag := range append(append([]string(nil), rule.RequiredWorldFlags...), rule.RequiredPlayerFlags...) {
			if flag == "" {
				return fmt.Errorf("contest rule %s has empty required flag", rule.ID)
			}
		}
		for _, effect := range rule.Effects {
			if !actors[effect.TargetID] || !actors[effect.FromID] {
				return fmt.Errorf("contest rule %s has invalid actor reference", rule.ID)
			}
		}
		if err := validateConditionsAndEffects(nil, nil, rule.Effects, bundle); err != nil {
			return fmt.Errorf("contest rule %s: %w", rule.ID, err)
		}
		return nil
	}
	for _, rule := range contest.OutcomeRules {
		if err := validate("outcome", rule); err != nil {
			return err
		}
	}
	for _, rule := range contest.RewardRules {
		if err := validate("reward", rule); err != nil {
			return err
		}
	}
	return nil
}

func validateDefaultPlayer(bundle domain.Bundle) error {
	player := bundle.DefaultPlayer
	if player.ID == "" || player.Name == "" {
		return fmt.Errorf("default player requires id and name")
	}
	if _, ok := bundle.Locations[player.Location]; !ok {
		return fmt.Errorf("default player references unknown location %s", player.Location)
	}
	if player.Injury < 0 || player.Injury > 3 {
		return fmt.Errorf("default player injury must be between 0 and 3")
	}
	for resource, amount := range player.Resources {
		if resource == "" || amount < 0 {
			return fmt.Errorf("default player has invalid resource %q=%d", resource, amount)
		}
	}
	for _, itemID := range player.Items {
		if _, ok := bundle.Items[itemID]; !ok {
			return fmt.Errorf("default player references unknown item %s", itemID)
		}
	}
	for _, belief := range player.Beliefs {
		if _, ok := bundle.Facts[belief.FactID]; !ok {
			return fmt.Errorf("default player references unknown fact %s", belief.FactID)
		}
	}
	return nil
}

func validateStoryArcs(bundle domain.Bundle) error {
	npcs := make(map[string]bool, len(bundle.NPCs))
	for _, npc := range bundle.NPCs {
		npcs[npc.ID] = true
	}
	choiceIDs := make(map[string]bool)
	for arcID, arc := range bundle.StoryArcs {
		if arc.ID == "" || arc.ID != arcID || arc.Title == "" || arc.InitialState == "" {
			return fmt.Errorf("invalid story arc %q", arcID)
		}
		states := make(map[string]bool, len(arc.States))
		for _, stateID := range arc.States {
			if stateID == "" || states[stateID] {
				return fmt.Errorf("story arc %s has invalid or duplicate state %q", arcID, stateID)
			}
			states[stateID] = true
		}
		if !states[arc.InitialState] {
			return fmt.Errorf("story arc %s initial state %s is not declared", arcID, arc.InitialState)
		}
		nodes := make(map[string]bool, len(arc.Nodes))
		for _, node := range arc.Nodes {
			if node.ID == "" || nodes[node.ID] || !states[node.FromState] || node.FromDay < 0 || node.UntilDay < 0 || node.FromDay > 0 && node.UntilDay > 0 && node.FromDay > node.UntilDay || len(node.Choices) == 0 {
				return fmt.Errorf("story arc %s has invalid node %q", arcID, node.ID)
			}
			nodes[node.ID] = true
			if !npcs[node.TargetID] {
				return fmt.Errorf("story arc %s node %s references unknown target %s", arcID, node.ID, node.TargetID)
			}
			if node.LocationID != "" {
				if _, ok := bundle.Locations[node.LocationID]; !ok {
					return fmt.Errorf("story arc %s node %s references unknown location %s", arcID, node.ID, node.LocationID)
				}
			}
			if node.FactID != "" {
				if _, ok := bundle.Facts[node.FactID]; !ok || node.MinConfidence < 1 || node.MinConfidence > 3 {
					return fmt.Errorf("story arc %s node %s references invalid fact %s", arcID, node.ID, node.FactID)
				}
			} else if node.MinConfidence != 0 {
				return fmt.Errorf("story arc %s node %s has confidence without fact", arcID, node.ID)
			}
			if _, ok := bundle.Actions[node.ActionID]; !ok {
				return fmt.Errorf("story arc %s node %s references unknown action %s", arcID, node.ID, node.ActionID)
			}
			for _, condition := range node.Conditions {
				if !validStoryCondition(condition) {
					return fmt.Errorf("story arc %s node %s has unsupported condition %s", arcID, node.ID, condition.Type)
				}
			}
			if err := validateConditionsAndEffects(node.Conditions, nil, nil, bundle); err != nil {
				return fmt.Errorf("story arc %s node %s: %w", arcID, node.ID, err)
			}
			for _, condition := range node.CompletionConditions {
				if !validStoryCondition(condition) {
					return fmt.Errorf("story arc %s node %s has unsupported completion condition %s", arcID, node.ID, condition.Type)
				}
			}
			if err := validateConditionsAndEffects(node.CompletionConditions, nil, nil, bundle); err != nil {
				return fmt.Errorf("story arc %s node %s completion: %w", arcID, node.ID, err)
			}
			choices := make(map[string]bool, len(node.Choices))
			for _, choice := range node.Choices {
				if choice.ID == "" || choices[choice.ID] || choiceIDs[choice.ID] || choice.Name == "" || choice.TermID == "" || !states[choice.ToState] {
					return fmt.Errorf("story arc %s node %s has invalid choice %q", arcID, node.ID, choice.ID)
				}
				choices[choice.ID] = true
				choiceIDs[choice.ID] = true
				for _, effect := range choice.Effects {
					if !validStoryActorReference(effect.TargetID, npcs) || !validStoryActorReference(effect.FromID, npcs) {
						return fmt.Errorf("story arc %s node %s choice %s has invalid actor reference", arcID, node.ID, choice.ID)
					}
				}
				if err := validateConditionsAndEffects(choice.Conditions, nil, choice.Effects, bundle); err != nil {
					return fmt.Errorf("story arc %s node %s choice %s: %w", arcID, node.ID, choice.ID, err)
				}
			}
		}
		progressIDs := make(map[string]bool, len(arc.ProgressRules))
		for _, rule := range arc.ProgressRules {
			if rule.ID == "" || progressIDs[rule.ID] || rule.Priority < 0 || rule.FromDay < 0 || rule.UntilDay < 0 || rule.FromDay > 0 && rule.UntilDay > 0 && rule.FromDay > rule.UntilDay || rule.RouteID == "" || rule.Label == "" || rule.Status == "" || rule.NextStep == "" {
				return fmt.Errorf("story arc %s has invalid progress rule %q", arcID, rule.ID)
			}
			progressIDs[rule.ID] = true
			if rule.LocationID != "" {
				if _, ok := bundle.Locations[rule.LocationID]; !ok {
					return fmt.Errorf("story arc %s progress rule %s references unknown location %s", arcID, rule.ID, rule.LocationID)
				}
			}
			for _, condition := range rule.Conditions {
				if !validStoryCondition(condition) {
					return fmt.Errorf("story arc %s progress rule %s has unsupported condition %s", arcID, rule.ID, condition.Type)
				}
			}
			if err := validateConditionsAndEffects(rule.Conditions, nil, nil, bundle); err != nil {
				return fmt.Errorf("story arc %s progress rule %s: %w", arcID, rule.ID, err)
			}
		}
		consequenceIDs := make(map[string]bool, len(arc.ConsequenceRules))
		for _, rule := range arc.ConsequenceRules {
			if rule.ID == "" || consequenceIDs[rule.ID] || len(rule.States) == 0 || rule.Text == "" {
				return fmt.Errorf("story arc %s has invalid consequence rule %q", arcID, rule.ID)
			}
			consequenceIDs[rule.ID] = true
			for _, stateID := range rule.States {
				if !states[stateID] {
					return fmt.Errorf("story arc %s consequence rule %s references unknown state %s", arcID, rule.ID, stateID)
				}
			}
			for _, condition := range rule.Conditions {
				if !validStoryCondition(condition) {
					return fmt.Errorf("story arc %s consequence rule %s has unsupported condition %s", arcID, rule.ID, condition.Type)
				}
			}
			if err := validateConditionsAndEffects(rule.Conditions, nil, nil, bundle); err != nil {
				return fmt.Errorf("story arc %s consequence rule %s: %w", arcID, rule.ID, err)
			}
			hasRelation := rule.RelationFromID != "" || rule.RelationToID != "" || rule.RelationMetric != ""
			if hasRelation {
				if !validConsequenceActorReference(rule.RelationFromID, npcs) || !validConsequenceActorReference(rule.RelationToID, npcs) || !validRelationMetric(rule.RelationMetric) || !strings.Contains(rule.Text, "{{value}}") {
					return fmt.Errorf("story arc %s consequence rule %s has invalid relation interpolation", arcID, rule.ID)
				}
			} else if strings.Contains(rule.Text, "{{value}}") {
				return fmt.Errorf("story arc %s consequence rule %s has value placeholder without relation interpolation", arcID, rule.ID)
			}
		}
	}
	return nil
}

func validRelationMetric(metric string) bool {
	switch metric {
	case "trust", "suspicion", "fear", "dependence", "hatred", "debt":
		return true
	default:
		return false
	}
}

func validConsequenceActorReference(actorID string, npcs map[string]bool) bool {
	return actorID == "player" || npcs[actorID]
}

func validStoryCondition(condition domain.Condition) bool {
	switch condition.Type {
	case "has_item", "missing_item", "flag", "missing_flag":
		return condition.Key != ""
	default:
		return false
	}
}

func validStoryActorReference(actorID string, npcs map[string]bool) bool {
	return actorID == "" || actorID == "player" || actorID == "target" || actorID == "world" || npcs[actorID]
}

func validateWorldDirectives(bundle domain.Bundle) error {
	seen := make(map[string]bool, len(bundle.Scenario.Directives))
	phases := make(map[string]bool, len(bundle.Scenario.Phases))
	for _, phase := range bundle.Scenario.Phases {
		phases[phase.Name] = true
	}
	markets := make(map[string]domain.MarketDefinition, len(bundle.Scenario.Markets))
	for _, market := range bundle.Scenario.Markets {
		markets[market.ID] = market
	}
	for _, directive := range bundle.Scenario.Directives {
		if directive.ID == "" || seen[directive.ID] {
			return fmt.Errorf("scenario has invalid or duplicate world directive %q", directive.ID)
		}
		seen[directive.ID] = true
		if directive.Description == "" || directive.Priority < 0 || directive.CooldownDays < 0 || directive.MaxUses < 0 {
			return fmt.Errorf("world directive %s has invalid description, priority, cooldown, or max uses", directive.ID)
		}
		if directive.FromDay < 0 || directive.UntilDay < 0 || directive.FromDay > bundle.Scenario.Duration || directive.UntilDay > bundle.Scenario.Duration || (directive.UntilDay > 0 && directive.FromDay > directive.UntilDay) {
			return fmt.Errorf("world directive %s has invalid day window", directive.ID)
		}
		if directive.Phase != "" && !phases[directive.Phase] {
			return fmt.Errorf("world directive %s references unknown phase %s", directive.ID, directive.Phase)
		}
		switch directive.Trigger {
		case "phase_entered":
			if directive.Phase == "" {
				return fmt.Errorf("world directive %s phase_entered requires phase", directive.ID)
			}
		case "quiet_days":
			if directive.MinQuietDays <= 0 {
				return fmt.Errorf("world directive %s quiet_days requires positive min_quiet_days", directive.ID)
			}
		case "market_stock_at_most":
			market, ok := markets[directive.TargetID]
			if !ok {
				return fmt.Errorf("world directive %s references unknown market %s", directive.ID, directive.TargetID)
			}
			if _, ok := market.Stock[directive.Key]; !ok || directive.MinValue < 0 {
				return fmt.Errorf("world directive %s references invalid market item %s", directive.ID, directive.Key)
			}
		case "actors_at_location_at_least":
			if _, ok := bundle.Locations[directive.TargetID]; !ok || directive.MinValue <= 0 {
				return fmt.Errorf("world directive %s requires a valid location and positive min_value", directive.ID)
			}
		default:
			return fmt.Errorf("world directive %s has unknown trigger %q", directive.ID, directive.Trigger)
		}
		for _, effect := range directive.Effects {
			switch effect.Type {
			case "set_flag":
				if effect.Scope != "world" && effect.TargetID != "world" {
					return fmt.Errorf("world directive %s may only set world-scoped flags", directive.ID)
				}
			case "open_opportunity", "close_opportunity":
				if effect.Key == "" {
					return fmt.Errorf("world directive %s has opportunity effect without key", directive.ID)
				}
			default:
				return fmt.Errorf("world directive %s may not use effect %s", directive.ID, effect.Type)
			}
		}
		if err := validateConditionsAndEffects(nil, nil, directive.Effects, bundle); err != nil {
			return fmt.Errorf("world directive %s: %w", directive.ID, err)
		}
	}
	return nil
}

func validateOpportunityActions(bundle domain.Bundle) error {
	opened := make(map[string]bool)
	for _, directive := range bundle.Scenario.Directives {
		for _, effect := range directive.Effects {
			if effect.Type == "open_opportunity" {
				opened[effect.Key] = true
			}
		}
	}
	seenIDs := make(map[string]bool, len(bundle.Scenario.Opportunities))
	seenKeys := make(map[string]bool, len(bundle.Scenario.Opportunities))
	for _, opportunity := range bundle.Scenario.Opportunities {
		if opportunity.ID == "" || opportunity.Key == "" || seenIDs[opportunity.ID] || seenKeys[opportunity.Key] {
			return fmt.Errorf("scenario has invalid or duplicate opportunity action %q", opportunity.ID)
		}
		seenIDs[opportunity.ID], seenKeys[opportunity.Key] = true, true
		if !opened[opportunity.Key] {
			return fmt.Errorf("opportunity action %s references key %s that no directive opens", opportunity.ID, opportunity.Key)
		}
		action, ok := bundle.Actions[opportunity.ActionID]
		if !ok || opportunity.Name == "" || opportunity.Description == "" {
			return fmt.Errorf("opportunity action %s has invalid action or presentation", opportunity.ID)
		}
		if _, ok := bundle.Locations[opportunity.LocationID]; !ok || opportunity.Duration < 0 {
			return fmt.Errorf("opportunity action %s has invalid location or duration", opportunity.ID)
		}
		if err := validateCosts(opportunity.Costs); err != nil {
			return fmt.Errorf("opportunity action %s: %w", opportunity.ID, err)
		}
		conditions := []domain.Condition{{Type: "opportunity", Key: opportunity.Key}, {Type: "location", Value: opportunity.LocationID}}
		if err := validateStaticMovement(action.Duration, opportunity.Duration, conditions, opportunity.Effects, "player", bundle); err != nil {
			return fmt.Errorf("opportunity action %s: %w", opportunity.ID, err)
		}
		if err := validateConditionsAndEffects(conditions, nil, opportunity.Effects, bundle); err != nil {
			return fmt.Errorf("opportunity action %s: %w", opportunity.ID, err)
		}
		closesSelf := false
		for _, effect := range opportunity.Effects {
			if effect.Type == "close_opportunity" && effect.Key == opportunity.Key {
				closesSelf = true
			}
			if effect.Type == "set_belief" {
				if _, ok := bundle.Facts[effect.FactID]; !ok {
					return fmt.Errorf("opportunity action %s references unknown fact %s", opportunity.ID, effect.FactID)
				}
			}
		}
		if !closesSelf {
			return fmt.Errorf("opportunity action %s must close its own opportunity", opportunity.ID)
		}
	}
	return nil
}

func validateTopics(bundle domain.Bundle) error {
	declared := make(map[string]bool, len(bundle.Scenario.Topics))
	used := make(map[string]bool)
	for _, topic := range bundle.Scenario.Topics {
		if topic == "" || declared[topic] {
			return fmt.Errorf("scenario has empty or duplicate topic %q", topic)
		}
		declared[topic] = true
	}
	check := func(owner string, topics []string) error {
		local := make(map[string]bool)
		for _, topic := range topics {
			if local[topic] {
				return fmt.Errorf("%s repeats topic %s", owner, topic)
			}
			if !declared[topic] {
				return fmt.Errorf("%s uses undeclared topic %s", owner, topic)
			}
			local[topic], used[topic] = true, true
		}
		return nil
	}
	for id, fact := range bundle.Facts {
		if err := check("fact "+id, fact.Topics); err != nil {
			return err
		}
	}
	for _, npc := range bundle.NPCs {
		if err := check("NPC "+npc.ID, npc.Interests); err != nil {
			return err
		}
		publicTopics := make([]string, 0, len(npc.PublicInterests))
		for _, interest := range npc.PublicInterests {
			if interest.Label == "" {
				return fmt.Errorf("NPC %s has public interest %s without a label", npc.ID, interest.Topic)
			}
			publicTopics = append(publicTopics, interest.Topic)
		}
		if err := check("NPC "+npc.ID+" public interests", publicTopics); err != nil {
			return err
		}
		for i, goal := range npc.Goals {
			if err := check(fmt.Sprintf("NPC %s goal %d", npc.ID, i), goal.Topics); err != nil {
				return err
			}
		}
	}
	for _, topic := range bundle.Scenario.Topics {
		if !used[topic] {
			return fmt.Errorf("scenario declares unused topic %s", topic)
		}
	}
	return nil
}

func validGoalType(goalType string) bool {
	switch goalType {
	case "acquire", "protect", "profit", "status", "avoid":
		return true
	default:
		return false
	}
}

func validateConditionsAndEffects(start, completion []domain.Condition, effects []domain.Effect, bundle domain.Bundle) error {
	for _, condition := range append(append([]domain.Condition(nil), start...), completion...) {
		if condition.Scope != "" && condition.Scope != "world" && condition.Scope != "actor" {
			return fmt.Errorf("condition %s has invalid scope %q", condition.Type, condition.Scope)
		}
	}
	for _, effect := range effects {
		if !effect.Type.Valid() {
			return fmt.Errorf("unknown effect type %q", effect.Type)
		}
		if effect.Scope != "" && effect.Scope != "world" && effect.Scope != "actor" {
			return fmt.Errorf("effect %s has invalid scope %q", effect.Type, effect.Scope)
		}
		if effect.Type == "transfer_unique" {
			item, ok := bundle.Items[effect.Key]
			if !ok || !item.Unique {
				return fmt.Errorf("transfer_unique references non-unique item %s", effect.Key)
			}
			if effect.FromID == "" {
				return fmt.Errorf("transfer_unique for %s requires from_id", effect.Key)
			}
		}
		if effect.Type == "market_buy" {
			marketFound, itemFound := false, false
			for _, market := range bundle.Scenario.Markets {
				if market.ID == effect.Value {
					marketFound = true
					_, itemFound = market.Stock[effect.Key]
					break
				}
			}
			if !marketFound || !itemFound || effect.Amount < 0 {
				return fmt.Errorf("market_buy references invalid market, item, or amount")
			}
		}
		if effect.Type == "set_belief" && (effect.EvidenceStrength < 0 || effect.EvidenceStrength > 5) {
			return fmt.Errorf("set_belief has invalid evidence strength %d", effect.EvidenceStrength)
		}
		if effect.Type == "set_belief" {
			if effect.Propagation != "" && effect.Propagation != "all" && effect.Propagation != "location" && effect.Propagation != "faction" && effect.Propagation != "private" {
				return fmt.Errorf("set_belief has invalid propagation %q", effect.Propagation)
			}
			if effect.Propagation == "private" && (effect.TargetID == "" || effect.TargetID == "*") {
				return fmt.Errorf("private set_belief requires an explicit target")
			}
			if effect.DelayDays < 0 || effect.Distortion < 0 || effect.Distortion > 2 || effect.Secrecy < 0 || effect.Secrecy > 3 {
				return fmt.Errorf("set_belief has invalid delay, distortion, or secrecy")
			}
		}
	}
	return nil
}

func validateCosts(costs map[string]int) error {
	resources := make([]string, 0, len(costs))
	for resource := range costs {
		resources = append(resources, resource)
	}
	sort.Strings(resources)
	for _, resource := range resources {
		if resource == "" || costs[resource] <= 0 {
			return fmt.Errorf("cost requires non-empty resource and positive amount: %q=%d", resource, costs[resource])
		}
	}
	return nil
}

func validateStaticMovement(actionDuration, overrideDuration int, conditions []domain.Condition, effects []domain.Effect, actorID string, bundle domain.Bundle) error {
	from := ""
	for _, condition := range conditions {
		if condition.Type == "location" {
			from = condition.Value
			break
		}
	}
	duration := overrideDuration
	if duration <= 0 {
		duration = actionDuration
	}
	for _, effect := range effects {
		if effect.Type != "move" || (effect.TargetID != "" && effect.TargetID != actorID) || from == "" {
			continue
		}
		location, ok := bundle.Locations[from]
		if !ok {
			return fmt.Errorf("movement starts at unknown location %s", from)
		}
		var route *domain.Route
		for i := range location.Routes {
			if location.Routes[i].To == effect.Value {
				route = &location.Routes[i]
				break
			}
		}
		if route == nil {
			return fmt.Errorf("movement has no route %s -> %s", from, effect.Value)
		}
		if duration > 0 && duration < route.Duration {
			return fmt.Errorf("movement duration %d is shorter than route %s -> %s duration %d", duration, from, effect.Value, route.Duration)
		}
	}
	return nil
}
