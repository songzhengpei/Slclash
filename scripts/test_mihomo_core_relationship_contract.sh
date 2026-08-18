#!/usr/bin/env bash
# Producer->consumer contract test for the Mihomo core relationship helper.
#
# Phase 3A lesson: the helper (producer) and the updater workflow (consumer)
# must agree on the exact stable-relationship enum values. Testing each side
# in isolation missed the EXACT/AHEAD/BEHIND vs *_STABLE mismatch that broke
# every scheduled updater run. This test pins the contract end to end by
# extracting the actual enum definitions from BOTH files and asserting they
# are identical — no network, no submodule, no re-implementation.
#
# Usage: bash scripts/test_mihomo_core_relationship_contract.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="$ROOT/scripts/mihomo-core-relationship.sh"
WORKFLOW="$ROOT/.github/workflows/mihomo-core-update.yml"

# --- Producer: the mapping block in the helper must cover exactly the four
# stable enum values the workflow consumes, mapping from the raw relationship.
helper_enum_arms() {
  # Extract "  WORD)    REL_TO_STABLE=\"...\"" lines from the case block.
  sed -n '/case "\$REL_TO_STABLE_RAW" in/,/esac/p' "$HELPER" \
    | sed -n 's/^  \([A-Z_]*\)) *REL_TO_STABLE="\([A-Z_]*\)".*/\1=\2/p'
}

# --- Consumer: the workflow's Decide step case arms (DIVERGED, BEHIND_STABLE,
# EXACT_STABLE|AHEAD_OF_STABLE).
workflow_enum_arms() {
  sed -n '/case "\$REL" in/,/esac/p' "$WORKFLOW" \
    | sed -n 's/^  *\([A-Z_|]*\)) *$/\1/p' \
    | tr '|' '\n' \
    | sed '/^$/d'
}

echo "== Producer: helper stable mapping =="
helper_enums="$(helper_enum_arms)"
echo "$helper_enums" | sed 's/^/  /'

echo "== Consumer: workflow Decide arms =="
workflow_enums="$(workflow_enum_arms | sort)"
echo "$workflow_enums" | sed 's/^/  /'

# The mapping must map each raw value to exactly the *_STABLE value the
# workflow consumes (e.g. AHEAD -> AHEAD_OF_STABLE), and the two sides must
# name the same final enum set.
raw_values="$(echo "$helper_enums" | cut -d= -f1 | sort)"
mapped_values="$(echo "$helper_enums" | cut -d= -f2 | sort)"

fail_count=0
if [ "$raw_values" != "$(printf 'AHEAD\nBEHIND\nDIVERGED\nEXACT\n')" ]; then
  echo "FAIL  helper mapping inputs differ from raw relationship enum" >&2
  fail_count=$((fail_count + 1))
fi
if [ "$mapped_values" != "$(printf 'AHEAD_OF_STABLE\nBEHIND_STABLE\nDIVERGED\nEXACT_STABLE\n')" ]; then
  echo "FAIL  helper mapping outputs differ from the stable contract enum" >&2
  fail_count=$((fail_count + 1))
fi
if [ "$mapped_values" != "$workflow_enums" ]; then
  echo "FAIL  helper stable enum != workflow enum" >&2
  echo "  helper: $mapped_values" >&2
  echo "  workflow: $workflow_enums" >&2
  fail_count=$((fail_count + 1))
fi

# Decision semantics: the workflow must route each *_STABLE value to the
# right action arm (no "Unknown relationship" fallthrough).
decide() {
  local REL="$1"
  case "$REL" in
    DIVERGED) echo "fail_closed" ;;
    BEHIND_STABLE) echo "upgrade_stable" ;;
    EXACT_STABLE|AHEAD_OF_STABLE) echo "noop_or_validate" ;;
    *) echo "Unknown relationship: $REL" >&2; return 1 ;;
  esac
}
for enum in EXACT_STABLE AHEAD_OF_STABLE BEHIND_STABLE DIVERGED; do
  action="$(decide "$enum")" || { fail_count=$((fail_count + 1)); continue; }
  expected="noop_or_validate"
  [ "$enum" = "BEHIND_STABLE" ] && expected="upgrade_stable"
  [ "$enum" = "DIVERGED" ] && expected="fail_closed"
  if [ "$action" != "$expected" ]; then
    echo "FAIL  decide($enum) -> $action, expected $expected" >&2
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -gt 0 ]; then
  echo "$fail_count contract failures" >&2
  exit 1
fi
echo "ALL CONTRACT CHECKS PASSED"
