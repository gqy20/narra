package engine

import "testing"

func TestActionRecordsUpstreamTriggerEvent(t *testing.T) {
	bundle := loadBlackwind(t)
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	var rumorEventID string
	for _, event := range state.Events {
		if event.CauseID == "EV05" {
			rumorEventID = event.ID
			break
		}
	}
	if rumorEventID == "" {
		t.Fatal("fixed rumor event was not recorded")
	}

	for _, event := range state.Events {
		if event.StrategyID != "N10-hoard-antidote" {
			continue
		}
		if !containsString(event.TriggerEventIDs, rumorEventID) {
			t.Fatalf("hoard event triggers = %v, want %s", event.TriggerEventIDs, rumorEventID)
		}
		return
	}
	t.Fatal("N10 hoard action was not recorded")
}

func TestEffectSourcesPointToProducingEvent(t *testing.T) {
	bundle := loadBlackwind(t)
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}

	sourceID := state.WorldFlagSources["rumor_public"]
	if sourceID == "" {
		t.Fatal("rumor_public has no source event")
	}
	for _, event := range state.Events {
		if event.ID == sourceID && event.CauseID == "EV05" {
			return
		}
	}
	t.Fatalf("flag source %s does not resolve to EV05", sourceID)
}

func containsString(values []string, want string) bool {
	for _, value := range values {
		if value == want {
			return true
		}
	}
	return false
}
