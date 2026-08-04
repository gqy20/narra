package app

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"narra/internal/domain"
)

const (
	currentSaveVersion           = 4
	currentDirectorReplayVersion = 1
)

type DirectorReplayData struct {
	Version   int                       `json:"version"`
	Complete  bool                      `json:"complete"`
	Decisions []domain.DirectorDecision `json:"decisions"`
}

type SaveData struct {
	Version        int                 `json:"version"`
	ScenarioID     string              `json:"scenario_id"`
	ContentVersion string              `json:"content_version,omitempty"`
	ContentHash    string              `json:"content_hash,omitempty"`
	Player         domain.PlayerConfig `json:"player"`
	History        []string            `json:"history"`
	Dialogues      []DialogueExchange  `json:"dialogues,omitempty"`
	DirectorReplay DirectorReplayData  `json:"director_replay"`
}

func (s *Session) Save(writer io.Writer) error {
	data := SaveData{
		Version: currentSaveVersion, ScenarioID: s.bundle.Scenario.ID,
		ContentVersion: s.bundle.Content.Version, ContentHash: s.bundle.Content.Hash,
		Player: clonePlayerConfig(s.initial), History: s.History(), Dialogues: s.dialogueHistory(),
		DirectorReplay: DirectorReplayData{
			Version: currentDirectorReplayVersion, Complete: true,
			Decisions: append([]domain.DirectorDecision{}, s.engine.State().DirectorDecisions...),
		},
	}
	encoder := json.NewEncoder(writer)
	encoder.SetIndent("", "  ")
	return encoder.Encode(data)
}

func LoadSession(bundle domain.Bundle, reader io.Reader) (*Session, error) {
	var data SaveData
	if err := json.NewDecoder(reader).Decode(&data); err != nil {
		return nil, fmt.Errorf("decode save: %w", err)
	}
	if data.ScenarioID != bundle.Scenario.ID {
		return nil, fmt.Errorf("save scenario %s does not match %s", data.ScenarioID, bundle.Scenario.ID)
	}
	if data.Version != currentSaveVersion {
		return nil, fmt.Errorf("unsupported save version %d; expected %d", data.Version, currentSaveVersion)
	}
	if data.ContentVersion == "" || data.ContentHash == "" {
		return nil, fmt.Errorf("save is missing content version metadata")
	}
	if data.ContentHash != bundle.Content.Hash {
		return nil, fmt.Errorf("save content %s (%s) does not match loaded content %s (%s)", data.ContentVersion, data.ContentHash, bundle.Content.Version, bundle.Content.Hash)
	}
	if data.DirectorReplay.Version != currentDirectorReplayVersion || !data.DirectorReplay.Complete || data.DirectorReplay.Decisions == nil {
		return nil, fmt.Errorf("save is missing a complete world director replay contract")
	}
	session, err := NewSession(bundle, data.Player)
	if err != nil {
		return nil, err
	}
	session.engine.SetDirectorReplay(data.DirectorReplay.Decisions)
	for turn, actionID := range data.History {
		if _, err := session.execute(actionID, true); err != nil {
			return nil, fmt.Errorf("replay turn %d action %s: %w", turn+1, actionID, err)
		}
	}
	session.engine.EndDirectorReplay()
	actualDecisions := session.engine.State().DirectorDecisions
	if !sameDirectorDecisions(actualDecisions, data.DirectorReplay.Decisions) {
		return nil, fmt.Errorf("replayed world director decisions do not match save")
	}
	if len(data.Dialogues) > 1000 {
		return nil, fmt.Errorf("save contains too many dialogue exchanges")
	}
	for index, exchange := range data.Dialogues {
		if exchange.ActorID == "" || exchange.Revision == "" || strings.TrimSpace(exchange.NPCText) == "" {
			return nil, fmt.Errorf("invalid dialogue exchange %d", index+1)
		}
		session.dialogues = append(session.dialogues, exchange)
	}
	return session, nil
}

func sameDirectorDecisions(actual, expected []domain.DirectorDecision) bool {
	if len(actual) != len(expected) {
		return false
	}
	for index := range actual {
		if actual[index].Day != expected[index].Day || actual[index].DirectiveID != expected[index].DirectiveID || actual[index].Source != expected[index].Source || actual[index].Reason != expected[index].Reason {
			return false
		}
	}
	return true
}
