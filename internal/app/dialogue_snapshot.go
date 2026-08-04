package app

import (
	"fmt"
	"sort"
	"strings"

	"narra/internal/domain"
)

// DialogueSnapshot is the immutable, deliberately redacted view supplied to
// the optional narrative service. It is not part of the authoritative world
// state and must never be used to settle game rules.
type DialogueSnapshot struct {
	Revision         string           `json:"revision"`
	ScenarioID       string           `json:"scenario_id"`
	Scenario         DialogueScenario `json:"scenario"`
	Day              int              `json:"day"`
	Situation        string           `json:"situation"`
	Actor            DialogueActor    `json:"actor"`
	Player           DialoguePlayer   `json:"player"`
	Relation         DialogueRelation `json:"relation"`
	PublicPlan       string           `json:"public_plan,omitempty"`
	RecentEvents     []DialogueEvent  `json:"recent_events,omitempty"`
	AllowedClaims    []DialogueClaim  `json:"allowed_claims,omitempty"`
	PrivateDrives    []string         `json:"private_drives,omitempty"`
	AllowedActs      []string         `json:"allowed_acts,omitempty"`
	AvailableActions []DialogueAction `json:"available_actions,omitempty"`
}

type DialogueScenario struct {
	Title                  string   `json:"title"`
	Context                string   `json:"context,omitempty"`
	PlayerAddress          string   `json:"player_address,omitempty"`
	Style                  string   `json:"style,omitempty"`
	Locale                 string   `json:"locale"`
	MinCharacters          int      `json:"min_characters"`
	PreferredMaxCharacters int      `json:"preferred_max_characters"`
	HardMaxCharacters      int      `json:"hard_max_characters"`
	MaxSentences           int      `json:"max_sentences"`
	UncertaintyMarkers     []string `json:"uncertainty_markers"`
	ForbiddenTerms         []string `json:"forbidden_terms,omitempty"`
	RumoredConfidence      string   `json:"rumored_confidence"`
}

type DialogueActor struct {
	ID             string   `json:"id"`
	Name           string   `json:"name"`
	Faction        string   `json:"faction"`
	PublicRole     string   `json:"public_role"`
	PublicProfile  string   `json:"public_profile"`
	PublicFocus    []string `json:"public_focus,omitempty"`
	SpeechGuidance []string `json:"speech_guidance,omitempty"`
	SelfAddress    string   `json:"self_address,omitempty"`
}

type DialoguePlayer struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type DialogueRelation struct {
	Attitude string `json:"attitude"`
	Trust    string `json:"trust"`
	Concern  string `json:"concern"`
}

type DialogueClaim struct {
	FactID     string `json:"fact_id"`
	Claim      string `json:"claim"`
	Confidence string `json:"confidence"`
}

type DialogueEvent struct {
	Day         int    `json:"day"`
	Description string `json:"description"`
}

type DialogueAction struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

// DialogueRevision returns the revision used to reject an AI response after
// the player has moved the authoritative session forward.
func (s *Session) DialogueRevision(actorID string) string {
	state := s.engine.State()
	return s.dialogueRevision(state, actorID)
}

