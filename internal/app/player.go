package app

import "fantu/internal/domain"

func DefaultPlayer(bundle domain.Bundle, name string) domain.PlayerConfig {
	player := clonePlayerConfig(bundle.DefaultPlayer)
	if name == "" {
		return player
	}
	player.Name = name
	return player
}
