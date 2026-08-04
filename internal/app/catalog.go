package app

import (
	"fmt"
	"sort"
	"strings"

	"narra/internal/domain"
)

type actionOption struct {
	view        AvailableAction
	command     *domain.PlayerCommand
	advanceMode string
}

func (s *Session) actionCatalog(state *domain.WorldState) []AvailableAction {
	options := s.actionOptions(state)
	result := make([]AvailableAction, 0, len(options))
	for _, option := range options {
		action := s.withDecisionContext(state, option.view)
		action = s.withResourceWarningContext(state, action, option.command)
		result = append(result, action)
	}
	sort.Slice(result, func(i, j int) bool {
		left, right := categoryOrder(result[i].Category), categoryOrder(result[j].Category)
		if left != right {
			return left < right
		}
		return result[i].ID < result[j].ID
	})
	return result
}

func (s *Session) withResourceWarningContext(state *domain.WorldState, action AvailableAction, command *domain.PlayerCommand) AvailableAction {
	if command == nil || state.Player == nil {
		return action
	}
	for _, rule := range s.bundle.Rules.Player.ResourceWarnings {
		delta := 0
		for _, effect := range command.Effects {
			if effect.Type == domain.EffectAdjustResource && effect.Key == rule.Resource && (effect.TargetID == "" || effect.TargetID == state.Player.ID) {
				delta += effect.Amount
			}
		}
		if delta == 0 {
			continue
		}
		current := state.Player.Resources[rule.Resource]
		after := maxInt(0, current+delta)
		if delta < 0 {
			persistent := false
			for _, threshold := range rule.Thresholds {
				persistent = persistent || state.WorldFlag(threshold.Flag)
			}
			if persistent && rule.DecreaseMessage != "" {
				action.Warnings = append(action.Warnings, renderRuleText(rule.DecreaseMessage, map[string]string{"before": fmt.Sprint(current), "after": fmt.Sprint(after)}))
			}
			continue
		}
		triggered := make([]string, 0, len(rule.Thresholds))
		for _, threshold := range rule.Thresholds {
			if current < threshold.Value && after >= threshold.Value && !state.WorldFlag(threshold.Flag) {
				triggered = append(triggered, threshold.Label)
			}
		}
		if len(triggered) > 0 && rule.IncreaseMessage != "" {
			action.Warnings = append(action.Warnings, renderRuleText(rule.IncreaseMessage, map[string]string{"before": fmt.Sprint(current), "after": fmt.Sprint(after), "labels": strings.Join(triggered, "、")}))
		}
	}
	return action
}

func renderRuleText(template string, values map[string]string) string {
	for key, value := range values {
		template = strings.ReplaceAll(template, "{"+key+"}", value)
	}
	return template
}

