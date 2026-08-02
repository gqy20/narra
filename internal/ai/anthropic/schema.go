package anthropic

func dialogueSchemaFor(allowedFactIDs, allowedActionIDs []string) map[string]any {
	factItems := map[string]any{"type": "string"}
	factList := map[string]any{
		"type":        "array",
		"description": "台词实际直接引用的 allowed_claims ID；未引用时为空数组",
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
		"description": "与本句意图匹配的 available_actions ID；不代表已经执行",
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
				"description": "人物当前说出的一句简短中文台词",
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
