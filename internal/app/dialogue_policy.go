package app

import (
	"sort"

	"fantu/internal/domain"
)

func dialogueAllowedClaims(state *domain.WorldState, npc *domain.NPCState) []DialogueClaim {
	result := make([]DialogueClaim, 0)
	for factID, belief := range npc.Beliefs {
		if belief.Secrecy > 0 && belief.Source != state.Player.ID {
			continue
		}
		claim := belief.Claim
		if claim == "" {
			continue
		}
		result = append(result, DialogueClaim{
			FactID: factID, Claim: claim, Confidence: dialogueConfidence(belief.Confidence),
		})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].FactID < result[j].FactID })
	return result
}

func dialoguePrivateDrives(config domain.NPCConfig, npc *domain.NPCState) []string {
	drives := make([]string, 0, 4)
	hasPrivateBelief := false
	for _, belief := range npc.Beliefs {
		if belief.Secrecy > 0 {
			hasPrivateBelief = true
			break
		}
	}
	if hasPrivateBelief {
		drives = append(drives, "正在保守与当前局势有关的信息，不会主动说明秘密内容")
	}
	for _, goal := range config.Goals {
		switch goal.Type {
		case "protect":
			drives = appendUnique(drives, "优先保护重要的人或资源")
		case "profit", "acquire":
			drives = appendUnique(drives, "会衡量消息和交易是否对自己有利")
		case "avoid":
			drives = appendUnique(drives, "倾向避免自己承担无法控制的损失")
		case "status":
			drives = appendUnique(drives, "在意自己的地位和他人评价")
		}
	}
	return drives
}

func dialogueSpeechGuidance(personality domain.Personality) []string {
	result := make([]string, 0, 4)
	if personality.Caution >= 4 {
		result = append(result, "措辞谨慎，先确认来意和消息来源")
	}
	if personality.Greed >= 4 {
		result = append(result, "说话时会自然衡量交换价值")
	}
	if personality.Loyalty >= 4 {
		result = append(result, "重视阵营责任，不轻易作出越权承诺")
	}
	if personality.Ambition >= 4 {
		result = append(result, "表达直接，关注事情能否推动自己的目标")
	}
	if personality.Credit >= 4 {
		result = append(result, "重视承诺和消息是否可靠")
	}
	if len(result) == 0 {
		result = append(result, "保持克制，不主动作出没有依据的承诺")
	}
	return result
}

func dialogueRelation(relation domain.Relation) DialogueRelation {
	attitude := "保持礼貌而克制"
	if relation.Hatred >= 3 || relation.Fear >= 4 {
		attitude = "明显戒备，不愿拉近距离"
	} else if relation.Trust >= 3 {
		attitude = "愿意认真听取玩家的话"
	} else if relation.Suspicion >= 3 {
		attitude = "对玩家的动机和来源保持怀疑"
	}
	return DialogueRelation{
		Attitude: attitude,
		Trust:    relationBand(relation.Trust, "信任较低", "尚未建立信任", "已有一定信任"),
		Concern:  relationBand(relation.Suspicion, "没有明显怀疑", "仍在观察", "怀疑较强"),
	}
}

func dialogueConfidence(value int) string {
	switch {
	case value >= 3:
		return "确信"
	case value == 2:
		return "较为相信"
	default:
		return "只是听说"
	}
}

func relationBand(value int, low, middle, high string) string {
	switch {
	case value >= 3:
		return high
	case value >= 1:
		return middle
	default:
		return low
	}
}

func appendUnique(values []string, value string) []string {
	for _, existing := range values {
		if existing == value {
			return values
		}
	}
	return append(values, value)
}
