package main

import (
	"cmp"
	"context"
	"encoding/json"
	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/common/observable"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/component/mmdb"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/updater"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	cp "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
	"golang.org/x/exp/slices"
	"net"
	"os"
	"runtime"
	"runtime/debug"
	"strconv"
	"strings"
	"time"
)

var (
	isInit            = false
	externalProviders = map[string]cp.Provider{}
	logSubscriber     observable.Subscription[log.Event]
	proxiesCache      ProxiesData
	proxiesCacheKey   string
	proxiesCacheValid bool
)

func handleInitClash(paramsString string) bool {
	runLock.Lock()
	defer runLock.Unlock()
	var params = InitParams{}
	err := json.Unmarshal([]byte(paramsString), &params)
	if err != nil {
		return false
	}
	version = params.Version
	constant.SetHomeDir(params.HomeDir)
	isInit = true
	return isInit
}

func handleStartListener() bool {
	runLock.Lock()
	defer runLock.Unlock()
	isRunning = true
	updateListeners()
	resolver.ResetConnection()
	return true
}

func handleStopListener() bool {
	runLock.Lock()
	defer runLock.Unlock()
	isRunning = false
	stopListeners()
	resolver.ResetConnection()
	return true
}

func handleGetIsInit() bool {
	return isInit
}

func handleForceGC() {
	log.Infoln("[APP] request force GC")
	runtime.GC()
	if runtime.GOOS == "android" {
		debug.FreeOSMemory()
	}
}

func handleShutdown() bool {
	stopListeners()
	executor.Shutdown()
	invalidateProxiesCache()
	handleForceGC()
	isInit = false
	return true
}

func handleValidateConfig(path string) string {
	buf, err := readFile(path)
	_, err = config.UnmarshalRawConfig(buf)
	if err != nil {
		return err.Error()
	}
	return ""
}

func handleGetProxies() ProxiesData {
	runLock.Lock()
	defer runLock.Unlock()

	nameList := getProxyNameList()
	rawProxies := tunnel.Proxies()
	providers := tunnel.Providers()
	cacheKey := buildProxiesCacheKey(nameList, rawProxies, providers)
	if proxiesCacheValid && proxiesCacheKey == cacheKey {
		return proxiesCache
	}

	// Merge direct proxies and provider proxies into a single flat map.
	proxies := make(map[string]constant.Proxy, len(rawProxies))
	for name, proxy := range rawProxies {
		if !isFrontendVisibleProxy(proxy) {
			continue
		}
		proxies[name] = proxy
	}
	for _, p := range providers {
		for _, proxy := range p.Proxies() {
			if !isFrontendVisibleProxy(proxy) {
				continue
			}
			proxies[proxy.Name()] = proxy
		}
	}

	hasGlobal := false

	allNames := make([]string, 0, len(nameList)+1)

	for _, name := range nameList {
		if name == "GLOBAL" {
			hasGlobal = true
		}

		p, ok := proxies[name]
		if !ok || p == nil {
			continue
		}
		switch p.Type() {
		case constant.Selector, constant.URLTest, constant.Fallback, constant.Relay, constant.LoadBalance:
			allNames = append(allNames, name)
		default:
		}
	}

	if !hasGlobal {
		if p, ok := proxies["GLOBAL"]; ok && p != nil {
			allNames = append([]string{"GLOBAL"}, allNames...)
		}
	}

	proxiesCache = ProxiesData{
		All:     allNames,
		Proxies: proxies,
	}
	proxiesCacheKey = cacheKey
	proxiesCacheValid = true
	return proxiesCache
}

func isFrontendVisibleProxy(proxy constant.Proxy) bool {
	if proxy == nil {
		return false
	}
	switch proxy.Type() {
	case constant.PassRule:
		return false
	default:
		return true
	}
}

func buildProxiesCacheKey(nameList []string, rawProxies map[string]constant.Proxy, providers map[string]cp.ProxyProvider) string {
	parts := make([]string, 0, len(nameList)+len(providers)+1)
	parts = append(parts, "raw:"+strconv.Itoa(len(rawProxies)))
	parts = append(parts, nameList...)
	providerNames := make([]string, 0, len(providers))
	for name := range providers {
		providerNames = append(providerNames, name)
	}
	slices.Sort(providerNames)
	for _, name := range providerNames {
		provider := providers[name]
		if provider == nil {
			parts = append(parts, name+":nil")
			continue
		}
		parts = append(
			parts,
			name+":"+
				strconv.Itoa(int(provider.Version()))+":"+
				strconv.Itoa(provider.Count()),
		)
	}
	return strings.Join(parts, "\x00")
}

func invalidateProxiesCache() {
	runLock.Lock()
	defer runLock.Unlock()
	invalidateProxiesCacheLocked()
}

func invalidateProxiesCacheLocked() {
	proxiesCache = ProxiesData{}
	proxiesCacheKey = ""
	proxiesCacheValid = false
}

