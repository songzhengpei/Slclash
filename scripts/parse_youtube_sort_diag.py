#!/usr/bin/env python3
"""
parse_youtube_sort_diag.py

Parses YT_SORT_DIAG logcat lines and generates a diagnosis report.

Usage:
  python3 parse_youtube_sort_diag.py <logcat_file> <output_dir>
"""

import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime


def parse_logcat(path: str) -> dict[str, list[dict]]:
    """Parse YT_SORT_DIAG log lines grouped by phase."""
    phases: dict[str, list[dict]] = defaultdict(list)
    pattern = re.compile(r"YT_SORT_DIAG\|([^|]+)\|(.+)")
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = pattern.search(line)
            if not m:
                continue
            phase = m.group(1).strip()
            raw = m.group(2)
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                data = {"_parse_error": raw[:200]}
            phases[phase].append(data)
    return dict(phases)


# ── Judgment helpers ─────────────────────────────────────────────────────────

def check_key_mismatch(phases: dict) -> tuple[bool, str]:
    missed = 0
    details = []
    for md in phases.get("match_diagnosis", []):
        missed += md.get("missingResultCount", 0)
        for item in md.get("items", []):
            if not item.get("matched"):
                details.append({
                    "nodeId": item.get("nodeId"),
                    "nodeName": item.get("nodeName"),
                    "normalizedName": item.get("normalizedName"),
                    "invalidReasons": item.get("invalidReasons", []),
                })
    if missed > 0:
        evidence = (
            f"**missingResultCount={missed}** — {len(details)} unmatched candidates.\n"
        )
        for d in details[:10]:
            evidence += (
                f"  - `{d['nodeId']}` norm=`{d['normalizedName']}` "
                f"reasons={d['invalidReasons']}\n"
            )
        return True, evidence
    return False, ""


def check_invalid_sort_key(phases: dict) -> tuple[bool, str]:
    invalid = 0
    details = []
    for md in phases.get("match_diagnosis", []):
        invalid += md.get("invalidSortKeyCount", 0)
        for item in md.get("items", []):
            reasons = item.get("invalidReasons", [])
            if reasons:
                details.append({
                    "nodeId": item.get("nodeId"),
                    "reasons": reasons,
                })
    if invalid > 0:
        evidence = (
            f"**invalidSortKeyCount={invalid}** — "
            f"sort key anomalies in {len(details)} items.\n"
        )
        for d in details[:10]:
            evidence += f"  - `{d['nodeId']}` → {d['reasons']}\n"
        return True, evidence
    return False, ""


def check_stale_cache(phases: dict) -> tuple[bool, str]:
    for ctx in phases.get("context", []):
        sub_id = ctx.get("subscriptionId", "?")
        prof_ver = ctx.get("profileVersion", "?")
        for rl in phases.get("results_loaded", []):
            cache_hit = rl.get("cacheHit", False)
            if not cache_hit:
                continue
            issues = []
            cache_sub = rl.get("cacheSubscriptionId")
            cache_ver = rl.get("cacheProfileVersion", "")
            if cache_sub is not None and str(cache_sub) != str(sub_id):
                issues.append(f"cacheSubscriptionId mismatch: "
                              f"current={sub_id} vs cache={cache_sub}")
            if cache_ver and str(cache_ver) != str(prof_ver):
                issues.append(f"cacheProfileVersion mismatch: "
                              f"current={prof_ver} vs cache={cache_ver}")
            if issues:
                evidence = "**Cache mismatch detected**\n"
                for i in issues:
                    evidence += f"  - {i}\n"
                return True, evidence
    return False, ""


def check_sort_error(phases: dict) -> tuple[bool, str]:
    errors = phases.get("sort_error", [])
    if errors:
        evidence = f"**{len(errors)} sort error(s) caught**\n"
        for e in errors:
            evidence += (
                f"  - error={e.get('error')} "
                f"candidateCount={e.get('candidateCount')}\n"
            )
        return True, evidence

    # Check for missing after_sort
    for phase_name in phases:
        if phase_name == "before_sort" and "after_sort" not in phases:
            evidence = "**before_sort present but after_sort MISSING**\n"
            return True, evidence
    return False, ""