func (s *Session) withDecisionContext(state *domain.WorldState, action AvailableAction) AvailableAction {
	if action.ID == "wait:next" {
		action.Timing = s.uiText("decision_wait_timing")
	} else {
		action.CompletionDay = state.Day + maxInt(1, action.Duration)
		action.Timing = s.actionTiming(state, action)
	}

	switch action.Kind {
	case "verify":
		action.ExpectedOutcomes = []string{s.uiText("decision_verify_outcome")}
		action.Resolves = []string{s.uiText("decision_verify_resolves")}
		action.KnownConditions = []string{s.uiText("decision_verify_has_clue"), s.uiText("decision_verify_pending")}
	case "opportunity":
		action.ExpectedOutcomes = []string{s.uiText("decision_opportunity_outcome")}
		action.KnownConditions = []string{s.uiText("decision_opportunity_open"), s.uiText("decision_opportunity_location")}
		action.Unknowns = []string{s.uiText("decision_opportunity_unknown")}
		action.Irreversible = true
	case "buy":
		action.ExpectedOutcomes = []string{s.uiText("decision_buy_outcome", "name", action.TargetName)}
		action.KnownConditions = []string{s.uiText("decision_buy_stock"), s.uiText("decision_buy_funds")}
		if action.TargetID == s.bundle.Scenario.Contest.RequiredItemID {
			action.ExpectedOutcomes = []string{s.uiText("decision_buy_required_outcome", "name", action.TargetName)}
			action.Resolves = []string{s.uiText("decision_missing_item", "name", action.TargetName)}
		}
	case "move":
		action.ExpectedOutcomes = []string{s.uiText("decision_move_outcome", "name", action.TargetName)}
		action.Resolves = []string{s.uiText("decision_move_resolves", "name", action.TargetName)}
		action.KnownConditions = []string{s.uiText("decision_move_ready")}
		action.Unknowns = []string{s.uiText("decision_move_unknown")}
	case "tell":
		if len(action.ExpectedOutcomes) == 0 {
			action.ExpectedOutcomes = []string{s.uiText("decision_tell_outcome", "name", action.TargetName), s.uiText("decision_tell_influence")}
		}
		action.KnownConditions = []string{s.uiText("decision_tell_location"), s.uiText("decision_tell_has_clue")}
		action.Unknowns = []string{s.uiText("decision_tell_unknown")}
		action.Irreversible = true
	case "escort":
		action.KnownConditions = append(action.KnownConditions, "同行承诺和出发条件仍然有效")
		action.Unknowns = append(action.Unknowns, "同行期间的局势仍可能改变")
	case "route":
		action.KnownConditions = []string{s.uiText("decision_route_triggered"), s.uiText("decision_route_window")}
		action.Unknowns = []string{"表态会改变其他人物之后如何看待你"}
	case "recover":
		action.KnownConditions = append(action.KnownConditions, "此前条件已经打开这条补救路线")
		action.Unknowns = append(action.Unknowns, "交换对象之后如何使用所得信息仍需观察")
	case "heal":
		if len(action.ExpectedOutcomes) == 0 {
			action.ExpectedOutcomes = []string{s.uiText("decision_heal_outcome")}
		}
		action.Resolves = []string{s.uiText("decision_heal_resolves")}
		action.KnownConditions = []string{s.uiText("decision_heal_injured"), s.uiText("decision_heal_ready")}
		action.Unknowns = []string{s.uiText("decision_heal_unknown")}
	case "cultivate":
		if len(action.ExpectedOutcomes) == 0 {
			action.ExpectedOutcomes = []string{"完成这次成长行动"}
		}
		action.KnownConditions = []string{s.uiText("decision_growth_ready")}
		action.Unknowns = []string{s.uiText("decision_growth_unknown")}
	case "advance":
		if action.ID == "wait:complete" {
			action.ExpectedOutcomes = []string{"完成当前行动，或在重要变化出现时提前停下"}
			action.Resolves = []string{"当前行动尚未完成"}
			action.KnownConditions = []string{"已有行动正在进行"}
			action.Unknowns = []string{"若出现重要变化，会提前停下让你重新决策"}
		} else {
			action.ExpectedOutcomes = []string{"跳过平静日，在下一次重要变化处停下"}
			action.Unknowns = []string{"停止日期取决于尚未发生的局势变化"}
		}
	}
	return action
}

func (s *Session) actionTiming(state *domain.WorldState, action AvailableAction) string {
	knownDay, basis, known := playerKnownDate(state.Player.Beliefs, s.bundle.Scenario.Contest)
	if !known {
		return "日期未知 · 无法判断是否挤压亲自抵达窗口"
	}
	timingBasis := s.uiText("timing_rumored")
	if basis == "confirmed" {
		timingBasis = s.uiText("timing_confirmed")
	}

	locationID := state.Player.Location
	if action.Kind == "move" && action.TargetID != "" {
		locationID = action.TargetID
	}
	_, travelDays, reachable := s.shortestPublicRoute(locationID, s.bundle.Scenario.Contest.LocationID)
	if !reachable {
		return fmt.Sprintf("%s · 完成后仍无可行抵达路线", timingBasis)
	}

	estimatedArrival := action.CompletionDay + travelDays
	remaining := knownDay - estimatedArrival
	switch {
	case remaining > 0:
		return fmt.Sprintf("%s · 行动后预留 %d 日抵达", timingBasis, remaining)
	case remaining == 0:
		return fmt.Sprintf("%s · 行动后必须立即赶路", timingBasis)
	default:
		return fmt.Sprintf("%s · 挤压抵达窗口，预计晚 %d 日", timingBasis, -remaining)
	}
}

