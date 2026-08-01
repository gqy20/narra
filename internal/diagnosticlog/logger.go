// Package diagnosticlog formats privacy-aware structured diagnostic events.
package diagnosticlog

import (
	"fmt"
	"log"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Level is the severity threshold for diagnostic events.
type Level int

const (
	Debug Level = iota
	Info
	Warn
	Error
)

var credentialPattern = regexp.MustCompile(`(?i)\b(token|password|secret|authorization|cookie)=([^\s&]+)`)

// ParseLevel accepts DEBUG, INFO, WARN, or ERROR and defaults to INFO.
func ParseLevel(value string) (Level, error) {
	switch strings.ToUpper(strings.TrimSpace(value)) {
	case "DEBUG":
		return Debug, nil
	case "", "INFO":
		return Info, nil
	case "WARN", "WARNING":
		return Warn, nil
	case "ERROR":
		return Error, nil
	default:
		return Info, fmt.Errorf("unsupported log level %q", value)
	}
}

func (level Level) String() string {
	switch level {
	case Debug:
		return "DEBUG"
	case Warn:
		return "WARN"
	case Error:
		return "ERROR"
	default:
		return "INFO"
	}
}

// Logger emits one key-value event per line.
type Logger struct {
	base      *log.Logger
	minimum   Level
	component string
	session   string
	version   string
}

// New constructs a structured logger.
func New(base *log.Logger, minimum Level, component, session, version string) *Logger {
	return &Logger{base: base, minimum: minimum, component: component, session: session, version: version}
}

// Enabled reports whether a severity will be written.
func (logger *Logger) Enabled(level Level) bool { return level >= logger.minimum }

// Event writes an event if it meets the configured threshold.
func (logger *Logger) Event(level Level, event, message string, fields ...any) {
	if !logger.Enabled(level) {
		return
	}
	var line strings.Builder
	line.WriteString("timestamp=")
	line.WriteString(time.Now().UTC().Format(time.RFC3339Nano))
	line.WriteString(" level=")
	line.WriteString(level.String())
	line.WriteString(" component=")
	line.WriteString(safeKey(logger.component))
	line.WriteString(" event=")
	line.WriteString(safeKey(event))
	line.WriteString(" session=")
	line.WriteString(strconv.Quote(RedactText(logger.session)))
	line.WriteString(" version=")
	line.WriteString(strconv.Quote(RedactText(logger.version)))
	line.WriteString(" message=")
	line.WriteString(strconv.Quote(RedactText(message)))
	for index := 0; index+1 < len(fields); index += 2 {
		key := fmt.Sprint(fields[index])
		line.WriteByte(' ')
		line.WriteString(safeKey(key))
		line.WriteByte('=')
		line.WriteString(strconv.Quote(RedactField(key, fields[index+1])))
	}
	logger.base.Print(line.String())
}

// RedactField removes credentials and normalizes local user paths.
func RedactField(key string, value any) string {
	lowerKey := strings.ToLower(key)
	for _, sensitive := range []string{"token", "password", "secret", "authorization", "cookie", "request_body", "response_body", "player_name", "query", "payload"} {
		if strings.Contains(lowerKey, sensitive) {
			return "[REDACTED]"
		}
	}
	text := RedactText(fmt.Sprint(value))
	if strings.Contains(lowerKey, "path") || lowerKey == "data" || lowerKey == "saves" || lowerKey == "crash_dir" {
		cleanText := filepath.Clean(text)
		if executable, err := os.Executable(); err == nil {
			applicationDir := filepath.Dir(executable)
			if strings.HasPrefix(strings.ToLower(cleanText), strings.ToLower(applicationDir)) {
				relative := strings.TrimLeft(cleanText[len(applicationDir):], `/\`)
				text = filepath.Join("<app>", relative)
				cleanText = filepath.Clean(text)
			}
		}
		if home, err := os.UserHomeDir(); err == nil && home != "" {
			cleanHome := filepath.Clean(home)
			if strings.HasPrefix(strings.ToLower(cleanText), strings.ToLower(cleanHome)) {
				relative := strings.TrimLeft(cleanText[len(cleanHome):], `/\`)
				text = filepath.Join("<user>", relative)
			}
		}
	}
	return text
}

// RedactText removes line breaks, URL queries, and common inline credentials.
func RedactText(value string) string {
	value = strings.ReplaceAll(value, "\r", `\r`)
	value = strings.ReplaceAll(value, "\n", `\n`)
	value = credentialPattern.ReplaceAllString(value, "$1=[REDACTED]")
	words := strings.Fields(value)
	for index, word := range words {
		trimmed := strings.Trim(word, `"'(),`)
		if parsed, err := url.Parse(trimmed); err == nil && parsed.Scheme != "" && parsed.RawQuery != "" {
			parsed.RawQuery = ""
			parsed.Fragment = ""
			words[index] = strings.Replace(word, trimmed, parsed.String(), 1)
		}
	}
	return strings.Join(words, " ")
}

func safeKey(value string) string {
	var result strings.Builder
	for _, character := range value {
		if character >= 'a' && character <= 'z' || character >= 'A' && character <= 'Z' || character >= '0' && character <= '9' || character == '_' || character == '-' {
			result.WriteRune(character)
		} else {
			result.WriteByte('_')
		}
	}
	if result.Len() == 0 {
		return "unknown"
	}
	return result.String()
}
