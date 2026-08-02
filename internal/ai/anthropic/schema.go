package anthropic

func dialogueSchemaFor(allowedFactIDs []string) map[string]any {
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
			"referenced_fact_ids": factList,
		},
		"required":             []string{"utterance", "emotion", "dialogue_act", "referenced_fact_ids"},
		"additionalProperties": false,
	}
}
