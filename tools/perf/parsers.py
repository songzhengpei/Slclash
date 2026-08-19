from __future__ import annotations

import re

_KV = re.compile(r"^\s*([A-Za-z][A-Za-z0-9 .]+?):\s*(-?\d+)\s*(?:ms)?\s*$")
_PHASE4 = re.compile(r"\[PHASE4\] mark=([A-Za-z0-9_.]+) elapsed_ms=(\d+)")


def parse_am_start_w(output: str) -> dict:
    """Parse `adb shell am start -W` output. Missing fields stay None."""
    result = {
        "this_time_ms": None,
        "wait_time_ms": None,
        "total_time_ms": None,
        "status": None,
        "activity": None,
        "raw": output,
    }
    for line in output.splitlines():
        stripped = line.strip()
        if stripped.startswith("Status:"):
            result["status"] = stripped.split(":", 1)[1].strip()
        elif stripped.startswith("Activity:"):
            result["activity"] = stripped.split(":", 1)[1].strip()
        else:
            match = _KV.match(stripped)
            if not match:
                continue
            key = match.group(1).strip().lower().replace(" ", "_")
            value = int(match.group(2))
            if key in {"this_time", "thistime"}:
                result["this_time_ms"] = value
            elif key in {"wait_time", "waittime"}:
                result["wait_time_ms"] = value
            elif key in {"total_time", "totaltime"}:
                result["total_time_ms"] = value
    return result


def parse_meminfo(output: str) -> dict:
    """Parse `dumpsys meminfo` App Summary / TOTAL PSS when present."""
    java_heap = None
    native_heap = None
    total_pss = None
    pid = None
    process = None
    header = re.search(r"MEMINFO in pid (\d+)\s*\[([^\]]+)\]", output)
    if header:
        pid = int(header.group(1))
        process = header.group(2)

    in_summary = False
    for line in output.splitlines():
        if "App Summary" in line:
            in_summary = True
            continue
        if in_summary:
            if "Java Heap:" in line:
                java_heap = _last_int(line)
            elif "Native Heap:" in line:
                native_heap = _last_int(line)
            elif re.search(r"\bTOTAL:\s+", line):
                total_pss = _first_int(line.split("TOTAL:", 1)[1])
                break

    if total_pss is None:
        match = re.search(r"TOTAL PSS:\s*(\d+)", output, re.I)
        if match:
            total_pss = int(match.group(1))
        else:
            for line in output.splitlines():
                if line.strip().startswith("TOTAL") and re.search(r"\d+", line):
                    total_pss = _first_int(line)
                    if total_pss is not None:
                        break

    return {
        "pid": pid,
        "process": process,
        "java_heap_kb": java_heap,
        "native_heap_kb": native_heap,
        "total_pss_kb": total_pss,
        "parse_ok": total_pss is not None,
    }


def parse_gfxinfo(output: str) -> dict:
    total = _named_int(output, r"Total frames rendered:\s*(\d+)")
    janky = _named_int(output, r"Janky frames:\s*(\d+)")
    janky_pct = None
    pct_match = re.search(r"Janky frames:\s*\d+\s*\(([\d.]+)%\)", output)
    if pct_match:
        janky_pct = float(pct_match.group(1))
    return {
        "total_frames": total,
        "janky_frames": janky,
        "janky_percent": janky_pct,
        "p50_ms": _named_int(output, r"50th percentile:\s*(\d+)"),
        "p90_ms": _named_int(output, r"90th percentile:\s*(\d+)"),
        "p95_ms": _named_int(output, r"95th percentile:\s*(\d+)"),
        "p99_ms": _named_int(output, r"99th percentile:\s*(\d+)"),
        "parse_ok": total is not None,
    }


def parse_phase4_logcat(output: str) -> dict[str, int]:
    marks: dict[str, int] = {}
    for match in _PHASE4.finditer(output):
        marks[match.group(1)] = int(match.group(2))
    return marks


def parse_pidof(output: str) -> int | None:
    text = output.strip().split()
    if not text:
        return None
    try:
        return int(text[0])
    except ValueError:
        return None


def _named_int(text: str, pattern: str) -> int | None:
    match = re.search(pattern, text)
    return int(match.group(1)) if match else None


def _first_int(text: str) -> int | None:
    match = re.search(r"(-?\d+)", text)
    return int(match.group(1)) if match else None


def _last_int(text: str) -> int | None:
    matches = re.findall(r"(-?\d+)", text)
    return int(matches[-1]) if matches else None
