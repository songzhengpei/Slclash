package configfixture

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"

	"github.com/metacubex/mihomo/config"
)

// TestRawConfigE2EFixtures pins the FIRST boundary of the compatibility
// suite: real profile YAML -> bundled Mihomo RawConfig -> Go JSON bridge.
//
// For every checked-in E2E fixture (test/fixtures/mihomo/e2e/*), this test
// re-derives the bridge output from source.yaml and compares it semantically
// against the checked-in, reviewed rawconfig*.json snapshots. A future Mihomo
// bump that changes a RawConfig tag, default, field shape, or JSON bridge output
// fails here before the mismatch can reach the Dart overlay.
//
// Comparison is semantic (generic decoded maps), never byte-for-byte, so JSON
// object ordering cannot cause false failures.
func TestRawConfigE2EFixtures(t *testing.T) {
	fixtures := []string{
		"standard_real_fields",
		"script_real_fields",
		"bridge_contract",
	}
	dir := filepath.Join("..", "..", "test", "fixtures", "mihomo", "e2e")
	for _, name := range fixtures {
		t.Run(name, func(t *testing.T) {
			srcPath := filepath.Join(dir, name, "source.yaml")
			contents, err := os.ReadFile(srcPath)
			if err != nil {
				t.Fatal(err)
			}
			raw, err := config.UnmarshalRawConfig(contents)
			if err != nil {
				t.Fatalf("UnmarshalRawConfig failed: %v", err)
			}
			data, err := json.Marshal(raw)
			if err != nil {
				t.Fatal(err)
			}
			var actual map[string]any
			if err := json.Unmarshal(data, &actual); err != nil {
				t.Fatal(err)
			}

			expectedPaths, err := filepath.Glob(filepath.Join(dir, name, "rawconfig*.json"))
			if err != nil {
				t.Fatal(err)
			}
			if len(expectedPaths) == 0 {
				t.Fatal("no reviewed RawConfig snapshots found")
			}
			for _, expectedPath := range expectedPaths {
				expectedBytes, err := os.ReadFile(expectedPath)
				if err != nil {
					t.Fatal(err)
				}
				var expected map[string]any
				if err := json.Unmarshal(expectedBytes, &expected); err != nil {
					t.Fatal(err)
				}
				if reflect.DeepEqual(actual, expected) {
					t.Logf("matches reviewed snapshot %s", filepath.Base(expectedPath))
					return
				}
			}
			pretty, _ := json.MarshalIndent(actual, "", "  ")
			t.Fatalf("source.yaml -> RawConfig -> JSON bridge differs from every reviewed snapshot in %s. "+
				"Review the upstream changes before running go run ./configfixture/cmd/generate -baseline vX.Y.Z. Actual bridge:\n%s",
				filepath.Join(dir, name), pretty)
		})
	}
}
