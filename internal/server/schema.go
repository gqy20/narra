package server

import (
	"encoding/json"
	"fmt"

	"github.com/invopop/jsonschema"
)

func ContractJSON() ([]byte, error) {
	reflector := jsonschema.Reflector{
		BaseSchemaID:               "https://fantu.local/schemas",
		RequiredFromJSONSchemaTags: false,
	}
	schema := reflector.Reflect(&Response{})
	data, err := json.MarshalIndent(schema, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("encode API contract: %w", err)
	}
	return append(data, '\n'), nil
}