func (s *Session) actionOptions(state *domain.WorldState) map[string]actionOption {
	options := make(map[string]actionOption)
	if state.Player.Pending != nil {
		options["wait:complete"] = actionOption{
			view:        AvailableAction{ID: "wait:complete", Kind: "advance", Category: "time", Name: s.uiText("action_wait_complete_name"), Description: s.uiText("action_wait_complete_description"), Duration: maxInt(1, state.Player.Pending.CompleteDay-state.Day)},
			advanceMode: "complete",
		}
		return options
	}
	s.addInvestigationActions(options, state)
	s.addOpportunityActions(options, state)
	s.addMarketActions(options, state)
	s.addMovementActions(options, state)
	s.addInformationActions(options, state)
	s.addStoryActions(options, state)
	s.addRecoveryActions(options, state)
	options["wait:next"] = actionOption{
		view:        AvailableAction{ID: "wait:next", Kind: "advance", Category: "time", Name: s.uiText("action_wait_next_name"), Description: s.uiText("action_wait_next_description"), Duration: 1, Warnings: s.advanceWarnings(state)},
		advanceMode: "next",
	}
	return options
}

func (s *Session) addOpportunityActions(options map[string]actionOption, state *domain.WorldState) {
	definitions := append([]domain.OpportunityActionDefinition(nil), s.bundle.Scenario.Opportunities...)
	sort.Slice(definitions, func(i, j int) bool { return definitions[i].ID < definitions[j].ID })
	for _, definition := range definitions {
		if _, open := state.Opportunities[definition.Key]; !open || state.Player.Location != definition.LocationID {
			continue
		}
		action, ok := s.bundle.Actions[definition.ActionID]
		if !ok {
			continue
		}
		duration := definition.Duration
		if duration <= 0 {
			duration = action.Duration
		}
		if !fitsHorizon(state.Day, duration, s.bundle.Scenario.Duration) || !canPayVisibleCosts(state.Player.Resources, definition.Costs) {
			continue
		}
		conditions := []domain.Condition{{Type: "opportunity", Key: definition.Key}, {Type: "location", Value: definition.LocationID}}
		options[definition.ID] = actionOption{
			view: AvailableAction{
				ID: definition.ID, Kind: "opportunity", Category: "investigate", Name: definition.Name,
				Description: definition.Description, Duration: duration, Costs: copyIntMap(definition.Costs),
			},
			command: &domain.PlayerCommand{
				ActionID: action.ID, Duration: duration, Description: definition.Name,
				Conditions: conditions, Effects: append([]domain.Effect(nil), definition.Effects...), Costs: copyIntMap(definition.Costs),
			},
		}
	}
}

func canPayVisibleCosts(resources, costs map[string]int) bool {
	for resource, amount := range costs {
		if resources[resource] < amount {
			return false
		}
	}
	return true
}

