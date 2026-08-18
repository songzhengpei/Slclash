#!/usr/bin/env bash
# Resolves the relationship between the bundled Mihomo submodule and the
# latest official stable / alpha lines, and prints KEY=VALUE lines for the
# caller to consume.
#
# Usage:
#   mihomo-core-relationship.sh <submodule-dir>
#
# Output keys:
#   current_sha            full SHA of the bundled submodule HEAD
#   nearest_release_tag    git describe --tags --abbrev=0 (informational only)
#   latest_stable_tag      latest official vX.Y.Z release tag
#   latest_stable_sha      full commit SHA of that tag
#   relationship_to_stable EXACT_STABLE | AHEAD_OF_STABLE | BEHIND_STABLE | DIVERGED
#   latest_alpha_sha       full SHA of the Prerelease-Alpha tag (or Alpha head)
#   relationship_to_alpha  EXACT | AHEAD | BEHIND | DIVERGED
#
# Relationship rules (never dates, never tag-string comparison):
#   EXACT   current == target
#   AHEAD   target is an ancestor of current
#   BEHIND  current is an ancestor of target
#   DIVERGED neither is an ancestor of the other
set -euo pipefail

SUBMODULE_DIR="${1:?usage: mihomo-core-relationship.sh <submodule-dir>}"

git -C "$SUBMODULE_DIR" remote add metacubex https://github.com/MetaCubeX/mihomo.git 2>/dev/null || \
  git -C "$SUBMODULE_DIR" remote set-url metacubex https://github.com/MetaCubeX/mihomo.git
git -C "$SUBMODULE_DIR" fetch --tags --force metacubex >/dev/null 2>&1 || true

CURRENT_SHA="$(git -C "$SUBMODULE_DIR" rev-parse HEAD)"
NEAREST_RELEASE_TAG="$(git -C "$SUBMODULE_DIR" describe --tags --abbrev=0 2>/dev/null || true)"

LATEST_STABLE_TAG="$(gh api repos/MetaCubeX/mihomo/releases/latest --jq '.tag_name' 2>/dev/null || true)"
if [ -z "$LATEST_STABLE_TAG" ] || ! [[ "$LATEST_STABLE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Unexpected Mihomo stable release tag: $LATEST_STABLE_TAG" >&2
  exit 1
fi
LATEST_STABLE_SHA="$(git -C "$SUBMODULE_DIR" rev-parse "refs/tags/$LATEST_STABLE_TAG^{commit}")"

LATEST_ALPHA_SHA="$(git -C "$SUBMODULE_DIR" rev-parse "refs/tags/Prerelease-Alpha^{commit}" 2>/dev/null || \
  git -C "$SUBMODULE_DIR" rev-parse "refs/remotes/metacubex/Alpha" 2>/dev/null || true)"

relationship() {
  local current="$1" target="$2"
  if [ "$current" = "$target" ]; then
    echo "EXACT"
    return
  fi
  if git -C "$SUBMODULE_DIR" merge-base --is-ancestor "$target" "$current" 2>/dev/null; then
    echo "AHEAD"
    return
  fi
  if git -C "$SUBMODULE_DIR" merge-base --is-ancestor "$current" "$target" 2>/dev/null; then
    echo "BEHIND"
    return
  fi
  echo "DIVERGED"
}

REL_TO_STABLE="$(relationship "$CURRENT_SHA" "$LATEST_STABLE_SHA")"
REL_TO_ALPHA="$(relationship "$CURRENT_SHA" "$LATEST_ALPHA_SHA")"

echo "current_sha=$CURRENT_SHA"
echo "nearest_release_tag=$NEAREST_RELEASE_TAG"
echo "latest_stable_tag=$LATEST_STABLE_TAG"
echo "latest_stable_sha=$LATEST_STABLE_SHA"
echo "relationship_to_stable=$REL_TO_STABLE"
echo "latest_alpha_sha=$LATEST_ALPHA_SHA"
echo "relationship_to_alpha=$REL_TO_ALPHA"
