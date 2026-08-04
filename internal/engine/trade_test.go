package engine

import (
	"testing"

	"narra/internal/domain"
)

func TestInformationTradeSellTransfersPaymentAndBelief(t *testing.T) {
	simulation := New(loadBlackwind(t))
	state, err := simulation.TradeInformation(domain.InformationTrade{ID: "sale", Mode: "sell", FromID: "N01", ToID: "N03", FactID: "F01", Price: 25})
	if err != nil {
		t.Fatalf("TradeInformation() error = %v", err)
	}
	if state.NPCs["N01"].Resources["spirit_stones"] != 125 || state.NPCs["N03"].Resources["spirit_stones"] != 95 {
		t.Fatalf("sale balances seller=%d buyer=%d", state.NPCs["N01"].Resources["spirit_stones"], state.NPCs["N03"].Resources["spirit_stones"])
	}
	belief := state.NPCs["N03"].Beliefs["F01"]
	if belief.Source != "N01" || belief.SourceEventID == "" {
		t.Fatalf("sold belief provenance = %+v", belief)
	}
}

func TestInformationTradeUsesScenarioCurrency(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.Rules.Economy.InformationTradeCurrency = "credit"
	for index := range bundle.NPCs {
		switch bundle.NPCs[index].ID {
		case "N01":
			bundle.NPCs[index].Resources["credit"] = 1
		case "N03":
			bundle.NPCs[index].Resources["credit"] = 5
		}
	}
	state, err := New(bundle).TradeInformation(domain.InformationTrade{ID: "credit-sale", Mode: "sell", FromID: "N01", ToID: "N03", FactID: "F01", Price: 2})
	if err != nil {
		t.Fatal(err)
	}
	if state.NPCs["N01"].Resources["credit"] != 3 || state.NPCs["N03"].Resources["credit"] != 3 {
		t.Fatalf("credit balances seller=%d buyer=%d", state.NPCs["N01"].Resources["credit"], state.NPCs["N03"].Resources["credit"])
	}
}

func TestInformationTradeExchangeSwapsKnownFacts(t *testing.T) {
	simulation := New(loadBlackwind(t))
	state, err := simulation.TradeInformation(domain.InformationTrade{ID: "swap", Mode: "exchange", FromID: "N01", ToID: "N02", FactID: "F10", ExchangeFactID: "F05"})
	if err != nil {
		t.Fatalf("TradeInformation() error = %v", err)
	}
	if _, ok := state.NPCs["N02"].Beliefs["F10"]; !ok {
		t.Fatal("recipient did not learn offered fact")
	}
	if _, ok := state.NPCs["N01"].Beliefs["F05"]; !ok {
		t.Fatal("source did not learn exchange fact")
	}
}

func TestInformationTradeTellIsFreeAndCanDistort(t *testing.T) {
	simulation := New(loadBlackwind(t))
	before := simulation.state.NPCs["N03"].Resources["spirit_stones"]
	state, err := simulation.TradeInformation(domain.InformationTrade{ID: "gift", Mode: "tell", FromID: "N01", ToID: "N03", FactID: "F01", Distortion: 1})
	if err != nil {
		t.Fatalf("TradeInformation() error = %v", err)
	}
	if state.NPCs["N03"].Resources["spirit_stones"] != before || state.NPCs["N03"].Beliefs["F01"].Confidence != 2 {
		t.Fatalf("free distorted tell state = resources %d belief %+v", state.NPCs["N03"].Resources["spirit_stones"], state.NPCs["N03"].Beliefs["F01"])
	}
}

func TestInformationTradeWithholdDoesNotLeakBelief(t *testing.T) {
	simulation := New(loadBlackwind(t))
	state, err := simulation.TradeInformation(domain.InformationTrade{ID: "deny", Mode: "withhold", FromID: "N01", ToID: "N03", FactID: "F01"})
	if err != nil {
		t.Fatalf("TradeInformation() error = %v", err)
	}
	if _, ok := state.NPCs["N03"].Beliefs["F01"]; ok {
		t.Fatal("withheld fact leaked to recipient")
	}
	if state.Events[len(state.Events)-1].Type != "information_withheld" {
		t.Fatal("withholding was not audited")
	}
}
