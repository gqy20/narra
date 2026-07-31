package scenario

import (
	"fmt"
	"sort"

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
