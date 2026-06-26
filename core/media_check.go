package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/config"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

const (
	mediaCheckDefaultTimeout = 15 * time.Second
	chatGPTBodyLimit         = 64 * 1024
	youTubeBodyLimit         = 256 * 1024
	mediaCheckAttempts       = 1
)

var chatGPTSupportedRegions = map[string]struct{}{
	"AF": {}, "AX": {}, "AL": {}, "DZ": {}, "AD": {}, "AO": {}, "AG": {}, "AR": {},
	"AM": {}, "AW": {}, "AU": {}, "AT": {}, "AZ": {}, "BS": {}, "BH": {}, "BD": {},
	"BB": {}, "BE": {}, "BZ": {}, "BM": {}, "BJ": {}, "BT": {}, "BO": {}, "BA": {},
	"BW": {}, "BR": {}, "BN": {}, "BG": {}, "BF": {}, "BI": {}, "CV": {}, "KH": {},
	"CM": {}, "CA": {}, "KY": {}, "CF": {}, "TD": {}, "CL": {}, "CO": {}, "KM": {},
	"CG": {}, "CD": {}, "CR": {}, "CI": {}, "HR": {}, "CY": {}, "CZ": {}, "DK": {},
	"DJ": {}, "DM": {}, "DO": {}, "EC": {}, "EG": {}, "SV": {}, "GQ": {}, "ER": {},
	"EE": {}, "SZ": {}, "ET": {}, "FO": {}, "FJ": {}, "FI": {}, "FR": {}, "GF": {},
	"PF": {}, "TF": {}, "GA": {}, "GM": {}, "GE": {}, "DE": {}, "GH": {}, "GR": {},
	"GD": {}, "GL": {}, "GT": {}, "GP": {}, "GN": {}, "GW": {}, "GY": {}, "HT": {},
	"VA": {}, "HN": {}, "HU": {}, "IS": {}, "IN": {}, "ID": {}, "IQ": {}, "IE": {},
	"IL": {}, "IT": {}, "JM": {}, "JP": {}, "JO": {}, "KZ": {}, "KE": {}, "KI": {},
	"KW": {}, "KG": {}, "LA": {}, "LV": {}, "LB": {}, "LS": {}, "LR": {}, "LY": {},
	"LI": {}, "LT": {}, "LU": {}, "MG": {}, "MW": {}, "MY": {}, "MV": {}, "ML": {},
	"MT": {}, "MH": {}, "MQ": {}, "MR": {}, "MU": {}, "YT": {}, "MX": {}, "FM": {},
	"MD": {}, "MC": {}, "MN": {}, "ME": {}, "MA": {}, "MZ": {}, "MM": {}, "NA": {},
	"NR": {}, "NP": {}, "NL": {}, "NC": {}, "NZ": {}, "NI": {}, "NE": {}, "NG": {},
	"MK": {}, "NO": {}, "OM": {}, "PK": {}, "PW": {}, "PS": {}, "PA": {}, "PG": {},
	"PY": {}, "PE": {}, "PH": {}, "PL": {}, "PT": {}, "QA": {}, "RE": {}, "RO": {},
	"RW": {}, "BL": {}, "SH": {}, "KN": {}, "LC": {}, "MF": {}, "PM": {}, "VC": {},
	"WS": {}, "SM": {}, "ST": {}, "SA": {}, "SN": {}, "RS": {}, "SC": {}, "SL": {},
	"SG": {}, "SK": {}, "SI": {}, "SB": {}, "SO": {}, "ZA": {}, "KR": {}, "SS": {},
	"ES": {}, "LK": {}, "SR": {}, "SE": {}, "CH": {}, "SD": {}, "SJ": {}, "TW": {},
	"TJ": {}, "TZ": {}, "TH": {}, "TL": {}, "TG": {}, "TO": {}, "TT": {}, "TN": {},
	"TR": {}, "TM": {}, "TV": {}, "UG": {}, "UA": {}, "AE": {}, "GB": {}, "US": {},
	"UY": {}, "UZ": {}, "VU": {}, "VN": {}, "WF": {}, "YE": {}, "ZM": {}, "ZW": {},
}

type MediaCheckResult struct {
	Name      string           `json:"name"`
	ChatGPT   MediaCheckItem   `json:"chatgpt"`
	YouTube   MediaCheckItem   `json:"youtube"`
	HTTPS     MediaHTTPSResult `json:"https"`
	Region    string           `json:"region,omitempty"`
	Score     int              `json:"score"`
	Error     string           `json:"error,omitempty"`
	CheckedAt int64            `json:"checked-at"`
}

