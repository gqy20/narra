package anthropic

func dialogueSchemaFor(allowedFactIDs, allowedActionIDs []string) map[string]any {
	factItems := map[string]any{"type": "string"}
	factList := map[string]any{
		"type":        "array",
		"description": "IDs from allowed_claims that are directly used in the utterance; empty when none are used",
		"items":       factItems,
	}
	if len(allowedFactIDs) == 0 {
		factList["maxItems"] = 0
	} else {
		factItems["enum"] = append([]string(nil), allowedFactIDs...)
	}
	actionIndex := map[string]any{
		"type": "integer", "minimum": -1,
		"description": "Zero-based available_actions index explicitly performed by player_message; -1 when the message is only conversation or ambiguous",
	}
	if len(allowedActionIDs) == 0 {
		actionIndex["maximum"] = -1
	} else {
		actionIndex["maximum"] = len(allowedActionIDs) - 1
	}
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"utterance": map[string]any{
				"type":        "string",
				"description": "One short NPC utterance in snapshot.scenario.locale",
			},
			"emotion": map[string]any{
				"type": "string",
				"enum": []string{"neutral", "alert", "troubled", "decisive"},
			},
			"dialogue_act": map[string]any{
				"type": "string",
				"enum": []string{"greet", "invite", "question", "warn", "refuse", "acknowledge"},
			},
			"referenced_fact_ids":     factList,
			"recognized_action_index": actionIndex,
		},
		"required":             []string{"utterance", "emotion", "dialogue_act", "referenced_fact_ids", "recognized_action_index"},
		"additionalProperties": false,
	}
}

func worldDirectiveSchemaFor(allowedDirectiveIDs []string) map[string]any {
	return map[string]any{
		"type": "object",
		"properties": map[string]any{
			"directive_id":         map[string]any{"type": "string", "enum": append([]string(nil), allowedDirectiveIDs...)},
			"reason":               map[string]any{"type": "string", "minLength": 1, "maxLength": 300},
			"focus_signal_indexes": map[string]any{"type": "array", "maxItems": 5, "items": map[string]any{"type": "integer", "minimum": 0}},
		},
		"required":             []string{"directive_id", "reason", "focus_signal_indexes"},
		"additionalProperties": false,
	}
}
