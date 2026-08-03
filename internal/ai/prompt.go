package ai

import _ "embed"

const promptVersion = "npc-conversation-v5"

//go:embed prompts/npc_conversation_v5.txt
var npcConversationSystemPrompt string
