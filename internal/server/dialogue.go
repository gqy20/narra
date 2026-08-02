package server

import (
	"context"
	"errors"
	"net/http"

	"fantu/internal/app"
)

func (s *GameServer) generateDialogue(writer http.ResponseWriter, request *http.Request) {
	if request.Method != http.MethodPost {
		writeError(writer, http.StatusMethodNotAllowed, "method_not_allowed", "仅支持 POST")
		return
	}
	var input dialogueRequest
	if err := decodeJSON(request, &input); err != nil || input.ActorID == "" {
		if err == nil {
			err = errors.New("actor_id 不能为空")
		}
		writeError(writer, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	s.mu.Lock()
	dialogueService := s.dialogue
	s.mu.Unlock()
	if dialogueService == nil || !dialogueService.Enabled() {
		writeError(writer, http.StatusServiceUnavailable, "ai_unavailable", "动态对话当前未启用")
		return
	}

	// Hold the session lock only while creating an immutable redacted snapshot.
	// The external model call must never block gameplay state access.
	s.mu.Lock()
	if s.session == nil {
		s.mu.Unlock()
		writeError(writer, http.StatusConflict, "no_active_game", "当前没有进行中的游戏")
		return
	}
	snapshot, err := s.session.DialogueSnapshotFor(input.ActorID, input.Situation)
	var history []app.DialogueExchange
	if err == nil {
		history = s.session.DialogueHistory(input.ActorID, snapshot.Revision, 8)
	}
	s.mu.Unlock()
	if err != nil {
		writeError(writer, http.StatusBadRequest, "dialogue_rejected", err.Error())
		return
	}

	dialogue, err := dialogueService.GenerateConversationTurn(request.Context(), snapshot, history, input.PlayerMessage)
	if err != nil {
		if errors.Is(err, context.DeadlineExceeded) {
			writeError(writer, http.StatusGatewayTimeout, "ai_timeout", "人物回应生成超时，请重试")
			return
		}
		writeError(writer, http.StatusBadGateway, "ai_generation_failed", "人物回应生成失败，请重试")
		return
	}

	// A dedicated AI request may finish after the player acts or changes scene.
	// Never attach that stale presentation to the new authoritative revision.
	s.mu.Lock()
	stale := s.session == nil || s.session.DialogueRevision(input.ActorID) != snapshot.Revision
	if !stale {
		err = s.session.RecordDialogue(app.DialogueExchange{
			ActorID: input.ActorID, Revision: snapshot.Revision, PlayerText: input.PlayerMessage,
			NPCText: dialogue.Utterance, Emotion: dialogue.Emotion, DialogueAct: dialogue.DialogueAct,
			ReferencedFacts: dialogue.ReferencedFacts, SuggestedActions: dialogue.SuggestedActions,
		})
	}
	s.mu.Unlock()
	if stale {
		writeError(writer, http.StatusConflict, "stale_dialogue", "局势已经变化，本次人物回应已失效")
		return
	}
	if err != nil {
		writeError(writer, http.StatusConflict, "dialogue_record_failed", err.Error())
		return
	}
	writeJSON(writer, http.StatusOK, Response{APIVersion: APIVersion, Dialogue: &dialogue})
}
