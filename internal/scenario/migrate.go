package scenario

import (
	"bytes"
	"crypto/sha256"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"

	"fantu/internal/domain"
	"go.yaml.in/yaml/v4"
)

type ContentMigrationReport struct {
	FromVersion int                    `json:"from_version"`
	ToVersion   int                    `json:"to_version"`
	Applied     bool                   `json:"applied"`
	Files       []ContentMigrationFile `json:"files"`
	Changes     []string               `json:"changes"`
}

type ContentMigrationFile struct {
	Path       string `json:"path"`
	BeforeHash string `json:"before_hash"`
	AfterHash  string `json:"after_hash"`
}

type contentMigration func(dir string, files map[string][]byte, report *ContentMigrationReport) error

var contentMigrations = map[int]contentMigration{
	1: migrateContentV1ToV2,
	2: migrateContentV2ToV3,
	3: migrateContentV3ToV4,
	4: migrateContentV4ToV5,
}

func migrateContentV4ToV5(_ string, files map[string][]byte, report *ContentMigrationReport) error {
	manifestSource := string(files["manifest.yml"])
	files["manifest.yml"] = []byte(strings.Replace(manifestSource, "schema_version: 4", "schema_version: 5", 1))
	report.Changes = append(report.Changes, "manifest schema_version: 4 -> 5")
	if files["rules.yml"] == nil && files["rules.yaml"] == nil {
		rules := domain.WorldRules{}
		encoded, err := yaml.Marshal(rules)
		if err != nil {
			return fmt.Errorf("encode rules.yml: %w", err)
		}
		files["rules.yml"] = encoded
		report.Changes = append(report.Changes, "rules.yml: add explicit world simulation policy")
	}
	return nil
}

func migrateContentV3ToV4(_ string, files map[string][]byte, report *ContentMigrationReport) error {
	manifestSource := string(files["manifest.yml"])
	files["manifest.yml"] = []byte(strings.Replace(manifestSource, "schema_version: 3", "schema_version: 4", 1))
	report.Changes = append(report.Changes, "manifest schema_version: 3 -> 4")
	if files["dialogue.yml"] != nil || files["dialogue.yaml"] != nil {
		return nil
	}
	var scenarioValue struct {
		Title string `json:"title"`
	}
	if err := yaml.Unmarshal(files["scenario.yml"], &scenarioValue); err != nil {
		return fmt.Errorf("decode scenario.yml for dialogue defaults: %w", err)
	}
	dialogue := domain.DialogueConfig{
		Context: scenarioValue.Title,
		Style:   "自然、克制、符合人物公开身份的中文叙事口吻",
	}
	encoded, err := yaml.Marshal(dialogue)
	if err != nil {
		return fmt.Errorf("encode dialogue.yml: %w", err)
	}
	files["dialogue.yml"] = encoded
	report.Changes = append(report.Changes, "dialogue.yml: add scenario dialogue metadata")
	return nil
}

func MigrateContent(dir string, write bool) (ContentMigrationReport, error) {
	files, err := readContentFiles(dir)
	if err != nil {
		return ContentMigrationReport{}, err
	}
	version, err := contentSchemaVersion(files["manifest.yml"])
	if err != nil {
		return ContentMigrationReport{}, err
	}
	report := ContentMigrationReport{FromVersion: version, ToVersion: CurrentSchemaVersion}
	if version > CurrentSchemaVersion {
		return report, fmt.Errorf("content schema version %d is newer than supported version %d", version, CurrentSchemaVersion)
	}
	before := cloneContentFiles(files)
	for version < CurrentSchemaVersion {
		migration, ok := contentMigrations[version]
		if !ok {
			return report, fmt.Errorf("no content migration registered from version %d", version)
		}
		if err := migration(dir, files, &report); err != nil {
			return report, fmt.Errorf("migrate content v%d to v%d: %w", version, version+1, err)
		}
		version++
	}
	for path, contents := range files {
		if bytes.Equal(before[path], contents) {
			continue
		}
		report.Files = append(report.Files, ContentMigrationFile{Path: path, BeforeHash: contentBytesHash(before[path]), AfterHash: contentBytesHash(contents)})
	}
	sort.Slice(report.Files, func(i, j int) bool { return report.Files[i].Path < report.Files[j].Path })
	if !write || len(report.Files) == 0 {
		return report, nil
	}
	if err := validateMigratedContent(dir, files); err != nil {
		return report, err
	}
	for _, file := range report.Files {
		if err := replaceContentFile(filepath.Join(dir, file.Path), files[file.Path]); err != nil {
			return report, err
		}
	}
	report.Applied = true
	return report, nil
}

