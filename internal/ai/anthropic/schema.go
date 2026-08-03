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
	actionItems := map[string]any{"type": "string"}
	actionList := map[string]any{
		"type": "array", "maxItems": 3,
		"description": "Up to three available_actions IDs that fit the utterance; suggestions do not execute actions",
		"items":       actionItems,
	}
	if len(allowedActionIDs) == 0 {
		actionList["maxItems"] = 0
	} else {
		actionItems["enum"] = append([]string(nil), allowedActionIDs...)
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
			"referenced_fact_ids":  factList,
			"suggested_action_ids": actionList,
		},
		"required":             []string{"utterance", "emotion", "dialogue_act", "referenced_fact_ids", "suggested_action_ids"},
		"additionalProperties": false,
	}
}
