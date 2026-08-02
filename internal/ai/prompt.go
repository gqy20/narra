package ai

import _ "embed"

const promptVersion = "npc-conversation-v3"

//go:embed prompts/npc_conversation_v3.txt
var npcConversationSystemPrompt string
