from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from parsers import jank_is_valid


def write_reports(result: dict, out_dir: Path, latest_dir: Path | None) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "result.json"
    md_path = out_dir / "summary.md"
    json_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md_path.write_text(render_markdown(result), encoding="utf-8")
    if latest_dir is not None:
        latest_dir.mkdir(parents=True, exist_ok=True)
        (latest_dir / "latest.json").write_text(json_path.read_text(encoding="utf-8"), encoding="utf-8")
        (latest_dir / "latest.md").write_text(md_path.read_text(encoding="utf-8"), encoding="utf-8")
    return json_path, md_path


def render_markdown(result: dict) -> str:
    env = result.get("env") or {}
    build = result.get("build") or {}
    lines = [
        "# Phase 4 performance run",
        "",
        f"- timestamp: `{result.get('timestamp')}`",
        f"- git commit: `{result.get('commit')}`",
        f"- dirty: `{build.get('dirty', env.get('dirty'))}`",
        f"- worktree_fingerprint: `{build.get('worktree_fingerprint') or env.get('worktree_fingerprint')}`",
        f"- product baseline: `{result.get('phase4_product_baseline')}`",
        f"- device: `{result.get('device') or env.get('model')}` / Android `{env.get('android_version')}`",
        f"- package: `{build.get('package') or env.get('package')}` "
        f"`{build.get('version_name') or env.get('version_name')}` "
        f"(code `{build.get('version_code') or env.get('version_code')}`)",
        f"- build mode/role: `{build.get('mode') or env.get('build_mode')}` / "
        f"`{build.get('role') or env.get('build_role')}` "
        f"(formal_eligible=`{build.get('formal_eligible', env.get('formal_eligible'))}`)",
        f"- flutter pid: `{env.get('flutter_pid')}`",
        f"- remote pid: `{env.get('remote_pid')}`",
        f"- overall ok: **{result.get('ok')}**",
        "",
    ]
    if result.get("notes"):
        lines.append("## Notes")
        for note in result["notes"]:
            lines.append(f"- {note}")
        lines.append("")
    if result.get("errors"):
        lines.append("## Errors")
        for err in result["errors"]:
            lines.append(f"- `{err.get('code')}`: {err.get('message')}")
        lines.append("")

    lines.extend(_cold_start_section(result.get("cold_start")))
    lines.extend(_memory_section(result.get("memory")))
    lines.extend(_jank_section(result.get("jank")))
    lines.extend(_vpn_section(result.get("vpn")))
    lines.extend(_background_section(result.get("background")))
    lines.extend(_navigation_section(result.get("navigation")))

    compare = result.get("compare")
    if compare:
        lines.append("## baseline vs current")
        lines.append("")
        for key, delta in compare.items():
            lines.append(f"- {key}: `{_fmt(delta)}`")
        lines.append("")
    return "\n".join(lines) + "\n"


def _cold_start_section(block: dict | None) -> list[str]:
    if not block:
        return []
    lines = ["## cold_start", "", f"- ok: `{block.get('ok')}`"]
    stats = block.get("stats") or {}
    lines.append(
        f"- cold start TotalTime ms: median=`{stats.get('median')}` "
        f"p90=`{stats.get('p90')}` min=`{stats.get('min')}` max=`{stats.get('max')}` "
        f"(n=`{stats.get('count')}`)"
    )
    marks = (block.get("startup_marks") or {}).get("stats") or {}
    ff = marks.get("first_frame") or {}
    mr = marks.get("main_ready") or {}
    cr = marks.get("core_ready") or {}
    lines.append(
        f"- first_frame ms: median=`{ff.get('median')}` p90=`{ff.get('p90')}` "
        f"(n=`{ff.get('count')}`)"
    )
    lines.append(
        f"- main_ready ms: median=`{mr.get('median')}` p90=`{mr.get('p90')}` "
        f"(n=`{mr.get('count')}`)"
    )
    lines.append(
        f"- core_ready ms: median=`{cr.get('median')}` p90=`{cr.get('p90')}` "
        f"(n=`{cr.get('count')}`)"
    )
    outcomes = (block.get("startup_marks") or {}).get("core_outcome_counts") or {}
    if outcomes:
        lines.append(f"- core outcomes: `{outcomes}`")
    if block.get("unreliable"):
        lines.append(f"- unreliable: {', '.join(block['unreliable'])}")
    for note in block.get("notes") or []:
        lines.append(f"- note: {note}")
    lines.append("")
    return lines


