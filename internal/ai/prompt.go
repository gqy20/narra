package ai

import _ "embed"

const promptVersion = "npc-conversation-v4"

//go:embed prompts/npc_conversation_v4.txt
var npcConversationSystemPrompt string
