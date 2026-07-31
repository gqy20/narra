package engine

import (
	"fmt"

	"fantu/internal/domain"
)

// TradeInformation resolves a negotiated information transaction between
// simulation steps. It never exposes a fact the source actor does not know.
func (e *Engine) TradeInformation(trade domain.InformationTrade) (*domain.WorldState, error) {
	if trade.ID == "" || trade.FromID == trade.ToID || !e.actorExists(trade.FromID) || !e.actorExists(trade.ToID) {
		return nil, fmt.Errorf("information trade requires an id and two distinct known actors")
	}
	if trade.Mode != "sell" && trade.Mode != "exchange" && trade.Mode != "tell" && trade.Mode != "withhold" {
		return nil, fmt.Errorf("unknown information trade mode %q", trade.Mode)
	}
	if trade.Price < 0 || trade.Distortion < 0 || trade.Distortion > 2 {
		return nil, fmt.Errorf("invalid information trade price or distortion")
	}
	sourceBeliefs := e.actorBeliefs(trade.FromID)
	source, ok := sourceBeliefs[trade.FactID]
	if !ok {
		return nil, fmt.Errorf("actor %s does not know fact %s", trade.FromID, trade.FactID)
	}
	var exchange domain.Belief
	if trade.Mode == "exchange" {
		if trade.ExchangeFactID == "" {
			return nil, fmt.Errorf("information exchange requires exchange fact")
		}
		exchange, ok = e.actorBeliefs(trade.ToID)[trade.ExchangeFactID]
		if !ok {
			return nil, fmt.Errorf("actor %s does not know exchange fact %s", trade.ToID, trade.ExchangeFactID)
		}
	}
	if trade.Mode == "sell" {
		if e.actorResources(trade.ToID)["spirit_stones"] < trade.Price {
			return nil, fmt.Errorf("actor %s cannot pay %d spirit stones", trade.ToID, trade.Price)
		}
	} else if trade.Price != 0 {
		return nil, fmt.Errorf("only sell mode accepts a price")
	}

	description := map[string]string{"sell": "出售情报", "exchange": "交换情报", "tell": "免费告知情报", "withhold": "拒绝透露情报"}[trade.Mode]
	event := e.newEvent("information_trade", trade.FromID, trade.ToID, description+"："+trade.FactID, trade.ID, nil)
	if source.SourceEventID != "" {
		event.TriggerEventIDs = append(event.TriggerEventIDs, source.SourceEventID)
	}
	if trade.Mode == "withhold" {
		event.Type = "information_withheld"
		e.state.Events = append(e.state.Events, event)
		return e.State(), nil
	}
	if trade.Mode == "sell" {
		e.actorResources(trade.ToID)["spirit_stones"] -= trade.Price
		e.actorResources(trade.FromID)["spirit_stones"] += trade.Price
	}
	e.mergeTradedBelief(trade.ToID, source, trade.FromID, event.ID, trade.Distortion)
	if trade.Mode == "exchange" {
		if exchange.SourceEventID != "" {
			event.TriggerEventIDs = append(event.TriggerEventIDs, exchange.SourceEventID)
		}
		e.mergeTradedBelief(trade.FromID, exchange, trade.ToID, event.ID, trade.Distortion)
	}
	e.state.Events = append(e.state.Events, event)
	return e.State(), nil
}

func (e *Engine) mergeTradedBelief(targetID string, belief domain.Belief, sourceID, eventID string, distortion int) {
	belief.Confidence = maxInt(1, belief.Confidence-distortion)
	belief.EvidenceStrength = maxInt(1, belief.EvidenceStrength-distortion)
	belief.Source = sourceID
	belief.SourceEventID = eventID
	belief.LearnedOn = e.state.Day
	belief.Evidence = nil
	e.mergeActorBelief(targetID, belief)
}

func (e *Engine) actorBeliefs(actorID string) map[string]domain.Belief {
	if e.isPlayer(actorID) {
		return e.state.Player.Beliefs
	}
	return e.state.NPCs[actorID].Beliefs
}

func (e *Engine) actorResources(actorID string) map[string]int {
	if e.isPlayer(actorID) {
		return e.state.Player.Resources
	}
	return e.state.NPCs[actorID].Resources
}
