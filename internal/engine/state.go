package engine

import (
	"fmt"

	"fantu/internal/domain"
)

func cloneWorld(source *domain.WorldState) *domain.WorldState {
	clone := &domain.WorldState{
		RunID: source.RunID, RunTitle: source.RunTitle,
		Day: source.Day, Phase: source.Phase, Facts: source.Facts, Outcome: source.Outcome,
		NPCs:               make(map[string]*domain.NPCState, len(source.NPCs)),
		Items:              make(map[string]string, len(source.Items)),
		WorldFlags:         make(map[string]bool, len(source.WorldFlags)),
		ActorFlags:         make(map[string]map[string]bool, len(source.ActorFlags)),
		WorldFlagSources:   make(map[string]string, len(source.WorldFlagSources)),
		ActorFlagSources:   make(map[string]map[string]string, len(source.ActorFlagSources)),
		ItemSources:        make(map[string]string, len(source.ItemSources)),
		Relations:          make(map[string]domain.Relation, len(source.Relations)),
		Opportunities:      make(map[string]string, len(source.Opportunities)),
		OpportunitySources: make(map[string]string, len(source.OpportunitySources)),
		StoryStates:        make(map[string]string, len(source.StoryStates)),
		Events:             append([]domain.WorldEvent(nil), source.Events...),
		Decisions:          append([]domain.DecisionRecord(nil), source.Decisions...),
		Director: domain.WorldDirectorState{
			LastPhase: source.Director.LastPhase, LastDirectiveDay: source.Director.LastDirectiveDay,
			Uses: make(map[string]int, len(source.Director.Uses)), LastUsedDay: make(map[string]int, len(source.Director.LastUsedDay)),
		},
		DirectorDecisions:  append([]domain.DirectorDecision(nil), source.DirectorDecisions...),
		PendingInformation: append([]domain.InformationDelivery(nil), source.PendingInformation...),
		Markets:            make(map[string]*domain.MarketState, len(source.Markets)),
		Debts:              make(map[string]*domain.Debt, len(source.Debts)),
		Alliances:          make(map[string]*domain.Alliance, len(source.Alliances)),
		Agreements:         make(map[string]*domain.Agreement, len(source.Agreements)),
	}
	for id, uses := range source.Director.Uses {
		clone.Director.Uses[id] = uses
	}
	for id, lastDay := range source.Director.LastUsedDay {
		clone.Director.LastUsedDay[id] = lastDay
	}
	for i := range clone.DirectorDecisions {
		clone.DirectorDecisions[i].Signals = append([]domain.WorldSignal(nil), source.DirectorDecisions[i].Signals...)
	}
	for i := range clone.Decisions {
		clone.Decisions[i].Choices = append([]domain.RankedChoice(nil), source.Decisions[i].Choices...)
		clone.Decisions[i].Counterfactuals = append([]domain.CounterfactualRecord(nil), source.Decisions[i].Counterfactuals...)
	}
	for i := range clone.Events {
		clone.Events[i].TriggerEventIDs = append([]string(nil), source.Events[i].TriggerEventIDs...)
		clone.Events[i].Effects = append([]domain.Effect(nil), source.Events[i].Effects...)
		clone.Events[i].Conditions = append([]domain.Condition(nil), source.Events[i].Conditions...)
	}
	for i := range clone.PendingInformation {
		clone.PendingInformation[i].Belief.Evidence = append([]domain.BeliefEvidence(nil), source.PendingInformation[i].Belief.Evidence...)
	}
	for marketID, market := range source.Markets {
		copyMarket := *market
		copyMarket.Stock = copyIntMap(market.Stock)
		copyMarket.Prices = copyIntMap(market.Prices)
		copyMarket.Sold = copyIntMap(market.Sold)
		clone.Markets[marketID] = &copyMarket
	}
	for debtID, debt := range source.Debts {
		copyDebt := *debt
		clone.Debts[debtID] = &copyDebt
	}
	for allianceID, alliance := range source.Alliances {
		copyAlliance := *alliance
		copyAlliance.Members = append([]string(nil), alliance.Members...)
		copyAlliance.BenefitShares = copyIntMap(alliance.BenefitShares)
		clone.Alliances[allianceID] = &copyAlliance
	}
	for agreementID, agreement := range source.Agreements {
		copyAgreement := *agreement
		copyAgreement.Parties = append([]string(nil), agreement.Parties...)
		copyAgreement.Shares = copyIntMap(agreement.Shares)
		clone.Agreements[agreementID] = &copyAgreement
	}
	for id, owner := range source.Items {
		clone.Items[id] = owner
	}
	for key, value := range source.WorldFlags {
		clone.WorldFlags[key] = value
	}
	for arcID, stateID := range source.StoryStates {
		clone.StoryStates[arcID] = stateID
	}
	for actorID, flags := range source.ActorFlags {
		clone.ActorFlags[actorID] = make(map[string]bool, len(flags))
		for key, value := range flags {
			clone.ActorFlags[actorID][key] = value
		}
	}
	for key, eventID := range source.WorldFlagSources {
		clone.WorldFlagSources[key] = eventID
	}
	for actorID, sources := range source.ActorFlagSources {
		clone.ActorFlagSources[actorID] = make(map[string]string, len(sources))
		for key, eventID := range sources {
			clone.ActorFlagSources[actorID][key] = eventID
		}
	}
	for itemID, eventID := range source.ItemSources {
		clone.ItemSources[itemID] = eventID
	}
	for key, value := range source.Relations {
		clone.Relations[key] = value
	}
	for key, value := range source.Opportunities {
		clone.Opportunities[key] = value
	}
	for key, eventID := range source.OpportunitySources {
		clone.OpportunitySources[key] = eventID
	}
	if source.Player != nil {
		copyPlayer := *source.Player
		copyPlayer.Resources = copyIntMap(source.Player.Resources)
		copyPlayer.Items = copyIntMap(source.Player.Items)
		copyPlayer.Beliefs = make(map[string]domain.Belief, len(source.Player.Beliefs))
		for factID, belief := range source.Player.Beliefs {
			belief.Evidence = append([]domain.BeliefEvidence(nil), belief.Evidence...)
			copyPlayer.Beliefs[factID] = belief
		}
		copyPlayer.Pending = copyPending(source.Player.Pending)
		clone.Player = &copyPlayer
	}
	for id, npc := range source.NPCs {
		copyNPC := *npc
		copyNPC.Interests = append([]string(nil), npc.Interests...)
		copyNPC.Goals = append([]domain.Goal(nil), npc.Goals...)
		for i := range copyNPC.Goals {
			copyNPC.Goals[i].Topics = append([]string(nil), npc.Goals[i].Topics...)
		}
		copyNPC.Resources = copyIntMap(npc.Resources)
		copyNPC.Items = copyIntMap(npc.Items)
		copyNPC.Beliefs = make(map[string]domain.Belief, len(npc.Beliefs))
		for factID, belief := range npc.Beliefs {
			belief.Evidence = append([]domain.BeliefEvidence(nil), belief.Evidence...)
			copyNPC.Beliefs[factID] = belief
		}
		copyNPC.Completed = make(map[string]bool, len(npc.Completed))
		for strategyID, done := range npc.Completed {
			copyNPC.Completed[strategyID] = done
		}
		copyNPC.Plans = make(map[string]*domain.PlanChain, len(npc.Plans))
		for planID, plan := range npc.Plans {
			copyPlan := *plan
			copyPlan.Steps = append([]domain.PlanStep(nil), plan.Steps...)
			copyNPC.Plans[planID] = &copyPlan
		}
		copyNPC.Pending = copyPending(npc.Pending)
		clone.NPCs[id] = &copyNPC
	}
	return clone
}

