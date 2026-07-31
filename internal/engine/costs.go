package engine

import (
	"fmt"
	"sort"

	"fantu/internal/domain"
)

func (e *Engine) canAfford(actorID string, costs map[string]int) (bool, string) {
	resources, ok := e.resourcesFor(actorID)
	if !ok {
		return false, "actor has no resource state"
	}
	for _, resource := range sortedCostKeys(costs) {
		amount := costs[resource]
		if amount > 0 && resources[resource] < amount {
			return false, fmt.Sprintf("资源 %s 不足：需要 %d，现有 %d", resource, amount, resources[resource])
		}
	}
	return true, ""
}

func (e *Engine) payCosts(actorID string, costs map[string]int) map[string]int {
	resources, _ := e.resourcesFor(actorID)
	paid := make(map[string]int, len(costs))
	for _, resource := range sortedCostKeys(costs) {
		amount := costs[resource]
		if amount <= 0 {
			continue
		}
		resources[resource] -= amount
		paid[resource] = amount
	}
	return paid
}

func (e *Engine) refundCosts(actorID string, costs map[string]int) {
	resources, ok := e.resourcesFor(actorID)
	if !ok {
		return
	}
	for resource, amount := range costs {
		resources[resource] += amount
	}
}

func (e *Engine) resourcesFor(actorID string) (map[string]int, bool) {
	if e.state.Player != nil && e.state.Player.ID == actorID {
		return e.state.Player.Resources, true
	}
	if npc, ok := e.state.NPCs[actorID]; ok {
		return npc.Resources, true
	}
	return nil, false
}

func costEffects(costs map[string]int) []domain.Effect {
	effects := make([]domain.Effect, 0, len(costs))
	for _, resource := range sortedCostKeys(costs) {
		if costs[resource] > 0 {
			effects = append(effects, domain.Effect{Type: "adjust_resource", Key: resource, Amount: -costs[resource]})
		}
	}
	return effects
}

func sortedCostKeys(costs map[string]int) []string {
	keys := make([]string, 0, len(costs))
	for resource := range costs {
		keys = append(keys, resource)
	}
	sort.Strings(keys)
	return keys
}
