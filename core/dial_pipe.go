//go:build windows && !cgo

package main

import (
	"io"

	"github.com/Microsoft/go-winio"
)

func dial(path string) (io.ReadWriteCloser, error) {
	return winio.DialPipe(path, nil)
}
