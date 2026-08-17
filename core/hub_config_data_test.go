package main

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// TestGetConfigWithDataMatchesPathAPI pins the Phase 2B single-snapshot
// guarantee at the bridge level: the data-based API must normalize exactly
// the same bytes the path-based API reads from the profile file, producing
// byte-identical JSON for the same fixture.
func TestGetConfigWithDataMatchesPathAPI(t *testing.T) {
	content := []byte(`
tun:
  enable: true
  auto-detect-interface: true
experimental:
  quic-go-disable-gso: true
dns:
  enable: true
  nameserver: [system://]
rules:
  - MATCH,DIRECT
`)
	dir := t.TempDir()
	path := filepath.Join(dir, "profile.yaml")
	if err := os.WriteFile(path, content, 0o600); err != nil {
		t.Fatal(err)
	}

	fromPath, err := handleGetConfig(path)
	if err != nil {
		t.Fatal(err)
	}
	fromData, err := handleGetConfigWithData(base64.StdEncoding.EncodeToString(content))
	if err != nil {
		t.Fatal(err)
	}

	pathJSON, err := json.Marshal(fromPath)
	if err != nil {
		t.Fatal(err)
	}
	dataJSON, err := json.Marshal(fromData)
	if err != nil {
		t.Fatal(err)
	}
	if string(pathJSON) != string(dataJSON) {
		t.Fatalf("data API diverged from path API:\npath: %s\ndata: %s", pathJSON, dataJSON)
	}

	// The bridge contract (json tags) is identical for both entry points:
	// rules marshal under "rule", canonical tun/experimental keys survive.
	var decoded map[string]any
	if err := json.Unmarshal(dataJSON, &decoded); err != nil {
		t.Fatal(err)
	}
	tun := decoded["tun"].(map[string]any)
	if tun["auto-detect-interface"] != true {
		t.Fatal("data API: tun.auto-detect-interface lost canonical key")
	}
	if _, ok := decoded["rules"]; ok {
		t.Fatal("data API: 'rules' must not appear in JSON; Dart rewrites rule -> rules")
	}
	if _, ok := decoded["rule"]; !ok {
		t.Fatal("data API: rules must marshal under json tag 'rule'")
	}
}

func TestGetConfigWithDataRejectsBadBase64(t *testing.T) {
	if _, err := handleGetConfigWithData("not-base64!!"); err == nil {
		t.Fatal("expected invalid base64 to be rejected")
	}
}

func TestGetConfigWithDataRejectsInvalidYAML(t *testing.T) {
	_, err := handleGetConfigWithData(base64.StdEncoding.EncodeToString([]byte("[not-a-map")))
	if err == nil {
		t.Fatal("expected invalid YAML to be rejected")
	}
}
