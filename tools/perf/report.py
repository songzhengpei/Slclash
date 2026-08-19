from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path


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
    out["jank_janky_percent"] = _delta(base_jank.get("janky_percent"), cur_jank.get("janky_percent"))
    out["jank_p90_ms"] = _delta(base_jank.get("p90_ms"), cur_jank.get("p90_ms"))

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
