#!/usr/bin/env bash
set -euo pipefail

flutter pub get
(
  cd plugins/setup/buildkit/build_tool
  dart pub get
  dart run bin/build_tool.dart \
    --root-dir "$GITHUB_WORKSPACE" patch-mihomo
)
# Keep analyzer errors blocking while allowing the repository's existing
# warning/info baseline to be handled independently of core updates.
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test test/mihomo/runtime_config_regression_test.dart
flutter test test/mihomo/source_config_preservation_test.dart
flutter test test/mihomo/runtime_config_ownership_test.dart
flutter test test/models/profile_atomic_write_test.dart
flutter test test/core/controller_test.dart
flutter test test/mihomo/structural_config_diff_test.dart
flutter test test/mihomo/script_source_preservation_test.dart
flutter test test/mihomo/e2e_compatibility_test.dart
flutter test test/models/tun_stack_test.dart

cd core
go mod tidy
git diff --exit-code go.mod go.sum
cd ..

# The wrapper is Android-specific and cannot be tested as a Linux
# executable. Test the patched Mihomo package here; the arm64 build
# below validates the complete wrapper and native library.
(cd core/Clash.Meta && go test ./tunnel/statistic)
(cd core && go test ./providerbridge ./configfixture)

flutter build apk --debug --target-platform android-arm64 \
  --dart-define=MIHOMO_VERSION="$LATEST_TAG"

CHECKED_OUT="$(git -C core/Clash.Meta rev-parse HEAD)"
if [ "$ACTION" = "upgrade_stable" ]; then
  if [ "$CHECKED_OUT" != "$LATEST_SHA" ]; then
    echo "Core commit mismatch: expected $LATEST_SHA, got $CHECKED_OUT"
    exit 1
  fi
  ACTUAL_VERSION="$(git -C core/Clash.Meta describe --tags --abbrev=0)"
  if [ "$ACTUAL_VERSION" != "$LATEST_TAG" ]; then
    echo "Core version mismatch: expected $LATEST_TAG, got $ACTUAL_VERSION"
    exit 1
  fi
  echo "Core update validation completed for $ACTUAL_VERSION."
else
  # validate_current: the submodule must still be the current SHA,
  # proving no downgrade or overwrite happened.
  if [ "$CHECKED_OUT" != "$CURRENT_SHA" ]; then
    echo "Core changed during validate_current: expected $CURRENT_SHA, got $CHECKED_OUT"
    exit 1
  fi
  echo "Current core validation completed for $CHECKED_OUT."
fi