func handleChangeProxy(data string, fn func(string string)) {
	runLock.Lock()
	go func() {
		defer runLock.Unlock()
		var params = &ChangeProxyParams{}
		err := json.Unmarshal([]byte(data), params)
		if err != nil {
			fn(err.Error())
			return
		}
		groupName := *params.GroupName
		proxyName := *params.ProxyName
		proxies := tunnel.Proxies()
		group, ok := proxies[groupName]
		if !ok {
			fn("Not found group")
			return
		}
		adapterProxy := group.(*adapter.Proxy)
		selector, ok := adapterProxy.ProxyAdapter.(outboundgroup.SelectAble)
		if !ok {
			fn("Group is not selectable")
			return
		}
		if proxyName == "" {
			selector.ForceSet(proxyName)
		} else {
			err = selector.Set(proxyName)
		}
		if err != nil {
			fn(err.Error())
			return
		}

		fn("")
		return
	}()
}

func handleGetTraffic(onlyStatisticsProxy bool) string {
	_ = onlyStatisticsProxy
	up, down := statistic.DefaultManager.Now()
	traffic := map[string]int64{
		"up":   up,
		"down": down,
	}
	data, err := json.Marshal(traffic)
	if err != nil {
		logError("Error: %s", err)
		return ""
	}
	return string(data)
}

func handleGetTotalTraffic(onlyStatisticsProxy bool) string {
	_ = onlyStatisticsProxy
	up, down := statistic.DefaultManager.Total()
	traffic := map[string]int64{
		"up":   up,
		"down": down,
	}
	data, err := json.Marshal(traffic)
	if err != nil {
		logError("Error: %s", err)
		return ""
	}
	return string(data)
}

func handleGetTrafficSnapshot(onlyStatisticsProxy bool) string {
	_ = onlyStatisticsProxy
	up, down := statistic.DefaultManager.Now()
	totalUp, totalDown := statistic.DefaultManager.Total()
	traffic := map[string]int64{
		"up":        up,
		"down":      down,
		"totalUp":   totalUp,
		"totalDown": totalDown,
	}
	data, err := json.Marshal(traffic)
	if err != nil {
		logError("Error: %s", err)
		return ""
	}
	return string(data)
}

func handleResetTraffic() {
	statistic.DefaultManager.ResetStatistic()
}

func handleAsyncTestDelay(paramsString string, fn func(string)) {
	mBatch.Go(paramsString, func() (bool, error) {
		var params = &TestDelayParams{}
		err := json.Unmarshal([]byte(paramsString), params)
		if err != nil {
			fn("")
			return false, nil
		}

		expectedStatus, err := utils.NewUnsignedRanges[uint16]("")
		if err != nil {
			fn("")
			return false, nil
		}

		ctx, cancel := context.WithTimeout(context.Background(), time.Millisecond*time.Duration(params.Timeout))
		defer cancel()

		proxy := tunnel.Proxies()[params.ProxyName]
		if proxy == nil {
			for _, p := range tunnel.Providers() {
				for _, pp := range p.Proxies() {
					if pp.Name() == params.ProxyName {
						proxy = pp
						break
					}
				}
				if proxy != nil {
					break
				}
			}
		}

		delayData := &Delay{
			Name: params.ProxyName,
		}

		if proxy == nil {
			delayData.Value = -1
			data, _ := json.Marshal(delayData)
			fn(string(data))
			return false, nil
		}

		testUrl := defaultTestURL

		if params.TestUrl != "" {
			testUrl = params.TestUrl
		}
		delayData.Url = testUrl
		delay, err := proxy.URLTest(ctx, testUrl, expectedStatus)
		if err != nil || delay == 0 {
			delayData.Value = -1
			data, _ := json.Marshal(delayData)
			fn(string(data))
			return false, nil
		}

		delayData.Value = int32(delay)
		data, _ := json.Marshal(delayData)
		fn(string(data))
		return false, nil
	})
}

func getProxyNameList() []string {
	if currentConfig == nil {
		return nil
	}

	if len(currentProxyGroupNames) > 0 {
		return append([]string{}, currentProxyGroupNames...)
	}

	names := make([]string, 0, len(currentConfig.Proxies))
	for name := range currentConfig.Proxies {
		names = append(names, name)
	}
	slices.SortFunc(names, func(a, b string) int {
		return cmp.Compare(a, b)
	})
	return names
}

func handleGetConnections() string {
	runLock.Lock()
	defer runLock.Unlock()
	snapshot := statistic.DefaultManager.Snapshot()
	data, err := json.Marshal(snapshot)
	if err != nil {
		logError("Error: %s", err)
		return ""
	}
	return string(data)
}

func handleCloseConnections() bool {
	runLock.Lock()
	defer runLock.Unlock()
	closeConnections()
	return true
}

func closeConnections() {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		err := c.Close()
		if err != nil {
			return false
		}
		return true
	})
}

func handleResetConnections() bool {
	runLock.Lock()
	defer runLock.Unlock()
	resolver.ResetConnection()
	return true
}

func handleCloseConnection(connectionId string) bool {
	runLock.Lock()
	defer runLock.Unlock()
	c := statistic.DefaultManager.Get(connectionId)
	if c == nil {
		return false
	}
	_ = c.Close()
	return true
}

