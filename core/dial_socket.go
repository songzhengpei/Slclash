//go:build !cgo && !windows

package main

import (
	"fmt"
	"io"
	"net"
	"strconv"
)

func dial(arg string) (io.ReadWriteCloser, error) {
	_, err := strconv.Atoi(arg)
	if err != nil {
		return net.Dial("unix", arg)
	}
	return net.Dial("tcp", fmt.Sprintf("127.0.0.1:%s", arg))
}