func copyPending(source *domain.PendingAction) *domain.PendingAction {
	if source == nil {
		return nil
	}
	clone := *source
	clone.Intent.Strategy.Conditions = append([]domain.Condition(nil), source.Intent.Strategy.Conditions...)
	clone.Intent.Strategy.CompletionConditions = append([]domain.Condition(nil), source.Intent.Strategy.CompletionConditions...)
	clone.Intent.Strategy.Effects = append([]domain.Effect(nil), source.Intent.Strategy.Effects...)
	clone.Intent.Strategy.GoalTypes = append([]string(nil), source.Intent.Strategy.GoalTypes...)
	clone.Intent.Strategy.Costs = copyIntMap(source.Intent.Strategy.Costs)
	clone.Intent.TriggerEventIDs = append([]string(nil), source.Intent.TriggerEventIDs...)
	clone.PaidCosts = copyIntMap(source.PaidCosts)
	return &clone
}

func ValidateState(state *domain.WorldState, bundle domain.Bundle) error {
	if len(state.StoryStates) != len(bundle.StoryArcs) {
		return fmt.Errorf("story state count does not match content")
	}
	for arcID, arc := range bundle.StoryArcs {
		if !storyStateDeclared(arc, state.StoryStates[arcID]) {
			return fmt.Errorf("story arc %s has invalid state %q", arcID, state.StoryStates[arcID])
		}
	}
	knownDirectives := make(map[string]bool, len(bundle.Scenario.Directives))
	for _, definition := range bundle.Scenario.Directives {
		knownDirectives[definition.ID] = true
	}
	for directiveID, uses := range state.Director.Uses {
		if !knownDirectives[directiveID] || uses < 0 {
			return fmt.Errorf("director has invalid use count for %s", directiveID)
		}
	}
	for directiveID, lastDay := range state.Director.LastUsedDay {
		if !knownDirectives[directiveID] || lastDay < 1 || lastDay > state.Day || state.Director.Uses[directiveID] <= 0 {
			return fmt.Errorf("director has invalid last-used day for %s", directiveID)
		}
	}
	eventsByID := make(map[string]domain.WorldEvent, len(state.Events))
	for _, event := range state.Events {
		eventsByID[event.ID] = event
	}
	for _, decision := range state.DirectorDecisions {
		event, ok := eventsByID[decision.EventID]
		if !knownDirectives[decision.DirectiveID] || decision.Day < 1 || decision.Day > state.Day || decision.Source == "" || !ok || event.Type != "director" || event.CauseID != decision.DirectiveID {
			return fmt.Errorf("invalid director decision %s on day %d", decision.DirectiveID, decision.Day)
		}
	}
	for key := range state.WorldFlags {
		if key == "" {
			return fmt.Errorf("world flag has empty key")
		}
	}
	for actorID, flags := range state.ActorFlags {
		_, npcExists := state.NPCs[actorID]
		playerExists := state.Player != nil && state.Player.ID == actorID
		if !npcExists && !playerExists {
			return fmt.Errorf("actor flags reference unknown actor %s", actorID)
		}
		for key := range flags {
			if key == "" {
				return fmt.Errorf("actor %s has empty flag key", actorID)
			}
		}
	}
	for actorID, npc := range state.NPCs {
		if npc.ActivePlanID != "" {
			plan := npc.Plans[npc.ActivePlanID]
			if plan == nil || plan.Status != "active" {
				return fmt.Errorf("NPC %s references invalid active plan %s", actorID, npc.ActivePlanID)
			}
		}
		for planID, plan := range npc.Plans {
			if plan == nil || plan.ID != planID || (plan.Status != "active" && plan.Status != "completed" && plan.Status != "failed") {
				return fmt.Errorf("NPC %s has invalid plan %s", actorID, planID)
			}
		}
	}
	for marketID, market := range state.Markets {
		if market == nil || market.ID != marketID {
			return fmt.Errorf("invalid market state %s", marketID)
		}
		if _, ok := bundle.Locations[market.LocationID]; !ok {
			return fmt.Errorf("market %s has unknown location %s", marketID, market.LocationID)
		}
		for itemID, stock := range market.Stock {
			if stock < 0 || market.Prices[itemID] <= 0 || market.Sold[itemID] < 0 {
				return fmt.Errorf("market %s has invalid state for %s", marketID, itemID)
			}
		}
	}
	for debtID, debt := range state.Debts {
		if debt == nil || debt.ID != debtID || debt.Principal <= 0 || debt.Outstanding < 0 || debt.Outstanding > debt.Principal || debt.DueDay < 1 {
			return fmt.Errorf("invalid debt state %s", debtID)
		}
		if !stateActorExists(state, debt.CreditorID) || !stateActorExists(state, debt.DebtorID) || (debt.Status != "active" && debt.Status != "paid" && debt.Status != "defaulted") {
			return fmt.Errorf("debt %s has invalid actors or status", debtID)
		}
	}
	for allianceID, alliance := range state.Alliances {
		if alliance == nil || alliance.ID != allianceID || (alliance.Status != "active" && alliance.Status != "betrayed") || len(alliance.Members) < 2 {
			return fmt.Errorf("invalid alliance state %s", allianceID)
		}
		total := 0
		for _, member := range alliance.Members {
			if !stateActorExists(state, member) || alliance.BenefitShares[member] <= 0 {
				return fmt.Errorf("alliance %s has invalid member or share %s", allianceID, member)
			}
			total += alliance.BenefitShares[member]
		}
		if total != 100 {
			return fmt.Errorf("alliance %s shares total %d", allianceID, total)
		}
	}
	for agreementID, agreement := range state.Agreements {
		if agreement == nil || agreement.ID != agreementID || agreement.Status != "settled" || !stateActorExists(state, agreement.CustodianID) {
			return fmt.Errorf("invalid agreement state %s", agreementID)
		}
		total := 0
		for party, share := range agreement.Shares {
			if !stateActorExists(state, party) || share <= 0 {
				return fmt.Errorf("agreement %s has invalid party share", agreementID)
			}
			total += share
		}
		if total != 100 {
			return fmt.Errorf("agreement %s shares total %d", agreementID, total)
		}
	}
	if state.Player != nil {
		if state.Player.Injury < 0 || state.Player.Injury > 3 {
			return fmt.Errorf("player has invalid injury %d", state.Player.Injury)
		}
		if _, ok := bundle.Locations[state.Player.Location]; !ok {
			return fmt.Errorf("player is at unknown location %s", state.Player.Location)
		}
		for resource, amount := range state.Player.Resources {
			if amount < 0 {
				return fmt.Errorf("player has negative resource %s=%d", resource, amount)
			}
		}
	}
	for id, npc := range state.NPCs {
		if npc.Injury < 0 || npc.Injury > 3 {
			return fmt.Errorf("NPC %s has invalid injury %d", id, npc.Injury)
		}
		if _, ok := bundle.Locations[npc.Location]; !ok {
			return fmt.Errorf("NPC %s is at unknown location %s", id, npc.Location)
		}
		for resource, amount := range npc.Resources {
			if amount < 0 {
				return fmt.Errorf("NPC %s has negative resource %s=%d", id, resource, amount)
			}
		}
		for item, amount := range npc.Items {
			if amount < 0 {
				return fmt.Errorf("NPC %s has negative item %s=%d", id, item, amount)
			}
		}
	}
	for key, relation := range state.Relations {
		if relation.From == "" || relation.To == "" {
			return fmt.Errorf("relation %s has empty actor", key)
		}
		values := []int{relation.Trust, relation.Suspicion, relation.Fear, relation.Dependence, relation.Hatred, relation.Debt}
		for _, value := range values {
			if value < -5 || value > 5 {
				return fmt.Errorf("relation %s has out-of-range value %d", key, value)
			}
		}
	}
	for itemID, item := range bundle.Items {
		if !item.Unique {
			continue
		}
		owner := state.Items[itemID]
		count := 0
		for id, npc := range state.NPCs {
			if npc.Items[itemID] > 0 {
				count += npc.Items[itemID]
				if owner != id {
					return fmt.Errorf("unique item %s owner mismatch: index=%s inventory=%s", itemID, owner, id)
				}
			}
		}
		if state.Player != nil && state.Player.Items[itemID] > 0 {
			count += state.Player.Items[itemID]
			if owner != state.Player.ID {
				return fmt.Errorf("unique item %s owner mismatch: index=%s inventory=%s", itemID, owner, state.Player.ID)
			}
		}
		if count > 1 {
			return fmt.Errorf("unique item %s appears %d times", itemID, count)
		}
	}
	return nil
}

func stateActorExists(state *domain.WorldState, actorID string) bool {
	if state.Player != nil && state.Player.ID == actorID {
		return true
	}
	_, ok := state.NPCs[actorID]
	return ok
}