def _memory_section(block: dict | None) -> list[str]:
    if not block:
        return []
    total = block.get("total_pss_kb") or {}
    lines = [
        "## memory",
        "",
        f"- ok: `{block.get('ok')}`",
        f"- app PSS kb: `{total.get('app')}`",
        f"- core/remote PSS kb: `{total.get('remote')}`",
        f"- combined PSS kb: `{total.get('combined')}`",
    ]
    app = block.get("app") or {}
    if app:
        lines.append(
            f"- app heaps kb: java=`{app.get('java_heap_kb')}` "
            f"native=`{app.get('native_heap_kb')}`"
        )
    if block.get("unreliable"):
        lines.append(f"- unreliable: {', '.join(block['unreliable'])}")
    for note in block.get("notes") or []:
        lines.append(f"- note: {note}")
    lines.append("")
    return lines


def _jank_section(block: dict | None) -> list[str]:
    if not block:
        return []
    summary = block.get("summary") or {}
    lines = [
        "## jank",
        "",
        f"- ok: `{block.get('ok')}`",
        f"- valid: `{block.get('valid')}`",
        f"- total frames: `{summary.get('total_frames')}`",
        f"- janky frames: `{summary.get('janky_frames')}` "
        f"({summary.get('janky_percent')}%)",
        f"- frame percentiles ms: p50=`{summary.get('p50_ms')}` "
        f"p90=`{summary.get('p90_ms')}` p95=`{summary.get('p95_ms')}` "
        f"p99=`{summary.get('p99_ms')}`",
    ]
    if block.get("unreliable"):
        lines.append(f"- unreliable: {', '.join(block['unreliable'])}")
    for note in block.get("notes") or []:
        lines.append(f"- note: {note}")
    lines.append("")
    return lines


def _vpn_section(block: dict | None) -> list[str]:
    if not block:
        return []
    lines = [
        "## vpn",
        "",
        f"- ok: `{block.get('ok')}`",
        f"- start_observable: `{block.get('start_observable')}`",
        f"- start_to_observable_ms: `{block.get('start_to_observable_ms')}`",
        f"- vpn_ready: `{block.get('vpn_ready')}`",
        f"- start_to_ready_ms: `{block.get('start_to_ready_ms')}`",
        f"- stop_success: `{block.get('stop_success')}`",
        f"- stop_to_cleared_ms: `{block.get('stop_to_cleared_ms')}`",
    ]
    if block.get("unreliable"):
        lines.append(f"- unreliable: {', '.join(block['unreliable'])}")
    for note in block.get("notes") or []:
        lines.append(f"- note: {note}")
    lines.append("")
    return lines


def _background_section(block: dict | None) -> list[str]:
    if not block:
        return []
    lines = [
        "## background",
        "",
        f"- ok: `{block.get('ok')}`",
        f"- vpn_active: `{block.get('vpn_active')}`",
        f"- vpn_inactive: `{block.get('vpn_inactive')}`",
    ]
    for label in ("foreground", "background"):
        snap = block.get(label) or {}
        mem = (snap.get("memory") or {}).get("total_pss_kb")
        lines.append(
            f"- {label}: focused=`{snap.get('app_focused')}` "
            f"flutter_pid=`{snap.get('flutter_pid')}` "
            f"remote_pid=`{snap.get('remote_pid')}` "
            f"pss_kb=`{mem}` "
            f"vpn_ready=`{(snap.get('vpn_state') or {}).get('vpn_ready')}`"
        )
    if block.get("unreliable"):
        lines.append(f"- unreliable: {', '.join(block['unreliable'])}")
    for note in block.get("notes") or []:
        lines.append(f"- note: {note}")
    lines.append("")
    return lines


