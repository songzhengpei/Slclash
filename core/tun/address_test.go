package tun

import "testing"

func TestParseAddresses(t *testing.T) {
	prefix4, prefix6, err := parseAddresses("172.19.0.1/30, fdfe:dcba:9876::1/126")
	if err != nil {
		t.Fatalf("parseAddresses returned error: %v", err)
	}
	if len(prefix4) != 1 || len(prefix6) != 1 {
		t.Fatalf("unexpected address split: ipv4=%v ipv6=%v", prefix4, prefix6)
	}
}

func TestParseAddressesRejectsInvalidAddress(t *testing.T) {
	if _, _, err := parseAddresses("not-a-cidr"); err == nil {
		t.Fatal("parseAddresses accepted an invalid address")
	}
}