def check_ui_order(phases: dict) -> tuple[bool, str]:
    """Compare after_sort.order with display_order.displayOrder."""
    afters = phases.get("after_sort", [])
    displays = phases.get("display_order", [])
    if not afters or not displays:
        return False, ""

    last_after = afters[-1]
    last_display = displays[-1]

    after_order = [o.get("nodeId") for o in last_after.get("order", [])]
    display_order = [o.get("nodeId") for o in last_display.get("displayOrder", [])]

    if after_order and display_order and after_order != display_order:
        evidence = (
            "**after_sort.order differs from display_order** — "
            "UI may not be using sorted result.\n"
        )
        evidence += f"  after_sort:    {after_order[:5]}...\n"
        evidence += f"  display_order: {display_order[:5]}...\n"
        return True, evidence
    return False, ""


def check_async_completion(phases: dict) -> tuple[bool, str]:
    """Detect if UI shows completion order instead of sorted order."""
    befores = phases.get("before_sort", [])
    displays = phases.get("display_order", [])
    afters = phases.get("after_sort", [])

    if not befores or not displays:
        return False, ""

    before_order = [o.get("nodeId") for o in befores[-1].get("order", [])]
    display_order = [o.get("nodeId") for o in displays[-1].get("displayOrder", [])]

    # If display_order closely matches before_sort (unsorted) order
    # AND after_sort is missing or significantly different
    if before_order == display_order and not afters:
        evidence = (
            "**UI order matches pre-sort (completion) order, "
            "no after_sort found** — async completion leaked to UI.\n"
        )
        return True, evidence

    if before_order == display_order and afters:
        after_order = [o.get("nodeId") for o in afters[-1].get("order", [])]
        if after_order != display_order:
            evidence = (
                "**UI shows pre-sort order despite after_sort being different** — "
                "sorted result not applied to UI.\n"
            )
            return True, evidence

    # Check if after_sort is missing or later than display
    if displays and not afters:
        evidence = "**display_order present but after_sort MISSING** — no sort applied.\n"
        return True, evidence

    return False, ""


# ── Report generation ────────────────────────────────────────────────────────

