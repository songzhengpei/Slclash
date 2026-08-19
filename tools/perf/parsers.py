from __future__ import annotations

import re
from collections import defaultdict

_KV = re.compile(r"^\s*([A-Za-z][A-Za-z0-9 .]+?):\s*(-?\d+)\s*(?:ms)?\s*$")
_PHASE4 = re.compile(r"\[PHASE4\] mark=([A-Za-z0-9_.]+) elapsed_ms=(\d+)")
# `ip -o link show` lines look like: `12: tun0: <POINTOPOINT,...>`
_TUN_IFACE = re.compile(r"^\d+:\s*(tun\d+)\s*:")

TIMING_MARKS = (
    "first_frame",
    "main_ready",
    "core_ready",
    "globalState.attach",
    "proxy_group_snapshot_hydration",
    "setupAction.initStatus",
    "runApp",
)

CORE_OUTCOME_MARKS = (
    "core_ready",
    "core_skipped",
    "core_connect_failed",
    "core_init_failed",
)


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


def parse_tun_interfaces(ip_link_output: str) -> list[str]:
    """Return only real `tunN` interface names from `ip -o link show`."""
    found: list[str] = []
    for line in ip_link_output.splitlines():
        match = _TUN_IFACE.match(line.strip())
        if match:
            found.append(match.group(1))
    return found


def connectivity_has_vpn_network(connectivity_output: str) -> bool:
    """Detect an active VPN network block in dumpsys connectivity.

    Requires NETWORK-type VPN wording; a bare substring 'vpn' is not enough.
    """
    for line in connectivity_output.splitlines():
        lower = line.lower()
        if "networkagentinfo" in lower.replace(" ", "") and "vpn" in lower:
            return True
        if re.search(r"\btype:\s*vpn\b", lower):
            return True
        if re.search(r"\bnetworkinfo:\s*type:\s*vpn\b", lower):
            return True
        if "vpn {" in lower or "transport=vpn" in lower or "transports: vpn" in lower:
            return True
    return False


def assess_vpn_state(
    *,
    tun_ifaces: list[str],
    vpn_service_running: bool,
    remote_pid: int | None,
    connectivity_vpn: bool,
) -> dict:
    """Distinguish weak start_observable from confidently confirmed VPN ready.

    ready is True only when VpnService is running and a real tunN iface exists.
    remote_pid alone never proves VPN ready (CommonService can own :remote).
    """
    has_tun = bool(tun_ifaces)
    observable = bool(vpn_service_running or has_tun or remote_pid is not None)
    if vpn_service_running and has_tun:
        ready = True
        confidence = "confirmed"
    elif not observable:
        ready = False
        confidence = "confirmed_absent"
    else:
        # Partial signals only — do not claim ready.
        ready = None
        confidence = "unconfirmed"
    return {
        "tun_ifaces": list(tun_ifaces),
        "vpn_service_running": vpn_service_running,
        "remote_pid": remote_pid,
        "connectivity_vpn": connectivity_vpn,
        "start_observable": observable,
        "vpn_ready": ready,
        "confidence": confidence,
    }


def vpn_stop_cleared(state: dict) -> bool:
    """STOP success: VpnService gone and no tunN interface remains."""
    return (not state.get("vpn_service_running")) and not state.get("tun_ifaces")


def aggregate_startup_marks(measure_rows: list[dict]) -> dict:
    """Aggregate PHASE4 marks across formal measurement runs (not warmup)."""
    by_name: dict[str, list[float]] = defaultdict(list)
    outcome_counts = {name: 0 for name in CORE_OUTCOME_MARKS}
    runs_with_marks = 0
    for row in measure_rows:
        marks = row.get("phase4_marks") or {}
        if not marks:
            continue
        runs_with_marks += 1
        for name in TIMING_MARKS:
            if name in marks:
                by_name[name].append(float(marks[name]))
        outcome = None
        for name in CORE_OUTCOME_MARKS:
            if name in marks:
                outcome = name
                break
        if outcome:
            outcome_counts[outcome] += 1
    from stats import summarize  # local import avoids cycle at module load in tests

    return {
        "runs_with_marks": runs_with_marks,
        "core_outcome_counts": outcome_counts,
        "stats": {name: summarize(values) for name, values in sorted(by_name.items())},
    }


def _named_int(text: str, pattern: str) -> int | None:
    match = re.search(pattern, text)
    return int(match.group(1)) if match else None


def _first_int(text: str) -> int | None:
    match = re.search(r"(-?\d+)", text)
    return int(match.group(1)) if match else None


def _last_int(text: str) -> int | None:
    matches = re.findall(r"(-?\d+)", text)
    return int(matches[-1]) if matches else None
