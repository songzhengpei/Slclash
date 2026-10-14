// Generate reviewed bridge snapshots manually; never run this in the updater.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/metacubex/mihomo/config"
)

func main() {
	baseline := flag.String("baseline", "", "official release tag, e.g. v1.19.32")
	flag.Parse()
	if !regexp.MustCompile(`^v[0-9]+\.[0-9]+\.[0-9]+$`).MatchString(*baseline) {
		fail(fmt.Errorf("-baseline must be an official release tag"))
	}
	current, err := exec.Command("git", "-C", "Clash.Meta", "rev-parse", "HEAD").Output()
	if err != nil {
		fail(err)
	}
	target, err := exec.Command("git", "-C", "Clash.Meta", "rev-parse", "refs/tags/"+*baseline+"^{commit}").Output()
	if err != nil || strings.TrimSpace(string(current)) != strings.TrimSpace(string(target)) {
		fail(fmt.Errorf("bundled core HEAD must match %s before generating its snapshots", *baseline))
	}
	for _, name := range []string{"standard_real_fields", "script_real_fields", "bridge_contract"} {
		dir := filepath.Join("..", "test", "fixtures", "mihomo", "e2e", name)
		source, err := os.ReadFile(filepath.Join(dir, "source.yaml"))
		if err != nil {
			fail(err)
		}
		raw, err := config.UnmarshalRawConfig(source)
		if err != nil {
			fail(err)
		}
		data, err := json.MarshalIndent(raw, "", "  ")
		if err != nil {
			fail(err)
		}
		path := filepath.Join(dir, "rawconfig-"+*baseline+".json")
		if err := os.WriteFile(path, append(data, '\n'), 0644); err != nil {
			fail(err)
		}
		fmt.Println(path)
	}
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, err)
	os.Exit(1)
}
