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
    lines = [
        "# Phase 4 performance run",
        "",
        f"- timestamp: `{result.get('timestamp')}`",
        f"- git commit: `{result.get('commit')}`",
        f"- product baseline: `{result.get('phase4_product_baseline')}`",
        f"- device: `{env.get('model')}` / Android `{env.get('android_version')}`",
        f"- package: `{env.get('package')}` `{env.get('version_name')}`",
        f"- flutter pid: `{env.get('flutter_pid')}`",
        f"- remote pid: `{env.get('remote_pid')}`",
        f"- overall ok: **{result.get('ok')}**",
        "",
    ]
    if result.get("errors"):
        lines.append("## Errors")
        for err in result["errors"]:
            lines.append(f"- `{err.get('code')}`: {err.get('message')}")
        lines.append("")
    for name in ("cold_start", "memory", "jank", "vpn", "background"):
        block = result.get(name)
        if not block:
            continue
        lines.append(f"## {name}")
        lines.append("")
        lines.append(f"- ok: `{block.get('ok')}`")
        if block.get("unreliable"):
            lines.append(f"- unreliable: {', '.join(block['unreliable'])}")
        summary = block.get("summary") or block.get("stats")
        if isinstance(summary, dict):
            for key, value in summary.items():
                lines.append(f"- {key}: `{value}`")
        if block.get("notes"):
            for note in block["notes"]:
                lines.append(f"- note: {note}")
        lines.append("")
    compare = result.get("compare")
    if compare:
        lines.append("## baseline vs current")
        lines.append("")
        for key, delta in compare.items():
            lines.append(f"- {key}: `{delta}`")
        lines.append("")
    return "\n".join(lines) + "\n"


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def compare_results(baseline: dict, current: dict) -> dict:
    out: dict = {}
    base_cs = ((baseline.get("cold_start") or {}).get("stats") or {})
    cur_cs = ((current.get("cold_start") or {}).get("stats") or {})
    for metric in ("median", "p90", "min", "max"):
        b = base_cs.get(metric)
        c = cur_cs.get(metric)
        out[f"cold_start_{metric}_ms"] = _delta(b, c)
    base_mem = (baseline.get("memory") or {}).get("total_pss_kb")
    cur_mem = (current.get("memory") or {}).get("total_pss_kb")
    if isinstance(base_mem, dict):
        base_mem = base_mem.get("app")
    if isinstance(cur_mem, dict):
        cur_mem = cur_mem.get("app")
    out["memory_app_total_pss_kb"] = _delta(base_mem, cur_mem)
    return out


def _delta(baseline, current):
    if baseline is None or current is None:
        return {"baseline": baseline, "current": current, "delta": None}
    return {
        "baseline": baseline,
        "current": current,
        "delta": current - baseline,
    }
