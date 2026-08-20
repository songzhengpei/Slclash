package main

import (
	"errors"
	"testing"

	"github.com/metacubex/mihomo/constant"
)

type stubSelectAble struct {
	selected string
}

func (s *stubSelectAble) Set(name string) error {
	s.selected = name
	return nil
}

func (s *stubSelectAble) ForceSet(name string) {
	s.selected = name
}

func TestApplyUnfixURLTestClearsPin(t *testing.T) {
	stub := &stubSelectAble{selected: "NodeA"}
	if err := applyUnfix(stub, constant.URLTest); err != nil {
		t.Fatal(err)
	}
	if stub.selected != "" {
		t.Fatalf("fixed not cleared: %q", stub.selected)
	}
}

func TestApplyUnfixFallbackClearsPin(t *testing.T) {
	stub := &stubSelectAble{selected: "NodeA"}
	if err := applyUnfix(stub, constant.Fallback); err != nil {
		t.Fatal(err)
	}
	if stub.selected != "" {
		t.Fatalf("fixed not cleared: %q", stub.selected)
	}
}

func TestApplyUnfixSelectorRejected(t *testing.T) {
	stub := &stubSelectAble{selected: "NodeA"}
	err := applyUnfix(stub, constant.Selector)
	if !errors.Is(err, errUnfixRejected) {
		t.Fatalf("expected errUnfixRejected, got %v", err)
	}
	if stub.selected != "NodeA" {
		t.Fatalf("selector pin must stay: %q", stub.selected)
	}
}

func TestApplyUnfixLoadBalanceRejected(t *testing.T) {
	err := applyUnfix(nil, constant.LoadBalance)
	if !errors.Is(err, errUnfixRejected) {
		t.Fatalf("expected errUnfixRejected, got %v", err)
	}
}

func TestApplyUnfixNilRejected(t *testing.T) {
	err := applyUnfix(nil, constant.URLTest)
	if !errors.Is(err, errUnfixRejected) {
		t.Fatalf("expected errUnfixRejected, got %v", err)
	}
}
