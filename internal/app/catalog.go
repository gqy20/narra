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
		if len(action.ExpectedOutcomes) == 0 {
			action.ExpectedOutcomes = []string{"让" + action.TargetName + "获得这条线索", "可能改变对方的后续选择"}
		}
		action.KnownConditions = []string{"对方就在此地", "你持有这条线索"}
		action.Unknowns = []string{"对方是否采用消息，只能从之后的公开行动判断"}
		action.Irreversible = true
	case "escort":
		action.KnownConditions = []string{"沈砚秋已答应让你随队", "青岚门队伍仍在驻地", "队伍将在次日开谷时出发"}
		action.Unknowns = []string{"进入谷内后仍需自行判断争夺时机"}
	case "route":
		action.KnownConditions = []string{"此前的情报条件已经引发回应", "这项选择只在当前路线窗口内有效"}
		action.Unknowns = []string{"表态会改变其他人物之后如何看待你"}
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
	s.addRouteDevelopmentActions(options, state)
	s.addRoutePayoffActions(options, state)
	s.addEscortFulfillmentAction(options, state)
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
			if actor.ID == "N03" && factID == "F01" && belief.Confidence >= 3 {
				s.addShenDateTermActions(options, state, actor, belief, action)
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

func (s *Session) addShenDateTermActions(options map[string]actionOption, state *domain.WorldState, actor VisibleActor, belief domain.Belief, action domain.ActionDefinition) {
	claim := belief.Claim
	if claim == "" {
		claim = "青髓芝将在第24天成熟"
	}
	beliefEffect := domain.Effect{Type: "set_belief", TargetID: actor.ID, FactID: "F01", Claim: claim, Confidence: belief.Confidence, EvidenceStrength: belief.EvidenceStrength, Source: state.Player.ID, Propagation: "private", Secrecy: belief.Secrecy}
	conditions := []domain.Condition{{Type: "belief", Key: "F01", MinConfidence: 3}, {Type: "location", Value: state.Player.Location}}
	relevance, risk := s.publicInformationContext(actor.ID, s.bundle.Facts["F01"])
	terms := []struct {
		id, label, name, description, personal string
		outcomes                               []string
		effects                                []domain.Effect
	}{
		{
			id: "trust", label: "无偿相助", name: "无偿告知沈砚秋", description: "不索取眼前回报，以可靠消息换取沈砚秋对你的长期信任。",
			personal: "沈砚秋对你的信任提高；若他凭此取得青髓芝，你会获得青岚门声望。",
			outcomes: []string{"沈砚秋获得已核实日期", "信任 +2，并可能直接采用你的消息提前备战"},
			effects:  []domain.Effect{{Type: "adjust_relation", FromID: "N03", TargetID: state.Player.ID, Key: "trust", Amount: 2}, {Type: "set_flag", TargetID: state.Player.ID, Key: "qinglan_intel_term_trust", Value: "true"}, {Type: "set_flag", TargetID: "world", Key: "player_backed_shen", Value: "true"}},
		},
		{
			id: "antidote", label: "交换解瘴丹", name: "以日期换取解瘴丹", description: "把已核实日期作为交易筹码，立即换取一枚解瘴丹，保留独自入谷的自由。",
			personal: "立即获得 1 枚解瘴丹，重新打开亲自入谷路线。",
			outcomes: []string{"获得沈砚秋持有的 1 枚解瘴丹", "青岚队伍失去这份入谷物资；沈砚秋会把消息视为一次对价交易"},
			effects:  []domain.Effect{{Type: "remove_item", TargetID: "N03", Key: "antidote", Amount: 1}, {Type: "add_item", TargetID: state.Player.ID, Key: "antidote", Amount: 1}, {Type: "set_flag", TargetID: state.Player.ID, Key: "qinglan_intel_term_antidote", Value: "true"}, {Type: "set_flag", TargetID: "world", Key: "player_took_shen_antidote", Value: "true"}},
		},
		{
			id: "escort", label: "换取同行名额", name: "以日期换取同行承诺", description: "暂不拿走物资，要求沈砚秋在开谷时把你编入青岚队伍。",
			personal: "获得第17日随青岚队伍出发的承诺；届时可取得随队药与 1 点支援。",
			outcomes: []string{"沈砚秋获得已核实日期", "取得开谷时随队出发的承诺，信任 +1"},
			effects:  []domain.Effect{{Type: "adjust_relation", FromID: "N03", TargetID: state.Player.ID, Key: "trust", Amount: 1}, {Type: "set_flag", TargetID: state.Player.ID, Key: "qinglan_escort_promised", Value: "true"}, {Type: "set_flag", TargetID: state.Player.ID, Key: "qinglan_intel_term_escort", Value: "true"}, {Type: "set_flag", TargetID: "world", Key: "player_joining_qinglan", Value: "true"}},
		},
	}
	for _, term := range terms {
		if term.id == "antidote" && state.Player.Items["antidote"] > 0 {
			continue
		}
		id := fmt.Sprintf("tell:%s:F01:%s", actor.ID, term.id)
		effects := append([]domain.Effect{beliefEffect}, term.effects...)
		options[id] = actionOption{
			view: AvailableAction{
				ID: id, Kind: "tell", Category: "information", Name: term.name, Description: term.description, Duration: action.Duration,
				TargetID: actor.ID, TargetName: actor.Name, TargetRole: actor.PublicRole, FactID: "F01", FactClaim: claim,
				TermID: term.id, TermLabel: term.label, PersonalOutcome: term.personal, Relevance: relevance, Risk: risk,
				ExpectedOutcomes: term.outcomes, Warnings: []string{"条件一旦提出，情报与承诺都不可撤回。"}, Irreversible: true,
			},
			command: &domain.PlayerCommand{ActionID: "spread", TargetID: actor.ID, Description: "玩家以“" + term.label + "”为条件向沈砚秋交付成熟日期", Conditions: conditions, Effects: effects},
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
	warnings := make([]string, 0, 3)
	if warning := routeProgressWarning(s.routeProgress(state), state.Day); warning != "" {
		warnings = append(warnings, warning)
	}
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

func (s *Session) addRoutePayoffActions(options map[string]actionOption, state *domain.WorldState) {
	visit, ok := s.bundle.Actions["visit"]
	if !ok || state.Player.Location != "L02" || !fitsHorizon(state.Day, visit.Duration, s.bundle.Scenario.Duration) {
		return
	}
	playerID := state.Player.ID
	add := func(view AvailableAction, effects []domain.Effect) {
		options[view.ID] = actionOption{
			view: view,
			command: &domain.PlayerCommand{
				ActionID: "visit", TargetID: view.TargetID, Description: view.Description,
				Conditions: []domain.Condition{{Type: "location", Value: "L02"}}, Effects: effects,
			},
		}
	}

	if state.Day >= 14 && state.Day <= 16 && state.ActorFlag(playerID, "qinglan_trust_vouched") && !state.ActorFlag(playerID, "qinglan_trust_late_resolved") {
		add(AvailableAction{
			ID: "route:trust:join", Kind: "route", Category: "information", Name: "把担保转为行动席位", Description: "以已经公开承担的责任换取青岚门行动物资，亲自加入入谷准备。", Duration: visit.Duration,
			TargetID: "N03", TargetName: "沈砚秋", TargetRole: "青岚门行动负责人", TermID: "join", TermLabel: "亲自入局", PersonalOutcome: "获得解瘴丹、2 点支援与额外筹备；你将有机会亲自争夺，而不只等待记功。",
			Relevance: "你已经替沈砚秋承担消息责任，有资格要求行动资源。", Risk: "亲自加入会消耗宗门人手，也意味着你要承担入谷风险。",
			ExpectedOutcomes: []string{"获得 1 枚解瘴丹", "支援 +2", "形成额外筹备"}, Warnings: []string{"选择行动席位后，本轮不能再领取情报报酬。"}, Irreversible: true,
		}, []domain.Effect{{Type: "add_item", TargetID: playerID, Key: "antidote", Amount: 1}, {Type: "adjust_resource", TargetID: playerID, Key: "support", Amount: 2}, {Type: "set_flag", TargetID: playerID, Key: "prepared", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_operation_joined", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_late_resolved", Value: "true"}})
		add(AvailableAction{
			ID: "route:trust:commission", Kind: "route", Category: "information", Name: "结算情报与担保报酬", Description: "不占用青岚门行动席位，提前结算情报核验与公开担保的报酬。", Duration: visit.Duration,
			TargetID: "N03", TargetName: "沈砚秋", TargetRole: "青岚门行动负责人", TermID: "commission", TermLabel: "领取报酬", PersonalOutcome: "立即获得 30 灵石与 1 点信用；保留沈砚秋获胜后的记功可能。",
			Relevance: "可靠消息与公开担保已经替青岚门节省了核验成本。", Risk: "你不会获得宗门入谷物资，亲自争夺路线仍需自行准备。",
			ExpectedOutcomes: []string{"获得 30 灵石", "信用 +1"}, Warnings: []string{"领取报酬后，本轮不能再申请行动席位。"}, Irreversible: true,
		}, []domain.Effect{{Type: "adjust_resource", TargetID: playerID, Key: "spirit_stones", Amount: 30}, {Type: "adjust_resource", TargetID: playerID, Key: "credit", Amount: 1}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_commissioned", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_late_resolved", Value: "true"}})
	}

	if state.Day >= 13 && state.Day <= 16 && state.ActorFlag(playerID, "qinglan_antidote_kept") && !state.ActorFlag(playerID, "qinglan_antidote_late_resolved") && state.Player.Items["antidote"] > 0 {
		add(AvailableAction{
			ID: "route:antidote:scout", Kind: "route", Category: "information", Name: "用解瘴丹提前踩点", Description: "保留丹药并独自勘察谷口裂隙，把入谷自由转化为路线优势。", Duration: visit.Duration,
			TargetID: "N06", TargetName: "苏晚照", TargetRole: "药理与移植研究者", TermID: "scout", TermLabel: "独行踩点", PersonalOutcome: "保留解瘴丹，获得 2 点支援并形成额外筹备，提高亲自争夺的胜算。",
			Relevance: "你拥有封锁后的稀缺丹药，可以比普通散修更早试探瘴气。", Risk: "独行踩点不会修复苏晚照对你的怀疑。",
			ExpectedOutcomes: []string{"保留解瘴丹", "支援 +2", "形成额外筹备"}, Warnings: []string{"完成踩点后，不能再出售本轮入谷名额。"}, Irreversible: true,
		}, []domain.Effect{{Type: "adjust_resource", TargetID: playerID, Key: "support", Amount: 2}, {Type: "set_flag", TargetID: playerID, Key: "prepared", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_scouted", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_late_resolved", Value: "true"}})
		add(AvailableAction{
			ID: "route:antidote:liquidate", Kind: "route", Category: "information", Name: "转售丹药与入谷路线", Description: "把封锁后的解瘴丹和独行路线打包转售，放弃争夺并锁定个人收益。", Duration: visit.Duration,
			TargetID: "N04", TargetName: "魏无咎", TargetRole: "黑水盟情报商", TermID: "liquidate", TermLabel: "变现资格", PersonalOutcome: "交出解瘴丹并获得 60 灵石；本局不再亲自参与核心争夺。",
			Relevance: "坊市封锁后，现成丹药和可行路线都具备溢价。", Risk: "失去解瘴丹后，你将无法进入内谷参加争夺。",
			ExpectedOutcomes: []string{"获得 60 灵石", "交出 1 枚解瘴丹", "锁定交易收益"}, Warnings: []string{"这会主动关闭本局亲自入谷路线。"}, Irreversible: true,
		}, []domain.Effect{{Type: "remove_item", TargetID: playerID, Key: "antidote", Amount: 1}, {Type: "adjust_resource", TargetID: playerID, Key: "spirit_stones", Amount: 60}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_liquidated", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_late_resolved", Value: "true"}})
	}

	if state.Day >= 17 && state.Day <= 18 && state.ActorFlag(playerID, "qinglan_escort_fulfilled") && !state.ActorFlag(playerID, "qinglan_escort_late_resolved") {
		add(AvailableAction{
			ID: "route:escort:vanguard", Kind: "route", Category: "information", Name: "接下先锋分工", Description: "带领随队人手先行探路，把同行承诺转化为正面争夺准备。", Duration: visit.Duration,
			TargetID: "N03", TargetName: "沈砚秋", TargetRole: "青岚门行动负责人", TermID: "vanguard", TermLabel: "担任先锋", PersonalOutcome: "支援 +3并形成额外筹备；按时抵达后具备与主要争夺者正面对抗的实力。",
			Relevance: "你已经通过审核并完成集结，队伍可以把一组人手交由你指挥。", Risk: "先锋要亲自承担谷口风险，不能同时领取后勤报酬。",
			ExpectedOutcomes: []string{"支援 +3", "形成额外筹备", "获得独立指挥权"}, Warnings: []string{"选择先锋后，本轮不能改领后勤报酬。"}, Irreversible: true,
		}, []domain.Effect{{Type: "adjust_resource", TargetID: playerID, Key: "support", Amount: 3}, {Type: "set_flag", TargetID: playerID, Key: "prepared", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_vanguard", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_late_resolved", Value: "true"}})
		add(AvailableAction{
			ID: "route:escort:quartermaster", Kind: "route", Category: "information", Name: "负责随队后勤", Description: "不争先锋位置，负责分配丹药、路线与补给，提前结算个人报酬。", Duration: visit.Duration,
			TargetID: "N03", TargetName: "沈砚秋", TargetRole: "青岚门行动负责人", TermID: "quartermaster", TermLabel: "负责后勤", PersonalOutcome: "获得 30 灵石、2 点信用与 1 点支援；仍可入谷，但不以正面争夺为主要回报。",
			Relevance: "队伍集结后需要熟悉情报来源的人统一物资与路线。", Risk: "后勤收益稳定，但不会提供足以压过主要争夺者的战力。",
			ExpectedOutcomes: []string{"获得 30 灵石", "信用 +2", "支援 +1"}, Warnings: []string{"选择后勤后，本轮不能改任先锋。"}, Irreversible: true,
		}, []domain.Effect{{Type: "adjust_resource", TargetID: playerID, Key: "spirit_stones", Amount: 30}, {Type: "adjust_resource", TargetID: playerID, Key: "credit", Amount: 2}, {Type: "adjust_resource", TargetID: playerID, Key: "support", Amount: 1}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_quartermaster", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_late_resolved", Value: "true"}})
	}
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
		stage := completed + 1
		cost := cultivationCost(completed)
		if state.Player.Resources["spirit_stones"] < cost {
			return
		}
		costs := make(map[string]int)
		warnings := make([]string, 0, 1)
		description := fmt.Sprintf("第 %d 阶段闭关三日，战力提高一点", stage)
		if cost > 0 {
			costs["spirit_stones"] = cost
			cumulativeCost := 0
			for index := 0; index <= completed; index++ {
				cumulativeCost += cultivationCost(index)
			}
			description = fmt.Sprintf("第 %d 阶段闭关三日，以 %d 灵石稳固气机，战力提高一点；完成后累计闭关耗费 %d 灵石", stage, cost, cumulativeCost)
			warnings = append(warnings, fmt.Sprintf("重复闭关已进入高耗阶段；本轮消耗 %d 灵石，完成后累计闭关耗费 %d 灵石。", cost, cumulativeCost))
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

func (s *Session) addRouteDevelopmentActions(options map[string]actionOption, state *domain.WorldState) {
	visit, hasVisit := s.bundle.Actions["visit"]
	spread, hasSpread := s.bundle.Actions["spread"]
	if !hasVisit || !hasSpread || state.Player.Location != "L02" {
		return
	}
	playerID := state.Player.ID

	if state.Day >= 10 && state.Day <= 12 && state.WorldFlag("n09_challenges_player_source") && !state.ActorFlag(playerID, "qinglan_trust_midgame_resolved") {
		if zhao, ok := state.NPCs["N09"]; ok && zhao.Location == "L02" {
			common := []domain.Condition{{Type: "location", Value: "L02"}, {Type: "flag", Key: "n09_challenges_player_source"}, {Type: "missing_flag", Scope: "actor", Key: "qinglan_trust_midgame_resolved"}}
			options["route:trust:vouch"] = actionOption{
				view: AvailableAction{
					ID: "route:trust:vouch", Kind: "route", Category: "information", Name: "为情报来源担保", Description: "在宗门审核中公开承担消息责任，不让沈砚秋独自承受赵鹤鸣的质疑。", Duration: visit.Duration,
					TargetID: "N09", TargetName: zhao.Name, TargetRole: "门内竞争者", TermID: "vouch", TermLabel: "公开担保", PersonalOutcome: "信用 +1，沈砚秋信任 +1；同时坐实你与沈砚秋的共同立场。",
					Relevance: "赵鹤鸣正在借宗门审核质疑这条消息的来源。", Risk: "担保会提高你的宗门声望，也会让赵鹤鸣把你视为沈砚秋一方。",
					ExpectedOutcomes: []string{"信用 +1", "沈砚秋信任 +1", "完成信任路线的中段履约"}, Warnings: []string{"公开担保后，无法再否认自己参与了沈砚秋的计划。"}, Irreversible: true,
				},
				command: &domain.PlayerCommand{ActionID: "visit", TargetID: "N09", Description: "玩家在宗门审核中为情报来源担保", Conditions: common, Effects: []domain.Effect{{Type: "adjust_resource", TargetID: playerID, Key: "credit", Amount: 1}, {Type: "adjust_relation", FromID: "N03", TargetID: playerID, Key: "trust", Amount: 1}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_vouched", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_midgame_resolved", Value: "true"}}},
			}
			belief := state.Player.Beliefs["F01"]
			options["route:trust:leak"] = actionOption{
				view: AvailableAction{
					ID: "route:trust:leak", Kind: "route", Category: "information", Name: "把计划转交赵鹤鸣", Description: "否认担保，并把沈砚秋的成熟日期与备战安排交给赵鹤鸣换取报酬。", Duration: spread.Duration,
					TargetID: "N09", TargetName: zhao.Name, TargetRole: "门内竞争者", FactID: "F01", FactClaim: belief.Claim, TermID: "leak", TermLabel: "转交计划", PersonalOutcome: "立即获得 20 灵石，但沈砚秋信任 -4，信任路线转为背约。",
					Relevance: "赵鹤鸣需要证据削弱沈砚秋在门内的地位。", Risk: "这会把一次无偿相助变成背叛；沈砚秋会知道计划从你这里泄露。",
					ExpectedOutcomes: []string{"获得 20 灵石", "沈砚秋信任 -4", "赵鹤鸣获得已核实日期"}, Warnings: []string{"这是信任路线的背约选择。"}, Irreversible: true,
				},
				command: &domain.PlayerCommand{ActionID: "spread", TargetID: "N09", Description: "玩家把沈砚秋的计划转交赵鹤鸣", Conditions: append(common, domain.Condition{Type: "belief", Key: "F01", MinConfidence: 3}), Effects: []domain.Effect{{Type: "set_belief", TargetID: "N09", FactID: "F01", Claim: belief.Claim, Confidence: belief.Confidence, EvidenceStrength: belief.EvidenceStrength, Source: playerID, Propagation: "private", Secrecy: belief.Secrecy}, {Type: "adjust_resource", TargetID: playerID, Key: "spirit_stones", Amount: 20}, {Type: "adjust_relation", FromID: "N03", TargetID: playerID, Key: "trust", Amount: -4}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_betrayed", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_trust_midgame_resolved", Value: "true"}}},
			}
		}
	}

	if state.Day >= 8 && state.Day <= 12 && state.WorldFlag("su_requests_antidote") && state.Player.Items["antidote"] > 0 && !state.ActorFlag(playerID, "qinglan_antidote_midgame_resolved") {
		if su, ok := state.NPCs["N06"]; ok && su.Location == "L02" {
			common := []domain.Condition{{Type: "location", Value: "L02"}, {Type: "has_item", Key: "antidote"}, {Type: "flag", Key: "su_requests_antidote"}, {Type: "missing_flag", Scope: "actor", Key: "qinglan_antidote_midgame_resolved"}}
			options["route:antidote:lend"] = actionOption{
				view: AvailableAction{
					ID: "route:antidote:lend", Kind: "route", Category: "information", Name: "把解瘴丹借回队伍", Description: "接受苏晚照的请求，把换来的解瘴丹交回青岚药修使用。", Duration: visit.Duration,
					TargetID: "N06", TargetName: su.Name, TargetRole: "药理与移植研究者", TermID: "lend", TermLabel: "借丹援队", PersonalOutcome: "失去解瘴丹与独行资格，换得 2 点支援和苏晚照 2 点信任。",
					Relevance: "坊市已经封锁，苏晚照无法为队伍补回这枚解瘴丹。", Risk: "交出后你的亲自入谷路线会再次关闭。",
					ExpectedOutcomes: []string{"支援 +2", "苏晚照信任 +2", "交出 1 枚解瘴丹"}, Warnings: []string{"交出后将失去当前的独自入谷条件。"}, Irreversible: true,
				},
				command: &domain.PlayerCommand{ActionID: "visit", TargetID: "N06", Description: "玩家把交易所得解瘴丹借给苏晚照", Conditions: common, Effects: []domain.Effect{{Type: "remove_item", TargetID: playerID, Key: "antidote", Amount: 1}, {Type: "add_item", TargetID: "N06", Key: "antidote", Amount: 1}, {Type: "adjust_resource", TargetID: playerID, Key: "support", Amount: 2}, {Type: "adjust_relation", FromID: "N06", TargetID: playerID, Key: "trust", Amount: 2}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_lent", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_midgame_resolved", Value: "true"}}},
			}
			options["route:antidote:keep"] = actionOption{
				view: AvailableAction{
					ID: "route:antidote:keep", Kind: "route", Category: "information", Name: "拒绝归还解瘴丹", Description: "明确告诉苏晚照，这枚丹药是一次完成的交易，你会保留它并独自决定入谷时机。", Duration: visit.Duration,
					TargetID: "N06", TargetName: su.Name, TargetRole: "药理与移植研究者", TermID: "keep", TermLabel: "坚持独行", PersonalOutcome: "保留解瘴丹与路线自由；苏晚照对你的怀疑 +2。",
					Relevance: "苏晚照把队伍药物缺口摆到了你面前。", Risk: "你仍可独行，但青岚药修不会把你视为可以托付物资的人。",
					ExpectedOutcomes: []string{"保留解瘴丹", "苏晚照怀疑 +2", "确认独行路线"}, Warnings: []string{"拒绝后，苏晚照不会再次提出借丹请求。"}, Irreversible: true,
				},
				command: &domain.PlayerCommand{ActionID: "visit", TargetID: "N06", Description: "玩家拒绝把交易所得解瘴丹借回青岚队伍", Conditions: common, Effects: []domain.Effect{{Type: "adjust_relation", FromID: "N06", TargetID: playerID, Key: "suspicion", Amount: 2}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_kept", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_antidote_midgame_resolved", Value: "true"}}},
			}
		}
	}

	if state.Day >= 10 && state.Day <= 13 && state.WorldFlag("qinglan_review") && state.ActorFlag(playerID, "qinglan_escort_promised") && !state.ActorFlag(playerID, "qinglan_escort_midgame_resolved") {
		if shen, ok := state.NPCs["N03"]; ok && shen.Location == "L02" {
			common := []domain.Condition{{Type: "location", Value: "L02"}, {Type: "flag", Key: "qinglan_review"}, {Type: "flag", Scope: "actor", Key: "qinglan_escort_promised"}, {Type: "missing_flag", Scope: "actor", Key: "qinglan_escort_midgame_resolved"}}
			options["route:escort:review"] = actionOption{
				view: AvailableAction{
					ID: "route:escort:review", Kind: "route", Category: "information", Name: "接受青岚门审核", Description: "登记情报来源与行动职责，以正式队员身份保留同行资格。", Duration: visit.Duration,
					TargetID: "N03", TargetName: shen.Name, TargetRole: "青岚门行动负责人", TermID: "review", TermLabel: "接受审核", PersonalOutcome: "信用 +1、沈砚秋信任 +1，并保留第16日随队集结资格。",
					Relevance: "青岚门要求所有参与者登记情报与职责。", Risk: "通过审核后，陈氏会把你视为青岚门行动的一员。",
					ExpectedOutcomes: []string{"信用 +1", "沈砚秋信任 +1", "保留同行资格"}, Warnings: []string{"你的阵营立场将变得公开。"}, Irreversible: true,
				},
				command: &domain.PlayerCommand{ActionID: "visit", TargetID: "N03", Description: "玩家接受青岚门同行审核", Conditions: common, Effects: []domain.Effect{{Type: "adjust_resource", TargetID: playerID, Key: "credit", Amount: 1}, {Type: "adjust_relation", FromID: "N03", TargetID: playerID, Key: "trust", Amount: 1}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_approved", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_midgame_resolved", Value: "true"}}},
			}
			options["route:escort:independent"] = actionOption{
				view: AvailableAction{
					ID: "route:escort:independent", Kind: "route", Category: "information", Name: "退出青岚同行名单", Description: "拒绝宗门审核，保留散修身份并放弃此前换得的同行名额。", Duration: visit.Duration,
					TargetID: "N03", TargetName: shen.Name, TargetRole: "青岚门行动负责人", TermID: "independent", TermLabel: "保持独立", PersonalOutcome: "放弃随队药与支援；沈砚秋信任 -2，陈青山不再把你视为青岚阵营。",
					Relevance: "宗门审核要求你在安全与独立之间作出明确选择。", Risk: "退出后，第16日不会再出现随队集结。",
					ExpectedOutcomes: []string{"取消同行承诺", "沈砚秋信任 -2", "恢复公开的散修身份"}, Warnings: []string{"退出后不能重新申请本次同行。"}, Irreversible: true,
				},
				command: &domain.PlayerCommand{ActionID: "visit", TargetID: "N03", Description: "玩家拒绝青岚门审核并退出同行名单", Conditions: common, Effects: []domain.Effect{{Type: "adjust_relation", FromID: "N03", TargetID: playerID, Key: "trust", Amount: -2}, {Type: "adjust_relation", FromID: "N02", TargetID: playerID, Key: "suspicion", Amount: -1}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_promised", Value: "false"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_refused", Value: "true"}, {Type: "set_flag", TargetID: playerID, Key: "qinglan_escort_midgame_resolved", Value: "true"}, {Type: "set_flag", TargetID: "world", Key: "player_declared_independent", Value: "true"}}},
			}
		}
	}
}

