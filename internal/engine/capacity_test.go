package engine

import (
	"fmt"
	"testing"

	"narra/internal/domain"
)

func scaleBundle(b *testing.B, count int) domain.Bundle {
	b.Helper()
	bundle := loadBlackwind(b)
	return configureScaleBundle(bundle, count)
}

func configureScaleBundle(bundle domain.Bundle, count int) domain.Bundle {
	bundle.Scenario.Duration = 3
	bundle.Scenario.FixedEvents = nil
	bundle.Scenario.Contest.Day = 4
	bundle.Scenario.Phases = []domain.SituationPhase{{ID: "scale", Name: "容量", FromDay: 1, ToDay: 3}}
	bundle.NPCs = make([]domain.NPCConfig, count)
	for i := range bundle.NPCs {
		bundle.NPCs[i] = domain.NPCConfig{
			ID: fmt.Sprintf("S%04d", i), Name: fmt.Sprintf("容量角色%d", i), Location: "L01",
			Resources: map[string]int{"combat": 5}, Personality: domain.Personality{},
		}
	}
	return bundle
}

func TestEngineHandles500NPCs(t *testing.T) {
	bundle := configureScaleBundle(loadBlackwind(t), 500)
	state, err := New(bundle).Run()
	if err != nil {
		t.Fatalf("500 NPC Run() error = %v", err)
	}
	if len(state.NPCs) != 500 || state.Day != 3 {
		t.Fatalf("capacity state NPCs/day = %d/%d", len(state.NPCs), state.Day)
	}
	if err := ValidateState(state, bundle); err != nil {
		t.Fatalf("500 NPC final state invalid: %v", err)
	}
}

func benchmarkEngineScale(b *testing.B, count int) {
	bundle := scaleBundle(b, count)
	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if _, err := New(bundle).Run(); err != nil {
			b.Fatal(err)
		}
	}
}

func BenchmarkEngineScale50(b *testing.B)  { benchmarkEngineScale(b, 50) }
func BenchmarkEngineScale100(b *testing.B) { benchmarkEngineScale(b, 100) }
func BenchmarkEngineScale500(b *testing.B) { benchmarkEngineScale(b, 500) }
