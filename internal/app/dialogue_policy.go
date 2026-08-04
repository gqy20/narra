package app

import (
	"sort"

	"narra/internal/domain"
)

func dialogueAllowedClaims(config domain.DialogueConfig, state *domain.WorldState, npc *domain.NPCState) []DialogueClaim {
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
			FactID: factID, Claim: claim, Confidence: dialogueConfidence(config, belief.Confidence),
		})
	}
	sort.Slice(result, func(i, j int) bool { return result[i].FactID < result[j].FactID })
	return result
}

func dialoguePrivateDrives(dialogue domain.DialogueConfig, config domain.NPCConfig, npc *domain.NPCState) []string {
	drives := make([]string, 0, 4)
	hasPrivateBelief := false
	for _, belief := range npc.Beliefs {
		if belief.Secrecy > 0 {
			hasPrivateBelief = true
			break
		}
	}
	if hasPrivateBelief {
		drives = appendConfigured(drives, dialogue.PrivateDrives["secret"])
	}
	for _, goal := range config.Goals {
		switch goal.Type {
		case "protect":
			drives = appendConfigured(drives, dialogue.PrivateDrives["protect"])
		case "profit", "acquire":
			drives = appendConfigured(drives, dialogue.PrivateDrives["profit"])
		case "avoid":
			drives = appendConfigured(drives, dialogue.PrivateDrives["avoid"])
		case "status":
			drives = appendConfigured(drives, dialogue.PrivateDrives["status"])
		}
	}
	return drives
}

func dialogueSpeechGuidance(config domain.DialogueConfig, personality domain.Personality, actor domain.ActorDialogueConfig) []string {
	result := make([]string, 0, 4)
	if personality.Caution >= 4 {
		result = appendConfigured(result, config.PersonalityGuidance["caution"])
	}
	if personality.Greed >= 4 {
		result = appendConfigured(result, config.PersonalityGuidance["greed"])
	}
	if personality.Loyalty >= 4 {
		result = appendConfigured(result, config.PersonalityGuidance["loyalty"])
	}
	if personality.Ambition >= 4 {
		result = appendConfigured(result, config.PersonalityGuidance["ambition"])
	}
	if personality.Credit >= 4 {
		result = appendConfigured(result, config.PersonalityGuidance["credit"])
	}
	if len(result) == 0 {
		result = appendConfigured(result, config.PersonalityGuidance["default"])
	}
	for _, guidance := range actor.Guidance {
		result = appendConfigured(result, guidance)
	}
	return result
}

func dialogueRelation(config domain.DialogueConfig, relation domain.Relation) DialogueRelation {
	attitude := config.Relations.DefaultAttitude
	if relation.Hatred >= 3 || relation.Fear >= 4 {
		attitude = config.Relations.GuardedAttitude
	} else if relation.Trust >= 3 {
		attitude = config.Relations.TrustingAttitude
	} else if relation.Suspicion >= 3 {
		attitude = config.Relations.SuspiciousAttitude
	}
	return DialogueRelation{
		Attitude: attitude,
		Trust:    relationBand(relation.Trust, config.Relations.TrustBands),
		Concern:  relationBand(relation.Suspicion, config.Relations.ConcernBands),
	}
}

func dialogueConfidence(config domain.DialogueConfig, value int) string {
	switch {
	case value >= 3:
		return config.ConfidenceLabels.Confirmed
	case value == 2:
		return config.ConfidenceLabels.Plausible
	default:
		return config.ConfidenceLabels.Rumored
	}
}

func relationBand(value int, labels []string) string {
	if len(labels) != 3 {
		return ""
	}
	switch {
	case value >= 3:
		return labels[2]
	case value >= 1:
		return labels[1]
	default:
		return labels[0]
	}
}

func appendConfigured(values []string, value string) []string {
	if value == "" {
		return values
	}
	return appendUnique(values, value)
}

func appendUnique(values []string, value string) []string {
	for _, existing := range values {
		if existing == value {
			return values
		}
	}
	return append(values, value)
}