def _fmt_stats(stats: dict | None, unit: str = "ms") -> str:
    stats = stats or {}
    return (
        f"median=`{stats.get('median')}` p90=`{stats.get('p90')}` "
        f"p99=`{stats.get('p99')}` min=`{stats.get('min')}` max=`{stats.get('max')}` "
        f"(n=`{stats.get('count')}` {unit})"
    )


def _navigation_section(block: dict | None) -> list[str]:
    if not block:
        return []
    display = block.get("display") or {}
    workloads = block.get("workloads") or {}
    a = workloads.get("A_dashboard_proxy") or {}
    b = workloads.get("B_round_robin") or {}
    c = workloads.get("C_first_vs_revisit") or {}
    d = workloads.get("D_same_tab_reselect") or {}
    e = workloads.get("E_page_counts") or {}
    lines = [
        "## navigation",
        "",
        f"- ok: `{block.get('ok')}`",
        f"- pages: `{block.get('pages')}`",
        f"- dumpsys refresh_hz: `{display.get('refresh_hz')}` budget_ms=`{display.get('budget_ms')}`",
        f"- dart refresh_hz: `{block.get('dart_refresh_hz')}` budget_ms=`{block.get('dart_budget_ms')}`",
        f"- A dashboard↔proxy total: {_fmt_stats((a.get('transitions') or {}).get('total_ms'))}",
        f"- A to_proxy: {_fmt_stats((a.get('to_proxy') or {}).get('total_ms'))}",
        f"- A to_dashboard: {_fmt_stats((a.get('to_dashboard') or {}).get('total_ms'))}",
        f"- A scroll_us: {_fmt_stats((a.get('transitions') or {}).get('scroll_us'), 'us')}",
        f"- B round-robin total: {_fmt_stats((b.get('transitions') or {}).get('total_ms'))}",
        f"- C first-mount total: {_fmt_stats((c.get('first') or {}).get('total_ms'))}",
        f"- C revisit total: {_fmt_stats((c.get('revisit') or {}).get('total_ms'))}",
        f"- D reselect total: {_fmt_stats((d.get('transitions') or {}).get('total_ms'))}",
        f"- D scroll_animation_complete_ms: {_fmt_stats((d.get('transitions') or {}).get('scroll_animation_complete_ms'))}",
        f"- E mounts: `{e.get('mounts')}`",
        f"- E builds: `{e.get('builds')}`",
    ]
    hotspots = block.get("hotspots") or []
    if hotspots:
        lines.append("- top transitions:")
        for row in hotspots[:8]:
            lines.append(
                f"  - {row.get('source')}→{row.get('target')} visit=`{row.get('visit')}` "
                f"total_ms=`{row.get('total_ms')}` worst_frame_ms=`{row.get('worst_frame_ms')}` "
                f"over_budget=`{row.get('over_budget')}` scroll_us=`{row.get('scroll_us')}` "
                f"keep_alive=`{row.get('keep_alive')}`"
            )
    if block.get("unreliable"):
        lines.append(f"- unreliable: {', '.join(block['unreliable'])}")
    for note in block.get("notes") or []:
        lines.append(f"- note: {note}")
    lines.append("")
    return lines


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def compare_results(baseline: dict, current: dict) -> dict:
    out: dict = {}
    base_cs = ((baseline.get("cold_start") or {}).get("stats") or {})
    cur_cs = ((current.get("cold_start") or {}).get("stats") or {})
    for metric in ("median", "p90", "min", "max"):
        out[f"cold_start_{metric}_ms"] = _delta(base_cs.get(metric), cur_cs.get(metric))

    base_marks = ((baseline.get("cold_start") or {}).get("startup_marks") or {}).get("stats") or {}
    cur_marks = ((current.get("cold_start") or {}).get("startup_marks") or {}).get("stats") or {}
    for mark in ("first_frame", "main_ready", "core_ready"):
        for metric in ("median", "p90"):
            out[f"{mark}_{metric}_ms"] = _delta(
                (base_marks.get(mark) or {}).get(metric),
                (cur_marks.get(mark) or {}).get(metric),
            )

    base_mem = (baseline.get("memory") or {}).get("total_pss_kb") or {}
    cur_mem = (current.get("memory") or {}).get("total_pss_kb") or {}
    if not isinstance(base_mem, dict):
        base_mem = {"app": base_mem}
    if not isinstance(cur_mem, dict):
        cur_mem = {"app": cur_mem}
    for key in ("app", "remote", "combined"):
        out[f"memory_{key}_pss_kb"] = _delta(base_mem.get(key), cur_mem.get(key))

    base_jank = (baseline.get("jank") or {}).get("summary") or {}
    cur_jank = (current.get("jank") or {}).get("summary") or {}
    if jank_is_valid(base_jank) and jank_is_valid(cur_jank):
        out["jank_janky_percent"] = _delta(
            base_jank.get("janky_percent"), cur_jank.get("janky_percent")
        )
        out["jank_p90_ms"] = _delta(base_jank.get("p90_ms"), cur_jank.get("p90_ms"))
    else:
        skipped = {
            "baseline": None,
            "current": None,
            "delta": None,
            "skipped": "jank_invalid_no_frames",
        }
        out["jank_janky_percent"] = dict(skipped)
        out["jank_p90_ms"] = dict(skipped)

    base_vpn = baseline.get("vpn") or {}
    cur_vpn = current.get("vpn") or {}
    out["vpn_start_to_observable_ms"] = _delta(
        base_vpn.get("start_to_observable_ms"), cur_vpn.get("start_to_observable_ms")
    )
    out["vpn_start_to_ready_ms"] = _delta(
        base_vpn.get("start_to_ready_ms"), cur_vpn.get("start_to_ready_ms")
    )
    out["vpn_stop_to_cleared_ms"] = _delta(
        base_vpn.get("stop_to_cleared_ms"), cur_vpn.get("stop_to_cleared_ms")
    )
    return out


