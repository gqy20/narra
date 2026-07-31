package app

import (
	"encoding/json"
	"fmt"
	"io"

	"fantu/internal/domain"
)

const saveVersion = 1

type SaveData struct {
	Version    int                 `json:"version"`
	ScenarioID string              `json:"scenario_id"`
	Player     domain.PlayerConfig `json:"player"`
	History    []string            `json:"history"`
}

func (s *Session) Save(writer io.Writer) error {
	data := SaveData{
		Version: saveVersion, ScenarioID: s.bundle.Scenario.ID,
		Player: clonePlayerConfig(s.initial), History: s.History(),
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
	if data.Version != saveVersion {
		return nil, fmt.Errorf("unsupported save version %d", data.Version)
	}
	if data.ScenarioID != bundle.Scenario.ID {
		return nil, fmt.Errorf("save scenario %s does not match %s", data.ScenarioID, bundle.Scenario.ID)
	}
	session, err := NewSession(bundle, data.Player)
	if err != nil {
		return nil, err
	}
	for turn, actionID := range data.History {
		if _, err := session.execute(actionID, true); err != nil {
			return nil, fmt.Errorf("replay turn %d action %s: %w", turn+1, actionID, err)
		}
	}
	return session, nil
}
