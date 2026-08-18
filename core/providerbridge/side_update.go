package providerbridge

import (
	"errors"

	"github.com/metacubex/mihomo/adapter/provider"
	cp "github.com/metacubex/mihomo/constant/provider"
	rp "github.com/metacubex/mihomo/rules/provider"
)

// SideUpdateExternalProvider applies side-loaded provider content and returns
// the underlying Mihomo error unchanged. Only external proxy/rule providers
// support this operation.
func SideUpdateExternalProvider(p cp.Provider, data []byte) error {
	switch providerValue := p.(type) {
	case *provider.ProxySetProvider:
		_, _, err := providerValue.SideUpdate(data)
		return err
	case *rp.RuleSetProvider:
		_, _, err := providerValue.SideUpdate(data)
		return err
	default:
		return errors.New("not external provider")
	}
}
