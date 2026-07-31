package engine

import (
	"sort"

	"fantu/internal/domain"
)

func (e *Engine) resolveUniqueClaimConflicts(intents []domain.ActionIntent) map[string]string {
	claims := make(map[string][]domain.ActionIntent)
	for _, intent := range intents {
		for _, effect := range intent.Strategy.Effects {
			if effect.Type == "transfer_unique" {
				claims[effect.Key] = append(claims[effect.Key], intent)
			}
		}
	}
	losers := make(map[string]string)
	for itemID, contenders := range claims {
		if len(contenders) < 2 {
			continue
		}
		sort.SliceStable(contenders, func(i, j int) bool {
			left, right := e.claimStrength(contenders[i]), e.claimStrength(contenders[j])
			if left != right {
				return left > right
			}
			return contenders[i].ActorID < contenders[j].ActorID
		})
		for _, loser := range contenders[1:] {
			losers[loser.ActorID] = itemID
		}
	}
	return losers
}

func (e *Engine) claimStrength(intent domain.ActionIntent) int {
	resources, _ := e.resourcesFor(intent.ActorID)
	return resources["combat"] + resources["support"] + intent.Score.Total
}

func (e *Engine) uniqueTransfersLegal(effects []domain.Effect) (bool, string) {
	for _, effect := range effects {
		if effect.Type != "transfer_unique" {
			continue
		}
		item, ok := e.bundle.Items[effect.Key]
		if !ok || !item.Unique {
			return false, "transfer_unique references non-unique item " + effect.Key
		}
		if effect.FromID == "" {
			return false, "transfer_unique requires from_id for " + effect.Key
		}
		if owner := e.state.Items[effect.Key]; owner != effect.FromID {
			return false, "唯一物品 " + effect.Key + " 当前归属 " + owner + "，预期来源 " + effect.FromID
		}
	}
	return true, ""
}