func handleGetExternalProviders() string {
	runLock.Lock()
	defer runLock.Unlock()
	externalProviders = getExternalProvidersRaw()
	eps := make([]ExternalProvider, 0)
	for _, p := range externalProviders {
		externalProvider, err := toExternalProvider(p)
		if err != nil {
			continue
		}
		eps = append(eps, *externalProvider)
	}
	slices.SortFunc(eps, func(a, b ExternalProvider) int {
		return cmp.Compare(a.Name, b.Name)
	})
	data, err := json.Marshal(eps)
	if err != nil {
		return ""
	}
	return string(data)
}

func handleGetExternalProvider(externalProviderName string) string {
	runLock.Lock()
	defer runLock.Unlock()
	externalProvider, exist := externalProviders[externalProviderName]
	if !exist {
		return ""
	}
	e, err := toExternalProvider(externalProvider)
	if err != nil {
		return ""
	}
	data, err := json.Marshal(e)
	if err != nil {
		return ""
	}
	return string(data)
}

func handleUpdateGeoData(geoType string, geoName string, fn func(value string)) {
	go func() {
		_ = geoName
		switch geoType {
		case "MMDB":
			err := updater.UpdateMMDB()
			if err != nil {
				fn(err.Error())
				return
			}
		case "ASN":
			err := updater.UpdateASN()
			if err != nil {
				fn(err.Error())
				return
			}
		case "GEOIP":
			err := updater.UpdateGeoIp()
			if err != nil {
				fn(err.Error())
				return
			}
		case "GEOSITE":
			err := updater.UpdateGeoSite()
			if err != nil {
				fn(err.Error())
				return
			}
		}
		fn("")
	}()
}

func handleUpdateExternalProvider(providerName string, fn func(value string)) {
	go func() {
		externalProvider, exist := externalProviders[providerName]
		if !exist {
			fn("external provider is not exist")
			return
		}
		err := externalProvider.Update()
		if err != nil {
			fn(err.Error())
			return
		}
		invalidateProxiesCache()
		fn("")
	}()
}

func handleSideLoadExternalProvider(providerName string, data []byte, fn func(value string)) {
	go func() {
		runLock.Lock()
		defer runLock.Unlock()
		externalProvider, exist := externalProviders[providerName]
		if !exist {
			fn("external provider is not exist")
			return
		}
		err := sideUpdateExternalProvider(externalProvider, data)
		if err != nil {
			fn(err.Error())
			return
		}
		invalidateProxiesCacheLocked()
		fn("")
	}()
}

func handleSuspend(suspended bool) bool {
	if suspended {
		tunnel.OnSuspend()
	} else {
		tunnel.OnRunning()
	}
	return true
}

func handleStartLog() {
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
	logSubscriber = log.Subscribe()
	go func() {
		for logData := range logSubscriber {
			if logData.LogLevel < log.Level() {
				continue
			}
			message := &Message{
				Type: LogMessage,
				Data: logData,
			}
			sendMessage(*message)
		}
	}()
}

func handleStopLog() {
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
}

func handleGetCountryCode(ip string, fn func(value string)) {
	go func() {
		runLock.Lock()
		defer runLock.Unlock()
		codes := mmdb.IPInstance().LookupCode(net.ParseIP(ip))
		if len(codes) == 0 {
			fn("")
			return
		}
		fn(codes[0])
	}()
}

func handleGetMemory(fn func(value string)) {
	go func() {
		fn(strconv.FormatUint(statistic.DefaultManager.Memory(), 10))
	}()
}

func handleGetConfig(path string) (*config.RawConfig, error) {
	bytes, err := readFile(path)
	if err != nil {
		return nil, err
	}
	prof, err := config.UnmarshalRawConfig(bytes)
	if err != nil {
		return nil, err
	}
	return prof, nil
}

func handleCrash() {
	panic("handle invoke crash")
}

func handleUpdateConfig(bytes []byte) string {
	var params = &UpdateParams{}
	err := json.Unmarshal(bytes, params)
	if err != nil {
		return err.Error()
	}
	updateConfig(params)
	return ""
}

func handleDelFile(path string, result ActionResult) {
	go func() {
		fileInfo, err := os.Stat(path)
		if err != nil {
			if !os.IsNotExist(err) {
				result.success(err.Error())
			}
			result.success("")
			return
		}
		if fileInfo.IsDir() {
			err = os.RemoveAll(path)
			if err != nil {
				result.success(err.Error())
				return
			}
		} else {
			err = os.Remove(path)
			if err != nil {
				result.success(err.Error())
				return
			}
		}
		result.success("")
	}()
}

func handleSetupConfig(bytes []byte) string {
	if !isInit {
		return "not initialized"
	}
	var params = defaultSetupParams()
	err := UnmarshalJson(bytes, params)
	if err != nil {
		logError("unmarshalRawConfig error %v", err)
		_ = applyConfig(defaultSetupParams())
		return err.Error()
	}
	err = applyConfig(params)
	if err != nil {
		return err.Error()
	}
	return ""
}
