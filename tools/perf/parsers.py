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
    "initStatus.begin",
    "updateStartTime",
    "session_snapshot",
    "preload",
    "connectCore",
    "ensureCoreReady",
    "initCore",
    "initCore.groups",
    "getProfile",
    "setupConfig",
    "applyProfile",
    "applyProfile.groups",
    "syncProviders",
    "startListener",
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


def jank_is_valid(summary: dict | None) -> bool:
    """Idle gfxinfo is only comparable when at least one frame was rendered."""
    if not summary:
        return False
    frames = summary.get("total_frames")
    if not isinstance(frames, int) or frames <= 0:
        return False
    parse_ok = summary.get("parse_ok")
    return parse_ok is not False


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


_PHASE4_LINE = re.compile(r"\[PHASE4\] mark=([A-Za-z0-9_.]+) elapsed_ms=(\d+)(.*)$")
_EXTRA = re.compile(r"([A-Za-z0-9_]+)=(\S+)")


def _coerce_extra(raw: str):
    if raw in {"true", "false"}:
        return raw == "true"
    if raw in {"null", "None"}:
        return None
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    if re.fullmatch(r"-?\d+\.\d+", raw):
        return float(raw)
    return raw


def parse_phase4_events(output: str) -> list[dict]:
    """All PHASE4 marks with extras. Navigation emits many rows per mark name."""
    events: list[dict] = []
    for line in output.splitlines():
        match = _PHASE4_LINE.search(line.rstrip("\r"))
        if not match:
            continue
        extras = {}
        for extra in _EXTRA.finditer(match.group(3) or ""):
            extras[extra.group(1)] = _coerce_extra(extra.group(2))
        events.append(
            {
                "mark": match.group(1),
                "elapsed_ms": int(match.group(2)),
                **extras,
            }
        )
    return events


def parse_display_refresh_hz(output: str) -> dict:
    """Best-effort refresh rate from dumpsys display / SurfaceFlinger."""
    candidates: list[float] = []
    for pattern in (
        r"renderFrameRate\s*=\s*([\d.]+)",
        r"refreshRate\s*=\s*([\d.]+)",
        r"fps=([\d.]+)",
        r"Refresh rate:\s*([\d.]+)",
    ):
        for match in re.finditer(pattern, output, re.I):
            try:
                value = float(match.group(1))
            except ValueError:
                continue
            if 20 <= value <= 240:
                candidates.append(value)
    hz = max(candidates) if candidates else None
    budget_ms = (1000.0 / hz) if hz else None
    return {
        "refresh_hz": hz,
        "budget_ms": budget_ms,
        "samples": sorted(set(round(v, 3) for v in candidates), reverse=True)[:8],
    }


def parse_phase4_session_fields(output: str) -> dict:
    """Last session_snapshot extras from PHASE4 logcat (session_id / state).

    Timing-only. Do not use missing log marks to judge session continuity.
    """
    session_id = None
    state = None
    for line in output.splitlines():
        if "mark=session_snapshot" not in line:
            continue
        sid = re.search(r"session_id=([0-9]+)", line)
        st = re.search(r"\bstate=([A-Za-z_]+)", line)
        if sid:
            session_id = int(sid.group(1))
        if st:
            state = st.group(1)
    return {"session_id": session_id, "state": state}


def parse_remote_session_presence(text: str) -> dict:
    """Parse `:remote` files/remote_session_presence.txt written by SessionPresence.encode."""
    session_id = None
    state = None
    pid = None
    started_at = None
    smart_paused = None
    for line in text.splitlines():
        stripped = line.strip()
        if "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        key = key.strip()
        value = value.strip()
        if key == "sessionId":
            try:
                session_id = int(value)
            except ValueError:
                session_id = None
        elif key == "state":
            state = value or None
        elif key == "pid":
            try:
                pid = int(value)
            except ValueError:
                pid = None
        elif key == "startedAt":
            try:
                started_at = int(value)
            except ValueError:
                started_at = None
        elif key == "smartPaused":
            lowered = value.lower()
            if lowered in {"true", "false"}:
                smart_paused = lowered == "true"
    parse_ok = isinstance(session_id, int) and bool(state)
    return {
        "session_id": session_id,
        "state": state,
        "pid": pid,
        "started_at": started_at,
        "smart_paused": smart_paused,
        "parse_ok": parse_ok,
    }


