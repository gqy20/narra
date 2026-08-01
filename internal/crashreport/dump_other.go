//go:build !windows

package crashreport

import (
	"errors"
)

func writeMiniDump(string) error { return errors.New("native minidumps are only available on Windows") }
