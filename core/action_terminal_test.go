//go:build !cgo

package main

import (
	"encoding/binary"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

type terminalCaptureConn struct {
	writes chan []byte
}

func newTerminalCaptureConn() *terminalCaptureConn {
	return &terminalCaptureConn{writes: make(chan []byte, 4)}
}

func (c *terminalCaptureConn) Read([]byte) (int, error) { return 0, io.EOF }
func (c *terminalCaptureConn) Close() error             { return nil }
func (c *terminalCaptureConn) Write(data []byte) (int, error) {
	c.writes <- append([]byte(nil), data...)
	return len(data), nil
}

func captureTerminalResult(t *testing.T, invoke func()) ActionResult {
	t.Helper()
	previous := conn
	capture := newTerminalCaptureConn()
	conn = capture
	t.Cleanup(func() { conn = previous })

	invoke()

	var frame []byte
	select {
	case frame = <-capture.writes:
	case <-time.After(2 * time.Second):
		t.Fatal("request did not produce a terminal result")
	}
	if len(frame) < 4 {
		t.Fatalf("invalid frame length: %d", len(frame))
	}
	length := int(binary.LittleEndian.Uint32(frame[:4]))
	if length != len(frame)-4 {
		t.Fatalf("frame length header=%d payload=%d", length, len(frame)-4)
	}
	var result ActionResult
	if err := json.Unmarshal(frame[4:], &result); err != nil {
		t.Fatalf("decode terminal result: %v", err)
	}

	select {
	case second := <-capture.writes:
		t.Fatalf("request produced a second terminal result: %q", second)
	case <-time.After(100 * time.Millisecond):
	}
	return result
}

func TestUnknownActionProducesExactlyOneError(t *testing.T) {
	result := captureTerminalResult(t, func() {
		handleAction(
			&Action{Id: "unknown#1", Method: Method("futureMethod")},
			ActionResult{Id: "unknown#1", Method: Method("futureMethod")},
		)
	})

	if result.Code != -1 {
		t.Fatalf("code=%d, want -1", result.Code)
	}
	if !strings.Contains(result.Data.(string), "unsupported action method") {
		t.Fatalf("unexpected error: %v", result.Data)
	}
}

func TestKnownActionProducesExactlyOneResult(t *testing.T) {
	result := captureTerminalResult(t, func() {
		handleAction(
			&Action{Id: "isInit#1", Method: getIsInitMethod},
			ActionResult{Id: "isInit#1", Method: getIsInitMethod},
		)
	})

	if result.Code != 0 {
		t.Fatalf("code=%d, want 0", result.Code)
	}
}

func TestHandleDelFileDeletesOnce(t *testing.T) {
	path := filepath.Join(t.TempDir(), "delete-me")
	if err := os.WriteFile(path, []byte("data"), 0o600); err != nil {
		t.Fatal(err)
	}
	result := captureTerminalResult(t, func() {
		handleDelFile(path, ActionResult{Id: "delete#1", Method: deleteFile})
	})

	if result.Code != 0 || result.Data != "" {
		t.Fatalf("unexpected result: %#v", result)
	}
	if _, err := os.Stat(path); !os.IsNotExist(err) {
		t.Fatalf("file still exists: %v", err)
	}
}

func TestHandleDelFileMissingPathSucceedsOnce(t *testing.T) {
	path := filepath.Join(t.TempDir(), "missing")
	result := captureTerminalResult(t, func() {
		handleDelFile(path, ActionResult{Id: "delete#2", Method: deleteFile})
	})

	if result.Code != 0 || result.Data != "" {
		t.Fatalf("unexpected result: %#v", result)
	}
}

func TestHandleDelFileStatErrorReturnsOnce(t *testing.T) {
	statErr := errors.New("stat permission denied")
	result := captureTerminalResult(t, func() {
		handleDelFileWithStat(
			"blocked",
			ActionResult{Id: "delete#3", Method: deleteFile},
			func(string) (os.FileInfo, error) { return nil, statErr },
		)
	})

	if result.Code != 0 || result.Data != statErr.Error() {
		t.Fatalf("unexpected result: %#v", result)
	}
}
