package anthropic

var dialogueSchema = map[string]any{
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
		"referenced_fact_ids": map[string]any{
			"type":        "array",
			"description": "台词实际直接引用的 allowed_claims ID；未引用时为空数组",
			"items":       map[string]any{"type": "string"},
		},
	},
	"required":             []string{"utterance", "emotion", "dialogue_act", "referenced_fact_ids"},
	"additionalProperties": false,
}
