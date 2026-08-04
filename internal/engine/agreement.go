package engine

import (
	"fmt"
	"sort"

	"narra/internal/domain"
)

func (e *Engine) SettleAgreement(request domain.AgreementRequest) (*domain.WorldState, error) {
	if request.ID == "" || e.state.Agreements[request.ID] != nil || (request.Mode != "buyout" && request.Mode != "custody" && request.Mode != "split") {
		return nil, fmt.Errorf("agreement requires unique id and valid mode")
	}
	item, ok := e.bundle.Items[request.ItemID]
	if !ok || !item.Unique || e.state.Items[request.ItemID] != request.OwnerID || !e.actorExists(request.OwnerID) || !e.actorExists(request.CustodianID) {
		return nil, fmt.Errorf("agreement requires current actor owner, custodian, and unique item")
	}
	shares := copyIntMap(request.Shares)
	if len(shares) == 0 {
		shares = map[string]int{request.CustodianID: 100}
	}
	total := 0
	parties := make([]string, 0, len(shares))
	for party, share := range shares {
		if !e.actorExists(party) || share <= 0 {
			return nil, fmt.Errorf("agreement has invalid party share")
		}
		total += share
		parties = append(parties, party)
	}
	if total != 100 {
		return nil, fmt.Errorf("agreement shares must total 100")
	}
	if request.Mode == "buyout" {
		currency := e.bundle.Rules.Economy.AgreementCurrency
		if currency == "" || request.Price <= 0 || e.actorResources(request.CustodianID)[currency] < request.Price {
			return nil, fmt.Errorf("buyout requires payable positive price")
		}
	} else if request.Price != 0 {
		return nil, fmt.Errorf("only buyout accepts a price")
	}
	sort.Strings(parties)
	event := e.newEvent("agreement_settled", request.OwnerID, request.CustodianID, "达成"+request.Mode+"协议："+request.ItemID, request.ID, nil)
	if sourceID := e.state.ItemSources[request.ItemID]; sourceID != "" {
		event.TriggerEventIDs = []string{sourceID}
	}
	if request.Mode == "buyout" {
		currency := e.bundle.Rules.Economy.AgreementCurrency
		e.actorResources(request.CustodianID)[currency] -= request.Price
		e.actorResources(request.OwnerID)[currency] += request.Price
	}
	e.transferUniqueItem(request.ItemID, request.OwnerID, request.CustodianID, event.ID)
	e.state.Agreements[request.ID] = &domain.Agreement{
		ID: request.ID, Mode: request.Mode, Parties: parties, ItemID: request.ItemID, CustodianID: request.CustodianID,
		Shares: shares, Price: request.Price, Currency: e.bundle.Rules.Economy.AgreementCurrency, Status: "settled", SettledEventID: event.ID,
	}
	e.state.Events = append(e.state.Events, event)
	return e.State(), nil
}

func (e *Engine) transferUniqueItem(itemID, fromID, toID, eventID string) {
	if from := e.state.NPCs[fromID]; from != nil && from.Items[itemID] > 0 {
		from.Items[itemID]--
	} else if e.isPlayer(fromID) && e.state.Player.Items[itemID] > 0 {
		e.state.Player.Items[itemID]--
	}
	e.state.Items[itemID] = toID
	e.state.ItemSources[itemID] = eventID
	if to := e.state.NPCs[toID]; to != nil {
		to.Items[itemID]++
	} else if e.isPlayer(toID) {
		e.state.Player.Items[itemID]++
	}
}
