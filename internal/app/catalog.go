package app

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
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
		result = append(result, option.view)
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

func (s *Session) actionOptions(state *domain.WorldState) map[string]actionOption {
	options := make(map[string]actionOption)
	if state.Player.Pending != nil {
		options["wait:complete"] = actionOption{
			view:        AvailableAction{ID: "wait:complete", Category: "time", Name: "继续到行动完成", Description: "逐日推进，遇到需要处理的变化会提前停下", Duration: maxInt(1, state.Player.Pending.CompleteDay-state.Day)},
			advanceMode: "complete",
		}
		return options
	}
	s.addInvestigationActions(options, state)
	s.addMarketActions(options, state)
	s.addMovementActions(options, state)
	s.addInformationActions(options, state)
	s.addRecoveryActions(options, state)
	options["wait:next"] = actionOption{
		view:        AvailableAction{ID: "wait:next", Category: "time", Name: "推进到下一变化", Description: "跳过没有新决策的日期", Duration: 1},
		advanceMode: "next",
	}
	return options
}

func (s *Session) addInvestigationActions(options map[string]actionOption, state *domain.WorldState) {
	action, ok := s.bundle.Actions["verify"]
	if !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
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
			view: AvailableAction{ID: id, Category: "investigate", Name: "核验线索", Description: "核验：“" + belief.Claim + "”", Duration: action.Duration},
			command: &domain.PlayerCommand{
				ActionID: "verify", Description: "玩家核验线索：" + factID,
				Conditions: []domain.Condition{{Type: "belief", Key: factID, MinConfidence: 1}, {Type: "belief_max", Key: factID, MaxConfidence: 2}},
				Effects:    effects,
			},
		}
	}
}

func (s *Session) addMarketActions(options map[string]actionOption, state *domain.WorldState) {
	action, ok := s.bundle.Actions["buy"]
	if !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
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
			if price <= 0 || state.Player.Resources["spirit_stones"] < price {
				continue
			}
			name := itemID
			if item, exists := s.bundle.Items[itemID]; exists {
				name = item.Name
			}
			id := fmt.Sprintf("buy:%s:%s", marketID, itemID)
			options[id] = actionOption{
				view: AvailableAction{ID: id, Category: "trade", Name: "购买" + name, Description: fmt.Sprintf("库存 %d，当前价格 %d 灵石", market.Stock[itemID], price), Duration: action.Duration, Costs: map[string]int{"spirit_stones": price}},
				command: &domain.PlayerCommand{
					ActionID: "buy", Description: "玩家购买" + name,
					Conditions: []domain.Condition{{Type: "location", Value: market.LocationID}, {Type: "resource_at_least", Key: "spirit_stones", MinConfidence: price}},
					Costs:      map[string]int{"spirit_stones": price}, Effects: []domain.Effect{{Type: "market_buy", Value: marketID, Key: itemID, Amount: 1}},
				},
			}
		}
	}
}

func (s *Session) addMovementActions(options map[string]actionOption, state *domain.WorldState) {
	if _, ok := s.bundle.Actions["explore"]; !ok {
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
			view:    AvailableAction{ID: id, Category: "move", Name: "前往" + destination.Name, Description: fmt.Sprintf("耗时 %d 天，危险度 %d", route.Duration, route.Danger), Duration: route.Duration},
			command: &domain.PlayerCommand{ActionID: "explore", Duration: route.Duration, Description: "玩家前往" + destination.Name, Conditions: conditions, Effects: []domain.Effect{{Type: "move", Value: route.To}}},
		}
	}
}

func (s *Session) addInformationActions(options map[string]actionOption, state *domain.WorldState) {
	action, ok := s.bundle.Actions["spread"]
	if !ok || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		return
	}
	actors := s.visibleActors(state)
	for _, actor := range actors {
		for factID, belief := range state.Player.Beliefs {
			if belief.Confidence <= 0 {
				continue
			}
			id := fmt.Sprintf("tell:%s:%s", actor.ID, factID)
			claim := belief.Claim
			if claim == "" {
				claim = "玩家转述的线索"
			}
			options[id] = actionOption{
				view: AvailableAction{ID: id, Category: "information", Name: "告知" + actor.Name + "一条线索", Description: "分享：“" + claim + "”", Duration: action.Duration},
				command: &domain.PlayerCommand{
					ActionID: "spread", TargetID: actor.ID, Description: "玩家向" + actor.Name + "分享情报：" + factID,
					Conditions: []domain.Condition{{Type: "belief", Key: factID, MinConfidence: 1}, {Type: "location", Value: state.Player.Location}},
					Effects:    []domain.Effect{{Type: "set_belief", TargetID: actor.ID, FactID: factID, Claim: claim, Confidence: belief.Confidence, EvidenceStrength: belief.EvidenceStrength, Source: state.Player.ID, Propagation: "private", Secrecy: belief.Secrecy}},
				},
			}
		}
	}
}

func (s *Session) addRecoveryActions(options map[string]actionOption, state *domain.WorldState) {
	if action, ok := s.bundle.Actions["heal"]; ok && state.Player.Injury > 0 && fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		options["heal"] = actionOption{
			view:    AvailableAction{ID: "heal", Category: "self", Name: "疗伤", Description: "专心处理伤势，降低一级伤势", Duration: action.Duration},
			command: &domain.PlayerCommand{ActionID: "heal", Description: "玩家专心疗伤", Conditions: []domain.Condition{{Type: "injury_at_least", MinConfidence: 1}}, Effects: []domain.Effect{{Type: "adjust_injury", Amount: -1}}},
		}
	}
	if action, ok := s.bundle.Actions["cultivate"]; ok && state.Player.Injury == 0 && fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		options["cultivate"] = actionOption{
			view:    AvailableAction{ID: "cultivate", Category: "self", Name: "修炼", Description: "闭关三日，战力提高一点", Duration: action.Duration},
			command: &domain.PlayerCommand{ActionID: "cultivate", Description: "玩家闭关修炼", Conditions: []domain.Condition{{Type: "injury_at_most", MaxConfidence: 0}}, Effects: []domain.Effect{{Type: "adjust_resource", Key: "combat", Amount: 1}}},
		}
	}
}

func waitOption(description string) actionOption {
	return actionOption{view: AvailableAction{ID: "wait", Category: "time", Name: "等待一天", Description: description, Duration: 1}}
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
