package tun

import (
	"fmt"
	"net/netip"
	"strings"
)

func parseAddresses(address string) (prefix4, prefix6 []netip.Prefix, err error) {
	for _, value := range strings.Split(address, ",") {
		value = strings.TrimSpace(value)
		if value == "" {
			continue
		}
		prefix, parseErr := netip.ParsePrefix(value)
		if parseErr != nil {
			return nil, nil, fmt.Errorf("parse TUN address %q: %w", value, parseErr)
		}
		if prefix.Addr().Is4() {
			prefix4 = append(prefix4, prefix)
		} else {
			prefix6 = append(prefix6, prefix)
		}
	}
	return prefix4, prefix6, nil
}