func migrateContentV1ToV2(_ string, files map[string][]byte, report *ContentMigrationReport) error {
	manifest := string(files["manifest.yml"])
	manifest = strings.Replace(manifest, "schema_version: 1", "schema_version: 2", 1)
	files["manifest.yml"] = []byte(manifest)
	arcs, changes, err := addStoryFeedback(string(files["arcs.yml"]))
	if err != nil {
		return err
	}
	files["arcs.yml"] = []byte(arcs)
	report.Changes = append(report.Changes, "manifest schema_version: 1 -> 2")
	report.Changes = append(report.Changes, changes...)
	return nil
}

func migrateContentV2ToV3(_ string, files map[string][]byte, report *ContentMigrationReport) error {
	manifestSource := string(files["manifest.yml"])
	files["manifest.yml"] = []byte(strings.Replace(manifestSource, "schema_version: 2", "schema_version: 3", 1))
	report.Changes = append(report.Changes, "manifest schema_version: 2 -> 3")
	if files["presentation.yml"] != nil || files["presentation.yaml"] != nil {
		return nil
	}
	var scenarioValue struct {
		Title string `json:"title"`
	}
	if err := yaml.Unmarshal(files["scenario.yml"], &scenarioValue); err != nil {
		return fmt.Errorf("decode scenario.yml for presentation defaults: %w", err)
	}
	var player struct {
		Resources map[string]int `json:"resources"`
	}
	if err := yaml.Unmarshal(files["player.yml"], &player); err != nil {
		return fmt.Errorf("decode player.yml for presentation defaults: %w", err)
	}
	resourceIDs := make([]string, 0, len(player.Resources))
	for id := range player.Resources {
		resourceIDs = append(resourceIDs, id)
	}
	sort.Strings(resourceIDs)
	presentation := domain.ScenarioPresentation{
		Brand: "凡途", WorldTitle: scenarioValue.Title, Objective: "核心目标将在这里落定",
		Resources: make([]domain.ResourcePresentation, 0, len(resourceIDs)),
	}
	for _, id := range resourceIDs {
		presentation.Resources = append(presentation.Resources, domain.ResourcePresentation{ID: id, Label: id})
	}
	encoded, err := yaml.Marshal(presentation)
	if err != nil {
		return fmt.Errorf("encode presentation.yml: %w", err)
	}
	files["presentation.yml"] = encoded
	report.Changes = append(report.Changes, "presentation.yml: add scenario display metadata")
	return nil
}

func addStoryFeedback(source string) (string, []string, error) {
	source = strings.ReplaceAll(source, "\r\n", "\n")
	sourceLines := strings.Split(source, "\n")
	var document yaml.Node
	if err := yaml.Unmarshal([]byte(source), &document); err != nil {
		return "", nil, fmt.Errorf("decode arcs.yml: %w", err)
	}
	type insertion struct {
		line int
		text string
	}
	insertions := make([]insertion, 0)
	changes := make([]string, 0)
	if len(document.Content) == 0 || document.Content[0].Kind != yaml.SequenceNode {
		return "", nil, fmt.Errorf("arcs.yml must contain a sequence")
	}
	for _, arc := range document.Content[0].Content {
		arcID := yamlScalar(arc, "id")
		nodes := yamlValue(arc, "nodes")
		if nodes == nil || nodes.Kind != yaml.SequenceNode {
			continue
		}
		for _, node := range nodes.Content {
			choices := yamlValue(node, "choices")
			if choices == nil || choices.Kind != yaml.SequenceNode {
				continue
			}
			for _, choice := range choices.Content {
				if yamlValue(choice, "feedback") != nil {
					continue
				}
				toState := yamlValue(choice, "to_state")
				if toState == nil || toState.Line <= 0 {
					return "", nil, fmt.Errorf("story choice %s has no to_state", yamlScalar(choice, "id"))
				}
				label := yamlScalar(choice, "description")
				if label == "" {
					label = yamlScalar(choice, "name") + "已经结算。"
				}
				line := sourceLines[toState.Line-1]
				indent := line[:len(line)-len(strings.TrimLeft(line, " "))]
				name := yamlScalar(choice, "name")
				block := fmt.Sprintf("%sfeedback:\n%s  messages: [%s]\n%s  journal: [%s]\n%s  presentation: {kind: actor_focus, intensity: 1, subject: target}", indent, indent, strconv.Quote(label), indent, strconv.Quote(name), indent)
				insertions = append(insertions, insertion{line: toState.Line, text: block})
				changes = append(changes, fmt.Sprintf("story %s choice %s: add feedback projection", arcID, yamlScalar(choice, "id")))
			}
		}
	}
	lines := append([]string(nil), sourceLines...)
	sort.Slice(insertions, func(i, j int) bool { return insertions[i].line > insertions[j].line })
	for _, item := range insertions {
		index := min(item.line, len(lines))
		lines = append(lines[:index], append([]string{item.text}, lines[index:]...)...)
	}
	return strings.Join(lines, "\n"), changes, nil
}

