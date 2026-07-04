#!/usr/bin/env bash
#
# diagnose_youtube_sort_android.sh
#
# Diagnostic script for YouTube 送中候选 result sorting on Android.
# Captures YT_SORT_DIAG logcat output, then runs the parser.
#
# Usage:
#   ./scripts/diagnose_youtube_sort_android.sh --apk <path> [--duration 120]
#   ./scripts/diagnose_youtube_sort_android.sh --build [--duration 120]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/yt_sort_diag"
APK=""
DURATION=120
BUILD_FIRST=false
APP_ID="com.slclash.app"

# ── Parse args ──────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apk)       APK="$2";        shift 2 ;;
    --build)     BUILD_FIRST=true; shift   ;;
    --duration)  DURATION="$2";    shift 2 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

if $BUILD_FIRST; then
  echo "==> Building debug APK …"
  cd "$PROJECT_DIR"
  flutter build apk --debug --target-platform android-arm64
  APK="$PROJECT_DIR/build/app/outputs/flutter-apk/app-debug.apk"
fi

if [[ -z "$APK" || ! -f "$APK" ]]; then
  echo "Error: APK not found at '$APK'"
  exit 1
fi

mkdir -p "$BUILD_DIR"

# ── Check adb ────────────────────────────────────────────────────────────────
if ! command -v adb &>/dev/null; then
  echo "Error: adb not found in PATH"
  exit 1
fi

DEVICES=$(adb devices | grep -v "^List" | grep -v "^$" | wc -l)
if [[ "$DEVICES" -eq 0 ]]; then
  echo "Error: No adb device connected"
  exit 1
fi

# ── Install ──────────────────────────────────────────────────────────────────
echo "==> Installing APK …"
adb install -r -d "$APK" 2>&1

# ── Clear logcat ─────────────────────────────────────────────────────────────
echo "==> Clearing logcat buffer …"
adb logcat -c 2>/dev/null || true

# ── Launch app ───────────────────────────────────────────────────────────────
echo "==> Launching $APP_ID …"
adb shell monkey -p "$APP_ID" 1 1>/dev/null 2>&1 || true
sleep 3

# ── Capture ──────────────────────────────────────────────────────────────────
LOGCAT_FILE="$BUILD_DIR/logcat.txt"
echo "==> Capturing YT_SORT_DIAG logs for ${DURATION}s …"
echo "    Output: $LOGCAT_FILE"
echo ""
echo "=== MANUAL STEP ==="
echo "请在手机上切换到异常订阅，进入：流媒体检测 -> YouTube 送中候选结果页面。"
echo "完成复现后按 Enter，脚本会停止抓取并自动分析日志。"
echo "（超时 ${DURATION}s 后自动停止）"
echo "==================="

# Start logcat capture in background
adb logcat -v time YT_SORT_DIAG:D '*:S' > "$LOGCAT_FILE" 2>&1 &
LOGCAT_PID=$!

# Wait for user or timeout
if read -t "$DURATION" _; then
  echo "User interrupted, stopping capture …"
else
  echo "Timeout reached (${DURATION}s), stopping capture …"
fi

kill "$LOGCAT_PID" 2>/dev/null || true
wait "$LOGCAT_PID" 2>/dev/null || true
echo "Capture done."

# ── Parse ────────────────────────────────────────────────────────────────────
echo "==> Running parser …"
PYTHON_SCRIPT="$SCRIPT_DIR/parse_youtube_sort_diag.py"
if [[ -f "$PYTHON_SCRIPT" ]]; then
  python3 "$PYTHON_SCRIPT" "$LOGCAT_FILE" "$BUILD_DIR"
  echo ""
  echo "Reports generated:"
  echo "  - $BUILD_DIR/diagnosis_report.md"
  echo "  - $BUILD_DIR/diagnosis.json"
else
  echo "Warning: parser not found at $PYTHON_SCRIPT"
  echo "Raw logs are at $LOGCAT_FILE"
fi
