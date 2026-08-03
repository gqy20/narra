package engine

import (
	"testing"

	"fantu/internal/domain"
)

func TestBuyoutAgreementTransfersPriceAndUniqueItem(t *testing.T) {
	simulation := New(loadBlackwind(t))
	state, err := simulation.SettleAgreement(domain.AgreementRequest{
		ID: "G1", Mode: "buyout", OwnerID: "N02", CustodianID: "N03", ItemID: "jade_box", Price: 30,
	})
	if err != nil {
		t.Fatalf("SettleAgreement() error = %v", err)
	}
	if state.Items["jade_box"] != "N03" || state.NPCs["N02"].Resources["spirit_stones"] != 210 || state.NPCs["N03"].Resources["spirit_stones"] != 90 {
		t.Fatalf("buyout item=%s seller=%d buyer=%d", state.Items["jade_box"], state.NPCs["N02"].Resources["spirit_stones"], state.NPCs["N03"].Resources["spirit_stones"])
	}
	if state.Agreements["G1"].Shares["N03"] != 100 || state.Agreements["G1"].Currency != "spirit_stones" {
		t.Fatalf("buyout agreement = %+v", state.Agreements["G1"])
	}
}

func TestBuyoutAgreementUsesScenarioCurrency(t *testing.T) {
	bundle := loadBlackwind(t)
	bundle.Rules.Economy.AgreementCurrency = "credit"
	for index := range bundle.NPCs {
		switch bundle.NPCs[index].ID {
		case "N02":
			bundle.NPCs[index].Resources["credit"] = 1
		case "N03":
			bundle.NPCs[index].Resources["credit"] = 5
		}
	}
	state, err := New(bundle).SettleAgreement(domain.AgreementRequest{ID: "G-credit", Mode: "buyout", OwnerID: "N02", CustodianID: "N03", ItemID: "jade_box", Price: 2})
	if err != nil {
		t.Fatal(err)
	}
	if state.NPCs["N02"].Resources["credit"] != 3 || state.NPCs["N03"].Resources["credit"] != 3 || state.Agreements["G-credit"].Currency != "credit" {
		t.Fatalf("credit buyout state = %+v", state.Agreements["G-credit"])
	}
}

func TestCustodyAgreementRecordsCustodian(t *testing.T) {
	simulation := New(loadBlackwind(t))
	state, err := simulation.SettleAgreement(domain.AgreementRequest{
		ID: "G1", Mode: "custody", OwnerID: "N02", CustodianID: "N06", ItemID: "jade_box",
	})
	if err != nil {
		t.Fatalf("SettleAgreement() error = %v", err)
	}
	if state.Items["jade_box"] != "N06" || state.Agreements["G1"].CustodianID != "N06" {
		t.Fatalf("custody state item=%s agreement=%+v", state.Items["jade_box"], state.Agreements["G1"])
	}
}

func TestSplitAgreementKeepsSingleCustodianAndSharedClaims(t *testing.T) {
	simulation := New(loadBlackwind(t))
	state, err := simulation.SettleAgreement(domain.AgreementRequest{
		ID: "G1", Mode: "split", OwnerID: "N02", CustodianID: "N06", ItemID: "jade_box",
		Shares: map[string]int{"N02": 60, "N06": 40},
	})
	if err != nil {
		t.Fatalf("SettleAgreement() error = %v", err)
	}
	agreement := state.Agreements["G1"]
	if state.Items["jade_box"] != "N06" || agreement.Shares["N02"] != 60 || agreement.Shares["N06"] != 40 {
		t.Fatalf("split state item=%s agreement=%+v", state.Items["jade_box"], agreement)
	}
	if state.NPCs["N02"].Items["jade_box"] != 0 || state.NPCs["N06"].Items["jade_box"] != 1 {
		t.Fatal("split agreement duplicated unique physical item")
	}
}
