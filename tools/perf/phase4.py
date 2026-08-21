#!/usr/bin/env python3
"""Phase 4 performance harness (Python + ADB).

Usage:
    python tools/perf/phase4.py all
    python tools/perf/phase4.py env|cold-start|memory|jank|vpn|background
    python tools/perf/phase4.py running-reattach
    python tools/perf/phase4.py navigation
    python tools/perf/phase4.py ipc --ipc-session idle
    python tools/perf/phase4.py ipc --ipc-session running
    python tools/perf/phase4.py compare --baseline a.json --current b.json
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
sys.path.insert(0, str(ROOT))

from adbutil import Adb, HarnessError, resolve_adb, select_device  # noqa: E402
from build_mode import parse_package_debuggable, resolve_build_mode, default_package_for_mode  # noqa: E402
from navigation import (  # noqa: E402
    filter_transitions,
    group_nav_transitions,
    mount_hotspots,
    summarize_hotspots,
    summarize_nav,
)
from parsers import (  # noqa: E402
    aggregate_startup_marks,
    assess_running_reattach_round,
    assess_vpn_lifecycle_observations,
    assess_vpn_state,
    connectivity_has_vpn_network,
    filter_vpn_lifecycle_lines,
    jank_is_valid,
    parse_am_start_w,
    parse_display_refresh_hz,
    assess_refresh_rate_provenance,
    parse_gfxinfo,
    parse_meminfo,
    parse_phase4_events,
    parse_phase4_logcat,
    parse_proc_stat,
    parse_proc_status,
    parse_remote_session_presence,
    parse_pidof,
    parse_tun_from_proc_net_dev,
    parse_tun_from_sys_class_net,
    parse_tun_interfaces,
    ui_process_kill_commands,
    vpn_stop_cleared,
    assess_running_navigation_continuity,
    assess_running_navigation_preconditions,
    summarize_delay_events,
    summarize_select_events,
    summarize_ipc_events,
    summarize_power_events,
    summarize_vpn_lifecycle_events,
    latest_ipc_window_id,
)
from provenance import collect_git_provenance  # noqa: E402
from report import (  # noqa: E402
    compare_results,
    render_baseline_markdown,
    render_navigation_baseline_markdown,
    utc_now,
    write_reports,
)
from stats import summarize  # noqa: E402

PRODUCT_BASELINE = "b7e08b6ef84546e9b3d084a411c3a59e3e4df7c8"
PHASE4E_BASELINE = "1a591aa025e825eebfb0abb735ac62649acb1e8b"
DEFAULT_PACKAGE = "com.slclash.app.dev"
MAIN_ACTIVITY = "com.follow.clash.MainActivity"
TEMP_ACTIVITY = "com.follow.clash.TempActivity"
WARMUP_RUNS = 2
MEASURE_RUNS = 10
NAV_RECEIVER = "com.follow.clash.Phase4PerfReceiver"
NAV_ROUND_TRIPS = 10
NAV_CYCLES = 10
NAV_RESELECTS = 10
DEFAULT_MOBILE_PAGES = ["dashboard", "proxies", "profiles", "tools"]


def git_commit() -> str:
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=REPO,
            capture_output=True,
            text=True,
            timeout=10,
        )
        if proc.returncode == 0:
            return proc.stdout.strip()
    except OSError:
        pass
    return "unknown"


def fail_result(code: str, message: str, **extra) -> dict:
    result = {
        "ok": False,
        "timestamp": utc_now(),
        "commit": git_commit(),
        "phase4_product_baseline": PRODUCT_BASELINE,
        "errors": [{"code": code, "message": message}],
        "cold_start": None,
        "memory": None,
        "jank": None,
        "vpn": None,
        "background": None,
        "running_reattach": None,
        "navigation": None,
    }
    result.update(extra)
    return result


class Runner:
    def __init__(
        self,
        adb: Adb,
        package: str,
        *,
        build_mode: str | None = None,
    ) -> None:
        self.adb = adb
        self.package = package
        self.build_mode_override = build_mode

    def require_package(self) -> None:
        proc = self.adb.shell(f"pm path {self.package}")
        if proc.returncode != 0 or "package:" not in proc.stdout:
            raise HarnessError(
                "app_not_installed",
                f"package {self.package} is not installed",
            )

    def dumpsys_package(self) -> dict:
        proc = self.adb.shell(f"dumpsys package {self.package}")
        version_name = None
        version_code = None
        for line in proc.stdout.splitlines():
            stripped = line.strip()
            if stripped.startswith("versionName="):
                version_name = stripped.split("=", 1)[1]
            elif stripped.startswith("versionCode="):
                version_code = stripped.split("=", 1)[1].split()[0]
        return {
            "version_name": version_name,
            "version_code": version_code,
            "debuggable": parse_package_debuggable(proc.stdout),
            "raw": proc.stdout,
        }

    def pid_of(self, process: str) -> int | None:
        proc = self.adb.shell(f"pidof {process}")
        pid = parse_pidof(proc.stdout)
        if pid is None:
            proc = self.adb.shell(f"pidof -s {process}")
            pid = parse_pidof(proc.stdout)
        return pid

    def collect_env(self) -> dict:
        self.require_package()
        model = self.adb.shell("getprop ro.product.model").stdout.strip()
        android = self.adb.shell("getprop ro.build.version.release").stdout.strip()
        sdk = self.adb.shell("getprop ro.build.version.sdk").stdout.strip()
        pkg = self.dumpsys_package()
        build_info = resolve_build_mode(
            explicit=self.build_mode_override,
            debuggable=pkg["debuggable"],
        )
        self.build_info = build_info
        flutter_pid = self.pid_of(self.package)
        remote_pid = self.pid_of(f"{self.package}:remote")
        provenance = collect_git_provenance(REPO)
        return {
            "adb_serial": self.adb.serial,
            "model": model or None,
            "android_version": android or None,
            "sdk": int(sdk) if sdk.isdigit() else sdk,
            "package": self.package,
            "version_name": pkg["version_name"],
            "version_code": pkg["version_code"],
            "flutter_pid": flutter_pid,
            "remote_pid": remote_pid,
            "git_commit": provenance.get("git_head") or git_commit(),
            "git_head": provenance.get("git_head"),
            "dirty": provenance.get("dirty"),
            "submodule_dirty": provenance.get("submodule_dirty"),
            "worktree_fingerprint": provenance.get("worktree_fingerprint"),
            "build_mode": build_info["mode"],
            "build_role": build_info["role"],
            "formal_eligible": build_info["formal_eligible"],
            "debuggable": build_info["debuggable"],
            "build_mode_detection": build_info["detection"],
            "build_mode_notes": build_info["notes"],
        }

    def force_stop(self) -> None:
        self.adb.shell(f"am force-stop {self.package}", timeout=20)

    def start_main(self) -> dict:
        proc = self.adb.shell(
            f"am start -W -n {self.package}/{MAIN_ACTIVITY}",
            timeout=60,
        )
        parsed = parse_am_start_w(proc.stdout + "\n" + proc.stderr)
        parsed["returncode"] = proc.returncode
        if proc.returncode != 0:
            parsed["ok"] = False
            parsed["error"] = (proc.stderr or proc.stdout).strip()
        else:
            parsed["ok"] = parsed["total_time_ms"] is not None
        return parsed

    def logcat_phase4_marks(self) -> dict[str, int]:
        # Do not rely on `-s flutter` alone: some devices/OEM builds buffer
        # Flutter lines under different tags. Dump recent buffer and parse.
        proc = self.adb.run(["logcat", "-d", "-t", "2000"], timeout=30)
        return parse_phase4_logcat(proc.stdout + proc.stderr)

    def cold_start(self, warmup: int = WARMUP_RUNS, runs: int = MEASURE_RUNS) -> dict:
        self.require_package()
        warmup_samples = []
        measure_samples = []
        warmup_traces = []
        measure_traces = []
        notes = []
        for i in range(warmup + runs):
            self.force_stop()
            time.sleep(1.0)
            self.adb.run(["logcat", "-c"], timeout=15)
            sample = self.start_main()
            # Allow attach/initStatus marks to land before dump.
            time.sleep(2.5)
            marks = self.logcat_phase4_marks()
            row = {"index": i, "am_start": sample, "phase4_marks": marks or None}
            if not sample.get("ok"):
                notes.append(f"run {i} am start -W failed")
                if i < warmup:
                    warmup_traces.append(row)
                else:
                    measure_traces.append(row)
                continue
            value = sample.get("total_time_ms")
            if value is None:
                notes.append(f"run {i} missing TotalTime")
                if i < warmup:
                    warmup_traces.append(row)
                else:
                    measure_traces.append(row)
                continue
            if i < warmup:
                warmup_samples.append(value)
                warmup_traces.append(row)
            else:
                measure_samples.append(value)
                measure_traces.append(row)
        stats = summarize(measure_samples)
        startup_marks = aggregate_startup_marks(measure_traces)
        ok = len(measure_samples) == runs
        unreliable = []
        if startup_marks["runs_with_marks"] == 0:
            role = (getattr(self, "build_info", None) or {}).get("role")
            if role == "production":
                unreliable.append(
                    "phase4_logcat_marks_missing: release/production defaults omit "
                    "StartupTrace; use profile (or release + PHASE4_PERF) for marks"
                )
            else:
                unreliable.append(
                    "phase4_logcat_marks_missing: no [PHASE4] lines in logcat "
                    "(need profile build or --dart-define=PHASE4_PERF=true)"
                )
        elif startup_marks["runs_with_marks"] < len(measure_samples):
            unreliable.append(
                f"phase4_marks_partial: {startup_marks['runs_with_marks']}/{len(measure_samples)} runs"
            )
        return {
            "ok": ok,
            "warmup": warmup,
            "requested_runs": runs,
            "measured_runs": len(measure_samples),
            "stats": stats,
            "warmup_samples_ms": warmup_samples,
            "samples_ms": measure_samples,
            "startup_marks": startup_marks,
            "traces": {
                "warmup_tail": warmup_traces[-1:],
                "measure_tail": measure_traces[-1:],
            },
            "unreliable": unreliable,
            "notes": notes,
        }

    def memory(self) -> dict:
        self.require_package()
        flutter_pid = self.pid_of(self.package)
        remote_pid = self.pid_of(f"{self.package}:remote")
        notes = []
        if flutter_pid is None:
            notes.append("flutter pid missing; launching app once")
            self.start_main()
            time.sleep(2)
            flutter_pid = self.pid_of(self.package)
            remote_pid = self.pid_of(f"{self.package}:remote")
        if flutter_pid is None:
            raise HarnessError("pid_missing", f"Flutter process pid not found for {self.package}")
        app_raw = self.adb.shell(f"dumpsys meminfo {self.package}").stdout
        app = parse_meminfo(app_raw)
        remote = None
        if remote_pid is None:
            notes.append("remote/core process not running (VPN/core likely idle)")
        else:
            remote_raw = self.adb.shell(f"dumpsys meminfo {self.package}:remote").stdout
            remote = parse_meminfo(remote_raw)
        total = app.get("total_pss_kb")
        if remote and remote.get("total_pss_kb") is not None and total is not None:
            combined = total + remote["total_pss_kb"]
        else:
            combined = total
        return {
            "ok": bool(app.get("parse_ok")),
            "flutter_pid": flutter_pid,
            "remote_pid": remote_pid,
            "app": app,
            "remote": remote,
            "total_pss_kb": {
                "app": app.get("total_pss_kb"),
                "remote": None if remote is None else remote.get("total_pss_kb"),
                "combined": combined,
            },
            "notes": notes,
            "unreliable": []
            if app.get("parse_ok")
            else ["meminfo_parse_incomplete"],
        }

    def jank(self, settle_seconds: float = 3.0) -> dict:
        self.require_package()
        self.start_main()
        reset = self.adb.shell(f"dumpsys gfxinfo {self.package} reset")
        if reset.returncode != 0:
            return {
                "ok": False,
                "notes": ["gfxinfo reset failed"],
                "unreliable": ["gfxinfo_unavailable"],
                "raw_error": (reset.stderr or reset.stdout).strip(),
            }
        time.sleep(settle_seconds)
        dumped = self.adb.shell(f"dumpsys gfxinfo {self.package}")
        parsed = parse_gfxinfo(dumped.stdout)
        notes = [
            "No UI automation: this is idle/home-screen framestats after launch, not a scroll scenario.",
        ]
        unreliable = ["idle_only_no_ui_automation"]
        if not parsed.get("parse_ok"):
            unreliable.append("gfxinfo_parse_incomplete")
        valid = jank_is_valid(parsed)
        if not valid:
            unreliable.append("jank_invalid_no_frames")
            notes.append(
                "total_frames <= 0: idle jank is invalid and excluded from formal compare."
            )
        return {
            "ok": bool(parsed.get("parse_ok")),
            "valid": valid,
            "summary": parsed,
            "notes": notes,
            "unreliable": unreliable,
        }

    def _tun_ifaces(self) -> list[str]:
        tun = parse_tun_interfaces(self.adb.shell("ip -o link show").stdout)
        if tun:
            return tun
        tun = parse_tun_from_proc_net_dev(self.adb.shell("cat /proc/net/dev").stdout)
        if tun:
            return tun
        return parse_tun_from_sys_class_net(self.adb.shell("ls /sys/class/net").stdout)

    def _vpn_status(self) -> dict:
        tun_ifaces = self._tun_ifaces()
        services = self.adb.shell(f"dumpsys activity services {self.package}").stdout
        vpn_service = "com.follow.clash.service.VpnService" in services
        remote_pid = self.pid_of(f"{self.package}:remote")
        connectivity_vpn = connectivity_has_vpn_network(
            self.adb.shell("dumpsys connectivity").stdout
        )
        return assess_vpn_state(
            tun_ifaces=tun_ifaces,
            vpn_service_running=vpn_service,
            remote_pid=remote_pid,
            connectivity_vpn=connectivity_vpn,
        )

    def _network_probe(self) -> dict:
        proc = self.adb.shell("ping -c 1 -W 3 1.1.1.1", timeout=10)
        ok = proc.returncode == 0
        return {
            "ok": ok,
            "command": "ping -c 1 -W 3 1.1.1.1",
            "returncode": proc.returncode,
            "note": "Device connectivity only; does not prove traffic is in the VPN tunnel.",
        }

    def _lifecycle_logcat(self) -> str:
        proc = self.adb.run(["logcat", "-d", "-t", "12000"], timeout=30)
        return proc.stdout + proc.stderr

    def _lifecycle_snapshot(self, label: str) -> dict:
        return {
            "label": label,
            "host_monotonic_ms": int(time.monotonic() * 1000),
            "flutter_pid": self.pid_of(self.package),
            "remote_pid": self.pid_of(f"{self.package}:remote"),
            "session": self.read_session_presence(),
            "vpn": self._vpn_status(),
        }

    def _quick_action(self, action: str) -> dict:
        command = (
            f"am start -W -n {self.package}/{TEMP_ACTIVITY} "
            f"-a {self.package}.action.{action.upper()}"
        )
        proc = self.adb.shell(command, timeout=30)
        return {
            "kind": "temp_activity",
            "action": action,
            "command": command,
            "returncode": proc.returncode,
            "am_start": parse_am_start_w(proc.stdout + "\n" + proc.stderr),
        }

    def _flutter_action(self, action: str) -> dict:
        self.nav_broadcast("vpn_action", {"action": action})
        return {"kind": "flutter_ui", "action": action, "returncode": 0}

    def _wait_lifecycle(
        self,
        label: str,
        expected_state: str,
        tun_present: bool,
        timeout_s: float,
    ) -> tuple[bool, int | None, list[dict]]:
        started = time.monotonic()
        observations: list[dict] = []
        while time.monotonic() - started < timeout_s:
            row = self._lifecycle_snapshot(label)
            observations.append(row)
            session = row.get("session") or {}
            vpn = row.get("vpn") or {}
            state = session.get("state")
            has_tun = bool(vpn.get("tun_ifaces"))
            if expected_state == "STOPPED":
                matched = session.get("parse_ok") is not True and vpn_stop_cleared(vpn)
            else:
                matched = state == expected_state and has_tun == tun_present
            if matched:
                return True, int((time.monotonic() - started) * 1000), observations
            time.sleep(0.25)
        return False, None, observations

    def _vpn_window(
        self,
        name: str,
        action,
        expected_state: str,
        tun_present: bool,
        timeout_s: float,
    ) -> dict:
        before = self._lifecycle_snapshot(f"{name}_before")
        self.adb.run(["logcat", "-c"], timeout=15)
        started = time.monotonic()
        dispatch = action()
        converged, elapsed_ms, observations = self._wait_lifecycle(
            name, expected_state, tun_present, timeout_s
        )
        if self.pid_of(self.package) is not None:
            self.nav_broadcast("vpn_dump")
            if before.get("flutter_pid") is None:
                time.sleep(8.0)
                self.nav_broadcast("vpn_dump")
            time.sleep(0.3)
        after = self._lifecycle_snapshot(f"{name}_after")
        raw_logcat = self._lifecycle_logcat()
        events = parse_phase4_events(raw_logcat)
        summary = summarize_vpn_lifecycle_events(events)
        return {
            "name": name,
            "ok": converged,
            "expected_state": expected_state,
            "expected_tun_present": tun_present,
            "elapsed_ms": elapsed_ms,
            "dispatch_elapsed_ms": int((time.monotonic() - started) * 1000),
            "dispatch": dispatch,
            "before": before,
            "observations": observations,
            "after": after,
            "lifecycle": summary,
            "observation_flags": assess_vpn_lifecycle_observations(observations + [after]),
            "raw_phase4_lines": filter_vpn_lifecycle_lines(raw_logcat),
        }

    def vpn(self, timeout_s: float = 25.0, scenario: str = "all") -> dict:
        """Phase 4E structured lifecycle baseline. Mutates only the profile test app."""
        self.require_package()
        scenario = (scenario or "all").lower()
        allowed = {"all", "start-stop", "reattach", "smart", "quick"}
        if scenario not in allowed:
            raise HarnessError("bad_vpn_scenario", f"unknown vpn scenario {scenario}")
        notes = [
            "Raw observations and ordered PHASE4 lines are retained; flags are not automatic bug classifications.",
            "TUN truth is device-observed tunN plus VpnService; SessionPresence is separate process/session truth.",
            "Only the profile/debug package is force-stopped for the initial known STOPPED state.",
        ]
        windows: list[dict] = []
        self.force_stop()
        time.sleep(0.8)
        initial = self._lifecycle_snapshot("initial_stopped")

        self.start_main()
        time.sleep(3.0)
        self.nav_broadcast("vpn_dump")
        time.sleep(0.3)

        if scenario in {"all", "start-stop"}:
            windows.append(
                self._vpn_window(
                    "flutter_start_1",
                    lambda: self._flutter_action("start"),
                    "RUNNING",
                    True,
                    timeout_s,
                )
            )
            windows.append(
                self._vpn_window(
                    "flutter_stop_1",
                    lambda: self._flutter_action("stop"),
                    "STOPPED",
                    False,
                    timeout_s,
                )
            )
            windows.append(
                self._vpn_window(
                    "flutter_start_2",
                    lambda: self._flutter_action("start"),
                    "RUNNING",
                    True,
                    timeout_s,
                )
            )

        if scenario in {"all", "reattach"}:
            if self._vpn_status().get("vpn_ready") is not True:
                windows.append(
                    self._vpn_window(
                        "reattach_prerequisite_start",
                        lambda: self._flutter_action("start"),
                        "RUNNING",
                        True,
                        timeout_s,
                    )
                )
            before = self._lifecycle_snapshot("reattach_before")
            self.adb.run(["logcat", "-c"], timeout=15)
            flutter_pid = before.get("flutter_pid")
            killed = (
                self.kill_ui_keep_remote(flutter_pid)
                if isinstance(flutter_pid, int)
                else {"ok": False, "reason": "ui_pid_missing"}
            )
            middle = self._lifecycle_snapshot("reattach_middle")
            launch = self.start_main()
            time.sleep(8.0)
            self.nav_broadcast("vpn_dump")
            time.sleep(0.3)
            after = self._lifecycle_snapshot("reattach_after")
            events = parse_phase4_events(self._lifecycle_logcat())
            round_ok, reason = assess_running_reattach_round(
                remote_before=before.get("remote_pid"),
                kill=killed,
                ui_pid_before=flutter_pid if isinstance(flutter_pid, int) else 0,
                remote_mid=middle.get("remote_pid"),
                remote_post=after.get("remote_pid"),
                session_before=before.get("session") or {},
                session_post=after.get("session") or {},
                vpn_ready_before=(before.get("vpn") or {}).get("vpn_ready"),
                vpn_ready_post=(after.get("vpn") or {}).get("vpn_ready"),
            )
            windows.append(
                {
                    "name": "running_reattach",
                    "ok": round_ok,
                    "reason": reason,
                    "before": before,
                    "kill": killed,
                    "middle": middle,
                    "launch": launch,
                    "after": after,
                    "lifecycle": summarize_vpn_lifecycle_events(events),
                    "raw_phase4_lines": filter_vpn_lifecycle_lines(
                        self._lifecycle_logcat()
                    ),
                }
            )

        if scenario in {"all", "smart"}:
            if self._vpn_status().get("vpn_ready") is not True:
                windows.append(
                    self._vpn_window(
                        "smart_prerequisite_start",
                        lambda: self._flutter_action("start"),
                        "RUNNING",
                        True,
                        timeout_s,
                    )
                )
            windows.append(
                self._vpn_window(
                    "smart_stop",
                    lambda: self._quick_action("smart_stop"),
                    "PAUSED",
                    False,
                    timeout_s,
                )
            )
            paused_before = self._lifecycle_snapshot("paused_reattach_before")
            paused_pid = paused_before.get("flutter_pid")
            paused_kill = (
                self.kill_ui_keep_remote(paused_pid)
                if isinstance(paused_pid, int)
                else {"ok": False, "reason": "ui_pid_missing"}
            )
            paused_middle = self._lifecycle_snapshot("paused_reattach_middle")
            self.adb.run(["logcat", "-c"], timeout=15)
            paused_launch = self.start_main()
            time.sleep(8.0)
            self.nav_broadcast("vpn_dump")
            time.sleep(0.3)
            paused_after = self._lifecycle_snapshot("paused_reattach_after")
            paused_events = parse_phase4_events(self._lifecycle_logcat())
            paused_ok = (
                (paused_after.get("session") or {}).get("state") == "PAUSED"
                and paused_after.get("remote_pid") == paused_before.get("remote_pid")
                and (paused_after.get("session") or {}).get("session_id")
                == (paused_before.get("session") or {}).get("session_id")
                and not (paused_after.get("vpn") or {}).get("tun_ifaces")
            )
            windows.append(
                {
                    "name": "paused_reattach",
                    "ok": paused_ok,
                    "before": paused_before,
                    "kill": paused_kill,
                    "middle": paused_middle,
                    "launch": paused_launch,
                    "after": paused_after,
                    "lifecycle": summarize_vpn_lifecycle_events(paused_events),
                    "raw_phase4_lines": filter_vpn_lifecycle_lines(
                        self._lifecycle_logcat()
                    ),
                }
            )
            windows.append(
                self._vpn_window(
                    "paused_toggle_resume",
                    lambda: self._quick_action("toggle"),
                    "RUNNING",
                    True,
                    timeout_s,
                )
            )
            windows.append(
                self._vpn_window(
                    "smart_stop_before_explicit_resume",
                    lambda: self._quick_action("smart_stop"),
                    "PAUSED",
                    False,
                    timeout_s,
                )
            )
            windows.append(
                self._vpn_window(
                    "smart_resume",
                    lambda: self._quick_action("smart_resume"),
                    "RUNNING",
                    True,
                    timeout_s,
                )
            )
            windows.append(
                self._vpn_window(
                    "automatic_smart_stop",
                    lambda: self.nav_broadcast(
                        "smart_auto_stop_config",
                        {"enabled": "true", "network": "0.0.0.0/0"},
                    ),
                    "PAUSED",
                    False,
                    timeout_s,
                )
            )
            windows.append(
                self._vpn_window(
                    "paused_quick_stop",
                    lambda: self._quick_action("stop"),
                    "STOPPED",
                    False,
                    timeout_s,
                )
            )
            self.nav_broadcast(
                "smart_auto_stop_config", {"enabled": "false"}
            )

        if scenario in {"all", "quick"}:
            windows.append(
                self._vpn_window(
                    "quick_stop",
                    lambda: self._quick_action("stop"),
                    "STOPPED",
                    False,
                    timeout_s,
                )
            )
            quick_ui_pid = self.pid_of(self.package)
            quick_kill = (
                self.kill_ui_keep_remote(quick_ui_pid)
                if isinstance(quick_ui_pid, int)
                else {"ok": True, "reason": "ui_already_absent"}
            )
            windows.append(
                self._vpn_window(
                    "quick_start_without_flutter",
                    lambda: self._quick_action("start"),
                    "RUNNING",
                    True,
                    timeout_s,
                )
            )
            windows.append(
                self._vpn_window(
                    "quick_final_stop",
                    lambda: self._quick_action("stop"),
                    "STOPPED",
                    False,
                    timeout_s,
                )
            )

        ok = bool(windows) and all(row.get("ok") is True for row in windows)
        return {
            "ok": ok,
            "scenario": scenario,
            "initial": initial,
            "quick_ui_kill": quick_kill if scenario in {"all", "quick"} else None,
            "windows": windows,
            "network_probe": self._network_probe()
            if any((row.get("after") or {}).get("vpn", {}).get("vpn_ready") is True for row in windows)
            else None,
            "unreliable": [] if ok else ["one_or_more_lifecycle_windows_failed"],
            "notes": notes,
        }

    def background(self, wait_s: float = 4.0) -> dict:
        self.require_package()
        self.start_main()
        time.sleep(1.0)
        fg = self._snapshot_process("foreground")
        self.adb.shell("input keyevent KEYCODE_HOME")
        time.sleep(wait_s)
        bg = self._snapshot_process("background")
        vpn_active = (fg.get("vpn_state") or {}).get("vpn_ready") is True or (
            (bg.get("vpn_state") or {}).get("vpn_ready") is True
        )
        vpn_inactive = (fg.get("vpn_state") or {}).get("vpn_ready") is False and (
            (bg.get("vpn_state") or {}).get("vpn_ready") is False
        )
        notes = [
            "Battery mAh is not inferred. These are process CPU/PSS/focus observations only.",
            "UI stats timer is cancelled on pause in Dart; ADB cannot see the Dart Timer directly.",
            "vpn_active/inactive use the same VpnService+tunN ready rule as the VPN scenario.",
        ]
        unreliable = [
            "cpu_from_dumpsys_cpuinfo_is_coarse",
            "no_battery_mah",
            "ui_timer_not_directly_observable",
        ]
        if (fg.get("vpn_state") or {}).get("vpn_ready") is None or (
            (bg.get("vpn_state") or {}).get("vpn_ready") is None
        ):
            unreliable.append("background_vpn_state_unconfirmed")
        return {
            "ok": fg.get("flutter_pid") is not None,
            "vpn_active": vpn_active,
            "vpn_inactive": vpn_inactive,
            "foreground": fg,
            "background": bg,
            "notes": notes,
            "unreliable": unreliable,
        }

    def _power_logcat_dump(self) -> str:
        proc = self.adb.run(["logcat", "-d"], timeout=30)
        return proc.stdout + proc.stderr

    def _power_process_snapshot(self) -> dict:
        rows = {}
        for role, process in (("main", self.package), ("remote", f"{self.package}:remote")):
            pid = self.pid_of(process)
            if pid is None:
                rows[role] = {"pid": None, "stat": {"available": False}, "status": {"available": False}, "memory": None}
                continue
            stat = parse_proc_stat(self.adb.shell(f"cat /proc/{pid}/stat").stdout)
            status = parse_proc_status(self.adb.shell(f"cat /proc/{pid}/status").stdout)
            memory = parse_meminfo(self.adb.shell(f"dumpsys meminfo {pid}").stdout)
            rows[role] = {"pid": pid, "stat": stat, "status": status, "memory": memory}
        return rows

    @staticmethod
    def _power_process_delta(before: dict, after: dict, duration_s: float, clock_ticks: int) -> dict:
        result = {}
        for role in ("main", "remote"):
            first = before.get(role) or {}
            last = after.get(role) or {}
            same_pid = first.get("pid") is not None and first.get("pid") == last.get("pid")
            stat_a, stat_b = first.get("stat") or {}, last.get("stat") or {}
            status_a, status_b = first.get("status") or {}, last.get("status") or {}
            cpu_ms = None
            if same_pid and stat_a.get("available") and stat_b.get("available"):
                ticks = (stat_b.get("utime_ticks", 0) + stat_b.get("stime_ticks", 0)) - (
                    stat_a.get("utime_ticks", 0) + stat_a.get("stime_ticks", 0)
                )
                cpu_ms = round(ticks * 1000.0 / max(clock_ticks, 1), 2)
            def delta_field(name: str):
                a, b = status_a.get(name), status_b.get(name)
                return b - a if same_pid and isinstance(a, int) and isinstance(b, int) else None
            minutes = duration_s / 60.0 if duration_s > 0 else 0.0
            ctxt = delta_field("voluntary_ctxt_switches")
            nonvol = delta_field("nonvoluntary_ctxt_switches")
            result[role] = {
                "pid_before": first.get("pid"),
                "pid_after": last.get("pid"),
                "pid_stable": same_pid,
                "cpu_ms": cpu_ms,
                "cpu_ms_per_min": round(cpu_ms / minutes, 2) if cpu_ms is not None and minutes else None,
                "voluntary_context_switches": ctxt,
                "nonvoluntary_context_switches": nonvol,
                "context_switches_per_min": round((ctxt + nonvol) / minutes, 2)
                if ctxt is not None and nonvol is not None and minutes else None,
                "threads_before": status_a.get("threads"),
                "threads_after": status_b.get("threads"),
                "rss_kb_before": status_a.get("rss_kb"),
                "rss_kb_after": status_b.get("rss_kb"),
                "memory_before": first.get("memory"),
                "memory_after": last.get("memory"),
            }
        return result

    def _power_window(self, label: str, duration_s: float, setup=None) -> dict:
        self.adb.run(["logcat", "-c"], timeout=20)
        if setup is not None:
            setup()
            time.sleep(2.0)
        transition_log = self._power_logcat_dump()
        self.adb.run(["logcat", "-c"], timeout=20)
        before = self._power_process_snapshot()
        vpn_before = self._vpn_status()
        session_before = self.read_session_presence()
        started = time.monotonic()
        time.sleep(duration_s)
        actual = time.monotonic() - started
        after = self._power_process_snapshot()
        vpn_after = self._vpn_status()
        session_after = self.read_session_presence()
        transition_events = parse_phase4_events(transition_log)
        measurement_events = parse_phase4_events(self._power_logcat_dump())
        ticks_raw = self.adb.shell("getconf CLK_TCK").stdout.strip()
        clock_ticks = int(ticks_raw) if ticks_raw.isdigit() else 100
        return {
            "window": label,
            "duration_s": round(actual, 3),
            "process": self._power_process_delta(before, after, actual, clock_ticks),
            "events": summarize_power_events(measurement_events, actual),
            "transition_events": summarize_power_events(transition_events, 0),
            "vpn_before": vpn_before,
            "vpn_after": vpn_after,
            "session_before": session_before,
            "session_after": session_after,
            "session_continuity": (session_before or {}).get("session_id") is not None
            and (session_before or {}).get("session_id") == (session_after or {}).get("session_id"),
            "raw_event_count": len(transition_events) + len(measurement_events),
        }

    def power(self, scale: float = 1.0) -> dict:
        """Phase 4F observer-only F0-F7 background/power attribution windows."""
        self.require_package()
        initial_session = self.read_session_presence()
        original_idle = self.adb.shell("dumpsys deviceidle").stdout
        windows = []
        durations = {"F0": 60, "F1": 60, "F2": 60, "F3": 90, "F4": 120, "F5": 120, "F6": 120, "F7": 120}
        durations = {key: max(1.0, value * scale) for key, value in durations.items()}

        def power_sources() -> dict:
            commands = {
                "battery": f"dumpsys batterystats {self.package}",
                "deviceidle": "dumpsys deviceidle",
                "power": "dumpsys power",
                "alarm": f"dumpsys alarm | grep -i {self.package} || true",
                "jobscheduler": f"dumpsys jobscheduler | grep -i {self.package} || true",
            }
            captured = {}
            for name, command in commands.items():
                proc = self.adb.shell(command, timeout=30)
                output = (proc.stdout + proc.stderr).strip()
                captured[name] = {
                    "available": proc.returncode == 0,
                    "output": output[:20000],
                    "truncated": len(output) > 20000,
                }
            return captured

        def wake():
            self.adb.shell("dumpsys deviceidle unforce")
            self.adb.shell("input keyevent KEYCODE_WAKEUP")
            self.adb.shell("wm dismiss-keyguard")

        try:
            supporting_before = power_sources()
            wake()
            self.start_main()
            self.wait_nav_ready(timeout=25.0)
            self.nav_broadcast("health_test_config", {"action": "save_disable"})
            self.nav_broadcast("vpn_action", {"action": "stop"})
            time.sleep(3.0)
            windows.append(self._power_window("F0", durations["F0"]))

            self.nav_broadcast("vpn_action", {"action": "start"})
            time.sleep(5.0)
            self.nav_broadcast("navigate", {"page": "dashboard"})
            windows.append(self._power_window("F1", durations["F1"]))

            self.nav_broadcast("navigate", {"page": "proxies"})
            windows.append(self._power_window("F2", durations["F2"]))

            windows.append(self._power_window("F3", durations["F3"], lambda: self.adb.shell("input keyevent KEYCODE_HOME")))

            wake()
            self.start_main()
            time.sleep(2.0)
            windows.append(self._power_window("F4", durations["F4"], lambda: self.adb.shell("input keyevent KEYCODE_SLEEP")))

            idle_result = {"supported": False, "output": None, "confirmed": False}
            def force_idle():
                proc = self.adb.shell("dumpsys deviceidle force-idle", timeout=30)
                idle_result["output"] = (proc.stdout + proc.stderr).strip()
                idle_result["supported"] = proc.returncode == 0
                state = self.adb.shell("dumpsys deviceidle get deep").stdout.strip().lower()
                idle_result["confirmed"] = state == "idle"
            windows.append(self._power_window("F5", durations["F5"], force_idle))

            wake()
            self.start_main()
            time.sleep(2.0)
            self.nav_broadcast("smart_action", {"action": "pause"})
            time.sleep(3.0)
            windows.append(self._power_window("F6", durations["F6"], lambda: self.adb.shell("input keyevent KEYCODE_SLEEP")))

            wake()
            self.start_main()
            self.nav_broadcast("smart_action", {"action": "resume"})
            self.nav_broadcast("health_test_config", {"action": "enable_due"})
            time.sleep(2.0)
            windows.append(self._power_window("F7", durations["F7"], lambda: self.adb.shell("input keyevent KEYCODE_HOME")))
            ok = len(windows) == 8
            supporting_after = power_sources()
            return {
                "ok": ok,
                "windows": windows,
                "device_idle": idle_result,
                "original_deviceidle": original_idle,
                "android_power_sources_before": supporting_before,
                "android_power_sources_after": supporting_after,
                "notes": [
                    "Observer-only profile/dev instrumentation; no cadence or lifecycle policy changes.",
                    "CPU derives from /proc stat ticks; unavailable fields remain null.",
                    "F7 is USER_OPT_IN_WORKLOAD and is excluded from ordinary VPN background cost.",
                    "Short windows cannot establish precise mAh savings.",
                ],
            }
        finally:
            wake()
            self.start_main()
            time.sleep(1.0)
            self.nav_broadcast("health_test_config", {"action": "restore"})
            state = str((initial_session or {}).get("state") or "STOPPED").upper()
            if state == "RUNNING":
                self.nav_broadcast("vpn_action", {"action": "start"})
            elif state == "PAUSED":
                self.nav_broadcast("vpn_action", {"action": "start"})
                time.sleep(2.0)
                self.nav_broadcast("smart_action", {"action": "pause"})
            else:
                self.nav_broadcast("vpn_action", {"action": "stop"})

    def _snapshot_process(self, label: str) -> dict:
        flutter_pid = self.pid_of(self.package)
        remote_pid = self.pid_of(f"{self.package}:remote")
        focus = self.adb.shell("dumpsys window displays").stdout
        focused = self.package in focus
        mem = None
        if flutter_pid is not None:
            mem = parse_meminfo(self.adb.shell(f"dumpsys meminfo {self.package}").stdout)
        cpu = self._cpu_for_pids([flutter_pid, remote_pid])
        vpn_state = self._vpn_status()
        return {
            "label": label,
            "app_focused": focused,
            "flutter_pid": flutter_pid,
            "remote_pid": remote_pid,
            "memory": mem,
            "cpu": cpu,
            "vpn_state": vpn_state,
        }

    def _cpu_for_pids(self, pids: list[int | None]) -> dict:
        wanted = {str(pid) for pid in pids if pid is not None}
        if not wanted:
            return {"ok": False, "reason": "pid_missing"}
        raw = self.adb.shell("dumpsys cpuinfo").stdout
        hits = []
        for line in raw.splitlines():
            if any(pid in line.split() for pid in wanted) or any(
                f"{self.package}" in line and pid in line for pid in wanted
            ):
                hits.append(line.strip())
        return {"ok": bool(hits), "lines": hits[:8]}

    def kill_ui_keep_remote(self, flutter_pid: int) -> dict:
        """Kill only the Flutter UI process. Never `am force-stop`."""
        notes = []
        used = None
        remote_pid = self.pid_of(f"{self.package}:remote")
        if remote_pid is not None and flutter_pid == remote_pid:
            return {
                "ok": False,
                "used": None,
                "ui_pid_before": flutter_pid,
                "ui_pid_after": flutter_pid,
                "notes": ["refusing to kill :remote pid masquerading as UI"],
            }
        for command in ui_process_kill_commands(self.package, flutter_pid):
            if "force-stop" in command:
                raise HarnessError("unsafe_kill", "force-stop is forbidden for UI reattach")
            proc = self.adb.shell(command, timeout=15)
            used = {"command": command, "returncode": proc.returncode}
            if proc.returncode == 0:
                break
            notes.append(f"{command} failed rc={proc.returncode}")
        time.sleep(0.6)
        still = self.pid_of(self.package)
        return {
            "ok": still != flutter_pid,
            "used": used,
            "ui_pid_before": flutter_pid,
            "ui_pid_after": still,
            "notes": notes,
        }

    def read_session_presence(self) -> dict:
        """Prefer run-as files/remote_session_presence.txt over logcat session marks."""
        proc = self.adb.shell(
            f"run-as {self.package} cat files/remote_session_presence.txt",
            timeout=10,
        )
        parsed = parse_remote_session_presence(proc.stdout + proc.stderr)
        parsed["ok"] = proc.returncode == 0 and parsed.get("parse_ok") is True
        parsed["returncode"] = proc.returncode
        return parsed

    def running_reattach(self, warmup: int = WARMUP_RUNS, runs: int = MEASURE_RUNS) -> dict:
        """VPN/Core stay up; Flutter UI process dies and is reopened."""
        self.require_package()
        before = self._vpn_status()
        if before.get("vpn_ready") is not True:
            return {
                "ok": False,
                "scenario": "running_reattach",
                "before": before,
                "unreliable": ["vpn_not_confirmed_running"],
                "notes": [
                    "Start VPN in the profile app first (VpnService + tunN). "
                    "Do not use am force-stop; that would tear down :remote."
                ],
            }
        remote_before = before.get("remote_pid")
        if remote_before is None:
            return {
                "ok": False,
                "scenario": "running_reattach",
                "before": before,
                "unreliable": ["remote_not_running"],
                "notes": [":remote must stay alive across UI restarts."],
            }

        warmup_samples = []
        measure_samples = []
        warmup_traces = []
        measure_traces = []
        notes = [
            "Kills Flutter UI pid only (run-as kill / am kill). Never am force-stop.",
            "Session continuity comes from files/remote_session_presence.txt, not logcat marks.",
        ]
        unreliable = []
        continuity_ok = True
        ping = self._network_probe()

        for i in range(warmup + runs):
            vpn_pre = self._vpn_status()
            session_pre = self.read_session_presence()
            flutter_pid = self.pid_of(self.package)
            if flutter_pid is None:
                self.start_main()
                time.sleep(1.0)
                flutter_pid = self.pid_of(self.package)
            if flutter_pid is None:
                notes.append(f"run {i} missing UI pid")
                continuity_ok = False
                continue
            self.adb.shell("input keyevent KEYCODE_HOME")
            time.sleep(0.4)
            self.adb.run(["logcat", "-c"], timeout=15)
            killed = self.kill_ui_keep_remote(flutter_pid)
            vpn_mid = self._vpn_status()
            remote_mid = vpn_mid.get("remote_pid")
            sample = self.start_main()
            time.sleep(8.0)
            logcat = self.adb.run(["logcat", "-d", "-t", "2000"], timeout=30)
            log_text = logcat.stdout + logcat.stderr
            marks = parse_phase4_logcat(log_text)
            session_post = self.read_session_presence()
            vpn_post = self._vpn_status()
            round_ok, round_reason = assess_running_reattach_round(
                remote_before=remote_before,
                kill=killed,
                ui_pid_before=flutter_pid,
                remote_mid=remote_mid,
                remote_post=vpn_post.get("remote_pid"),
                session_before=session_pre,
                session_post=session_post,
                vpn_ready_before=vpn_pre.get("vpn_ready"),
                vpn_ready_post=vpn_post.get("vpn_ready"),
            )
            if not round_ok:
                continuity_ok = False
                notes.append(f"run {i} {round_reason}")
            row = {
                "index": i,
                "kill": killed,
                "am_start": sample,
                "phase4_marks": marks or None,
                "session": session_post,
                "session_pre_kill": session_pre,
                "remote_pid": vpn_post.get("remote_pid"),
                "vpn_ready": vpn_post.get("vpn_ready"),
                "tun_ifaces": vpn_post.get("tun_ifaces"),
                "formal_ok": round_ok,
                "formal_reason": round_reason,
            }
            target = warmup_traces if i < warmup else measure_traces
            target.append(row)
            if (
                round_ok
                and sample.get("ok")
                and sample.get("total_time_ms") is not None
            ):
                if i < warmup:
                    warmup_samples.append(sample["total_time_ms"])
                else:
                    measure_samples.append(sample["total_time_ms"])

        startup_marks = aggregate_startup_marks(measure_traces)
        ok = (
            continuity_ok
            and len(measure_samples) == runs
            and before.get("vpn_ready") is True
        )
        if not continuity_ok:
            unreliable.append("running_reattach_gates_failed")
        return {
            "ok": ok,
            "scenario": "running_reattach",
            "warmup": warmup,
            "requested_runs": runs,
            "measured_runs": len(measure_samples),
            "stats": summarize(measure_samples),
            "warmup_samples_ms": warmup_samples,
            "samples_ms": measure_samples,
            "startup_marks": startup_marks,
            "remote_pid": remote_before,
            "session_continuity": continuity_ok,
            "network_probe": ping,
            "before": before,
            "traces": {
                "warmup_tail": warmup_traces[-1:],
                "measure_tail": measure_traces[-1:],
            },
            "unreliable": unreliable,
            "notes": notes,
        }

    def logcat_dump(self, lines: int = 8000) -> str:
        """App-scoped logcat. Device-wide -t N on noisy OEMs drops Flutter lines."""
        pid = self.pid_of(self.package)
        args = ["logcat", "-d"]
        if pid is not None:
            args.extend(["--pid", str(pid)])
        else:
            args.extend(["-t", str(lines)])
        proc = self.adb.run(args, timeout=30)
        return proc.stdout + proc.stderr

    def logcat_events(self) -> list[dict]:
        return parse_phase4_events(self.logcat_dump())

    def collect_display(self) -> dict:
        raw = self.adb.shell("dumpsys display", timeout=20).stdout
        parsed = parse_display_refresh_hz(raw)
        parsed["source"] = "dumpsys display"
        return parsed

    def nav_broadcast(self, cmd: str, extras: dict[str, str] | None = None) -> None:
        # Explicit MainActivity extras: OEM-safe, brings UI to foreground,
        # and does not add a new exported intent action.
        parts = [
            f"am start -n {self.package}/{MAIN_ACTIVITY}",
            f"--es phase4_cmd {cmd}",
        ]
        for key, value in (extras or {}).items():
            parts.append(f"--es {key} {value}")
        proc = self.adb.shell(" ".join(parts), timeout=20)
        if proc.returncode != 0:
            raise HarnessError(
                "nav_broadcast_failed",
                (proc.stderr or proc.stdout or cmd).strip() or cmd,
            )

    def _count_marks(self, mark: str) -> int:
        return sum(1 for event in self.logcat_events() if event.get("mark") == mark)

    def wait_mark_count(self, mark: str, minimum: int, timeout: float = 12.0) -> bool:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self._count_marks(mark) >= minimum:
                return True
            time.sleep(0.2)
        return False

    def wait_nav_ready(self, timeout: float = 25.0) -> dict:
        deadline = time.monotonic() + timeout
        last = {}
        while time.monotonic() < deadline:
            last = parse_phase4_logcat(self.logcat_dump())
            if "nav_listener_ready" in last and "main_ready" in last:
                return last
            time.sleep(0.4)
        return last

    def _mem_snapshot(self) -> dict:
        raw = self.adb.shell(f"dumpsys meminfo {self.package}", timeout=20).stdout
        parsed = parse_meminfo(raw)
        return {
            "total_pss_kb": parsed.get("total_pss_kb"),
            "java_heap_kb": parsed.get("java_heap_kb"),
            "native_heap_kb": parsed.get("native_heap_kb"),
            "parse_ok": parsed.get("parse_ok"),
        }

    def _idle_gfxinfo(self, settle_seconds: float = 2.0) -> dict:
        self.adb.shell(f"dumpsys gfxinfo {self.package} reset", timeout=20)
        time.sleep(settle_seconds)
        dumped = self.adb.shell(f"dumpsys gfxinfo {self.package}", timeout=20)
        parsed = parse_gfxinfo(dumped.stdout)
        parsed["valid"] = jank_is_valid(parsed)
        return parsed

    def _dashboard_keep_experiment(self, navigate, home: str, other: str) -> dict:
        """Profile-only keep:true vs product keep:false. Does not change shipped UX."""
        notes = [
            "Experimental keep:true is PHASE4_PERF override only. Product Dashboard keep stays false.",
            "Offscreen probes are taken while Proxies is selected after Dashboard has been visited.",
        ]
        keep_before = self._count_marks("nav_keep_dashboard")
        self.nav_broadcast("keep_dashboard", {"keep": "true"})
        self.wait_mark_count("nav_keep_dashboard", keep_before + 1, timeout=8)
        navigate(other)
        navigate(home)
        navigate(other)
        dump_before = self._count_marks("nav_page_counts")
        self.nav_broadcast("dump_counts")
        self.wait_mark_count("nav_page_counts", dump_before + 1, timeout=6)
        offscreen = next(
            (event for event in reversed(self.logcat_events()) if event.get("mark") == "nav_page_counts"),
            {},
        )
        mem_true = self._mem_snapshot()
        idle_true = self._idle_gfxinfo(2.0)
        seq_from = 0
        events_before = self.logcat_events()
        seqs = [int(e["seq"]) for e in events_before if isinstance(e.get("seq"), int)]
        seq_from = max(seqs) if seqs else 0
        for _ in range(NAV_ROUND_TRIPS):
            navigate(home)
            navigate(other)
        events = self.logcat_events()
        transitions = group_nav_transitions(events)
        measured = [row for row in transitions if seq_from < row["seq"]]
        dash_bound = filter_transitions(measured, target=home)
        to_proxy = filter_transitions(measured, pair=(home, other))
        to_dash = filter_transitions(measured, pair=(other, home))
        self.nav_broadcast("keep_dashboard", {"keep": "clear"})
        return {
            "ok": bool(dash_bound),
            "notes": notes,
            "offscreen_on_proxies": {
                "mounts": offscreen.get("mounts"),
                "builds": offscreen.get("builds"),
                "dashboard_hero_mounted": offscreen.get("dashboard_hero_mounted"),
                "dashboard_sheen_repeating": offscreen.get("dashboard_sheen_repeating"),
                "dashboard_pulse_repeating": offscreen.get("dashboard_pulse_repeating"),
                "network_latency_timer": offscreen.get("network_latency_timer"),
                "network_latency_bar": offscreen.get("network_latency_bar"),
                "dashboard_keep_override": offscreen.get("dashboard_keep_override"),
            },
            "memory_pss_kb": mem_true,
            "idle_gfxinfo_on_proxies": idle_true,
            "dashboard_bound": summarize_nav(dash_bound),
            "to_dashboard": summarize_nav(to_dash),
            "to_proxy": summarize_nav(to_proxy),
        }

    def navigation(self, session: str = "idle") -> dict:
        self.require_package()
        session = (session or "idle").lower()
        if session not in {"idle", "running"}:
            raise HarnessError("bad_nav_session", f"nav session must be idle or running, got {session}")
        notes = [
            "FrameTiming from Flutter; idle dumpsys gfxinfo is not used as navigation jank.",
            "FrameTiming from Flutter. over_budget uses Flutter display.refreshRate; dumpsys max Hz is not actual presentation rate.",
            "Does not change tab scroll-to-top product behavior.",
        ]
        unreliable: list[str] = []
        display = self.collect_display()
        vpn_before = None
        session_before = None
        started: dict
        ready: dict
        if session == "running":
            notes.append(
                "RUNNING workload: never am force-stop. VPN/Core session must stay up."
            )
            vpn_before = self._vpn_status()
            session_before = self.read_session_presence()
            pre_ok, pre_reasons = assess_running_navigation_preconditions(
                vpn=vpn_before,
                session=session_before,
            )
            if not pre_ok:
                return {
                    "ok": False,
                    "scenario": "navigation",
                    "session": session,
                    "display": display,
                    "vpn_before": vpn_before,
                    "session_before": session_before,
                    "unreliable": pre_reasons,
                    "notes": notes
                    + [
                        "Start VPN in the profile app first (VpnService + tunN + :remote RUNNING). "
                        "Do not use am force-stop."
                    ],
                }
            started = self.start_main()
            time.sleep(1.0)
            self.adb.run(["logcat", "-c"], timeout=15)
            ping_probe = self._count_marks("nav_pong")
            self.nav_broadcast("ping")
            pong_ok = self.wait_mark_count("nav_pong", ping_probe + 1, timeout=8)
            ready = {"nav_pong": pong_ok}
            if not pong_ok:
                return {
                    "ok": False,
                    "scenario": "navigation",
                    "session": session,
                    "display": display,
                    "am_start": started,
                    "ready_marks": ready,
                    "vpn_before": vpn_before,
                    "session_before": session_before,
                    "unreliable": ["nav_pong_missing"],
                    "notes": notes
                    + [
                        "Need a profile APK (or PHASE4_PERF=true). "
                        "RUNNING navigation pings the existing UI; it does not force-stop."
                    ],
                }
        else:
            self.force_stop()
            time.sleep(0.8)
            self.adb.run(["logcat", "-c"], timeout=15)
            started = self.start_main()
            time.sleep(2.0)
            ready = self.wait_nav_ready()
            if "nav_listener_ready" not in ready:
                return {
                    "ok": False,
                    "scenario": "navigation",
                    "session": session,
                    "display": display,
                    "am_start": started,
                    "ready_marks": ready,
                    "unreliable": ["nav_listener_missing"],
                    "notes": notes
                    + [
                        "Need a profile APK (or PHASE4_PERF=true). "
                        "NavigationTrace is compile-time off in production release."
                    ],
                }

            ping_before = self._count_marks("nav_pong")
            self.nav_broadcast("ping")
            self.wait_mark_count("nav_pong", ping_before + 1, timeout=8)
        pages = DEFAULT_MOBILE_PAGES
        current = "dashboard"
        for event in reversed(self.logcat_events()):
            if event.get("mark") == "nav_pong":
                raw_pages = str(event.get("pages") or "")
                parsed = [item for item in raw_pages.split(",") if item]
                if parsed:
                    pages = parsed
                current = str(event.get("current") or current)
                break

        completes_before = self._count_marks("nav_complete")

        def current_max_seq() -> int:
            seqs = [
                int(event["seq"])
                for event in self.logcat_events()
                if isinstance(event.get("seq"), int)
            ]
            return max(seqs) if seqs else 0

        def navigate(page: str) -> None:
            nonlocal completes_before, current
            # Same-tab toPage is a product no-op (listener requires prev != next).
            # Do not wait for nav_complete; D measures reselect separately.
            if page == current:
                return
            self.nav_broadcast("navigate", {"page": page})
            ok_wait = self.wait_mark_count(
                "nav_complete",
                completes_before + 1,
                timeout=12,
            )
            if not ok_wait:
                unreliable.append(f"timeout_waiting_nav_complete:{page}")
            else:
                completes_before += 1
                current = page
            time.sleep(0.15)

        # A warmup then measure dashboard <-> proxies
        other = "proxies" if "proxies" in pages else (pages[1] if len(pages) > 1 else pages[0])
        home = pages[0] if pages else "dashboard"
        if current != home:
            navigate(home)
        for _ in range(2):
            navigate(other)
            navigate(home)
        a_from_seq = current_max_seq()
        for _ in range(NAV_ROUND_TRIPS):
            navigate(other)
            navigate(home)
        a_to_seq = current_max_seq()

        # B round-robin all visible tabs
        for _ in range(2):
            for page in pages:
                navigate(page)
        b_from_seq = current_max_seq()
        for _ in range(NAV_CYCLES):
            for page in pages:
                navigate(page)
        b_to_seq = current_max_seq()

        d_from_seq = current_max_seq()
        d_to_seq = d_from_seq
        keep_false_counts = {}
        keep_false_mem = self._mem_snapshot()
        keep_false_idle = {}
        keep_experiment: dict | None = {
            "ok": None,
            "skipped": "running_workload_skips_p7",
        }
        if session != "running":
            # D same-tab reselect after scrolling a long page (>=10)
            if other in pages:
                navigate(other)
            d_from_seq = current_max_seq()
            for _ in range(NAV_RESELECTS):
                scroll_before = self._count_marks("nav_scroll_by")
                self.nav_broadcast("scroll_by", {"dy": "1400"})
                self.wait_mark_count("nav_scroll_by", scroll_before + 1, timeout=6)
                self.nav_broadcast("scroll_by", {"dy": "1400"})
                self.wait_mark_count("nav_scroll_by", scroll_before + 2, timeout=6)
                self.nav_broadcast("reselect")
                if self.wait_mark_count("nav_complete", completes_before + 1, timeout=8):
                    completes_before += 1
                else:
                    unreliable.append("timeout_waiting_nav_complete:reselect")
            d_to_seq = current_max_seq()

            dump_before = self._count_marks("nav_page_counts")
            self.nav_broadcast("dump_counts")
            self.wait_mark_count("nav_page_counts", dump_before + 1, timeout=6)
            keep_false_counts = next(
                (event for event in reversed(self.logcat_events()) if event.get("mark") == "nav_page_counts"),
                {},
            )
            keep_false_mem = self._mem_snapshot()
            keep_false_idle = self._idle_gfxinfo(2.0)

            keep_experiment = self._dashboard_keep_experiment(
                navigate=navigate,
                home=home,
                other=other,
            )
        else:
            dump_before = self._count_marks("nav_page_counts")
            self.nav_broadcast("dump_counts")
            self.wait_mark_count("nav_page_counts", dump_before + 1, timeout=6)
            keep_false_counts = next(
                (event for event in reversed(self.logcat_events()) if event.get("mark") == "nav_page_counts"),
                {},
            )
            notes.append(
                "RUNNING skips D same-tab reselect and P7 keep experiment. A/B only."
            )

        events = self.logcat_events()
        transitions = group_nav_transitions(events)
        measured_a = [
            row
            for row in transitions
            if a_from_seq < row["seq"] <= a_to_seq
        ]
        measured_b = [
            row
            for row in transitions
            if b_from_seq < row["seq"] <= b_to_seq
        ]
        measured_d = [
            row
            for row in transitions
            if d_from_seq < row["seq"] <= d_to_seq
        ]

        first = filter_transitions(transitions, visit="first")
        revisit = filter_transitions(transitions, visit="revisit")
        dash_proxy = filter_transitions(measured_a, pair=(home, other))
        proxy_dash = filter_transitions(measured_a, pair=(other, home))
        tools_dash = filter_transitions(measured_b, pair=("tools", home))
        if not tools_dash:
            tools_dash = filter_transitions(transitions, pair=("tools", home))

        dart_refresh = None
        dart_budget = None
        for row in reversed(transitions):
            complete = row.get("complete") or {}
            if complete.get("refresh_hz") is not None:
                dart_refresh = complete.get("refresh_hz")
                dart_budget = complete.get("budget_ms")
                break

        refresh_provenance = assess_refresh_rate_provenance(
            flutter_refresh_hz=dart_refresh,
            system_max_refresh_hz=display.get("system_max_refresh_hz")
            if display.get("system_max_refresh_hz") is not None
            else display.get("refresh_hz"),
        )
        if refresh_provenance.get("refresh_rate_mismatch"):
            notes.append(
                "refresh_rate_mismatch: Flutter display.refreshRate differs from "
                "dumpsys system_max_refresh_hz. over_budget is not comparable "
                "across captures. build/raster/totalSpan/worst_frame remain valid."
            )

        ok = (
            started.get("ok") is True
            and (session == "running" or "nav_listener_ready" in ready)
            and len(measured_a) >= NAV_ROUND_TRIPS
            and len(measured_b) >= NAV_CYCLES
            and (session == "running" or len(measured_d) >= NAV_RESELECTS)
            and not any(item.startswith("timeout_waiting_nav_complete") for item in unreliable)
        )
        vpn_after = None
        session_after = None
        if session == "running":
            vpn_after = self._vpn_status()
            session_after = self.read_session_presence()
            cont_ok, cont_reasons = assess_running_navigation_continuity(
                before_vpn=vpn_before or {},
                after_vpn=vpn_after,
                before_session=session_before or {},
                after_session=session_after,
            )
            if not cont_ok:
                ok = False
                unreliable.extend(cont_reasons)
                notes.append(
                    "RUNNING navigation result ok=false: VPN session changed during the workload."
                )
        if display.get("refresh_hz") is None and dart_refresh is None:
            unreliable.append("refresh_rate_unparsed")
            notes.append("Could not parse dumpsys display refresh rate; Dart FrameTiming budget still recorded.")
        notes.append(
            "target_first_build_latency_ms is wait until target root build() is called, "
            "not Dashboard/Proxy build CPU duration."
        )
        notes.append(
            "D total_ms waits for animateTo settle when tracing; product scroll UX is unchanged."
        )

        return {
            "ok": ok,
            "scenario": "navigation",
            "session": session,
            "am_start": started,
            "ready_marks": ready,
            "display": display,
            "dart_refresh_hz": dart_refresh,
            "dart_budget_ms": dart_budget,
            "refresh_rate": refresh_provenance,
            "pages": pages,
            "vpn_before": vpn_before,
            "vpn_after": vpn_after,
            "session_before": session_before,
            "session_after": session_after,
            "workloads": {
                "A_dashboard_proxy": {
                    "pair": [home, other],
                    "round_trips": NAV_ROUND_TRIPS,
                    "transitions": summarize_nav(measured_a),
                    "to_proxy": summarize_nav(dash_proxy),
                    "to_dashboard": summarize_nav(proxy_dash),
                },
                "B_round_robin": {
                    "pages": pages,
                    "cycles": NAV_CYCLES,
                    "transitions": summarize_nav(measured_b),
                    "tools_to_dashboard": summarize_nav(tools_dash),
                },
                "C_first_vs_revisit": {
                    "first": summarize_nav(first),
                    "revisit": summarize_nav(revisit),
                },
                "D_same_tab_reselect": {
                    "page": other,
                    "repeats": NAV_RESELECTS,
                    "transitions": summarize_nav(measured_d),
                    "note": (
                        "scroll_command_ms = DFS+animateTo issued; "
                        "scroll_animation_complete_ms = awaited animateTo Future. "
                        "Product UX still fire-and-forget; only the trace waits."
                    ),
                },
                "E_page_counts": {
                    "mounts": keep_false_counts.get("mounts"),
                    "builds": keep_false_counts.get("builds"),
                    "dashboard_hero_mounted": keep_false_counts.get("dashboard_hero_mounted"),
                    "dashboard_sheen_repeating": keep_false_counts.get("dashboard_sheen_repeating"),
                    "network_latency_timer": keep_false_counts.get("network_latency_timer"),
                    "network_latency_bar": keep_false_counts.get("network_latency_bar"),
                },
                "P7_keep_experiment": keep_experiment,
            },
            "frame_timing": {
                "dashboard_to_proxy": summarize_nav(dash_proxy),
                "proxy_to_dashboard": summarize_nav(proxy_dash),
                "tools_to_dashboard": summarize_nav(tools_dash),
                "round_robin": summarize_nav(measured_b),
            },
            "rebuilds": {
                "dashboard_to_proxy": summarize_hotspots(dash_proxy),
                "proxy_to_dashboard": summarize_hotspots(proxy_dash),
                "tools_to_dashboard": summarize_hotspots(tools_dash),
                "round_robin": summarize_hotspots(measured_b),
            },
            "hotspots": mount_hotspots(measured_a + measured_b + measured_d),
            "transition_count": len(transitions),
            "keep_false_memory": keep_false_mem,
            "keep_false_idle_gfx": keep_false_idle,
            "unreliable": unreliable,
            "notes": notes,
        }


    def proxy(
        self,
        session: str = "idle",
        delay_max: int = 20,
        delay_sizes: list[int] | None = None,
        evidence: bool = True,
    ) -> dict:
        """Phase 4C Proxy UX evidence. Never force-stops. Does not change product UX."""
        self.require_package()
        session = (session or "idle").lower()
        sizes = delay_sizes or ([delay_max] if delay_max > 0 else [])
        notes = [
            "4C.1B proxy evidence never uses am force-stop.",
            "delay batch(100) is await grouping only; futures start at map().toList().",
            "Does not change changeProxy / closeConnections / delay semantics.",
            "Selection ACK gen is the request gen, not the latest intent.",
        ]
        unreliable: list[str] = []
        vpn_before = self._vpn_status()
        session_before = self.read_session_presence()
        if session == "running":
            pre_ok, pre_reasons = assess_running_navigation_preconditions(
                vpn=vpn_before,
                session=session_before,
            )
            if not pre_ok:
                return {
                    "ok": False,
                    "session": session,
                    "unreliable": pre_reasons,
                    "notes": notes + ["RUNNING preconditions failed; not constructing a fake session."],
                    "vpn_before": vpn_before,
                    "session_before": session_before,
                    "blocked": "4C.1B BLOCKED: real RUNNING evidence unavailable",
                }
        self.nav_broadcast("ping")
        ready = self.wait_nav_ready(timeout=25.0)
        completes_before = self._count_marks("nav_complete")
        self.nav_broadcast("navigate", {"page": "dashboard"})
        self.wait_mark_count("nav_complete", completes_before + 1, timeout=12)
        completes_before = self._count_marks("nav_complete")
        self.nav_broadcast("proxy_session", {"value": "start"})
        self.nav_broadcast("navigate", {"page": "proxies"})
        self.wait_mark_count("nav_complete", completes_before + 1, timeout=12)
        time.sleep(2.5)
        event_dumps: list[dict] = []
        delay_runs: list[dict] = []
        for size in sizes:
            if size <= 0:
                continue
            self.nav_broadcast("counts", {"op": "reset", "event": f"delay_{size}"})
            self.nav_broadcast("delay_test", {"max": str(size)})
            deadline = time.monotonic() + 120.0
            while time.monotonic() < deadline:
                events = self.logcat_events()
                if any(e.get("mark") == "delay_test_end" for e in events):
                    break
                time.sleep(0.4)
            self.nav_broadcast("counts", {"op": "dump", "event": f"delay_{size}"})
            time.sleep(0.3)
            delay_runs.append({"requested": size})
        if evidence:
            event_dumps.extend(self._proxy_event_matrix())
            self.nav_broadcast("select_named", {})
            time.sleep(0.2)
            for _ in range(9):
                self.nav_broadcast("select_named", {})
                time.sleep(0.85)
            self.nav_broadcast("select_fixed", {"action": "pin"})
            time.sleep(0.85)
            self.nav_broadcast("select_fixed", {"action": "unfix"})
            time.sleep(0.85)
        self.nav_broadcast("select_race", {"pattern": "abc"})
        time.sleep(1.3)
        self.nav_broadcast("select_race", {"pattern": "aba"})
        time.sleep(1.3)
        if evidence:
            self.nav_broadcast("select_cross", {})
            time.sleep(1.3)
        completes_mid = self._count_marks("nav_complete")
        self.nav_broadcast("navigate", {"page": "dashboard"})
        self.wait_mark_count("nav_complete", completes_mid + 1, timeout=12)
        self.nav_broadcast("navigate", {"page": "proxies"})
        self.wait_mark_count("nav_complete", completes_mid + 2, timeout=12)
        self.nav_broadcast("proxy_session", {"value": "end"})
        time.sleep(0.4)
        events = self.logcat_events()
        transitions = group_nav_transitions(events)
        dash_proxy = filter_transitions(transitions, pair=("dashboard", "proxies"))
        proxy_dash = filter_transitions(transitions, pair=("proxies", "dashboard"))
        delay = summarize_delay_events(events)
        select = summarize_select_events(events)
        eager = [e for e in events if e.get("mark") == "proxy_eager_list"]
        entry = [e for e in events if e.get("mark") == "proxy_page_entry"]
        first_visible = [e for e in events if e.get("mark") == "proxy_first_group_visible"]
        dumps = [e for e in events if e.get("mark") == "proxy_event_dump"]
        unfold = [e for e in events if e.get("mark") == "proxy_unfold"]
        core_unavail = [e for e in events if e.get("mark") == "proxy_groups_core_unavailable"]
        owner_guard = [e for e in events if e.get("mark") == "proxy_groups_owner_guard"]
        select_race = [e for e in events if e.get("mark") in ("proxy_select_race_issued", "proxy_select_race_skip")]
        session_end = next(
            (e for e in reversed(events) if e.get("mark") == "proxy_session_end"),
            None,
        )
        vpn_after = self._vpn_status()
        session_after = self.read_session_presence()
        cont_ok, cont_reasons = True, []
        if session == "running":
            cont_ok, cont_reasons = assess_running_navigation_continuity(
                before_vpn=vpn_before or {},
                after_vpn=vpn_after,
                before_session=session_before or {},
                after_session=session_after,
            )
            if not cont_ok:
                unreliable.extend(cont_reasons)
        ok = bool(ready.get("nav_listener_ready")) and (session != "running" or cont_ok)
        return {
            "ok": ok,
            "session": session,
            "delay_max": delay_max,
            "delay_sizes": sizes,
            "delay": delay,
            "delay_runs": delay_runs,
            "select": select,
            "eager_list": eager[-1] if eager else None,
            "eager_history": eager,
            "page_entry": entry,
            "first_group_visible": first_visible[-1] if first_visible else None,
            "event_dumps": dumps,
            "unfold": unfold,
            "core_unavailable": core_unavail,
            "owner_guard": owner_guard,
            "session_end": session_end,
            "frame_timing": {
                "dashboard_to_proxy": summarize_nav(dash_proxy),
                "proxy_to_dashboard": summarize_nav(proxy_dash),
            },
            "select_intent_count": select.get("intent_count"),
            "select_ack_count": select.get("ack_count"),
            "select_race": select_race,
            "vpn_before": vpn_before,
            "vpn_after": vpn_after,
            "session_before": session_before,
            "session_after": session_after,
            "continuity_ok": cont_ok,
            "unreliable": unreliable,
            "notes": notes,
        }

    def _proxy_event_matrix(self) -> list[dict]:
        steps = [
            ("E1", lambda: self.nav_broadcast("select_named", {})),
            ("E2", lambda: self.nav_broadcast("delay_one", {})),
            ("E3", lambda: self.nav_broadcast("sort_bump", {})),
            ("E4", lambda: self.nav_broadcast("unfold", {"expand": "1"})),
            ("E5", lambda: self.nav_broadcast("unfold", {"expand": "collapse"})),
            ("E6", lambda: self.nav_broadcast("refresh_groups", {})),
            ("E7", lambda: self.nav_broadcast("select_fixed", {"action": "pin"})),
        ]
        for event, action in steps:
            self.nav_broadcast("counts", {"op": "reset", "event": event})
            action()
            time.sleep(0.9)
            self.nav_broadcast("counts", {"op": "dump", "event": event})
            time.sleep(0.2)
        self.nav_broadcast("scroll_by", {"dy": "1200"})
        time.sleep(0.4)
        self.nav_broadcast("scroll_by", {"dy": "2400"})
        time.sleep(0.4)
        self.nav_broadcast("unfold", {"expand": "1"})
        time.sleep(0.4)
        self.nav_broadcast("unfold", {"expand": "collapse"})
        time.sleep(0.3)
        self.nav_broadcast("unfold", {"expand": "1"})
        time.sleep(0.3)
        return []

    def _ipc_rate(self, summary: dict, window_s: float) -> dict:
        if window_s <= 0:
            return {}
        rates = {}
        for method, info in (summary.get("methods") or {}).items():
            rates[method] = round((info.get("count") or 0) * 60.0 / window_s, 2)
        return rates

    def _ipc_page_window(self, page: str, seconds: float, run_id: str) -> dict:
        self.nav_broadcast("navigate", {"page": page})
        time.sleep(0.8)
        self.nav_broadcast("ipc_window", {"value": "start", "page": page})
        time.sleep(seconds)
        self.nav_broadcast("ipc_dump", {"reason": page})
        self.nav_broadcast("ipc_window", {"value": "end", "page": page})
        time.sleep(0.3)
        events = self.logcat_events()
        window_id = latest_ipc_window_id(events, run_id=run_id, page=page)
        summary = summarize_ipc_events(
            events, page=page, run_id=run_id, window_id=window_id
        )
        summary["window_s"] = seconds
        summary["per_min"] = self._ipc_rate(summary, seconds)
        return summary

    def ipc(
        self,
        session: str = "idle",
        delay_max: int = 20,
    ) -> dict:
        """Phase 4D.0 Core IPC baseline. Never force-stops. No cadence changes."""
        self.require_package()
        session = (session or "idle").lower()
        notes = [
            "4D.0 IPC audit never uses am force-stop.",
            "Does not change poll intervals, invoke timeouts, or null fallbacks.",
            "result_class transport_null_or_timeout is not a proven timeout.",
        ]
        unreliable: list[str] = []
        vpn_before = self._vpn_status()
        session_before = self.read_session_presence()
        if session == "running":
            pre_ok, pre_reasons = assess_running_navigation_preconditions(
                vpn=vpn_before,
                session=session_before,
            )
            if not pre_ok:
                return {
                    "ok": False,
                    "session": session,
                    "unreliable": pre_reasons,
                    "notes": notes + ["RUNNING preconditions failed; not constructing a fake session."],
                    "vpn_before": vpn_before,
                    "session_before": session_before,
                    "blocked": "4D.0 BLOCKED: real RUNNING evidence unavailable",
                }
        self.nav_broadcast("ping")
        self.wait_nav_ready(timeout=25.0)
        run_id = f"r{int(time.time())}"
        self.nav_broadcast("ipc_run", {"run_id": run_id})
        time.sleep(0.3)
        pages = {
            "dashboard": self._ipc_page_window("dashboard", 18.0, run_id),
            "proxies": self._ipc_page_window("proxies", 16.0, run_id),
            "profiles": self._ipc_page_window("profiles", 12.0, run_id),
            "tools": self._ipc_page_window("tools", 12.0, run_id),
        }
        self.nav_broadcast("navigate", {"page": "dashboard"})
        time.sleep(0.6)
        delay_size = 20 if session == "running" else max(delay_max, 20)
        self.nav_broadcast("ipc_window", {"value": "start", "page": "delay"})
        time.sleep(0.4)
        delay_window_id = latest_ipc_window_id(
            self.logcat_events(), run_id=run_id, page="delay"
        )
        self.nav_broadcast("delay_test", {"max": str(delay_size)})
        deadline = time.monotonic() + 90.0
        while time.monotonic() < deadline:
            events = self.logcat_events()
            if any(
                e.get("mark") == "delay_test_end"
                and str(e.get("window_id") or "") == str(delay_window_id or "")
                for e in events
            ):
                break
            time.sleep(0.4)
        time.sleep(2.0)
        self.nav_broadcast("ipc_dump", {"reason": "delay"})
        self.nav_broadcast("ipc_window", {"value": "end", "page": "delay"})
        time.sleep(0.3)
        events = self.logcat_events()
        delay_window_id = latest_ipc_window_id(events, run_id=run_id, page="delay")
        delay_summary = summarize_ipc_events(
            events, page="delay", run_id=run_id, window_id=delay_window_id
        )
        delay_summary["delay_size"] = delay_size
        delay_summary["delay"] = summarize_delay_events(
            events, run_id=run_id, window_id=delay_window_id
        )

        self.nav_broadcast(
            "ipc_window",
            {"value": "start", "page": "background", "auto_end_ms": "10000"},
        )
        self.adb.shell("input keyevent KEYCODE_HOME", timeout=10)
        time.sleep(11.0)
        events = self.logcat_events()
        bg_window_id = latest_ipc_window_id(events, run_id=run_id, page="background")
        background = summarize_ipc_events(
            events, page="background", run_id=run_id, window_id=bg_window_id
        )

        self.nav_broadcast("ipc_window", {"value": "start", "page": "resume"})
        time.sleep(8.0)
        self.nav_broadcast("ipc_dump", {"reason": "resume"})
        self.nav_broadcast("ipc_window", {"value": "end", "page": "resume"})
        time.sleep(0.3)
        events = self.logcat_events()
        resume_window_id = latest_ipc_window_id(events, run_id=run_id, page="resume")
        resume = summarize_ipc_events(
            events, page="resume", run_id=run_id, window_id=resume_window_id
        )

        vpn_after = self._vpn_status()
        session_after = self.read_session_presence()
        cont_ok = True
        cont_reasons: list[str] = []
        if session == "running":
            cont_ok, cont_reasons = assess_running_navigation_continuity(
                before_vpn=vpn_before,
                after_vpn=vpn_after,
                before_session=session_before,
                after_session=session_after,
            )
            if not cont_ok:
                unreliable.extend(cont_reasons)

        peak = max(
            [block.get("peak_inflight") or 0 for block in pages.values()]
            + [
                delay_summary.get("peak_inflight") or 0,
                background.get("peak_inflight") or 0,
                resume.get("peak_inflight") or 0,
            ]
        )
        return {
            "ok": True if session != "running" else bool(cont_ok),
            "session": session,
            "run_id": run_id,
            "pages": pages,
            "delay_interference": delay_summary,
            "background": background,
            "resume": resume,
            "peak_inflight": peak,
            "vpn_before": vpn_before,
            "vpn_after": vpn_after,
            "session_before": session_before,
            "session_after": session_after,
            "continuity_ok": cont_ok if session == "running" else None,
            "unreliable": unreliable,
            "notes": notes,
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SlClash Phase 4 performance harness")
    parser.add_argument(
        "command",
        choices=["all", "env", "cold-start", "memory", "jank", "vpn", "background", "power", "running-reattach", "navigation", "proxy", "ipc", "compare"],
    )
    parser.add_argument(
        "--package",
        default=None,
        help=(
            "Installed applicationId. Defaults: debug=.dev, profile=.profile, "
            "release=com.slclash.app. Override with SLCLASH_PACKAGE."
        ),
    )
    parser.add_argument("--serial")
    parser.add_argument("--adb")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--current", type=Path)
    parser.add_argument(
        "--build-mode",
        choices=["debug", "profile", "release"],
        help=(
            "Flutter build mode of the installed APK. Required for formal profile baselines "
            "(non-debuggable packages otherwise default to release/production)."
        ),
    )
    parser.add_argument(
        "--out",
        type=Path,
        help="Output directory. Default: .perf-captures/phase4/<timestamp>",
    )
    parser.add_argument(
        "--write-baseline-doc",
        type=Path,
        help=(
            "Write aggregated formal baseline markdown. Rejects debug/diagnostic_only builds."
        ),
    )
    parser.add_argument(
        "--write-nav-baseline-doc",
        type=Path,
        help="Write Phase 4B navigation baseline markdown. Rejects debug/diagnostic_only builds.",
    )
    parser.add_argument(
        "--nav-session",
        choices=["idle", "running"],
        default="idle",
        help="navigation workload: idle force-stops; running never force-stops a live VPN session.",
    )
    parser.add_argument(
        "--proxy-session",
        choices=["idle", "running"],
        default="idle",
        help="4C.0 proxy workload: never force-stops. running requires live VPN continuity.",
    )
    parser.add_argument(
        "--ipc-session",
        choices=["idle", "running"],
        default="idle",
        help="4D.0 IPC workload: never force-stops. running requires live VPN continuity.",
    )
    parser.add_argument(
        "--vpn-scenario",
        choices=["all", "start-stop", "reattach", "smart", "quick"],
        default="all",
        help="4E lifecycle scenario set. Initial force-stop applies only to the selected profile/debug package.",
    )
    parser.add_argument(
        "--delay-max",
        type=int,
        default=20,
        help="4C delay_test node cap. 0 skips delay_test unless --delay-sizes is set.",
    )
    parser.add_argument(
        "--delay-sizes",
        default="",
        help="Comma-separated delay_test sizes, e.g. 20,100. Overrides repeating --delay-max.",
    )
    parser.add_argument(
        "--proxy-evidence",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="4C.1B extra event-scope / selection / unfold matrix. Default on.",
    )
    parser.add_argument(
        "--power-scale",
        type=float,
        default=1.0,
        help="Scale F0-F7 durations for instrumentation smoke tests; formal baseline uses 1.0.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
    args = build_parser().parse_args(argv)
    if args.command == "compare":
        if not args.baseline or not args.current:
            print("compare requires --baseline and --current", file=sys.stderr)
            return 2
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        current = json.loads(args.current.read_text(encoding="utf-8"))
        print(json.dumps(compare_results(baseline, current), indent=2))
        return 0

    package = (
        args.package
        or os.environ.get("SLCLASH_PACKAGE")
        or default_package_for_mode(args.build_mode)
    )

    captures = REPO / ".perf-captures" / "phase4"
    stamp = utc_now().replace(":", "").replace("-", "")
    out_dir = args.out or (captures / stamp)
    latest_dir = captures

    try:
        adb_path = resolve_adb(args.adb)
        serial = select_device(adb_path, args.serial)
        runner = Runner(
            Adb(adb_path, serial),
            package,
            build_mode=args.build_mode,
        )
        env = runner.collect_env()
        result = {
            "ok": True,
            "timestamp": utc_now(),
            "commit": env["git_commit"],
            "phase4_product_baseline": PRODUCT_BASELINE,
            "phase4e_baseline": PHASE4E_BASELINE,
            "device": env.get("model"),
            "build": {
                "package": env.get("package"),
                "version_name": env.get("version_name"),
                "version_code": env.get("version_code"),
                "mode": env.get("build_mode"),
                "role": env.get("build_role"),
                "formal_eligible": env.get("formal_eligible"),
                "debuggable": env.get("debuggable"),
                "mode_detection": env.get("build_mode_detection"),
                "mode_notes": env.get("build_mode_notes"),
                "git_head": env.get("git_head"),
                "dirty": env.get("dirty"),
                "submodule_dirty": env.get("submodule_dirty"),
                "worktree_fingerprint": env.get("worktree_fingerprint"),
            },
            "env": env,
            "errors": [],
            "notes": [],
            "cold_start": None,
            "memory": None,
            "jank": None,
            "vpn": None,
            "background": None,
            "running_reattach": None,
            "navigation": None,
            "proxy": None,
            "ipc": None,
            "power": None,
        }
        if env.get("build_role") == "diagnostic_only":
            result["notes"].append(
                "debug/diagnostic_only build: harness OK for instrumentation checks only; "
                "not formal baseline and not for claiming improvement percentages"
            )
        mapping = {
            "env": [],
            "cold-start": ["cold_start"],
            "memory": ["memory"],
            "jank": ["jank"],
            "vpn": ["vpn"],
            "background": ["background"],
            "running-reattach": ["running_reattach"],
            "navigation": ["navigation"],
            "proxy": ["proxy"],
            "ipc": ["ipc"],
            "power": ["power"],
            "all": ["cold_start", "memory", "jank", "vpn", "background"],
        }
        for name in mapping[args.command]:
            if name == "navigation":
                block = runner.navigation(session=args.nav_session)
            elif name == "proxy":
                sizes = [
                    int(part)
                    for part in str(getattr(args, "delay_sizes", "") or "").split(",")
                    if part.strip()
                ]
                block = runner.proxy(
                    session=args.proxy_session,
                    delay_max=args.delay_max,
                    delay_sizes=sizes or None,
                    evidence=getattr(args, "proxy_evidence", True),
                )
            elif name == "ipc":
                block = runner.ipc(
                    session=args.ipc_session,
                    delay_max=args.delay_max,
                )
            elif name == "vpn":
                block = runner.vpn(scenario=args.vpn_scenario)
            elif name == "power":
                block = runner.power(scale=args.power_scale)
            else:
                block = getattr(runner, name)()
            result[name] = block
            if not block.get("ok"):
                result["ok"] = False
                result["errors"].append(
                    {"code": f"{name}_failed", "message": f"{name} did not complete successfully"}
                )
    except HarnessError as exc:
        result = fail_result(exc.code, exc.message)
        write_reports(result, out_dir, latest_dir)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        print(f"wrote {out_dir}", file=sys.stderr)
        return 2
    except subprocess.TimeoutExpired as exc:
        result = fail_result("timeout", str(exc))
        write_reports(result, out_dir, latest_dir)
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 2

    if args.baseline and args.baseline.exists():
        baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
        result["compare"] = compare_results(baseline, result)
    elif args.command == "all":
        result["compare"] = None

    json_path, md_path = write_reports(result, out_dir, latest_dir)
    if args.write_baseline_doc:
        build = result.get("build") or {}
        if not build.get("formal_eligible"):
            print(
                "refusing --write-baseline-doc: formal baseline requires profile "
                "(profiling) or release (production); debug is diagnostic_only only",
                file=sys.stderr,
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            print(f"wrote {json_path} and {md_path}", file=sys.stderr)
            return 2
        args.write_baseline_doc.parent.mkdir(parents=True, exist_ok=True)
        args.write_baseline_doc.write_text(
            render_baseline_markdown(result), encoding="utf-8"
        )
        print(f"wrote baseline doc {args.write_baseline_doc}", file=sys.stderr)
    if args.write_nav_baseline_doc:
        build = result.get("build") or {}
        if not build.get("formal_eligible"):
            print(
                "refusing --write-nav-baseline-doc: formal baseline requires profile "
                "(profiling) or release (production); debug is diagnostic_only only",
                file=sys.stderr,
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            print(f"wrote {json_path} and {md_path}", file=sys.stderr)
            return 2
        args.write_nav_baseline_doc.parent.mkdir(parents=True, exist_ok=True)
        nav_block = result.get("navigation") or {}
        if build.get("dirty"):
            unreliable = list(nav_block.get("unreliable") or [])
            if "worktree_dirty" not in unreliable:
                unreliable.append("worktree_dirty")
            nav_block["unreliable"] = unreliable
            result["navigation"] = nav_block
            print(
                "nav baseline worktree is dirty: document will be marked UNRELIABLE, "
                "not a formal 4B.1 BEFORE",
                file=sys.stderr,
            )
        args.write_nav_baseline_doc.write_text(
            render_navigation_baseline_markdown(result), encoding="utf-8"
        )
        print(f"wrote nav baseline doc {args.write_nav_baseline_doc}", file=sys.stderr)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    print(f"wrote {json_path} and {md_path}", file=sys.stderr)
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
