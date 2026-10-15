//go:build android && cgo

package main

/*
#cgo android LDFLAGS: -llog
#include <android/log.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>

static void emit_tun_close_stage(const char *stage, const char *phase) {
	struct timespec timestamp;
	if (clock_gettime(CLOCK_BOOTTIME, &timestamp) != 0) return;
	long long elapsed_ms = (long long) timestamp.tv_sec * 1000 + timestamp.tv_nsec / 1000000;
	__android_log_print(ANDROID_LOG_INFO, "Phase4Lifecycle",
		"[PHASE4] mark=tun_close_stage elapsed_ms=%lld pid=%d stage=%s phase=%s",
		elapsed_ms, (int) getpid(), stage, phase);
}
*/
import "C"

import (
	"unsafe"

	"github.com/metacubex/mihomo/constant"
)

func tunCloseTrace(stage, phase string) {
	if !tunCloseTraceAllowed(constant.Path.HomeDir()) {
		return
	}
	cStage := C.CString(stage)
	defer C.free(unsafe.Pointer(cStage))
	cPhase := C.CString(phase)
	defer C.free(unsafe.Pointer(cPhase))
	C.emit_tun_close_stage(cStage, cPhase)
}