func readContentFiles(dir string) (map[string][]byte, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	files := make(map[string][]byte)
	for _, entry := range entries {
		if entry.IsDir() || (filepath.Ext(entry.Name()) != ".yml" && filepath.Ext(entry.Name()) != ".yaml") {
			continue
		}
		contents, err := os.ReadFile(filepath.Join(dir, entry.Name()))
		if err != nil {
			return nil, err
		}
		files[entry.Name()] = contents
	}
	if files["manifest.yml"] == nil || files["arcs.yml"] == nil {
		return nil, fmt.Errorf("content package requires manifest.yml and arcs.yml")
	}
	return files, nil
}

func contentSchemaVersion(source []byte) (int, error) {
	var value manifest
	if err := decodeYAML(source, &value); err != nil {
		return 0, fmt.Errorf("decode manifest.yml: %w", err)
	}
	return value.SchemaVersion, nil
}

func validateMigratedContent(sourceDir string, files map[string][]byte) error {
	tempDir, err := os.MkdirTemp("", "fantu-content-migration-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tempDir)
	entries, err := os.ReadDir(sourceDir)
	if err != nil {
		return err
	}
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		contents, ok := files[entry.Name()]
		if !ok {
			contents, err = os.ReadFile(filepath.Join(sourceDir, entry.Name()))
			if err != nil {
				return err
			}
		}
		if err := os.WriteFile(filepath.Join(tempDir, entry.Name()), contents, 0o644); err != nil {
			return err
		}
	}
	for name, contents := range files {
		if _, err := os.Stat(filepath.Join(tempDir, name)); err == nil {
			continue
		}
		if err := os.WriteFile(filepath.Join(tempDir, name), contents, 0o644); err != nil {
			return err
		}
	}
	if _, err := Load(tempDir); err != nil {
		return fmt.Errorf("validate migrated content: %w", err)
	}
	return nil
}

func replaceContentFile(path string, contents []byte) error {
	temporary, err := os.CreateTemp(filepath.Dir(path), ".fantu-content-*.tmp")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer os.Remove(temporaryPath)
	if _, err := temporary.Write(contents); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Sync(); err != nil {
		temporary.Close()
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	return os.Rename(temporaryPath, path)
}

func yamlValue(mapping *yaml.Node, key string) *yaml.Node {
	if mapping == nil || mapping.Kind != yaml.MappingNode {
		return nil
	}
	for index := 0; index+1 < len(mapping.Content); index += 2 {
		if mapping.Content[index].Value == key {
			return mapping.Content[index+1]
		}
	}
	return nil
}

func yamlScalar(mapping *yaml.Node, key string) string {
	value := yamlValue(mapping, key)
	if value == nil {
		return ""
	}
	return value.Value
}

func cloneContentFiles(source map[string][]byte) map[string][]byte {
	result := make(map[string][]byte, len(source))
	for path, contents := range source {
		result[path] = append([]byte(nil), contents...)
	}
	return result
}

func contentBytesHash(contents []byte) string {
	sum := sha256.Sum256(contents)
	return fmt.Sprintf("sha256:%x", sum[:])
}