func (s *Session) addInvestigationActions(options map[string]actionOption, state *domain.WorldState) {
	rule := s.bundle.Rules.Player.Investigation
	action, ok := s.bundle.Actions[rule.ActionID]
	if !rule.Enabled || !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		return
	}
	for factID, belief := range state.Player.Beliefs {
		fact, exists := s.bundle.Facts[factID]
		if !exists || !fact.Discoverable || belief.Confidence < 1 || belief.Confidence >= 3 {
			continue
		}
		id := "verify:" + factID
		effects := []domain.Effect{{Type: "set_belief", FactID: factID, Confidence: 3, EvidenceStrength: 4, Source: "player-investigation"}}
		for _, lead := range fact.Leads {
			if lead.FactID == factID {
				continue
			}
			effects = append(effects, domain.Effect{
				Type: "set_belief", FactID: lead.FactID, Confidence: lead.Confidence,
				EvidenceStrength: lead.Confidence, Source: "player-investigation-lead",
			})
		}
		options[id] = actionOption{
			view: AvailableAction{ID: id, Kind: "verify", Category: "investigate", Name: s.uiText("action_verify_name"), Description: s.uiText("action_verify_description", "claim", belief.Claim), Duration: action.Duration, FactID: factID, FactClaim: belief.Claim},
			command: &domain.PlayerCommand{
				ActionID: rule.ActionID, Description: s.uiText("command_verify", "claim", belief.Claim),
				Conditions: []domain.Condition{{Type: "belief", Key: factID, MinConfidence: 1}, {Type: "belief_max", Key: factID, MaxConfidence: 2}},
				Effects:    effects,
			},
		}
	}
}

func (s *Session) addMarketActions(options map[string]actionOption, state *domain.WorldState) {
	rule := s.bundle.Rules.Player.MarketPurchase
	action, ok := s.bundle.Actions[rule.ActionID]
	if !rule.Enabled || !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		return
	}
	marketIDs := make([]string, 0, len(state.Markets))
	for marketID := range state.Markets {
		marketIDs = append(marketIDs, marketID)
	}
	sort.Strings(marketIDs)
	for _, marketID := range marketIDs {
		market := state.Markets[marketID]
		if market.LocationID != state.Player.Location || (market.BlockadeFlag != "" && state.WorldFlag(market.BlockadeFlag)) {
			continue
		}
		itemIDs := make([]string, 0, len(market.Stock))
		for itemID := range market.Stock {
			itemIDs = append(itemIDs, itemID)
		}
		sort.Strings(itemIDs)
		for _, itemID := range itemIDs {
			if market.Stock[itemID] <= 0 {
				continue
			}
			price := market.Prices[itemID]
			if price <= 0 || state.Player.Resources[market.Currency] < price {
				continue
			}
			name := itemID
			if item, exists := s.bundle.Items[itemID]; exists {
				name = item.Name
			}
			id := fmt.Sprintf("buy:%s:%s", marketID, itemID)
			options[id] = actionOption{
				view: AvailableAction{ID: id, Kind: "buy", Category: "trade", Name: s.uiText("action_buy_name", "name", name), Description: s.uiText("action_buy_description", "stock", intText(market.Stock[itemID]), "price", intText(price), "currency", s.resourceName(market.Currency)), Duration: action.Duration, Costs: map[string]int{market.Currency: price}, TargetID: itemID, TargetName: name},
				command: &domain.PlayerCommand{
					ActionID: rule.ActionID, Description: s.uiText("command_buy", "name", name),
					Conditions: []domain.Condition{{Type: "location", Value: market.LocationID}, {Type: "resource_at_least", Key: market.Currency, MinConfidence: price}},
					Costs:      map[string]int{market.Currency: price}, Effects: []domain.Effect{{Type: "market_buy", Value: marketID, Key: itemID, Amount: 1}},
				},
			}
		}
	}
}

