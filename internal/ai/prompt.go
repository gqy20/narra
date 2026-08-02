package ai

import _ "embed"

const promptVersion = "npc-conversation-v2"

//go:embed prompts/npc_conversation_v2.txt
var npcConversationSystemPrompt string