type MediaCheckItem struct {
	Status           string `json:"status"`
	Region           string `json:"region,omitempty"`
	Evidence         string `json:"evidence,omitempty"`
	PremiumAvailable *bool  `json:"premium-available,omitempty"`
	Error            string `json:"error,omitempty"`
}

type MediaHTTPSResult struct {
	Delay   int    `json:"delay"`
	Success int    `json:"success"`
	Total   int    `json:"total"`
	Values  []int  `json:"values"`
	Error   string `json:"error,omitempty"`
}

func handleMediaCheck(paramsString string) string {
	params := &MediaCheckParams{}
	if err := json.Unmarshal([]byte(paramsString), params); err != nil {
		return mediaCheckError("", err).json()
	}

	timeout := time.Duration(params.Timeout) * time.Millisecond
	if timeout <= 0 {
		timeout = mediaCheckDefaultTimeout
	}
	if timeout > mediaCheckDefaultTimeout {
		timeout = mediaCheckDefaultTimeout
	}
	mode := strings.ToLower(strings.TrimSpace(params.Mode))
	if params.HealthOnly {
		mode = "health"
	}
	if mode == "" {
		mode = "full"
	}

	result := MediaCheckResult{
		Name:      params.ProxyName,
		CheckedAt: time.Now().UnixMilli(),
		ChatGPT:   MediaCheckItem{Status: "failed"},
		YouTube:   MediaCheckItem{Status: "failed"},
		HTTPS:     MediaHTTPSResult{Delay: -1, Total: 3},
	}
	if mode == "health" {
		result.ChatGPT = MediaCheckItem{Status: "skipped"}
		result.YouTube = MediaCheckItem{Status: "skipped"}
	} else if mode == "gpt" || mode == "chatgpt" {
		result.YouTube = MediaCheckItem{Status: "skipped"}
		result.HTTPS = MediaHTTPSResult{Delay: -1, Total: 0}
	} else if mode == "youtube" {
		result.ChatGPT = MediaCheckItem{Status: "skipped"}
		result.HTTPS = MediaHTTPSResult{Delay: -1, Total: 0}
	}

	proxy, err := getMediaCheckProxy(params)
	if err != nil {
		result.Error = err.Error()
		return result.withScore().json()
	}
	if proxy == nil {
		result.Error = "proxy not found"
		return result.withScore().json()
	}

	if mode == "health" {
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		result.HTTPS = checkHTTPS(ctx, proxy)
		cancel()
		return result.withScore().json()
	}

	client := newMediaCheckClient(proxy, timeout)
	defer client.CloseIdleConnections()

	if mode == "gpt" || mode == "chatgpt" {
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		result.ChatGPT = checkChatGPT(ctx, client)
		cancel()
		result.Region = result.ChatGPT.Region
		return result.withScore().json()
	}

	if mode == "youtube" {
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		result.YouTube = checkYouTube(ctx, client)
		cancel()
		result.Region = result.YouTube.Region
		return result.withScore().json()
	}

	var httpsResult MediaHTTPSResult
	var chatGPTResult MediaCheckItem
	var youTubeResult MediaCheckItem
	var wg sync.WaitGroup
	wg.Add(3)

	go func() {
		defer wg.Done()
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		httpsResult = checkHTTPS(ctx, proxy)
	}()
	go func() {
		defer wg.Done()
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		chatGPTResult = checkChatGPT(ctx, client)
	}()
	go func() {
		defer wg.Done()
		ctx, cancel := context.WithTimeout(context.Background(), timeout)
		defer cancel()
		youTubeResult = checkYouTube(ctx, client)
	}()

	wg.Wait()
	result.HTTPS = httpsResult
	result.ChatGPT = chatGPTResult
	result.YouTube = youTubeResult
	result.Region = firstNonEmpty(result.ChatGPT.Region, result.YouTube.Region)

	return result.withScore().json()
}

