package engine

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
)

func (e *Engine) marketPurchasesLegal(effects []domain.Effect, actorID string, costs map[string]int) (bool, string) {
	for _, effect := range effects {
		if effect.Type != "market_buy" {
			continue
		}
		market := e.state.Markets[effect.Value]
		if market == nil {
			return false, "unknown market " + effect.Value
		}
		location, _ := e.actorLocationFaction(actorID)
		if location != market.LocationID {
			return false, fmt.Sprintf("actor %s is not at market %s", actorID, market.ID)
		}
		if market.BlockadeFlag != "" && e.state.WorldFlag(market.BlockadeFlag) {
			return false, "market is blocked by " + market.BlockadeFlag
		}
		amount := effect.Amount
		if amount <= 0 {
			amount = 1
		}
		if market.Stock[effect.Key] < amount {
			return false, "insufficient stock for " + effect.Key
		}
		price := marketPurchasePrice(market, effect.Key, amount)
		if costs["spirit_stones"] < price {
			return false, fmt.Sprintf("purchase cost %d is below current price %d", costs["spirit_stones"], price)
		}
	}
	return true, ""
}

func marketPurchasePrice(market *domain.MarketState, itemID string, amount int) int {
	price := 0
	for i := 0; i < amount; i++ {
		price += market.Prices[itemID] + market.PriceStep*i
	}
	return price
}

func (e *Engine) resolveMarketPurchaseConflicts(intents []domain.ActionIntent) map[string]string {
	type request struct {
		intent domain.ActionIntent
		amount int
	}
	groups := make(map[string][]request)
	for _, intent := range intents {
		for _, effect := range intent.Strategy.Effects {
			if effect.Type != "market_buy" {
				continue
			}
			amount := effect.Amount
			if amount <= 0 {
				amount = 1
			}
			key := effect.Value + ":" + effect.Key
			groups[key] = append(groups[key], request{intent: intent, amount: amount})
		}
	}
	losers := make(map[string]string)
	for key, requests := range groups {
		if len(requests) < 2 {
			continue
		}
		sort.SliceStable(requests, func(i, j int) bool {
			left, right := e.claimStrength(requests[i].intent), e.claimStrength(requests[j].intent)
			if left != right {
				return left > right
			}
			return requests[i].intent.ActorID < requests[j].intent.ActorID
		})
		parts := splitMarketKey(key)
		available := e.state.Markets[parts[0]].Stock[parts[1]]
		for _, request := range requests {
			if request.amount <= available {
				available -= request.amount
				continue
			}
			losers[request.intent.ActorID] = key
		}
	}
	return losers
}

func splitMarketKey(key string) [2]string {
	for i := range key {
		if key[i] == ':' {
			return [2]string{key[:i], key[i+1:]}
		}
	}
	return [2]string{key, ""}
}

func (e *Engine) marketOffer(actorID, itemID string, amount int) (string, int, bool) {
	location, _ := e.actorLocationFaction(actorID)
	ids := make([]string, 0, len(e.state.Markets))
	for id := range e.state.Markets {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	for _, id := range ids {
		market := e.state.Markets[id]
		if market.LocationID != location || market.Stock[itemID] < amount || (market.BlockadeFlag != "" && e.state.WorldFlag(market.BlockadeFlag)) {
			continue
		}
		return id, marketPurchasePrice(market, itemID, amount), true
	}
	return "", 0, false
}
