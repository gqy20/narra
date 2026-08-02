package engine

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
)

func (e *Engine) applyEffects(event domain.WorldEvent, effects []domain.Effect, defaultTarget string) error {
	for _, effect := range effects {
		targetID := effect.TargetID
		if targetID == "" {
			targetID = defaultTarget
		}
		switch effect.Type {
		case "move":
			if ok, reason := e.movementLegal(targetID, effect.Value, 0, effect.BypassRouteFlag); !ok {
				return fmt.Errorf("illegal move for %s: %s", targetID, reason)
			}
			if e.isPlayer(targetID) {
				if _, ok := e.bundle.Locations[effect.Value]; !ok {
					return fmt.Errorf("unknown destination %s", effect.Value)
				}
				e.state.Player.Location = effect.Value
				continue
			}
			npc, err := e.state.NPC(targetID)
			if err != nil {
				return err
			}
			if _, ok := e.bundle.Locations[effect.Value]; !ok {
				return fmt.Errorf("unknown destination %s", effect.Value)
			}
			npc.Location = effect.Value
		case "add_item":
			if e.isPlayer(targetID) {
				amount := effect.Amount
				if amount == 0 {
					amount = 1
				}
				e.state.Player.Items[effect.Key] += amount
				continue
			}
			npc, err := e.state.NPC(targetID)
			if err != nil {
				return err
			}
			amount := effect.Amount
			if amount == 0 {
				amount = 1
			}
			npc.Items[effect.Key] += amount
		case "remove_item":
			if e.isPlayer(targetID) {
				amount := effect.Amount
				if amount == 0 {
					amount = 1
				}
				if e.state.Player.Items[effect.Key] < amount {
					return fmt.Errorf("player lacks item %s", effect.Key)
				}
				e.state.Player.Items[effect.Key] -= amount
				continue
			}
			npc, err := e.state.NPC(targetID)
			if err != nil {
				return err
			}
			amount := effect.Amount
			if amount == 0 {
				amount = 1
			}
			if npc.Items[effect.Key] < amount {
				return fmt.Errorf("NPC %s lacks item %s", targetID, effect.Key)
			}
			npc.Items[effect.Key] -= amount
		case "market_buy":
			market := e.state.Markets[effect.Value]
			amount := effect.Amount
			if amount <= 0 {
				amount = 1
			}
			if market == nil || market.Stock[effect.Key] < amount {
				return fmt.Errorf("market %s lacks stock for %s", effect.Value, effect.Key)
			}
			market.Stock[effect.Key] -= amount
			market.Sold[effect.Key] += amount
			market.Prices[effect.Key] += market.PriceStep * amount
			if e.isPlayer(targetID) {
				e.state.Player.Items[effect.Key] += amount
			} else {
				e.state.NPCs[targetID].Items[effect.Key] += amount
			}
		case "adjust_resource":
			if e.isPlayer(targetID) {
				e.state.Player.Resources[effect.Key] += effect.Amount
				continue
			}
			npc, err := e.state.NPC(targetID)
			if err != nil {
				return err
			}
			npc.Resources[effect.Key] += effect.Amount
		case "adjust_injury":
			if e.isPlayer(targetID) {
				e.state.Player.Injury += effect.Amount
				if e.state.Player.Injury < 0 {
					e.state.Player.Injury = 0
				}
				if e.state.Player.Injury > 3 {
					e.state.Player.Injury = 3
				}
				continue
			}
			npc, err := e.state.NPC(targetID)
			if err != nil {
				return err
			}
			npc.Injury += effect.Amount
			if npc.Injury < 0 {
				npc.Injury = 0
			}
			if npc.Injury > 3 {
				npc.Injury = 3
			}
		case "set_belief":
			if _, ok := e.state.Facts[effect.FactID]; !ok {
				return fmt.Errorf("unknown fact %s", effect.FactID)
			}
			claim := effect.Claim
			if claim == "" {
				claim = e.state.Facts[effect.FactID].Truth
			}
			source := effect.Source
			if source == "" {
				source = event.ActorID
			}
			belief := domain.Belief{
				FactID: effect.FactID, Claim: claim, Confidence: maxInt(1, effect.Confidence-effect.Distortion),
				Source: source, SourceEventID: event.ID, LearnedOn: e.state.Day,
				EvidenceStrength: maxInt(1, effect.EvidenceStrength-effect.Distortion), Secrecy: effect.Secrecy,
			}
			if effect.EvidenceStrength == 0 {
				belief.EvidenceStrength = belief.Confidence
			}
			targets, err := e.informationTargets(event.ActorID, targetID, effect.Propagation)
			if err != nil {
				return err
			}
			for _, id := range targets {
				if effect.DelayDays > 0 {
					e.state.PendingInformation = append(e.state.PendingInformation, domain.InformationDelivery{
						DeliverDay: e.state.Day + effect.DelayDays, SourceActorID: event.ActorID,
						TargetID: id, SourceEventID: event.ID, Belief: belief,
					})
					continue
				}
				e.mergeActorBelief(id, belief)
			}
		case "set_flag":
			value := effect.Value != "false"
			if effect.Scope == "world" || targetID == "world" {
				e.state.SetWorldFlagWithSource(effect.Key, value, event.ID)
			} else {
				e.state.SetActorFlagWithSource(targetID, effect.Key, value, event.ID)
			}
		case "transfer_unique":
			if ok, reason := e.uniqueTransfersLegal([]domain.Effect{effect}); !ok {
				return fmt.Errorf("illegal unique transfer: %s", reason)
			}
			owner := e.state.Items[effect.Key]
			if oldNPC, ok := e.state.NPCs[owner]; ok && oldNPC.Items[effect.Key] > 0 {
				oldNPC.Items[effect.Key]--
			}
			if e.state.Player != nil && owner == e.state.Player.ID && e.state.Player.Items[effect.Key] > 0 {
				e.state.Player.Items[effect.Key]--
			}
			e.state.Items[effect.Key] = targetID
			e.state.ItemSources[effect.Key] = event.ID
			if e.isPlayer(targetID) {
				e.state.Player.Items[effect.Key]++
			} else if npc, ok := e.state.NPCs[targetID]; ok {
				npc.Items[effect.Key]++
			}
		case "set_outcome":
			e.state.Outcome = effect.Value
		case "adjust_relation":
			fromID := effect.FromID
			if fromID == "" {
				fromID = event.ActorID
			}
			if !e.actorExists(fromID) || !e.actorExists(targetID) {
				return fmt.Errorf("invalid relation actors %s -> %s", fromID, targetID)
			}
			key := domain.RelationKey(fromID, targetID)
			relation := e.state.Relations[key]
			relation.From, relation.To = fromID, targetID
			switch effect.Key {
			case "trust":
				relation.Trust = clampRelation(relation.Trust + effect.Amount)
			case "suspicion":
				relation.Suspicion = clampRelation(relation.Suspicion + effect.Amount)
			case "fear":
				relation.Fear = clampRelation(relation.Fear + effect.Amount)
			case "dependence":
				relation.Dependence = clampRelation(relation.Dependence + effect.Amount)
			case "hatred":
				relation.Hatred = clampRelation(relation.Hatred + effect.Amount)
			case "debt":
				relation.Debt = clampRelation(relation.Debt + effect.Amount)
			default:
				return fmt.Errorf("unknown relation dimension %s", effect.Key)
			}
			e.state.Relations[key] = relation
		case "open_opportunity":
			e.state.Opportunities[effect.Key] = effect.Value
			e.state.OpportunitySources[effect.Key] = event.ID
		case "close_opportunity":
			delete(e.state.Opportunities, effect.Key)
			delete(e.state.OpportunitySources, effect.Key)
		case "set_story_state":
			arc, ok := e.bundle.StoryArcs[effect.Key]
			if !ok || !storyStateDeclared(arc, effect.Value) {
				return fmt.Errorf("unknown story state %s:%s", effect.Key, effect.Value)
			}
			e.state.StoryStates[effect.Key] = effect.Value
		default:
			return fmt.Errorf("unknown effect type %s", effect.Type)
		}
	}
	return nil
}