def assess_running_reattach_round(
    *,
    remote_before: int | None,
    kill: dict,
    ui_pid_before: int,
    remote_mid: int | None,
    remote_post: int | None,
    session_before: dict,
    session_post: dict,
    vpn_ready_before,
    vpn_ready_post,
) -> tuple[bool, str | None]:
    """Formal running-reattach gates. Any miss is not official data."""
    if kill.get("ok") is not True:
        return False, "kill_ui_keep_remote_failed"
    if kill.get("ui_pid_after") == ui_pid_before:
        return False, "old_ui_pid_still_alive"
    if remote_before is None:
        return False, "remote_pid_missing"
    if remote_mid != remote_before or remote_post != remote_before:
        return False, "remote_pid_changed"
    sid_before = session_before.get("session_id")
    sid_post = session_post.get("session_id")
    if not isinstance(sid_before, int) or sid_before <= 0:
        return False, "session_id_missing_before"
    if not isinstance(sid_post, int) or sid_post <= 0:
        return False, "session_id_missing_after"
    if sid_before != sid_post:
        return False, "session_id_changed"
    if session_before.get("state") != "RUNNING" or session_post.get("state") != "RUNNING":
        return False, "state_not_running"
    if vpn_ready_before is not True or vpn_ready_post is not True:
        return False, "vpn_ready_lost"
    return True, None


def assess_running_navigation_preconditions(*, vpn: dict, session: dict) -> tuple[bool, list[str]]:
    """RUNNING navigation may start only with a live VPN session. Never force-stop."""
    reasons: list[str] = []
    if vpn.get("vpn_service_running") is not True:
        reasons.append("vpn_service_not_running")
    if not vpn.get("tun_ifaces"):
        reasons.append("tun_missing")
    if vpn.get("remote_pid") is None:
        reasons.append("remote_not_running")
    if vpn.get("vpn_ready") is not True:
        reasons.append("vpn_ready_false")
    sid = session.get("session_id")
    if not isinstance(sid, int) or sid <= 0:
        reasons.append("session_id_invalid")
    if session.get("state") != "RUNNING":
        reasons.append("session_not_running")
    return not reasons, reasons


def assess_running_navigation_continuity(
    *,
    before_vpn: dict,
    after_vpn: dict,
    before_session: dict,
    after_session: dict,
) -> tuple[bool, list[str]]:
    """RUNNING navigation fails if the VPN session is restarted or reconfigured."""
    reasons: list[str] = []
    if before_vpn.get("remote_pid") != after_vpn.get("remote_pid"):
        reasons.append("remote_pid_changed")
    if before_session.get("session_id") != after_session.get("session_id"):
        reasons.append("session_id_changed")
    if after_vpn.get("vpn_ready") is not True:
        reasons.append("vpn_ready_lost")
    if after_session.get("state") != "RUNNING":
        reasons.append("session_not_running_after")
    before_tun = set(before_vpn.get("tun_ifaces") or [])
    after_tun = set(after_vpn.get("tun_ifaces") or [])
    if before_tun != after_tun:
        reasons.append("tun_interrupted")
    return not reasons, reasons


def ui_process_kill_commands(package: str, pid: int) -> list[str]:
    """Commands that may kill the Flutter UI pid. Never force-stop the package."""
    return [
        f"run-as {package} kill -9 {pid}",
        f"am kill {package}",
    ]


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


_PROC_TUN = re.compile(r"^\s*(tun\d+)\s*:")
_SYS_TUN = re.compile(r"^tun\d+$")


def parse_tun_from_proc_net_dev(output: str) -> list[str]:
    """Parse `tunN` names from `/proc/net/dev`. Does not match `tunl0`."""
    found: list[str] = []
    for line in output.splitlines():
        match = _PROC_TUN.match(line)
        if match:
            found.append(match.group(1))
    return found


def parse_tun_from_sys_class_net(output: str) -> list[str]:
    """Parse `tunN` names from `ls /sys/class/net`."""
    found: list[str] = []
    for line in output.split():
        name = line.strip()
        if _SYS_TUN.match(name):
            found.append(name)
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