func (s *Session) addMovementActions(options map[string]actionOption, state *domain.WorldState) {
	rule := s.bundle.Rules.Player.Movement
	if _, ok := s.bundle.Actions[rule.ActionID]; !rule.Enabled || !ok {
		return
	}
	location := s.bundle.Locations[state.Player.Location]
	for _, route := range location.Routes {
		if !fitsHorizon(state.Day, route.Duration, s.bundle.Scenario.Duration) || route.RequiredItem != "" && state.Player.Items[route.RequiredItem] <= 0 || route.RequiredFlag != "" && !state.WorldFlag(route.RequiredFlag) {
			continue
		}
		destination := s.bundle.Locations[route.To]
		id := "move:" + route.To
		conditions := []domain.Condition{{Type: "location", Value: state.Player.Location}}
		if route.RequiredItem != "" {
			conditions = append(conditions, domain.Condition{Type: "has_item", Key: route.RequiredItem})
		}
		if route.RequiredFlag != "" {
			conditions = append(conditions, domain.Condition{Type: "flag", Key: route.RequiredFlag})
		}
		options[id] = actionOption{
			view:    AvailableAction{ID: id, Kind: "move", Category: "move", Name: s.uiText("action_move_name", "name", destination.Name), Description: s.uiText("action_move_description", "days", intText(route.Duration), "danger", intText(route.Danger)), Duration: route.Duration, TargetID: route.To, TargetName: destination.Name},
			command: &domain.PlayerCommand{ActionID: rule.ActionID, Duration: route.Duration, Description: s.uiText("command_move", "name", destination.Name), Conditions: conditions, Effects: []domain.Effect{{Type: "move", Value: route.To}}},
		}
	}
}

func (s *Session) addInformationActions(options map[string]actionOption, state *domain.WorldState) {
	rule := s.bundle.Rules.Player.ShareInformation
	action, ok := s.bundle.Actions[rule.ActionID]
	if !rule.Enabled || !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		return
	}
	actors := s.visibleActors(state)
	for _, actor := range actors {
		for factID, belief := range state.Player.Beliefs {
			if belief.Confidence <= 0 {
				continue
			}
			if s.hasDeliveredFact(state, actor.ID, factID) {
				continue
			}
			if s.addStoryInformationActions(options, state, actor, belief, action) {
				continue
			}
			id := fmt.Sprintf("tell:%s:%s", actor.ID, factID)
			claim := belief.Claim
			if claim == "" {
				claim = s.uiText("information_unknown_claim")
			}
			relevance, risk := s.publicInformationContext(actor.ID, s.bundle.Facts[factID])
			warnings := make([]string, 0, 1)
			if belief.Confidence < 3 {
				warnings = append(warnings, s.uiText("information_unverified_warning"))
			}
			options[id] = actionOption{
				view: AvailableAction{
					ID: id, Kind: "tell", Category: "information", Name: s.uiText("action_tell_name", "name", actor.Name),
					Description: s.uiText("action_tell_description", "claim", claim), Duration: action.Duration,
					TargetID: actor.ID, TargetName: actor.Name, TargetRole: actor.PublicRole,
					FactID: factID, FactClaim: claim, Relevance: relevance, Risk: risk, Warnings: warnings,
				},
				command: &domain.PlayerCommand{
					ActionID: rule.ActionID, TargetID: actor.ID, Description: s.uiText("command_tell", "name", actor.Name, "claim", claim),
					Conditions: []domain.Condition{{Type: "belief", Key: factID, MinConfidence: 1}, {Type: "location", Value: state.Player.Location}},
					Effects:    []domain.Effect{{Type: "set_belief", TargetID: actor.ID, FactID: factID, Claim: claim, Confidence: belief.Confidence, EvidenceStrength: belief.EvidenceStrength, Source: state.Player.ID, Propagation: "private", Secrecy: belief.Secrecy}},
				},
			}
		}
	}
}

func (s *Session) publicInformationContext(actorID string, fact domain.Fact) (string, string) {
	for _, actor := range s.bundle.NPCs {
		if actor.ID != actorID {
			continue
		}
		matched := make([]string, 0)
		for _, interest := range actor.PublicInterests {
			for _, topic := range fact.Topics {
				if interest.Topic == topic {
					matched = append(matched, interest.Label)
					break
				}
			}
		}
		relevance := s.uiText("information_relevance_low")
		if len(matched) > 0 {
			relevance = s.uiText("information_relevance_high", "topics", strings.Join(matched, "、"))
		}
		risk := actor.PublicRisk
		if risk == "" {
			risk = s.uiText("information_risk_unknown")
		}
		return relevance, risk
	}
	return s.uiText("information_relevance_unknown"), s.uiText("information_use_unknown")
}