func getMediaCheckProxy(params *MediaCheckParams) (C.Proxy, error) {
	if params.ProfilePath == "" {
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
		if proxy == nil {
			return nil, fmt.Errorf("proxy not found: %s", params.ProxyName)
		}
		return proxy, nil
	}

	bytes, err := readFile(params.ProfilePath)
	if err != nil {
		return nil, err
	}
	rawCfg, err := config.UnmarshalRawConfig(bytes)
	if err != nil {
		return nil, err
	}
	for _, mapping := range rawCfg.Proxy {
		name, ok := mapping["name"].(string)
		if !ok || name != params.ProxyName {
			continue
		}
		return adapter.ParseProxy(mapping, adapter.WithTunnelForAPI(tunnel.Tunnel))
	}
	// Fallback: search tunnel.Providers() for proxy-provider proxies
	for _, p := range tunnel.Providers() {
		for _, pp := range p.Proxies() {
			if pp.Name() == params.ProxyName {
				return pp, nil
			}
		}
	}
	return nil, fmt.Errorf("proxy %q not found in profile", params.ProxyName)
}

func newMediaCheckClient(proxy C.Proxy, timeout time.Duration) *http.Client {
	transport := &http.Transport{
		DialContext: func(ctx context.Context, network, address string) (net.Conn, error) {
			metadata, err := mediaURLToMetadata("https://" + address)
			if err != nil {
				return nil, err
			}
			return proxy.DialContext(ctx, &metadata)
		},
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          12,
		MaxIdleConnsPerHost:   4,
		IdleConnTimeout:       15 * time.Second,
		TLSHandshakeTimeout:   8 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
		TLSClientConfig:       &tls.Config{MinVersion: tls.VersionTLS12},
	}

	return &http.Client{
		Timeout:   timeout,
		Transport: transport,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 3 {
				return http.ErrUseLastResponse
			}
			return nil
		},
	}
}

func checkChatGPT(ctx context.Context, client *http.Client) MediaCheckItem {
	trace, err := getChatGPTTrace(ctx, client)
	if err != nil {
		item := MediaCheckItem{Status: "failed", Error: err.Error()}
		if isMediaTimeout(err) {
			item.Status = "timeout"
		}
		return item
	}
	region := parseTraceLoc(trace)
	if region == "" {
		return MediaCheckItem{Status: "failed", Evidence: "trace", Error: "missing loc in trace"}
	}
	if !isChatGPTSupportedRegion(region) {
		return MediaCheckItem{Status: "unsupported", Region: region, Evidence: "trace"}
	}
	return MediaCheckItem{Status: "clean", Region: region, Evidence: "trace"}
}

func getChatGPTTrace(ctx context.Context, client *http.Client) (string, error) {
	urls := []string{
		"https://chatgpt.com/cdn-cgi/trace",
		"https://chat.openai.com/cdn-cgi/trace",
	}
	var lastErr error
	for _, rawURL := range urls {
		trace, err := mediaGetLimitedWithRetry(
			ctx,
			client,
			rawURL,
			chatGPTBodyLimit,
			3*time.Second,
			mediaCheckAttempts,
		)
		if err == nil && parseTraceLoc(trace) != "" {
			return trace, nil
		}
		if err != nil {
			lastErr = err
		} else {
			lastErr = fmt.Errorf("missing loc in trace")
		}
	}
	if lastErr == nil {
		lastErr = fmt.Errorf("trace unavailable")
	}
	return "", lastErr
}

func isChatGPTSupportedRegion(region string) bool {
	_, ok := chatGPTSupportedRegions[strings.ToUpper(strings.TrimSpace(region))]
	return ok
}

func isMediaTimeout(err error) bool {
	if err == nil {
		return false
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return true
	}
	if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
		return true
	}
	return strings.Contains(strings.ToLower(err.Error()), "timeout")
}

func checkYouTube(ctx context.Context, client *http.Client) MediaCheckItem {
	body, err := mediaGetLimitedWithRetry(
		ctx,
		client,
		"https://www.youtube.com/premium",
		youTubeBodyLimit,
		8*time.Second,
		mediaCheckAttempts,
	)
	if err != nil {
		item := MediaCheckItem{Status: "failed", Error: err.Error()}
		if isMediaTimeout(err) {
			item.Status = "timeout"
		}
		return item
	}

	lower := strings.ToLower(body)
	region, evidence := parseYouTubeRegion(body)

	// 1. CN region → cn_confirmed (always, never available)
	if strings.EqualFold(region, "CN") {
		available := false
		return MediaCheckItem{
			Status:           "cn_confirmed",
			Region:           region,
			Evidence:         evidence,
			PremiumAvailable: &available,
		}
	}

	// 2. "not available" → unavailable (with region if parsed)
	if isYouTubePremiumUnavailable(lower) {
		available := false
		ev := evidence
		if ev == "" {
			ev = "not-available"
		}
		return MediaCheckItem{
			Status:           "unavailable",
			Region:           region,
			Evidence:         ev,
			PremiumAvailable: &available,
		}
	}

	// 3. Region parsed (non-CN) → available
	if region != "" {
		available := true
		ev := evidence
		// Attach premium markers as supplementary evidence
		if isYouTubePremiumAvailable(lower) && ev == "" {
			ev = "page-marker"
		}
		return MediaCheckItem{
			Status:           "available",
			Region:           region,
			Evidence:         ev,
			PremiumAvailable: &available,
		}
	}

	// 4. No region parsed — check premium markers as weak evidence
	if isYouTubePremiumAvailable(lower) {
		available := true
		return MediaCheckItem{
			Status:           "available",
			Evidence:         "page-marker",
			PremiumAvailable: &available,
		}
	}

	// 5. Nothing matched → unknown
	return MediaCheckItem{Status: "unknown"}
}

