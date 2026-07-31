package engine

import (
	"strings"
	"testing"

	"fantu/internal/domain"
)

func marketTestNPC(id string, score int) domain.NPCConfig {
	return domain.NPCConfig{
		ID: id, Name: id, Location: "L01", Resources: map[string]int{"spirit_stones": 20},
		Strategies: []domain.Strategy{{
			ID: id + "-buy", ActionID: "buy", Description: "购买最后一份解瘴丹", FromDay: 1, UntilDay: 1, Once: true,
			Score: domain.ScoreInput{Goal: score}, Costs: map[string]int{"spirit_stones": 20},
			Effects: []domain.Effect{{Type: "market_buy", Value: "M01", Key: "antidote", Amount: 1}},
		}},
	}
}

func TestSameDayMarketPurchaseArbitratesLastStockAndRefundsLoser(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.Scenario.Duration = 1
	bundle.Scenario.FixedEvents = nil
	bundle.Scenario.Contest.Day = 2
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "test", Name: "测试", FromDay: 1, ToDay: 1}}
	bundle.Scenario.Markets[0].Stock["antidote"] = 1
	bundle.Scenario.Markets[0].PriceStep = 5
	bundle.NPCs = []domain.NPCConfig{marketTestNPC("N01", 5), marketTestNPC("N02", 1)}
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.NPCs["N01"].Items["antidote"] != 1 || state.NPCs["N02"].Items["antidote"] != 0 {
		t.Fatalf("inventories winner=%v loser=%v", state.NPCs["N01"].Items, state.NPCs["N02"].Items)
	}
	if state.NPCs["N01"].Resources["spirit_stones"] != 0 || state.NPCs["N02"].Resources["spirit_stones"] != 20 {
		t.Fatalf("balances winner=%d loser=%d", state.NPCs["N01"].Resources["spirit_stones"], state.NPCs["N02"].Resources["spirit_stones"])
	}
	if state.Markets["M01"].Stock["antidote"] != 0 {
		t.Fatalf("stock = %d, want 0", state.Markets["M01"].Stock["antidote"])
	}
	for _, event := range state.Events {
		if event.ActorID == "N02" && event.Type == "action_failed" && strings.Contains(event.Description, "市场库存竞争失败") {
			return
		}
	}
	t.Fatal("losing purchase did not produce an audited failure")
}

func TestMarketPriceRisesAfterEachPurchase(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.Scenario.Duration = 2
	bundle.Scenario.FixedEvents = nil
	bundle.Scenario.Contest.Day = 3
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "test", Name: "测试", FromDay: 1, ToDay: 2}}
	bundle.Scenario.Markets[0].Stock["antidote"] = 2
	npc := marketTestNPC("N01", 5)
	npc.Resources["spirit_stones"] = 100
	npc.Strategies = append(npc.Strategies, domain.Strategy{
		ID: "N01-buy-again", ActionID: "buy", Description: "按上涨价格再次购买", FromDay: 2, UntilDay: 2, Once: true,
		Score: domain.ScoreInput{Goal: 5}, Costs: map[string]int{"spirit_stones": 25},
		Effects: []domain.Effect{{Type: "market_buy", Value: "M01", Key: "antidote", Amount: 1}},
	})
	bundle.NPCs = []domain.NPCConfig{npc}
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.NPCs["N01"].Items["antidote"] != 2 || state.NPCs["N01"].Resources["spirit_stones"] != 55 {
		t.Fatalf("inventory/resources = %v/%v", state.NPCs["N01"].Items, state.NPCs["N01"].Resources)
	}
	if state.Markets["M01"].Prices["antidote"] != 30 || state.Markets["M01"].Sold["antidote"] != 2 {
		t.Fatalf("market after purchases = %+v", state.Markets["M01"])
	}
}

func TestMarketBlockadePreventsPurchase(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.Scenario.Duration = 1
	bundle.Scenario.Contest.Day = 2
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "test", Name: "测试", FromDay: 1, ToDay: 1}}
	bundle.Scenario.FixedEvents = []domain.FixedEvent{{
		ID: "block", Day: 1, Timing: "start", Description: "封锁市场",
		Effects: []domain.Effect{{Type: "set_flag", TargetID: "world", Key: "antidote_blockade", Value: "true"}},
	}}
	bundle.NPCs = []domain.NPCConfig{marketTestNPC("N01", 5)}
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if state.NPCs["N01"].Items["antidote"] != 0 || state.Markets["M01"].Stock["antidote"] != 30 {
		t.Fatal("blocked market purchase unexpectedly settled")
	}
}
