#!/usr/bin/env bash
# ============================================================
#  SlClash Dev Environment (WSL)
#  Usage: source dev-env.sh
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export GRADLE_USER_HOME="$SCRIPT_DIR/.dev-tools/gradle"
export GOPATH="$SCRIPT_DIR/.dev-tools/go-pkg"
export GOMODCACHE="$SCRIPT_DIR/.dev-tools/go-pkg/mod"
export PUB_CACHE="$SCRIPT_DIR/.dev-tools/pub-cache"

export PATH="/mnt/d/Code/Tools/Go/go/bin:/mnt/d/Code/Tools/flutter/bin:/mnt/d/Code/Tools/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME="/mnt/d/Code/Tools/Android/Sdk"
export ANDROID_NDK="/mnt/d/Code/Tools/Android/Sdk/ndk/28.2.13676358"

echo "[SlClash] Dev environment loaded."
echo "  GRADLE_USER_HOME = $GRADLE_USER_HOME"
echo "  GOPATH           = $GOPATH"
echo "  GOMODCACHE       = $GOMODCACHE"
echo "  PUB_CACHE        = $PUB_CACHE"
echo "  ANDROID_HOME     = $ANDROID_HOME"
echo "  ANDROID_NDK      = $ANDROID_NDK"
