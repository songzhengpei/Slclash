//go:build android && cgo

package tun

import "C"
import (
	"github.com/metacubex/mihomo/constant"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"net"
	"strings"
	"syscall"
)

func Start(fd int, stack string, address, dns string) (listener *sing_tun.Listener, err error) {
	ownsFD := true
	defer func() {
		if err != nil && ownsFD {
			_ = syscall.Close(fd)
		}
	}()

	tunStack, ok := constant.StackTypeMapping[strings.ToLower(stack)]
	if !ok {
		tunStack = constant.TunSystem
	}
	prefix4, prefix6, err := parseAddresses(address)
	if err != nil {
		log.Errorln("TUN:", err)
		return nil, err
	}

	var dnsHijack []string
	for _, d := range strings.Split(dns, ",") {
		d = strings.TrimSpace(d)
		if len(d) == 0 {
			continue
		}
		dnsHijack = append(dnsHijack, net.JoinHostPort(d, "53"))
	}

	options := LC.Tun{
		Enable:              true,
		Device:              "FlClash",
		Stack:               tunStack,
		DNSHijack:           dnsHijack,
		AutoRoute:           false,
		AutoDetectInterface: false,
		Inet4Address:        prefix4,
		Inet6Address:        prefix6,
		MTU:                 9000,
		FileDescriptor:      fd,
	}

	listener, err = sing_tun.New(options, tunnel.Tunnel)

	if err != nil {
		log.Errorln("TUN:", err)
		return nil, err
	}

	ownsFD = false
	return listener, nil
}
