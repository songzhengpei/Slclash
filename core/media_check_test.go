package main

import (
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
)

type mediaCheckRoundTripFunc func(*http.Request) (*http.Response, error)

func (fn mediaCheckRoundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return fn(req)
}

func mediaCheckTextResponse(body string) *http.Response {
	return &http.Response{
		StatusCode: http.StatusOK,
		Header:     make(http.Header),
		Body:       io.NopCloser(strings.NewReader(body)),
	}
}

func TestCheckChatGPTTraceOnly(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			if req.URL.Host+req.URL.Path == "chatgpt.com/cdn-cgi/trace" {
				return mediaCheckTextResponse("loc=JP\n"), nil
			}
			return nil, errors.New("unexpected request: " + req.URL.String())
		}),
	}

	result := checkChatGPT(context.Background(), client)
	if result.Status != "clean" {
		t.Fatalf("expected clean, got %+v", result)
	}
	if result.Region != "JP" {
		t.Fatalf("expected JP region, got %q", result.Region)
	}
}

func TestCheckChatGPTUnsupportedRegion(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			if req.URL.Host+req.URL.Path == "chatgpt.com/cdn-cgi/trace" {
				return mediaCheckTextResponse("loc=CN\n"), nil
			}
			return nil, errors.New("unexpected request: " + req.URL.String())
		}),
	}

	result := checkChatGPT(context.Background(), client)
	if result.Status != "unsupported" {
		t.Fatalf("expected unsupported, got %+v", result)
	}
	if result.Region != "CN" {
		t.Fatalf("expected CN region, got %q", result.Region)
	}
}

func TestCheckChatGPTTraceTimeout(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			return nil, context.DeadlineExceeded
		}),
	}

	result := checkChatGPT(context.Background(), client)
	if result.Status != "timeout" {
		t.Fatalf("expected timeout, got %+v", result)
	}
}

func TestCheckYouTubeGoogleCNReturnsCNConfirmed(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			if req.URL.Host+req.URL.Path == "www.youtube.com/premium" {
				return mediaCheckTextResponse(`<html>redirected to https://www.youtube.com/premium?hl=zh-CN</html><a href="https://www.google.cn">`), nil
			}
			return nil, errors.New("unexpected request: " + req.URL.String())
		}),
	}

	result := checkYouTube(context.Background(), client)
	if result.Status != "cn_confirmed" {
		t.Fatalf("expected cn_confirmed, got %+v", result)
	}
	if result.Region != "CN" {
		t.Fatalf("expected CN region, got %q", result.Region)
	}
}

func TestCheckYouTubeCountryCodeCNReturnsCNConfirmed(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			if req.URL.Host+req.URL.Path == "www.youtube.com/premium" {
				return mediaCheckTextResponse(`{"countryCode":"CN"}`), nil
			}
			return nil, errors.New("unexpected request: " + req.URL.String())
		}),
	}

	result := checkYouTube(context.Background(), client)
	if result.Status != "cn_confirmed" {
		t.Fatalf("expected cn_confirmed, got %+v", result)
	}
	if result.Region != "CN" {
		t.Fatalf("expected CN region, got %q", result.Region)
	}
}

func TestCheckYouTubeNotAvailableWithRegionReturnsUnavailable(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			if req.URL.Host+req.URL.Path == "www.youtube.com/premium" {
				return mediaCheckTextResponse(`{"countryCode":"JP"}Premium is not available in your country`), nil
			}
			return nil, errors.New("unexpected request: " + req.URL.String())
		}),
	}

	result := checkYouTube(context.Background(), client)
	if result.Status != "unavailable" {
		t.Fatalf("expected unavailable, got %+v", result)
	}
	if result.Region != "JP" {
		t.Fatalf("expected JP region, got %q", result.Region)
	}
}

func TestCheckYouTubeRegionJPReturnsAvailable(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			if req.URL.Host+req.URL.Path == "www.youtube.com/premium" {
				return mediaCheckTextResponse(`{"INNERTUBE_CONTEXT_GL":"JP"}`), nil
			}
			return nil, errors.New("unexpected request: " + req.URL.String())
		}),
	}

	result := checkYouTube(context.Background(), client)
	if result.Status != "available" {
		t.Fatalf("expected available, got %+v", result)
	}
	if result.Region != "JP" {
		t.Fatalf("expected JP region, got %q", result.Region)
	}
}

func TestCheckYouTubeNoRegionReturnsUnknown(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			if req.URL.Host+req.URL.Path == "www.youtube.com/premium" {
				return mediaCheckTextResponse(`<html>generic youtube page</html>`), nil
			}
			return nil, errors.New("unexpected request: " + req.URL.String())
		}),
	}

	result := checkYouTube(context.Background(), client)
	if result.Status != "unknown" {
		t.Fatalf("expected unknown, got %+v", result)
	}
}

func TestCheckYouTubePremiumPageTimeoutReturnsTimeout(t *testing.T) {
	client := &http.Client{
		Transport: mediaCheckRoundTripFunc(func(req *http.Request) (*http.Response, error) {
			return nil, context.DeadlineExceeded
		}),
	}

	result := checkYouTube(context.Background(), client)
	if result.Status != "timeout" {
		t.Fatalf("expected timeout, got %+v", result)
	}
}