func parseYouTubeRegion(body string) (string, string) {
	patterns := []struct {
		evidence string
		pattern  string
	}{
		{"country-code", `id=["']country-code["'][^>]*>\s*([A-Za-z]{2,3})\s*<`},
		{"countryCode", `"countryCode"\s*:\s*"([A-Za-z]{2})"`},
		{"countryCode-escaped", `\\"countryCode\\"\s*:\s*\\"([A-Za-z]{2})\\"`},
		{"GL", `"GL"\s*:\s*"([A-Za-z]{2})"`},
		{"GL-escaped", `\\"GL\\"\s*:\s*\\"([A-Za-z]{2})\\"`},
		{"INNERTUBE_CONTEXT_GL", `"INNERTUBE_CONTEXT_GL"\s*:\s*"([A-Za-z]{2})"`},
		{"INNERTUBE_CONTEXT_GL-escaped", `\\"INNERTUBE_CONTEXT_GL\\"\s*:\s*\\"([A-Za-z]{2})\\"`},
		{"country_code", `"country_code"\s*:\s*"([A-Za-z]{2})"`},
		{"contentRegion", `"contentRegion"\s*:\s*"([A-Za-z]{2})"`},
		{"gl-query", `[?&]gl=([A-Za-z]{2})(?:[&"'<\s]|$)`},
		{"hl-gl", `"hl"\s*:\s*"[a-zA-Z-]+"\s*,\s*"gl"\s*:\s*"([A-Za-z]{2})"`},
	}

	for _, item := range patterns {
		re := regexp.MustCompile(item.pattern)
		matches := re.FindStringSubmatch(body)
		if len(matches) > 1 {
			return strings.ToUpper(strings.TrimSpace(matches[1])), item.evidence
		}
	}

	// Strongest CN signal — www.google.cn redirect means China
	if strings.Contains(body, "www.google.cn") {
		return "CN", "google-cn"
	}

	return "", ""
}

func isYouTubePremiumUnavailable(bodyLower string) bool {
	patterns := []string{
		"youtube premium is not available in your country",
		"premium is not available in your country",
		"premium is not available in your region",
		"not available in your country",
		"not available in your region",
		"not available in this country",
		"is not currently available",
		"isn't available in your country",
		"isn’t available in your country",
	}
	for _, pattern := range patterns {
		if strings.Contains(bodyLower, pattern) {
			return true
		}
	}
	return false
}

func isYouTubePremiumAvailable(bodyLower string) bool {
	patterns := []string{
		"youtube premium",
		"ad-free",
		"background play",
		`"browseid":"spunlimited"`,
	}
	for _, pattern := range patterns {
		if strings.Contains(bodyLower, pattern) {
			return true
		}
	}
	return false
}

func checkHTTPS(ctx context.Context, proxy C.Proxy) MediaHTTPSResult {
	expectedStatus, err := utils.NewUnsignedRanges[uint16]("")
	if err != nil {
		return MediaHTTPSResult{Delay: -1, Total: 3, Error: err.Error()}
	}

	type probeResult struct {
		delay int
		err   string
	}
	results := make([]probeResult, 3)
	var wg sync.WaitGroup
	wg.Add(3)
	for i := 0; i < 3; i++ {
		go func(idx int) {
			defer wg.Done()
			reqCtx, cancel := context.WithTimeout(ctx, 4*time.Second)
			defer cancel()
			d, e := proxy.URLTest(reqCtx, "https://www.gstatic.com/generate_204", expectedStatus)
			if e != nil || d == 0 {
				if e != nil {
					results[idx] = probeResult{err: e.Error()}
				}
				return
			}
			results[idx] = probeResult{delay: int(d)}
		}(i)
	}
	wg.Wait()

	values := make([]int, 0, 3)
	lastErr := ""
	for _, r := range results {
		if r.delay > 0 {
			values = append(values, r.delay)
		} else if r.err != "" {
			lastErr = r.err
		}
	}

	sort.Ints(values)
	median := -1
	if len(values) > 0 {
		median = values[len(values)/2]
	}

	return MediaHTTPSResult{
		Delay:   median,
		Success: len(values),
		Total:   3,
		Values:  values,
		Error:   lastErr,
	}
}

