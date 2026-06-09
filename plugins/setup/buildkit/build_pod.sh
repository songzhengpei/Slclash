#!/usr/bin/env bash
set -euo pipefail

# This script is invoked by the CocoaPods script build phase.
# It forwards Xcode build environment to the build_tool and runs it.

# Xcode strips PATH to a minimal set. Restore common tool locations.
export PATH="/opt/homebrew/bin:/usr/local/bin:${HOME}/fvm/default/bin:${HOME}/.pub-cache/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${PODS_ROOT:-$PWD}/../.." && pwd)"

# Forward CocoaPods/Xcode environment to variables the build_tool expects
export CARGOKIT_DARWIN_PLATFORM_NAME="${PLATFORM_NAME:-macosx}"
export CARGOKIT_DARWIN_ARCHS="${ARCHS:-arm64}"
export CARGOKIT_CONFIGURATION="${CONFIGURATION:-Release}"
export PROJECT_DIR

if [ -z "${APP_ENV:-}" ]; then
  export APP_ENV="pre"
fi

exec "$SCRIPT_DIR/run_build_tool.sh" macos
