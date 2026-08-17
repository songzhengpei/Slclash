package configfixture

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/metacubex/mihomo/config"
	_ "github.com/metacubex/mihomo/hub/executor"
)

func TestBundledMihomoAcceptsCompatibilityFixtures(t *testing.T) {
	// Only fixtures made of fields the bundled Mihomo actually supports belong
	// here. Synthetic preservation fixtures (synthetic_unknown_fields.yaml)
	// intentionally contain made-up future fields and must never gate a core
	// update, so they are validated only by the Dart overlay tests.
	fixtures := []string{
		"base.yaml", "dns.yaml", "dns_override.yaml", "tun.yaml",
		"sniffer.yaml", "proxy_provider.yaml", "rule_provider.yaml",
		"rules.yaml", "proxy_groups.yaml", "script.yaml", "ipv6.yaml",
		"mihomo_current_features.yaml", "real_source_preservation.yaml",
	}
	fixtureDir := filepath.Join("..", "..", "build", "mihomo-runtime-fixtures")
	if _, err := os.Stat(fixtureDir); os.IsNotExist(err) {
		t.Fatal("processed runtime fixtures are missing; run the Flutter Mihomo regression test first")
	}
	for _, name := range fixtures {
		t.Run(name, func(t *testing.T) {
			path := filepath.Join(fixtureDir, name)
			contents, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if _, err := config.Parse(contents); err != nil {
				t.Fatalf("bundled Mihomo rejected %s: %v", name, err)
			}
		})
	}
}
