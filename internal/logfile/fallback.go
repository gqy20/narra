package logfile

import (
	"fmt"
	"io"
	"sync"
)

// FallbackWriter mirrors output to a file writer and a fallback stream. A file
// failure is reported once to the fallback without interrupting later logs.
type FallbackWriter struct {
	Primary  io.Writer
	Fallback io.Writer
	mu       sync.Mutex
	reported bool
}

// Write implements io.Writer.
func (writer *FallbackWriter) Write(data []byte) (int, error) {
	writer.mu.Lock()
	defer writer.mu.Unlock()
	if writer.Fallback != nil {
		_, _ = writer.Fallback.Write(data)
	}
	if writer.Primary == nil {
		return len(data), nil
	}
	if _, err := writer.Primary.Write(data); err != nil {
		if !writer.reported && writer.Fallback != nil {
			writer.reported = true
			_, _ = fmt.Fprintf(writer.Fallback, "narra logging fallback: file output disabled after write failure: %v\n", err)
		}
	}
	return len(data), nil
}

var _ io.Writer = (*FallbackWriter)(nil)
