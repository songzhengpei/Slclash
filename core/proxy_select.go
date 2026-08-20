package main

import (
	"encoding/json"
	"errors"

	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

var errUnfixRejected = errors.New("Group is not unfixable")

// applyUnfix matches pinned Mihomo DELETE /proxies/{name}:
// SelectAble && type != Selector → ForceSet("") and clear cache selection.
func applyUnfix(selectAble outboundgroup.SelectAble, typ constant.AdapterType) error {
	if selectAble == nil || typ == constant.Selector {
		return errUnfixRejected
	}
	selectAble.ForceSet("")
	return nil
}

func handleUnfixProxy(data string, fn func(string)) {
	runLock.Lock()
	go func() {
		defer runLock.Unlock()
		var params = &UnfixProxyParams{}
		err := json.Unmarshal([]byte(data), params)
		if err != nil {
			fn(err.Error())
			return
		}
		if params.GroupName == nil || *params.GroupName == "" {
			fn("Not found group")
			return
		}
		groupName := *params.GroupName
		proxies := tunnel.Proxies()
		group, ok := proxies[groupName]
		if !ok {
			fn("Not found group")
			return
		}
		selectAble, _ := group.Adapter().(outboundgroup.SelectAble)
		if err := applyUnfix(selectAble, group.Type()); err != nil {
			fn(err.Error())
			return
		}
		cachefile.Cache().SetSelected(group.Name(), "")
		invalidateProxiesCacheLocked()
		fn("")
	}()
}