def generate_report(phases: dict, output_dir: str, label: str) -> dict:
    verdicts = {}
    evidence_parts = []

    # A. Key mismatch
    found, ev = check_key_mismatch(phases)
    verdicts["candidate_result_key_mismatch"] = found
    if found:
        evidence_parts.append(("A. candidate_result_key_mismatch", ev))

    # B. Invalid sort key
    found, ev = check_invalid_sort_key(phases)
    verdicts["invalid_sort_key"] = found
    if found:
        evidence_parts.append(("B. invalid_sort_key", ev))

    # C. Stale / cross-subscription cache
    found, ev = check_stale_cache(phases)
    verdicts["stale_or_cross_subscription_cache"] = found
    if found:
        evidence_parts.append(("C. stale_or_cross_subscription_cache", ev))

    # D. Sort exception / aborted
    found, ev = check_sort_error(phases)
    verdicts["sort_exception_or_sort_aborted"] = found
    if found:
        evidence_parts.append(("D. sort_exception_or_sort_aborted", ev))

    # E. UI not using sorted result
    found, ev = check_ui_order(phases)
    verdicts["ui_display_order_not_using_sorted_result"] = found
    if found:
        evidence_parts.append(("E. ui_display_order_not_using_sorted_result", ev))

    # F. Async completion leaked to UI
    found, ev = check_async_completion(phases)
    verdicts["async_completion_order_leaked_to_ui"] = found
    if found:
        evidence_parts.append(("F. async_completion_order_leaked_to_ui", ev))

    # Pick the most likely root cause
    root_cause = "unknown"
    for key in [
        "candidate_result_key_mismatch",
        "stale_or_cross_subscription_cache",
        "invalid_sort_key",
        "sort_exception_or_sort_aborted",
        "ui_display_order_not_using_sorted_result",
        "async_completion_order_leaked_to_ui",
    ]:
        if verdicts.get(key):
            root_cause = key
            break

    # Build report
    lines = []
    lines.append(f"# Diagnosis Report — {label}")
    lines.append(f"Generated: {datetime.now().isoformat()}")
    lines.append("")
    lines.append(f"## Likely Root Cause")
    lines.append(f"**{root_cause}**")
    lines.append("")

    if evidence_parts:
        lines.append("## Evidence")
        for title, ev in evidence_parts:
            lines.append(f"### {title}")
            lines.append(ev)
            lines.append("")

    # Summary stats
    lines.append("## Summary Stats")
    for ctx in phases.get("context", []):
        lines.append(f"- subscriptionId: {ctx.get('subscriptionId')}")
        lines.append(f"- subscriptionName: {ctx.get('subscriptionName')}")
        lines.append(f"- profileVersion: {ctx.get('profileVersion')}")
        break
    for cl in phases.get("candidates_loaded", []):
        lines.append(f"- candidateCount: {cl.get('candidateCount')}")
    for rl in phases.get("results_loaded", []):
        lines.append(f"- resultCount: {rl.get('resultCount')}")
        lines.append(f"- cacheHit: {rl.get('cacheHit')}")
    for md in phases.get("match_diagnosis", []):
        lines.append(f"- matchedCount: {md.get('matchedCount')}")
        lines.append(f"- missingResultCount: {md.get('missingResultCount')}")
        lines.append(f"- invalidSortKeyCount: {md.get('invalidSortKeyCount')}")
    for af in phases.get("after_sort", []):
        lines.append(f"- after_sort.changed: {af.get('changed')}")
    lines.append("")

    # Phase presence
    lines.append("## Phase Presence")
    for p in ["context", "candidates_loaded", "results_loaded",
              "match_diagnosis", "before_sort", "after_sort",
              "sort_error", "display_order"]:
        count = len(phases.get(p, []))
        lines.append(f"- {p}: {count} entries")

    report_text = "\n".join(lines)

    # Write markdown
    report_path = os.path.join(output_dir, "diagnosis_report.md")
    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report_text)

    # Write JSON
    diag = {
        "label": label,
        "rootCause": root_cause,
        "verdicts": verdicts,
        "stats": {
            "candidateCount": next(
                (c.get("candidateCount") for c in phases.get("candidates_loaded", [])),
                None),
            "resultCount": next(
                (r.get("resultCount") for r in phases.get("results_loaded", [])),
                None),
            "cacheHit": next(
                (r.get("cacheHit") for r in phases.get("results_loaded", [])),
                None),
            "missingResultCount": next(
                (m.get("missingResultCount") for m in phases.get("match_diagnosis", [])),
                None),
            "invalidSortKeyCount": next(
                (m.get("invalidSortKeyCount") for m in phases.get("match_diagnosis", [])),
                None),
            "afterSortChanged": next(
                (a.get("changed") for a in phases.get("after_sort", [])),
                None),
        },
    }
    json_path = os.path.join(output_dir, "diagnosis.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(diag, f, indent=2, ensure_ascii=False)

    return diag


def compare_rounds(failing_diag: dict, normal_diag: dict, output_dir: str):
    """Generate final comparison report."""
    lines = []
    lines.append("# Final Comparison Report")
    lines.append(f"Generated: {datetime.now().isoformat()}")
    lines.append("")

    # Comparison table
    keys = [
        ("missingResultCount", "Missing Result Count"),
        ("invalidSortKeyCount", "Invalid Sort Key Count"),
        ("cacheHit", "Cache Hit"),
        ("candidateCount", "Candidate Count"),
        ("resultCount", "Result Count"),
        ("afterSortChanged", "After Sort Changed"),
    ]
    lines.append("| Metric | Failing | Normal |")
    lines.append("|---|---:|---:|")
    for k, label in keys:
        fv = failing_diag.get("stats", {}).get(k, "N/A")
        nv = normal_diag.get("stats", {}).get(k, "N/A")
        fv = "-" if fv is None else str(fv)
        nv = "-" if nv is None else str(nv)
        lines.append(f"| {label} | {fv} | {nv} |")

    lines.append("")
    lines.append("## Verdicts")
    for key in sorted(set(list(failing_diag.get("verdicts", {}).keys()) +
                          list(normal_diag.get("verdicts", {}).keys()))):
        fv = failing_diag.get("verdicts", {}).get(key, False)
        nv = normal_diag.get("verdicts", {}).get(key, False)
        lines.append(f"- **{key}**: failing={fv}, normal={nv}")

    lines.append("")
    lines.append("## Root Cause")
    lines.append(f"- Failing: **{failing_diag.get('rootCause')}**")
    lines.append(f"- Normal: **{normal_diag.get('rootCause')}**")

    report = "\n".join(lines)
    path = os.path.join(output_dir, "final_comparison_report.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write(report)
    print(f"  - {path}")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <logcat_file> [output_dir]")
        sys.exit(1)

    logcat_path = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "build/yt_sort_diag"

    if not os.path.isfile(logcat_path):
        print(f"Error: {logcat_path} not found")
        sys.exit(1)

    os.makedirs(output_dir, exist_ok=True)

    phases = parse_logcat(logcat_path)
    if not phases:
        print("No YT_SORT_DIAG entries found in logcat.")
        return

    diag = generate_report(phases, output_dir, "Single Run")
    print(f"  - {output_dir}/diagnosis_report.md")
    print(f"  - {output_dir}/diagnosis.json")
    print(f"\nRoot cause: {diag['rootCause']}")


if __name__ == "__main__":
    main()