func (s *Session) advanceWarnings(state *domain.WorldState) []string {
	warnings := make([]string, 0, 3)
	warnings = append(warnings, routeProgressWarnings(s.routeProgresses(state), state.Day)...)
	requiredItemID := s.bundle.Scenario.Contest.RequiredItemID
	if requiredItemID != "" && state.Player.Items[requiredItemID] <= 0 {
		for _, market := range state.Markets {
			if market.Stock[requiredItemID] > 0 && (market.BlockadeFlag == "" || !state.WorldFlag(market.BlockadeFlag)) {
				itemName := requiredItemID
				if item, ok := s.bundle.Items[requiredItemID]; ok {
					itemName = item.Name
				}
				warnings = append(warnings, s.uiText("wait_missing_item_warning", "name", itemName))
				break
			}
		}
	}
	if travel := s.travelGuidance(state); travel != nil && travel.Timing != "" {
		warnings = append(warnings, travel.Timing)
	}
	return warnings
}

func (s *Session) hasDeliveredFact(state *domain.WorldState, targetID, factID string) bool {
	for _, event := range state.Events {
		if event.ActorID != state.Player.ID || event.TargetID != targetID || event.ActionID != s.bundle.Rules.Player.ShareInformation.ActionID {
			continue
		}
		for _, effect := range event.Effects {
			if effect.Type == "set_belief" && effect.TargetID == targetID && effect.FactID == factID {
				return true
			}
		}
	}
	return false
}

func (s *Session) addRecoveryActions(options map[string]actionOption, state *domain.WorldState) {
	for _, rule := range s.bundle.Rules.Player.Actions {
		action, ok := s.bundle.Actions[rule.ActionID]
		if !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) || !playerCatalogConditionsMet(state, rule.Conditions) {
			continue
		}
		completed := s.countHistoryAction(rule.ID)
		stage := completed + 1
		cost, cumulativeCost, costResource := repeatActionCost(rule.RepeatCost, completed)
		if cost > 0 && state.Player.Resources[costResource] < cost {
			continue
		}
		costs := make(map[string]int)
		warnings := make([]string, 0, 1)
		values := map[string]string{
			"stage": fmt.Sprint(stage), "cost": fmt.Sprint(cost), "cumulative": fmt.Sprint(cumulativeCost),
			"cost_resource": s.resourceName(costResource), "effect_resource": s.playerActionEffectResource(rule.Effects),
		}
		description := renderRuleText(rule.Description, values)
		if cost > 0 {
			costs[costResource] = cost
			if rule.PaidDescription != "" {
				description = renderRuleText(rule.PaidDescription, values)
			}
			if rule.Warning != "" {
				warnings = append(warnings, renderRuleText(rule.Warning, values))
			}
		}
		options[rule.ID] = actionOption{
			view: AvailableAction{
				ID: rule.ID, Kind: rule.Kind, Category: rule.Category, Name: rule.Name, Description: description,
				Duration: action.Duration, Costs: costs, Warnings: warnings, ExpectedOutcomes: s.playerActionOutcomes(rule.Effects),
			},
			command: &domain.PlayerCommand{
				ActionID: rule.ActionID, Description: rule.CommandDescription,
				Conditions: append([]domain.Condition(nil), rule.Conditions...), Costs: costs, Effects: append([]domain.Effect(nil), rule.Effects...),
			},
		}
	}
}