def _delta(baseline, current):
    if baseline is None or current is None:
        return {"baseline": baseline, "current": current, "delta": None}
    return {
        "baseline": baseline,
        "current": current,
        "delta": current - baseline,
    }


def _fmt(value) -> str:
    if isinstance(value, dict):
        return (
            f"baseline={value.get('baseline')} current={value.get('current')} "
            f"delta={value.get('delta')}"
        )
    return str(value)


def render_baseline_markdown(result: dict) -> str:
    """Compact GitHub-reviewable baseline: aggregates only, no dumpsys raw."""
    env = result.get("env") or {}
    build = result.get("build") or {}
    cold = result.get("cold_start") or {}
    marks = (cold.get("startup_marks") or {}).get("stats") or {}
    mem = (result.get("memory") or {}).get("total_pss_kb") or {}
    jank = (result.get("jank") or {}).get("summary") or {}
    vpn = result.get("vpn") or {}
    bg = result.get("background") or {}

    unreliable: list[str] = []
    for name in ("cold_start", "memory", "jank", "vpn", "background"):
        block = result.get(name) or {}
        for item in block.get("unreliable") or []:
            unreliable.append(f"{name}: {item}")

    lines = [
        "# Phase 4A.0 baseline",
        "",
        "> Aggregated harness metrics only. Raw capture artifacts live under "
        "`.perf-captures/` (gitignored).",
        "",
        f"- captured_at: `{result.get('timestamp')}`",
        f"- harness_commit: `{result.get('commit')}`",
        f"- product_baseline_sha: `{result.get('phase4_product_baseline')}`",
        f"- device: `{result.get('device') or env.get('model')}`",
        f"- android: `{env.get('android_version')}` (sdk `{env.get('sdk')}`)",
        f"- build: `{build.get('package') or env.get('package')}` "
        f"{build.get('version_name') or env.get('version_name')} "
        f"(code {build.get('version_code') or env.get('version_code')})",
        f"- build_mode: `{build.get('mode') or env.get('build_mode')}`",
        f"- build_role: `{build.get('role') or env.get('build_role')}` "
        f"(debug=diagnostic_only, profile=profiling, release=production)",
        f"- formal_eligible: `{build.get('formal_eligible', env.get('formal_eligible'))}`",
        f"- git_head: `{build.get('git_head') or env.get('git_head') or result.get('commit')}`",
        f"- dirty: `{build.get('dirty', env.get('dirty'))}`",
        f"- worktree_fingerprint: `{build.get('worktree_fingerprint') or env.get('worktree_fingerprint')}`",
        "",
        "## Cold start",
        "",
        f"- TotalTime median/p90/min/max ms: "
        f"`{(cold.get('stats') or {}).get('median')}` / "
        f"`{(cold.get('stats') or {}).get('p90')}` / "
        f"`{(cold.get('stats') or {}).get('min')}` / "
        f"`{(cold.get('stats') or {}).get('max')}` "
        f"(n=`{(cold.get('stats') or {}).get('count')}`)",
        f"- first_frame median/p90 ms: "
        f"`{(marks.get('first_frame') or {}).get('median')}` / "
        f"`{(marks.get('first_frame') or {}).get('p90')}`",
        f"- main_ready median/p90 ms: "
        f"`{(marks.get('main_ready') or {}).get('median')}` / "
        f"`{(marks.get('main_ready') or {}).get('p90')}`",
        f"- core_ready median/p90 ms: "
        f"`{(marks.get('core_ready') or {}).get('median')}` / "
        f"`{(marks.get('core_ready') or {}).get('p90')}`",
        f"- core outcomes: `{(cold.get('startup_marks') or {}).get('core_outcome_counts')}`",
        "",
        "## Memory (PSS kb)",
        "",
        f"- app: `{mem.get('app')}`",
        f"- core/remote: `{mem.get('remote')}`",
        f"- combined: `{mem.get('combined')}`",
        "",
        "## Jank (idle)",
        "",
        f"- valid: `{(result.get('jank') or {}).get('valid')}`",
        f"- frames: `{jank.get('total_frames')}`",
        f"- janky: `{jank.get('janky_frames')}` ({jank.get('janky_percent')}%)",
        f"- p90 frame ms: `{jank.get('p90_ms')}`",
        "",
        "## VPN",
        "",
        f"- start_observable_ms: `{vpn.get('start_to_observable_ms')}`",
        f"- vpn_ready: `{vpn.get('vpn_ready')}`",
        f"- start_to_ready_ms: `{vpn.get('start_to_ready_ms')}`",
        f"- stop_success: `{vpn.get('stop_success')}`",
        f"- stop_to_cleared_ms: `{vpn.get('stop_to_cleared_ms')}`",
        "",
        "## Background",
        "",
        f"- vpn_active: `{bg.get('vpn_active')}`",
        f"- vpn_inactive: `{bg.get('vpn_inactive')}`",
        "",
        "## Unreliable",
        "",
    ]
    if unreliable:
        for item in unreliable:
            lines.append(f"- {item}")
    else:
        lines.append("- (none)")
    lines.append("")
    return "\n".join(lines)


