package app

import (
	"fmt"
	"sort"
	"strings"

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
		result = append(result, s.withDecisionContext(state, option.view))
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

func (s *Session) withDecisionContext(state *domain.WorldState, action AvailableAction) AvailableAction {
	if action.ID == "wait:next" {
		action.Timing = "停止日期取决于下一次值得关注的变化，无法预先保证剩余时间。"
	} else {
		action.CompletionDay = state.Day + maxInt(1, action.Duration)
		action.Timing = s.actionTiming(state, action)
	}

	switch action.Kind {
	case "verify":
		action.ExpectedOutcomes = []string{"把这条线索核验为可靠结论，并整理关联线索"}
		action.Resolves = []string{"这条线索尚未核实"}
		action.KnownConditions = []string{"你持有这条线索", "线索仍待核实"}
	case "buy":
		action.ExpectedOutcomes = []string{"获得 1 件" + action.TargetName}
		action.KnownConditions = []string{"当前仍有库存", "灵石足够支付"}
		if action.TargetID == "antidote" {
			action.ExpectedOutcomes = []string{"获得 1 枚解瘴丹，保留亲自入谷路线"}
			action.Resolves = []string{"缺少解瘴丹"}
		}
	case "move":
		action.ExpectedOutcomes = []string{"抵达" + action.TargetName}
		action.Resolves = []string{"尚未抵达" + action.TargetName}
		action.KnownConditions = []string{"路线的公开条件均已满足"}
		action.Unknowns = []string{"途中局势仍会按日推进"}
	case "tell":
		action.ExpectedOutcomes = []string{"让" + action.TargetName + "获得这条线索", "可能改变对方的后续选择"}
		action.KnownConditions = []string{"对方就在此地", "你持有这条线索"}
		action.Unknowns = []string{"对方是否采用消息，只能从之后的公开行动判断"}
		action.Irreversible = true
	case "recover":
		action.KnownConditions = []string{"坊市购买路线已经关闭", "已核实成熟日期", "苏晚照就在青岚门驻地"}
		action.Unknowns = []string{"苏晚照如何使用这条消息，只能从之后的公开行动判断"}
	case "heal":
		action.ExpectedOutcomes = []string{"伤势降低 1 级"}
		action.Resolves = []string{"当前伤势"}
		action.KnownConditions = []string{"当前带伤", "疗伤条件允许"}
		action.Unknowns = []string{"疗伤期间局势仍会按日推进"}
	case "cultivate":
		action.ExpectedOutcomes = []string{"战力提高 1 点"}
		action.KnownConditions = []string{"当前没有伤势妨碍闭关"}
		action.Unknowns = []string{"闭关期间局势仍会按日推进"}
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
	knownDay, basis, known := playerKnownDate(state.Player.Beliefs)
	if !known {
		return "日期未知 · 无法判断是否挤压亲自抵达窗口"
	}
	timingBasis := "传闻口径"
	if basis == "已核实日期" {
		timingBasis = "已核实"
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
			view:        AvailableAction{ID: "wait:complete", Kind: "advance", Category: "time", Name: "继续到行动完成", Description: "逐日推进，遇到需要处理的变化会提前停下", Duration: maxInt(1, state.Player.Pending.CompleteDay-state.Day)},
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
		view:        AvailableAction{ID: "wait:next", Kind: "advance", Category: "time", Name: "等待局势变化", Description: "逐日推演并在下一次值得关注的变化处停下，可能跨越多个平静日", Duration: 1, Warnings: s.advanceWarnings(state)},
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
			view: AvailableAction{ID: id, Kind: "verify", Category: "investigate", Name: "核验线索", Description: "核验：“" + belief.Claim + "”", Duration: action.Duration, FactID: factID, FactClaim: belief.Claim},
			command: &domain.PlayerCommand{
				ActionID: "verify", Description: "核验线索：“" + belief.Claim + "”",
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
				view: AvailableAction{ID: id, Kind: "buy", Category: "trade", Name: "购买" + name, Description: fmt.Sprintf("库存 %d，当前价格 %d 灵石", market.Stock[itemID], price), Duration: action.Duration, Costs: map[string]int{"spirit_stones": price}, TargetID: itemID, TargetName: name},
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
			view:    AvailableAction{ID: id, Kind: "move", Category: "move", Name: "前往" + destination.Name, Description: fmt.Sprintf("耗时 %d 天，危险度 %d", route.Duration, route.Danger), Duration: route.Duration, TargetID: route.To, TargetName: destination.Name},
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
			if s.hasDeliveredFact(state, actor.ID, factID) {
				continue
			}
			id := fmt.Sprintf("tell:%s:%s", actor.ID, factID)
			claim := belief.Claim
			if claim == "" {
				claim = "玩家转述的线索"
			}
			relevance, risk := s.publicInformationContext(actor.ID, s.bundle.Facts[factID])
			warnings := make([]string, 0, 1)
			if belief.Confidence < 3 {
				warnings = append(warnings, "这条线索尚未核实；对方可能据此改变行动。")
			}
			options[id] = actionOption{
				view: AvailableAction{
					ID: id, Kind: "tell", Category: "information", Name: "告知" + actor.Name + "一条线索",
					Description: "分享：“" + claim + "”", Duration: action.Duration,
					TargetID: actor.ID, TargetName: actor.Name, TargetRole: actor.PublicRole,
					FactID: factID, FactClaim: claim, Relevance: relevance, Risk: risk, Warnings: warnings,
				},
				command: &domain.PlayerCommand{
					ActionID: "spread", TargetID: actor.ID, Description: "玩家向" + actor.Name + "分享消息：“" + claim + "”",
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
		relevance := "从公开信息看，这条线索与对方当前关注的事项关联不明显。"
		if len(matched) > 0 {
			relevance = "直接相关 · 对方公开关注：" + strings.Join(matched, "、")
		}
		risk := actor.PublicRisk
		if risk == "" {
			risk = "公开信息不足，暂时无法判断对方可能如何使用这条消息。"
		}
		return relevance, risk
	}
	return "尚不了解对方为何会在意这条线索。", "尚不了解对方可能如何使用这条消息。"
}

func (s *Session) advanceWarnings(state *domain.WorldState) []string {
	warnings := make([]string, 0, 2)
	if state.Player.Items["antidote"] <= 0 {
		for _, market := range state.Markets {
			if market.Stock["antidote"] > 0 && (market.BlockadeFlag == "" || !state.WorldFlag(market.BlockadeFlag)) {
				warnings = append(warnings, "你尚未持有解瘴丹；继续等待可能错过坊市购买机会，关闭亲自入谷路线。")
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
		if event.ActorID != state.Player.ID || event.TargetID != targetID || event.ActionID != "spread" {
			continue
		}
		for _, effect := range event.Effects {
			if effect.Type == "set_belief" && effect.FactID == factID {
				return true
			}
		}
	}
	return false
}

func (s *Session) addRecoveryActions(options map[string]actionOption, state *domain.WorldState) {
	s.addAntidoteRecoveryAction(options, state)
	if action, ok := s.bundle.Actions["heal"]; ok && state.Player.Injury > 0 && fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		options["heal"] = actionOption{
			view:    AvailableAction{ID: "heal", Kind: "heal", Category: "self", Name: "疗伤", Description: "专心处理伤势，降低一级伤势", Duration: action.Duration},
			command: &domain.PlayerCommand{ActionID: "heal", Description: "玩家专心疗伤", Conditions: []domain.Condition{{Type: "injury_at_least", MinConfidence: 1}}, Effects: []domain.Effect{{Type: "adjust_injury", Amount: -1}}},
		}
	}
	if action, ok := s.bundle.Actions["cultivate"]; ok && state.Player.Injury == 0 && fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		completed := s.countHistoryAction("cultivate")
		cost := cultivationCost(completed)
		if state.Player.Resources["spirit_stones"] < cost {
			return
		}
		costs := make(map[string]int)
		warnings := make([]string, 0, 1)
		description := "闭关三日，战力提高一点"
		if cost > 0 {
			costs["spirit_stones"] = cost
			description = fmt.Sprintf("继续闭关三日，以 %d 灵石稳固气机，战力提高一点", cost)
			warnings = append(warnings, "重复闭关已进入高耗阶段；仍可提升战力，但不再是无代价的稳定最优选择。")
		}
		options["cultivate"] = actionOption{
			view:    AvailableAction{ID: "cultivate", Kind: "cultivate", Category: "self", Name: "修炼", Description: description, Duration: action.Duration, Costs: costs, Warnings: warnings},
			command: &domain.PlayerCommand{ActionID: "cultivate", Description: "玩家闭关修炼", Conditions: []domain.Condition{{Type: "injury_at_most", MaxConfidence: 0}}, Costs: costs, Effects: []domain.Effect{{Type: "adjust_resource", Key: "combat", Amount: 1}}},
		}
	}
}

func (s *Session) addAntidoteRecoveryAction(options map[string]actionOption, state *domain.WorldState) {
	action, ok := s.bundle.Actions["spread"]
	belief, knowsDate := state.Player.Beliefs["F01"]
	su, hasSu := state.NPCs["N06"]
	if !ok || !knowsDate || belief.Confidence < 3 || state.Player.Items["antidote"] > 0 || !state.WorldFlag("antidote_blockade") || !hasSu || state.Player.Location != "L02" || su.Location != "L02" || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		return
	}
	claim := belief.Claim
	if claim == "" {
		claim = "已核实的成熟日期"
	}
	options["recover:N06:antidote"] = actionOption{
		view: AvailableAction{
			ID: "recover:N06:antidote", Kind: "recover", Category: "information", Name: "以情报换取解瘴丹",
			Description: "把已核实的成熟日期交给苏晚照，换取一枚青岚门备用解瘴丹。", Duration: action.Duration,
			TargetID: "N06", TargetName: "苏晚照", TargetRole: "青岚门药修",
			FactID: "F01", FactClaim: claim, Relevance: "直接相关 · 苏晚照公开关注青髓芝药性与移植时机",
			Risk:             "苏晚照会获得准确成熟日期，并可能据此调整青岚门的后续安排。",
			ExpectedOutcomes: []string{"获得 1 枚解瘴丹，重新打开亲自入谷路线", "苏晚照获得已核实的成熟日期"},
			Resolves:         []string{"坊市封锁后无法购得解瘴丹"},
			Warnings:         []string{"这是不可撤回的情报交换；消息送出后不能收回。"}, Irreversible: true,
		},
		command: &domain.PlayerCommand{
			ActionID: "spread", TargetID: "N06", Description: "玩家以成熟日期向苏晚照换取解瘴丹",
			Conditions: []domain.Condition{{Type: "location", Value: "L02"}, {Type: "missing_item", Key: "antidote"}, {Type: "flag", Key: "antidote_blockade"}, {Type: "belief", Key: "F01", MinConfidence: 3}},
			Effects: []domain.Effect{
				{Type: "set_belief", TargetID: "N06", FactID: "F01", Claim: claim, Confidence: 3, EvidenceStrength: belief.EvidenceStrength, Source: state.Player.ID, Propagation: "private", Secrecy: belief.Secrecy},
				{Type: "add_item", Key: "antidote", Amount: 1},
			},
		},
	}
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

func cultivationCost(completed int) int {
	switch completed {
	case 0, 1:
		return 0
	case 2:
		return 10
	case 3:
		return 20
	default:
		return 30
	}
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
