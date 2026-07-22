package main

import (
	"encoding/base64"
	"testing"
)

func TestNormalizeProviderContentYAML(t *testing.T) {
	input := []byte("proxies:\n  - name: yaml-node\n    type: ss\n    server: 192.0.2.1\n    port: 443\n    cipher: aes-128-gcm\n    password: test\n")
	proxies, err := handleNormalizeProviderContent(base64.StdEncoding.EncodeToString(input))
	if err != nil {
		t.Fatal(err)
	}
	if len(proxies) != 1 || proxies[0]["name"] != "yaml-node" {
		t.Fatalf("unexpected proxies: %#v", proxies)
	}
}

func TestNormalizeProviderContentURI(t *testing.T) {
	input := []byte("vless://a1b2c3d4-eacc-4433-981b-7e5f9a8b@192.0.2.1:443?encryption=none&type=tcp#uri-node")
	proxies, err := handleNormalizeProviderContent(base64.StdEncoding.EncodeToString(input))
	if err != nil {
		t.Fatal(err)
	}
	if len(proxies) != 1 || proxies[0]["name"] != "uri-node" {
		t.Fatalf("unexpected proxies: %#v", proxies)
	}
}

func TestNormalizeProviderContentRejectsEmpty(t *testing.T) {
	_, err := handleNormalizeProviderContent(base64.StdEncoding.EncodeToString([]byte("proxies: []\n")))
	if err == nil {
		t.Fatal("expected empty provider content to be rejected")
	}
}
