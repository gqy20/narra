//go:build windows

package crashreport

import (
	"fmt"
	"os"
	"syscall"
)

const miniDumpWithThreadInfo = 0x00001000

var (
	dbghelpDLL            = syscall.NewLazyDLL("Dbghelp.dll")
	kernel32DLL           = syscall.NewLazyDLL("Kernel32.dll")
	miniDumpWriteDumpProc = dbghelpDLL.NewProc("MiniDumpWriteDump")
	getCurrentProcessProc = kernel32DLL.NewProc("GetCurrentProcess")
)

func writeMiniDump(path string) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()
	process, _, _ := getCurrentProcessProc.Call()
	result, _, callErr := miniDumpWriteDumpProc.Call(
		process,
		uintptr(os.Getpid()),
		file.Fd(),
		miniDumpWithThreadInfo,
		0,
		0,
		0,
	)
	if result == 0 {
		_ = os.Remove(path)
		if callErr != syscall.Errno(0) {
			return callErr
		}
		return fmt.Errorf("MiniDumpWriteDump failed")
	}
	return nil
}
