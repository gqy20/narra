package ai

import _ "embed"

const promptVersion = "npc-conversation-v6"

//go:embed prompts/npc_conversation_v6.txt
var npcConversationSystemPrompt string