func mediaGetLimited(ctx context.Context, client *http.Client, rawURL string, limit int64) (string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return "", err
	}
	req.Header.Set("User-Agent", "Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, limit))
	if err != nil {
		return "", err
	}
	if resp.StatusCode >= 500 {
		return string(body), fmt.Errorf("http %d", resp.StatusCode)
	}
	return string(body), nil
}

func mediaGetLimitedWithRetry(
	ctx context.Context,
	client *http.Client,
	rawURL string,
	limit int64,
	perAttemptTimeout time.Duration,
	attempts int,
) (string, error) {
	if attempts <= 0 {
		attempts = 1
	}
	var lastErr error
	for i := 0; i < attempts; i++ {
		if ctx.Err() != nil {
			return "", ctx.Err()
		}
		attemptCtx, cancel := context.WithTimeout(ctx, perAttemptTimeout)
		body, err := mediaGetLimited(attemptCtx, client, rawURL, limit)
		cancel()
		if err == nil {
			return body, nil
		}
		lastErr = err
		if !shouldRetryMediaError(err) {
			break
		}
	}
	if lastErr == nil {
		lastErr = fmt.Errorf("request unavailable")
	}
	return "", lastErr
}

func shouldRetryMediaError(err error) bool {
	if err == nil {
		return false
	}
	// Do not retry on timeout — retrying a timeout usually just times out again
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "connection reset") ||
		strings.Contains(message, "connection refused") ||
		strings.Contains(message, "unexpected eof") ||
		strings.Contains(message, "temporary") ||
		strings.Contains(message, "http 5")
}

func allMediaTimeout(errs []error) bool {
	hasErr := false
	for _, err := range errs {
		if err == nil {
			continue
		}
		hasErr = true
		if !isMediaTimeout(err) {
			return false
		}
	}
	return hasErr
}

func joinMediaErrors(errs []error) string {
	parts := make([]string, 0, len(errs))
	for _, err := range errs {
		if err != nil {
			parts = append(parts, err.Error())
		}
	}
	return strings.Join(parts, "; ")
}

func parseTraceLoc(body string) string {
	for _, line := range strings.Split(body, "\n") {
		if strings.HasPrefix(line, "loc=") {
			return strings.TrimSpace(strings.TrimPrefix(line, "loc="))
		}
	}
	return ""
}

func mediaURLToMetadata(rawURL string) (metadata C.Metadata, err error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return metadata, err
	}
	port := parsed.Port()
	if port == "" {
		switch parsed.Scheme {
		case "https":
			port = "443"
		case "http":
			port = "80"
		default:
			return metadata, fmt.Errorf("%s scheme not support", rawURL)
		}
	}
	err = metadata.SetRemoteAddress(net.JoinHostPort(parsed.Hostname(), port))
	return metadata, err
}

func (result MediaCheckResult) withScore() MediaCheckResult {
	score := 0
	switch result.ChatGPT.Status {
	case "clean":
		score += 5000
	case "unsupported":
		score += 1000
	}
	if result.YouTube.Status == "cn_confirmed" || result.YouTube.Status == "unavailable" {
		score += 3000
	}
	if result.HTTPS.Success == result.HTTPS.Total && result.HTTPS.Total > 0 {
		score += 1500
	}
	if result.HTTPS.Delay > 0 {
		score += max(0, 1000-result.HTTPS.Delay)
	}
	result.Score = score
	return result
}

func (result MediaCheckResult) json() string {
	data, err := json.Marshal(result)
	if err != nil {
		return "{}"
	}
	return string(data)
}

func mediaCheckError(name string, err error) MediaCheckResult {
	return MediaCheckResult{
		Name:      name,
		CheckedAt: time.Now().UnixMilli(),
		ChatGPT:   MediaCheckItem{Status: "failed"},
		YouTube:   MediaCheckItem{Status: "failed"},
		HTTPS:     MediaHTTPSResult{Delay: -1, Total: 3},
		Error:     err.Error(),
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if value != "" {
			return value
		}
	}
	return ""
}
