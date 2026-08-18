package configfixture

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/config"
)

// TestRawConfigJSONBridgeContract pins the Go JSON bridge key contract that
// CoreController.getConfig() (lib/core/controller.dart) depends on.
//
// The bridge is: profile YAML -> RawConfig (yaml tags) -> json.Marshal
// (json tags) -> Dart map. Dart-side canonicalization only rewrites
// rule -> rules; every other key must already arrive YAML-canonical.
// This test fails a core update if a future Mihomo bump regresses the json
// tags, e.g. by dropping them on newly added fields.
func TestRawConfigJSONBridgeContract(t *testing.T) {
	contents := []byte(`
tun:
  enable: true
  auto-detect-interface: true
experimental:
  quic-go-disable-gso: true
  quic-go-disable-ecn: true
  dialer-ip4p-convert: true
dns:
  enable: true
rules:
  - MATCH,DIRECT
`)
	raw, err := config.UnmarshalRawConfig(contents)
	if err != nil {
		t.Fatal(err)
	}
	data, err := json.Marshal(raw)
	if err != nil {
		t.Fatal(err)
	}
	var decoded map[string]any
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}

	tun, ok := decoded["tun"].(map[string]any)
	if !ok {
		t.Fatalf("json bridge: expected map under tun, got %T", decoded["tun"])
	}
	if got, _ := tun["auto-detect-interface"].(bool); !got {
		t.Fatal("json bridge: tun.auto-detect-interface must survive as YAML-canonical key")
	}
	if _, ok := tun["AutoDetectInterface"]; ok {
		t.Fatal("json bridge: Go field name AutoDetectInterface leaked into JSON")
	}

	experimental, ok := decoded["experimental"].(map[string]any)
	if !ok {
		t.Fatalf("json bridge: expected map under experimental, got %T", decoded["experimental"])
	}
	for _, key := range []string{"quic-go-disable-gso", "quic-go-disable-ecn", "dialer-ip4p-convert"} {
		if got, _ := experimental[key].(bool); !got {
			t.Fatalf("json bridge: experimental.%s must survive as YAML-canonical key", key)
		}
	}
	for _, key := range []string{"QUICGoDisableGSO", "QUICGoDisableECN", "IP4PEnable"} {
		if _, ok := experimental[key]; ok {
			t.Fatalf("json bridge: Go field name %s leaked into JSON", key)
		}
	}

	// rules uses yaml:"rules" json:"rule", the one mismatch Dart canonicalizes.
	if _, ok := decoded["rule"]; !ok {
		t.Fatal("json bridge: rules must marshal under the json tag key 'rule'")
	}
	if _, ok := decoded["rules"]; ok {
		t.Fatal("json bridge: 'rules' must not appear in JSON; Dart rewrites rule -> rules")
	}

	// Global invariant: every bridge key is lowercase YAML-canonical. A single
	// missing json tag would surface here as a PascalCase key and fail the
	// core update workflow before the mismatch can reach the overlay.
	var walk func(string, any)
	walk = func(path string, value any) {
		switch v := value.(type) {
		case map[string]any:
			for key, child := range v {
				if key != strings.ToLower(key) {
					t.Errorf("json bridge: non-canonical key %q at %s", key, path)
				}
				walk(path+"/"+key, child)
			}
		case []any:
			for _, child := range v {
				walk(path, child)
			}
		}
	}
	walk("", decoded)
}
