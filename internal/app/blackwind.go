package app

import "fantu/internal/domain"

func DefaultBlackwindPlayer(name string) domain.PlayerConfig {
	if name == "" {
		name = "无名散修"
	}
	return domain.PlayerConfig{
		ID: "P00", Name: name, Location: "L01",
		Resources: map[string]int{"combat": 2, "support": 0, "spirit_stones": 100, "credit": 3},
		Items:     []string{"healing_pill"},
		Beliefs: []domain.Belief{{
			FactID: "F02", Claim: "青髓芝将在第24天成熟", Confidence: 1,
			Source: "坊市传言", LearnedOn: 0, Secrecy: 0,
		}},
	}
}
