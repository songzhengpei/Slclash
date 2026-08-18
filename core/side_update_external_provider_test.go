package main

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/metacubex/mihomo/adapter/provider"
	"github.com/metacubex/mihomo/common/utils"
	C "github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	rp "github.com/metacubex/mihomo/rules/provider"
)

// stubVehicle lets a SideUpdate fail at the vehicle.Write stage, which happens
// after a successful parse, so a non-nil error proves the Fetcher error is
// propagated instead of being swallowed.
type stubVehicle struct {
	writeErr error
}

func (v *stubVehicle) Read(ctx context.Context, oldHash utils.HashType) ([]byte, utils.HashType, error) {
	return nil, utils.HashType{}, nil
}

func (v *stubVehicle) Write(buf []byte) error {
	return v.writeErr
}

func (v *stubVehicle) Path() string        { return "stub" }
func (v *stubVehicle) Url() string         { return "" }
func (v *stubVehicle) Proxy() string       { return "" }
func (v *stubVehicle) Type() cp.VehicleType { return cp.File }

// stubTunnel satisfies the rules/provider tunnel contract so a successful
// rule provider SideUpdate can emit its update callback.
type stubTunnel struct {
	cp.Tunnel
	cb *utils.Callback[cp.RuleProvider]
}

func (t *stubTunnel) RuleUpdateCallback() *utils.Callback[cp.RuleProvider] {
	return t.cb
}

func newTestProxyProvider(t *testing.T, writeErr error) *provider.ProxySetProvider {
	t.Helper()
	psp, err := provider.NewProxySetProvider(
		"test-proxy",
		0,
		nil,
		func(buf []byte) ([]C.Proxy, error) { return []C.Proxy{}, nil },
		&stubVehicle{writeErr: writeErr},
		provider.NewHealthCheck(nil, "", 0, 0, true, nil),
	)
	if err != nil {
		t.Fatalf("create proxy provider: %v", err)
	}
	return psp
}

func newTestRuleProvider(t *testing.T, writeErr error) *rp.RuleSetProvider {
	t.Helper()
	rp.SetTunnel(&stubTunnel{cb: utils.NewCallback[cp.RuleProvider]()})
	t.Cleanup(func() { rp.SetTunnel(nil) })
	ruleProvider := rp.NewRuleSetProvider(
		"test-rule",
		cp.Domain,
		cp.TextRule,
		0,
		&stubVehicle{writeErr: writeErr},
		nil,
		nil,
		nil,
	)
	return ruleProvider.(*rp.RuleSetProvider)
}

type stubProvider struct{}

func (p *stubProvider) Name() string           { return "stub" }
func (p *stubProvider) VehicleType() cp.VehicleType { return cp.Compatible }
func (p *stubProvider) Type() cp.ProviderType       { return cp.Proxy }
func (p *stubProvider) Initial() error         { return nil }
func (p *stubProvider) Update() error          { return nil }

func TestSideUpdateExternalProviderProxySuccess(t *testing.T) {
	psp := newTestProxyProvider(t, nil)
	if err := sideUpdateExternalProvider(psp, []byte("proxies: []\n")); err != nil {
		t.Fatalf("expected successful proxy side update, got %v", err)
	}
}

func TestSideUpdateExternalProviderProxyFailure(t *testing.T) {
	psp := newTestProxyProvider(t, errors.New("disk full"))
	err := sideUpdateExternalProvider(psp, []byte("proxies: []\n"))
	if err == nil {
		t.Fatal("expected proxy side update failure to propagate")
	}
	if !strings.Contains(err.Error(), "disk full") {
		t.Fatalf("unexpected proxy error: %v", err)
	}
}

func TestSideUpdateExternalProviderRuleSuccess(t *testing.T) {
	ruleProvider := newTestRuleProvider(t, nil)
	if err := sideUpdateExternalProvider(ruleProvider, []byte("example.com\n")); err != nil {
		t.Fatalf("expected successful rule side update, got %v", err)
	}
}

func TestSideUpdateExternalProviderRuleFailure(t *testing.T) {
	ruleProvider := newTestRuleProvider(t, errors.New("disk full"))
	err := sideUpdateExternalProvider(ruleProvider, []byte("example.com\n"))
	if err == nil {
		t.Fatal("expected rule side update failure to propagate")
	}
	if !strings.Contains(err.Error(), "disk full") {
		t.Fatalf("unexpected rule error: %v", err)
	}
}

func TestSideUpdateExternalProviderUnknownType(t *testing.T) {
	err := sideUpdateExternalProvider(&stubProvider{}, []byte("x"))
	if err == nil || !strings.Contains(err.Error(), "not external provider") {
		t.Fatalf("expected not external provider error, got %v", err)
	}
}
