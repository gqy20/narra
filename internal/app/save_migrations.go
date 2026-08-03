package app

import (
	"fmt"

	"fantu/internal/domain"
)

type saveMigration func(SaveData, domain.Bundle) (SaveData, error)

var saveMigrations = map[int]saveMigration{
	1: migrateSaveV1ToV2,
}

func migrateSaveData(data SaveData, bundle domain.Bundle) (SaveData, error) {
	if data.Version < 1 || data.Version > currentSaveVersion {
		return SaveData{}, fmt.Errorf("unsupported save version %d", data.Version)
	}
	for data.Version < currentSaveVersion {
		migration, ok := saveMigrations[data.Version]
		if !ok {
			return SaveData{}, fmt.Errorf("save version %d has no migration to version %d", data.Version, data.Version+1)
		}
		previous := data.Version
		var err error
		data, err = migration(data, bundle)
		if err != nil {
			return SaveData{}, fmt.Errorf("migrate save version %d: %w", previous, err)
		}
		if data.Version != previous+1 {
			return SaveData{}, fmt.Errorf("save migration %d produced version %d", previous, data.Version)
		}
	}
	return data, nil
}

func migrateSaveV1ToV2(data SaveData, bundle domain.Bundle) (SaveData, error) {
	if data.ScenarioID == "" {
		return SaveData{}, fmt.Errorf("legacy save is missing scenario id")
	}
	data.Version = 2
	data.ContentVersion = bundle.Content.Version
	data.ContentHash = bundle.Content.Hash
	return data, nil
}