def _short_median(stats: dict | None) -> str:
    stats = stats or {}
    return f"`{stats.get('median')}`"


def _pss_delta(p7: dict, nav: dict) -> str:
    true_kb = (p7.get("memory_pss_kb") or {}).get("total_pss_kb")
    false_kb = (nav.get("keep_false_memory") or {}).get("total_pss_kb")
    if not isinstance(true_kb, (int, float)) or not isinstance(false_kb, (int, float)):
        return "None"
    return str(true_kb - false_kb)


def _frame_lines(title: str, stats: dict | None) -> list[str]:
    stats = stats or {}
    return [
        f"### {title}",
        "",
        f"- n=`{stats.get('count')}`",
        f"- transition total_ms: {_fmt_stats(stats.get('total_ms'))}",
        f"- target_first_build_latency_ms (**not** build CPU): {_fmt_stats(stats.get('target_first_build_latency_ms'))}",
        f"- frame build p50/p90/p99 (median across transitions): "
        f"{_short_median(stats.get('build_p50_ms'))} / "
        f"{_short_median(stats.get('build_p90_ms'))} / "
        f"{_short_median(stats.get('build_p99_ms'))}",
        f"- frame raster p50/p90/p99: "
        f"{_short_median(stats.get('raster_p50_ms'))} / "
        f"{_short_median(stats.get('raster_p90_ms'))} / "
        f"{_short_median(stats.get('raster_p99_ms'))}",
        f"- frame totalSpan p50/p90/p99: "
        f"{_short_median(stats.get('total_span_p50_ms'))} / "
        f"{_short_median(stats.get('total_span_p90_ms'))} / "
        f"{_short_median(stats.get('total_span_p99_ms'))}",
        f"- worst_frame_ms: {_fmt_stats(stats.get('worst_frame_ms'))}",
        f"- over-budget frames: {_fmt_stats(stats.get('over_budget'), 'frames')}",
        f"- frame_count: {_fmt_stats(stats.get('frame_count'), 'frames')}",
        "",
    ]