func (s *Session) addEscortFulfillmentAction(options map[string]actionOption, state *domain.WorldState) {
	action, ok := s.bundle.Actions["visit"]
	shen, hasShen := state.NPCs["N03"]
	if !ok || !hasShen || state.Day != 16 || state.Player.Location != "L02" || shen.Location != "L02" || !state.ActorFlag(state.Player.ID, "qinglan_escort_promised") || !state.ActorFlag(state.Player.ID, "qinglan_escort_approved") || state.ActorFlag(state.Player.ID, "qinglan_escort_fulfilled") || !fitsHorizon(state.Day, action.Duration, s.bundle.Scenario.Duration) {
		return
	}
	options["escort:N03:depart"] = actionOption{
		view: AvailableAction{
			ID: "escort:N03:depart", Kind: "escort", Category: "information", Name: "兑现同行承诺", Description: "在开谷前完成集结；次日领取随队解瘴丹与人手，自行决定是否跟进青岚队伍。", Duration: action.Duration,
			TargetID: "N03", TargetName: shen.Name, TargetRole: "青岚门行动负责人", TermID: "escort", TermLabel: "随队集结", PersonalOutcome: "获得 1 枚解瘴丹与 1 点支援，打开开谷后的入谷路线。",
			ExpectedOutcomes: []string{"获得 1 枚解瘴丹与 1 点支援", "在开谷日获得前往黑风谷外围的选择"}, Resolves: []string{"缺少解瘴丹"},
		},
		command: &domain.PlayerCommand{
			ActionID: "visit", TargetID: "N03", Description: "玩家兑现与沈砚秋的同行约定", Duration: action.Duration,
			Conditions: []domain.Condition{{Type: "location", Value: "L02"}, {Type: "flag", Scope: "actor", Key: "qinglan_escort_promised"}, {Type: "flag", Key: "valley_open"}},
			Effects:    []domain.Effect{{Type: "add_item", TargetID: state.Player.ID, Key: "antidote", Amount: 1}, {Type: "adjust_resource", TargetID: state.Player.ID, Key: "support", Amount: 1}, {Type: "set_flag", TargetID: state.Player.ID, Key: "qinglan_escort_fulfilled", Value: "true"}},
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
