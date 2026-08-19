#!/usr/bin/env python3
"""Phase 4 performance harness (Python + ADB).

Usage:
    python tools/perf/phase4.py all
    python tools/perf/phase4.py env|cold-start|memory|jank|vpn|background
    python tools/perf/phase4.py running-reattach
    python tools/perf/phase4.py navigation
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
    summarize_nav,
)
from parsers import (  # noqa: E402
    aggregate_startup_marks,
    assess_running_reattach_round,
    assess_vpn_state,
    connectivity_has_vpn_network,
    jank_is_valid,
    parse_am_start_w,
    parse_display_refresh_hz,
    parse_gfxinfo,
    parse_meminfo,
    parse_phase4_events,
    parse_phase4_logcat,
    parse_remote_session_presence,
    parse_pidof,
    parse_tun_from_proc_net_dev,
    parse_tun_from_sys_class_net,
    parse_tun_interfaces,
    ui_process_kill_commands,
    vpn_stop_cleared,
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

    def vpn(self, timeout_s: float = 20.0) -> dict:
        self.require_package()
        unreliable = [
            "vpn_consent_cannot_be_granted_over_adb",
            "network_probe_is_not_tunnel_attribution",
        ]
        notes = [
            "Uses existing TempActivity START/STOP intents from Phase 1–3 Android quick actions.",
            "vpn_ready requires VpnService + real tunN iface; remote pid alone is not enough.",
        ]
        self.force_stop()
        time.sleep(0.5)
        start_cmd = (
            f"am start -W -n {self.package}/{TEMP_ACTIVITY} "
            f"-a {self.package}.action.START"
        )
        started_at = time.monotonic()
        start_proc = self.adb.shell(start_cmd, timeout=30)
        start_parsed = parse_am_start_w(start_proc.stdout + "\n" + start_proc.stderr)

        observed = None
        start_to_observable_ms = None
        start_to_ready_ms = None
        vpn_ready = None
        deadline = started_at + timeout_s
        while time.monotonic() < deadline:
            observed = self._vpn_status()
            now_ms = int((time.monotonic() - started_at) * 1000)
            if start_to_observable_ms is None and observed["start_observable"]:
                start_to_observable_ms = now_ms
            if observed["vpn_ready"] is True:
                start_to_ready_ms = now_ms
                vpn_ready = True
                break
            time.sleep(0.5)
        else:
            if observed is None:
                observed = self._vpn_status()
            vpn_ready = observed.get("vpn_ready")
            if vpn_ready is True and start_to_ready_ms is None:
                start_to_ready_ms = int((time.monotonic() - started_at) * 1000)
            if vpn_ready is None:
                unreliable.append("vpn_ready_unconfirmed_partial_signals_only")
                notes.append(
                    "Partial start signals observed but VpnService+tunN were not both present; "
                    "start_to_ready_ms left null."
                )
            elif vpn_ready is False:
                notes.append(
                    "VPN did not become ready. Consent dialog, missing profile, "
                    "or core failure — ready timing is null."
                )

        probe = self._network_probe() if vpn_ready is True else None

        stop_cmd = (
            f"am start -W -n {self.package}/{TEMP_ACTIVITY} "
            f"-a {self.package}.action.STOP"
        )
        stop_started = time.monotonic()
        stop_proc = self.adb.shell(stop_cmd, timeout=30)
        stop_observed = None
        stop_to_cleared_ms = None
        stop_success = False
        stop_deadline = stop_started + timeout_s
        while time.monotonic() < stop_deadline:
            stop_observed = self._vpn_status()
            if vpn_stop_cleared(stop_observed):
                stop_to_cleared_ms = int((time.monotonic() - stop_started) * 1000)
                stop_success = True
                break
            time.sleep(0.5)
        if stop_observed is None:
            stop_observed = self._vpn_status()
        if not stop_success:
            if vpn_stop_cleared(stop_observed):
                stop_success = True
                stop_to_cleared_ms = int((time.monotonic() - stop_started) * 1000)
            else:
                unreliable.append("vpn_stop_not_cleared")
                notes.append(
                    "After STOP, VpnService and/or tunN still present; stop timing not counted as success."
                )
                stop_to_cleared_ms = None

        # Scenario ok only when VPN readiness was confirmed; never invent ready timing.
        ok = vpn_ready is True
        return {
            "ok": ok,
            "start": {
                "command": start_cmd,
                "am_start": start_parsed,
                "returncode": start_proc.returncode,
            },
            "observed": observed,
            "start_observable": bool(observed and observed.get("start_observable")),
            "start_to_observable_ms": start_to_observable_ms,
            "vpn_ready": vpn_ready,
            "start_to_ready_ms": start_to_ready_ms if vpn_ready is True else None,
            "network_probe": probe,
            "stop": {
                "command": stop_cmd,
                "returncode": stop_proc.returncode,
                "observed": stop_observed,
            },
            "stop_success": stop_success,
            "stop_to_cleared_ms": stop_to_cleared_ms if stop_success else None,
            "unreliable": unreliable,
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

    def navigation(self) -> dict:
        self.require_package()
        notes = [
            "FrameTiming from Flutter; idle dumpsys gfxinfo is not used as navigation jank.",
            "Frame budget comes from the device refresh rate, not a hardcoded 16.67ms.",
            "Does not change tab scroll-to-top product behavior.",
        ]
        unreliable: list[str] = []
        display = self.collect_display()
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

        ok = (
            started.get("ok") is True
            and "nav_listener_ready" in ready
            and len(measured_a) >= NAV_ROUND_TRIPS
            and len(measured_b) >= NAV_CYCLES
            and len(measured_d) >= NAV_RESELECTS
            and not any(item.startswith("timeout_waiting_nav_complete") for item in unreliable)
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
            "am_start": started,
            "ready_marks": ready,
            "display": display,
            "dart_refresh_hz": dart_refresh,
            "dart_budget_ms": dart_budget,
            "pages": pages,
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
            "hotspots": mount_hotspots(measured_a + measured_b + measured_d),
            "transition_count": len(transitions),
            "keep_false_memory": keep_false_mem,
            "keep_false_idle_gfx": keep_false_idle,
            "unreliable": unreliable,
            "notes": notes,
        }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="SlClash Phase 4 performance harness")
    parser.add_argument(
        "command",
        choices=["all", "env", "cold-start", "memory", "jank", "vpn", "background", "running-reattach", "navigation", "compare"],
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
    return parser


def main(argv: list[str] | None = None) -> int:
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
            "all": ["cold_start", "memory", "jank", "vpn", "background"],
        }
        for name in mapping[args.command]:
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