func storyStateDeclared(arc domain.StoryArc, stateID string) bool {
	for _, candidate := range arc.States {
		if candidate == stateID {
			return true
		}
	}
	return false
}

func (e *Engine) isPlayer(id string) bool {
	return e.state.Player != nil && e.state.Player.ID == id
}

func (e *Engine) actorExists(id string) bool {
	if e.isPlayer(id) {
		return true
	}
	_, ok := e.state.NPCs[id]
	return ok
}

func (e *Engine) informationTargets(sourceActorID, targetID, propagation string) ([]string, error) {
	if targetID != "*" {
		if !e.actorExists(targetID) {
			return nil, fmt.Errorf("unknown belief target %s", targetID)
		}
		return []string{targetID}, nil
	}
	if propagation == "private" {
		return nil, fmt.Errorf("private information requires an explicit target")
	}
	ids := effectTargets(e.state, targetID)
	if propagation == "" || propagation == "all" {
		return ids, nil
	}
	sourceLocation, sourceFaction := e.actorLocationFaction(sourceActorID)
	filtered := make([]string, 0, len(ids))
	for _, id := range ids {
		location, faction := e.actorLocationFaction(id)
		if propagation == "location" && sourceLocation != "" && location == sourceLocation {
			filtered = append(filtered, id)
		}
		if propagation == "faction" && sourceFaction != "" && faction == sourceFaction {
			filtered = append(filtered, id)
		}
	}
	return filtered, nil
}