// DialogueSnapshotFor builds a safe prompt snapshot for a visible actor.
func (s *Session) DialogueSnapshotFor(actorID, situation string) (DialogueSnapshot, error) {
	state := s.engine.State()
	npc, ok := state.NPCs[actorID]
	if !ok {
		return DialogueSnapshot{}, fmt.Errorf("unknown actor %q", actorID)
	}
	if npc.Location != state.Player.Location {
		return DialogueSnapshot{}, fmt.Errorf("actor %q is not at the player's location", actorID)
	}
	if situation == "" {
		situation = "focus"
	}
	if situation != "focus" {
		return DialogueSnapshot{}, fmt.Errorf("unsupported dialogue situation %q", situation)
	}

	config := s.actorConfig(actorID)
	voice := s.bundle.Dialogue.Actors[actorID]
	visible := s.visibleActorForDialogue(state, actorID)
	relation := state.RelationBetween(actorID, state.Player.ID)
	snapshot := DialogueSnapshot{
		Revision: s.dialogueRevision(state, actorID), ScenarioID: s.bundle.Scenario.ID,
		Scenario: DialogueScenario{
			Title: s.bundle.Scenario.Title, Context: s.bundle.Dialogue.Context,
			PlayerAddress: dialoguePlayerAddress(s.bundle.Dialogue, voice), Style: dialogueActorStyle(s.bundle.Dialogue, voice),
			Locale: s.bundle.Dialogue.Language.Locale, MinCharacters: s.bundle.Dialogue.Language.MinCharacters,
			PreferredMaxCharacters: s.bundle.Dialogue.Language.PreferredMaxCharacters,
			HardMaxCharacters:      s.bundle.Dialogue.Language.HardMaxCharacters,
			MaxSentences:           s.bundle.Dialogue.Language.MaxSentences,
			UncertaintyMarkers:     append([]string(nil), s.bundle.Dialogue.Language.UncertaintyMarkers...),
			ForbiddenTerms:         append(append([]string(nil), s.bundle.Dialogue.Language.ForbiddenSelfAddresses...), voice.ForbiddenTerms...),
			RumoredConfidence:      s.bundle.Dialogue.ConfidenceLabels.Rumored,
		},
		Day: state.Day, Situation: situation,
		Actor: DialogueActor{
			ID: actorID, Name: npc.Name, Faction: npc.Faction,
			PublicRole: visible.PublicRole, PublicProfile: visible.PublicProfile,
			PublicFocus:    append([]string(nil), visible.PublicFocus...),
			SpeechGuidance: dialogueSpeechGuidance(s.bundle.Dialogue, npc.Personality, voice),
			SelfAddress:    voice.SelfAddress,
		},
		Player:        DialoguePlayer{ID: state.Player.ID, Name: state.Player.Name},
		Relation:      dialogueRelation(s.bundle.Dialogue, relation),
		AllowedClaims: dialogueAllowedClaims(s.bundle.Dialogue, state, npc),
		PrivateDrives: dialoguePrivateDrives(s.bundle.Dialogue, config, npc),
		AllowedActs:   s.dialogueAllowedActs(state, actorID),
	}
	for _, option := range s.actionCatalog(state) {
		if option.TargetID == actorID && option.Kind != "advance" {
			snapshot.AvailableActions = append(snapshot.AvailableActions, DialogueAction{
				ID: option.ID, Name: option.Name,
			})
		}
	}
	if visible.Plan != nil {
		snapshot.PublicPlan = strings.TrimSpace(visible.Plan.Plan + "；" + visible.Plan.Reason)
	}
	events := s.visibleEvents(state)
	if len(events) > 5 {
		events = events[len(events)-5:]
	}
	for _, event := range events {
		snapshot.RecentEvents = append(snapshot.RecentEvents, DialogueEvent{Day: event.Day, Description: event.Description})
	}
	return snapshot, nil
}

func dialoguePlayerAddress(config domain.DialogueConfig, actor domain.ActorDialogueConfig) string {
	if actor.PlayerAddress != "" {
		return actor.PlayerAddress
	}
	return config.PlayerAddress
}

func dialogueActorStyle(config domain.DialogueConfig, actor domain.ActorDialogueConfig) string {
	if actor.Style != "" {
		return config.Style + "；" + actor.Style
	}
	return config.Style
}

func (s *Session) dialogueRevision(state *domain.WorldState, actorID string) string {
	return fmt.Sprintf("%s:%d:%d:%s", s.bundle.Scenario.ID, state.Day, len(s.history), actorID)
}

func (s *Session) visibleActorForDialogue(state *domain.WorldState, actorID string) VisibleActor {
	for _, actor := range s.visibleActors(state) {
		if actor.ID == actorID {
			return actor
		}
	}
	return VisibleActor{ID: actorID, PublicRole: "可交谈人物", PublicProfile: "公开资料尚未收集"}
}

func (s *Session) dialogueAllowedActs(state *domain.WorldState, actorID string) []string {
	seen := make(map[string]bool)
	for _, option := range s.actionOptions(state) {
		if option.view.TargetID != actorID || option.view.Kind == "" {
			continue
		}
		seen[option.view.Kind] = true
	}
	result := make([]string, 0, len(seen))
	for kind := range seen {
		result = append(result, kind)
	}
	sort.Strings(result)
	return result
}
