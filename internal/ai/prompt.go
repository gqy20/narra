package ai

import _ "embed"

const promptVersion = "npc-focus-v1"

//go:embed prompts/npc_focus_v1.txt
var npcFocusSystemPrompt string