func playerCatalogConditionsMet(state *domain.WorldState, conditions []domain.Condition) bool {
	for _, condition := range conditions {
		switch condition.Type {
		case domain.ConditionBelief:
			belief, ok := state.Player.Beliefs[condition.Key]
			if !ok || belief.Confidence < condition.MinConfidence {
				return false
			}
		case domain.ConditionBeliefMax:
			belief, ok := state.Player.Beliefs[condition.Key]
			if !ok || belief.Confidence > condition.MaxConfidence {
				return false
			}
		case domain.ConditionHasItem:
			if state.Player.Items[condition.Key] <= 0 {
				return false
			}
		case domain.ConditionMissingItem:
			if state.Player.Items[condition.Key] > 0 {
				return false
			}
		case domain.ConditionLocation:
			if state.Player.Location != condition.Value {
				return false
			}
		case domain.ConditionFlag:
			if condition.Scope == "actor" && !state.ActorFlag(state.Player.ID, condition.Key) || condition.Scope != "actor" && !state.WorldFlag(condition.Key) {
				return false
			}
		case domain.ConditionMissingFlag:
			if condition.Scope == "actor" && state.ActorFlag(state.Player.ID, condition.Key) || condition.Scope != "actor" && state.WorldFlag(condition.Key) {
				return false
			}
		case domain.ConditionResourceAtLeast:
			if state.Player.Resources[condition.Key] < condition.MinConfidence {
				return false
			}
		case domain.ConditionResourceAtMost:
			if state.Player.Resources[condition.Key] > condition.MaxConfidence {
				return false
			}
		case domain.ConditionInjuryAtLeast:
			if state.Player.Injury < condition.MinConfidence {
				return false
			}
		case domain.ConditionInjuryAtMost:
			if state.Player.Injury > condition.MaxConfidence {
				return false
			}
		case domain.ConditionOpportunity:
			if _, ok := state.Opportunities[condition.Key]; !ok {
				return false
			}
		default:
			return false
		}
	}
	return true
}

func repeatActionCost(rule *domain.RepeatCostRule, completed int) (int, int, string) {
	if rule == nil || len(rule.Amounts) == 0 {
		return 0, 0, ""
	}
	amountAt := func(index int) int {
		if index >= len(rule.Amounts) {
			return rule.Amounts[len(rule.Amounts)-1]
		}
		return rule.Amounts[index]
	}
	cumulative := 0
	for index := 0; index <= completed; index++ {
		cumulative += amountAt(index)
	}
	return amountAt(completed), cumulative, rule.Resource
}

func (s *Session) playerActionEffectResource(effects []domain.Effect) string {
	for _, effect := range effects {
		if effect.Type == domain.EffectAdjustResource && effect.Key != "" {
			return s.resourceName(effect.Key)
		}
	}
	return "资源"
}

func (s *Session) playerActionOutcomes(effects []domain.Effect) []string {
	result := make([]string, 0, len(effects))
	for _, effect := range effects {
		switch effect.Type {
		case domain.EffectAdjustResource:
			result = append(result, fmt.Sprintf("%s%+d 点", s.resourceName(effect.Key), effect.Amount))
		case domain.EffectAdjustInjury:
			result = append(result, s.uiText("effect_injury", "amount", fmt.Sprintf("%+d", effect.Amount)))
		case domain.EffectAddItem:
			name := effect.Key
			if item, ok := s.bundle.Items[effect.Key]; ok {
				name = item.Name
			}
			result = append(result, fmt.Sprintf("获得 %d 件%s", maxInt(1, effect.Amount), name))
		}
	}
	return result
}

func (s *Session) countHistoryAction(actionID string) int {
	count := 0
	for _, entry := range s.history {
		if entry == actionID {
			count++
		}
	}
	return count
}

func waitOption(description string) actionOption {
	return actionOption{view: AvailableAction{ID: "wait", Kind: "advance", Category: "time", Name: "等待一天", Description: description, Duration: 1}}
}

func maxInt(left, right int) int {
	if left > right {
		return left
	}
	return right
}

func fitsHorizon(currentDay, duration, horizon int) bool {
	if duration <= 0 {
		duration = 1
	}
	return currentDay+duration <= horizon
}

func categoryOrder(category string) int {
	switch category {
	case "investigate":
		return 0
	case "information":
		return 1
	case "trade":
		return 2
	case "move":
		return 3
	case "self":
		return 4
	case "time":
		return 5
	default:
		return 6
	}
}
