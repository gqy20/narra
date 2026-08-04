package aiconfig

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadDotEnvLoadsValuesAndPreservesProcessEnvironment(t *testing.T) {
	directory := t.TempDir()
	path := filepath.Join(directory, ".env")
	if err := os.WriteFile(path, []byte("NARRA_ENV_TEST_NEW='loaded'\nNARRA_ENV_TEST_EXISTING=file\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("NARRA_ENV_TEST_EXISTING", "process")
	os.Unsetenv("NARRA_ENV_TEST_NEW")
	t.Cleanup(func() { os.Unsetenv("NARRA_ENV_TEST_NEW") })
	if err := LoadDotEnv(path); err != nil {
		t.Fatal(err)
	}
	if got := os.Getenv("NARRA_ENV_TEST_NEW"); got != "loaded" {
		t.Fatalf("loaded value = %q", got)
	}
	if got := os.Getenv("NARRA_ENV_TEST_EXISTING"); got != "process" {
		t.Fatalf("process environment was overwritten: %q", got)
	}
}

func TestLoadDotEnvAllowsMissingFile(t *testing.T) {
	if err := LoadDotEnv(filepath.Join(t.TempDir(), "missing.env")); err != nil {
		t.Fatal(err)
	}
}