func (e *Engine) actorLocationFaction(actorID string) (string, string) {
	if e.isPlayer(actorID) {
		return e.state.Player.Location, "player"
	}
	if npc, ok := e.state.NPCs[actorID]; ok {
		return npc.Location, npc.Faction
	}
	return "", ""
}

func (e *Engine) mergeActorBelief(actorID string, belief domain.Belief) {
	if e.isPlayer(actorID) {
		mergeBelief(e.state.Player.Beliefs, belief)
		return
	}
	mergeBelief(e.state.NPCs[actorID].Beliefs, belief)
}

func maxInt(left, right int) int {
	if left > right {
		return left
	}
	return right
}

func clampRelation(value int) int {
	if value > 5 {
		return 5
	}
	if value < -5 {
		return -5
	}
	return value
}

func mergeBelief(beliefs map[string]domain.Belief, incoming domain.Belief) {
	current, exists := beliefs[incoming.FactID]
	incoming = normalizeBelief(incoming)
	if !exists {
		beliefs[incoming.FactID] = incoming
		return
	}
	current = normalizeBelief(current)
	combined := append(append([]domain.BeliefEvidence(nil), current.Evidence...), incoming.Evidence...)
	currentStrength := current.EvidenceStrength
	incomingStrength := incoming.EvidenceStrength
	if incomingStrength > currentStrength || (incomingStrength == currentStrength && current.Claim == "" && incoming.Claim != "") {
		incoming.Evidence = combined
		incoming.Contested = evidenceContested(combined)
		beliefs[incoming.FactID] = incoming
		return
	}
	current.Evidence = combined
	current.Contested = evidenceContested(combined)
	beliefs[incoming.FactID] = current
}

func normalizeBelief(belief domain.Belief) domain.Belief {
	if belief.EvidenceStrength <= 0 {
		belief.EvidenceStrength = belief.Confidence
	}
	if len(belief.Evidence) == 0 {
		belief.Evidence = []domain.BeliefEvidence{{
			Claim: belief.Claim, Strength: belief.EvidenceStrength, Confidence: belief.Confidence,
			Source: belief.Source, SourceEventID: belief.SourceEventID, LearnedOn: belief.LearnedOn,
		}}
	}
	belief.Contested = belief.Contested || evidenceContested(belief.Evidence)
	return belief
}

func evidenceContested(evidence []domain.BeliefEvidence) bool {
	claims := make(map[string]bool)
	for _, item := range evidence {
		if item.Claim != "" {
			claims[item.Claim] = true
		}
	}
	return len(claims) > 1
}

func effectTargets(state *domain.WorldState, target string) []string {
	if target != "*" {
		return []string{target}
	}
	ids := make([]string, 0, len(state.NPCs))
	for id := range state.NPCs {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}