def render_navigation_baseline_markdown(result: dict) -> str:
    """4B navigation FrameTiming baseline. Idle gfxinfo is not this baseline."""
    env = result.get("env") or {}
    build = result.get("build") or {}
    nav = result.get("navigation") or {}
    display = nav.get("display") or {}
    workloads = nav.get("workloads") or {}
    frames = nav.get("frame_timing") or {}
    a = workloads.get("A_dashboard_proxy") or {}
    b = workloads.get("B_round_robin") or {}
    c = workloads.get("C_first_vs_revisit") or {}
    d = workloads.get("D_same_tab_reselect") or {}
    e = workloads.get("E_page_counts") or {}
    p7 = workloads.get("P7_keep_experiment") or {}
    unreliable = list(nav.get("unreliable") or [])
    dirty = build.get("dirty", env.get("dirty"))
    formal = (
        bool(nav.get("ok"))
        and dirty is False
        and bool(build.get("formal_eligible", env.get("formal_eligible")))
    )
    title = (
        "# Phase 4B.0.1 navigation baseline (formal 4B.1 BEFORE)"
        if formal
        else "# Phase 4B.0.1 navigation baseline (UNRELIABLE — not formal BEFORE)"
    )
    lines = [
        title,
        "",
        "> Navigation/Page Mount FrameTiming only. Idle gfxinfo is not this baseline.",
        ">",
        "> `target_first_build_latency_ms` is elapsed time from `nav_begin` until the target page-root `build()` is **called**. It is not the CPU duration of that build.",
        "",
        f"- captured_at: `{result.get('timestamp')}`",
        f"- git_head: `{build.get('git_head') or env.get('git_head') or result.get('commit')}`",
        f"- dirty: `{dirty}`",
        f"- submodule_dirty: `{build.get('submodule_dirty', env.get('submodule_dirty'))}`",
        f"- worktree_fingerprint: `{build.get('worktree_fingerprint') or env.get('worktree_fingerprint')}`",
        f"- harness_commit: `{result.get('commit')}`",
        f"- product_baseline_sha: `{result.get('phase4_product_baseline')}`",
        f"- formal: `{formal}`",
        f"- device: `{result.get('device') or env.get('model')}`",
        f"- android: `{env.get('android_version')}` (sdk `{env.get('sdk')}`)",
        f"- build: `{build.get('package') or env.get('package')}` "
        f"{build.get('version_name') or env.get('version_name')} "
        f"(code {build.get('version_code') or env.get('version_code')})",
        f"- build_mode: `{build.get('mode') or env.get('build_mode')}`",
        f"- build_role: `{build.get('role') or env.get('build_role')}`",
        f"- formal_eligible: `{build.get('formal_eligible', env.get('formal_eligible'))}`",
        f"- dumpsys refresh_hz: `{display.get('refresh_hz')}` budget_ms=`{display.get('budget_ms')}`",
        f"- dart refresh_hz: `{nav.get('dart_refresh_hz')}` budget_ms=`{nav.get('dart_budget_ms')}`",
        f"- pages: `{nav.get('pages')}`",
        f"- ok: `{nav.get('ok')}`",
        "",
        "## Semantics",
        "",
        "- `total_ms`: nav_begin → nav_complete (tab switch includes `pageEnter` 280ms).",
        "- `target_first_build_latency_ms`: wait until target root `build()` is invoked. Do not treat 87–100ms as Dashboard CPU.",
        "- `build_*` / `raster_*` / `total_span_*`: Flutter FrameTiming percentiles for frames during the active transition.",
        "- D `scroll_command_ms`: DFS + `animateTo` issued. `scroll_animation_complete_ms`: awaited `animateTo` Future. Product UX is still fire-and-forget.",
        "",
        "## A. Dashboard ↔ Proxy",
        "",
        f"- pair: `{a.get('pair')}` round_trips=`{a.get('round_trips')}`",
        f"- total_ms: {_fmt_stats((a.get('transitions') or {}).get('total_ms'))}",
        f"- target_first_build_latency_ms: {_fmt_stats((a.get('transitions') or {}).get('target_first_build_latency_ms'))}",
        f"- worst_frame_ms: {_fmt_stats((a.get('transitions') or {}).get('worst_frame_ms'))}",
        f"- over_budget frames: {_fmt_stats((a.get('transitions') or {}).get('over_budget'), 'frames')}",
        f"- scroll_to_top us: {_fmt_stats((a.get('transitions') or {}).get('scroll_us'), 'us')}",
        f"- scroll elements: {_fmt_stats((a.get('transitions') or {}).get('scroll_elements'), 'elements')}",
        "",
        "## FrameTiming slices",
        "",
    ]
    lines.extend(_frame_lines("Dashboard → Proxy", frames.get("dashboard_to_proxy") or a.get("to_proxy")))
    lines.extend(_frame_lines("Proxy → Dashboard", frames.get("proxy_to_dashboard") or a.get("to_dashboard")))
    lines.extend(_frame_lines("Tools → Dashboard", frames.get("tools_to_dashboard") or b.get("tools_to_dashboard")))
    lines.extend(_frame_lines("Round-robin", frames.get("round_robin") or b.get("transitions")))
    lines.extend(
        [
            "## B. Bottom navigation round-robin",
            "",
            f"- pages: `{b.get('pages')}` cycles=`{b.get('cycles')}`",
            f"- total_ms: {_fmt_stats((b.get('transitions') or {}).get('total_ms'))}",
            f"- worst_frame_ms: {_fmt_stats((b.get('transitions') or {}).get('worst_frame_ms'))}",
            f"- over_budget frames: {_fmt_stats((b.get('transitions') or {}).get('over_budget'), 'frames')}",
            "",
            "## C. First mount vs revisit",
            "",
            f"- first total_ms: {_fmt_stats((c.get('first') or {}).get('total_ms'))}",
            f"- revisit total_ms: {_fmt_stats((c.get('revisit') or {}).get('total_ms'))}",
            f"- first target_first_build_latency_ms: {_fmt_stats((c.get('first') or {}).get('target_first_build_latency_ms'))}",
            f"- revisit target_first_build_latency_ms: {_fmt_stats((c.get('revisit') or {}).get('target_first_build_latency_ms'))}",
            "",
            "## D. Same-tab reselect / scroll-to-top settle",
            "",
            f"- page: `{d.get('page')}` repeats=`{d.get('repeats')}`",
            f"- total_ms: {_fmt_stats((d.get('transitions') or {}).get('total_ms'))}",
            f"- scroll_command_ms: {_fmt_stats((d.get('transitions') or {}).get('scroll_command_ms'))}",
            f"- scroll_animation_complete_ms: {_fmt_stats((d.get('transitions') or {}).get('scroll_animation_complete_ms'))}",
            f"- scroll_us (DFS): {_fmt_stats((d.get('transitions') or {}).get('scroll_us'), 'us')}",
            f"- note: {d.get('note')}",
            "",
            "## E. Page root mount / build counts (product keep:false)",
            "",
            f"- mounts: `{e.get('mounts')}`",
            f"- builds: `{e.get('builds')}`",
            f"- dashboard_hero_mounted: `{e.get('dashboard_hero_mounted')}`",
            f"- dashboard_sheen_repeating: `{e.get('dashboard_sheen_repeating')}`",
            f"- network_latency_timer: `{e.get('network_latency_timer')}`",
            "",
            "## P7 keep experiment (not a product change)",
            "",
            f"- ok: `{p7.get('ok')}`",
            f"- offscreen mounts: `{(p7.get('offscreen_on_proxies') or {}).get('mounts')}`",
            f"- offscreen dashboard_hero_mounted: `{(p7.get('offscreen_on_proxies') or {}).get('dashboard_hero_mounted')}`",
            f"- offscreen sheen_repeating: `{(p7.get('offscreen_on_proxies') or {}).get('dashboard_sheen_repeating')}`",
            f"- offscreen pulse_repeating: `{(p7.get('offscreen_on_proxies') or {}).get('dashboard_pulse_repeating')}`",
            f"- offscreen latency_timer: `{(p7.get('offscreen_on_proxies') or {}).get('network_latency_timer')}`",
            f"- offscreen latency_bar: `{(p7.get('offscreen_on_proxies') or {}).get('network_latency_bar')}`",
            f"- keep:true PSS kb: `{(p7.get('memory_pss_kb') or {}).get('total_pss_kb')}`",
            f"- keep:false PSS kb: `{(nav.get('keep_false_memory') or {}).get('total_pss_kb')}`",
            f"- PSS delta kb (true - false): `{_pss_delta(p7, nav)}`",
            f"- keep:true idle gfxinfo frames: `{(p7.get('idle_gfxinfo_on_proxies') or {}).get('total_frames')}`",
            f"- keep:false idle gfxinfo frames: `{(nav.get('keep_false_idle_gfx') or {}).get('total_frames')}`",
            "",
            "Product keep:false FrameTiming is the slices above (A/B). Experimental keep:true:",
            "",
        ]
    )
    lines.extend(_frame_lines("P7 keep:true Proxy → Dashboard", p7.get("to_dashboard")))
    lines.extend(_frame_lines("P7 keep:true Dashboard → Proxy", p7.get("to_proxy")))
    lines.extend(
        [
            "Hero/overview: offscreen `dashboard_hero_mounted` true with keep:true means the Hero subtree was not disposed. Product keep:false drops that subtree when leaving Dashboard.",
            "",
            "## Measured ranking (do not start 4B.1 here)",
            "",
            "- Do **not** use `target_first_build_latency_ms` as Dashboard CPU cost.",
            "- Use FrameTiming `build_*` vs `raster_*` to see whether jank is UI/layout or raster/compositing.",
            "- Dashboard remount is proven by mount counts. That does **not** by itself prove remount is the largest CPU source.",
            "- Element DFS remains ~0.4–0.8ms and is not a 4B.1 target.",
            "- P7 keep:true is an experiment only. Product `keep` is unchanged.",
            "",
            "## Top transitions",
            "",
        ]
    )
    for row in nav.get("hotspots") or []:
        lines.append(
            f"- {row.get('source')}→{row.get('target')} visit=`{row.get('visit')}` "
            f"keep_alive=`{row.get('keep_alive')}` total_ms=`{row.get('total_ms')}` "
            f"target_first_build_latency_ms=`{row.get('target_first_build_latency_ms')}` "
            f"build_p99_ms=`{row.get('build_p99_ms')}` raster_p99_ms=`{row.get('raster_p99_ms')}` "
            f"worst_frame_ms=`{row.get('worst_frame_ms')}` over_budget=`{row.get('over_budget')}` "
            f"scroll_us=`{row.get('scroll_us')}` elements=`{row.get('scroll_elements')}`"
        )
    if not nav.get("hotspots"):
        lines.append("- (none)")
    lines.extend(["", "## Unreliable", ""])
    if unreliable:
        for item in unreliable:
            lines.append(f"- {item}")
    else:
        lines.append("- (none)")
    lines.append("")
    return "\n".join(lines)
