from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from adbutil import HarnessError, select_device  # noqa: E402
from build_mode import (  # noqa: E402
    default_package_for_mode,
    is_formal_eligible,
    parse_package_debuggable,
    resolve_build_mode,
    role_for_mode,
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
    parse_phase4_session_fields,
    parse_remote_session_presence,
    parse_pidof,
    parse_tun_from_proc_net_dev,
    parse_tun_from_sys_class_net,
    parse_tun_interfaces,
    ui_process_kill_commands,
    vpn_stop_cleared,
)
from provenance import provenance_from_git_outputs  # noqa: E402
from report import (  # noqa: E402
    compare_results,
    render_baseline_markdown,
    render_markdown,
    render_navigation_baseline_markdown,
)
from navigation import group_nav_transitions, summarize_nav  # noqa: E402
from stats import summarize  # noqa: E402


class BuildModeTests(unittest.TestCase):
    def test_roles(self) -> None:
        self.assertEqual(role_for_mode("debug"), "diagnostic_only")
        self.assertEqual(role_for_mode("profile"), "profiling")
        self.assertEqual(role_for_mode("release"), "production")
        self.assertFalse(is_formal_eligible(mode="debug"))
        self.assertTrue(is_formal_eligible(mode="profile"))
        self.assertTrue(is_formal_eligible(mode="release"))

    def test_default_package_by_mode(self) -> None:
        self.assertEqual(default_package_for_mode("debug"), "com.slclash.app.dev")
        self.assertEqual(default_package_for_mode("profile"), "com.slclash.app.profile")
        self.assertEqual(default_package_for_mode("release"), "com.slclash.app")
        self.assertEqual(default_package_for_mode(None), "com.slclash.app.dev")

    def test_debuggable_detection(self) -> None:
        self.assertTrue(
            parse_package_debuggable("flags=[ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ]")
        )
        self.assertFalse(
            parse_package_debuggable("flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ]")
        )
        self.assertTrue(parse_package_debuggable("flags=0x28e83"))  # includes 0x2
        self.assertFalse(parse_package_debuggable("flags=0x28e81"))

    def test_resolve_defaults_and_cli(self) -> None:
        dbg = resolve_build_mode(explicit=None, debuggable=True)
        self.assertEqual(dbg["mode"], "debug")
        self.assertEqual(dbg["role"], "diagnostic_only")
        self.assertFalse(dbg["formal_eligible"])

        rel = resolve_build_mode(explicit=None, debuggable=False)
        self.assertEqual(rel["mode"], "release")
        self.assertEqual(rel["role"], "production")
        self.assertTrue(rel["formal_eligible"])

        prof = resolve_build_mode(explicit="profile", debuggable=False)
        self.assertEqual(prof["mode"], "profile")
        self.assertEqual(prof["role"], "profiling")
        self.assertTrue(prof["formal_eligible"])


class StatsTests(unittest.TestCase):
    def test_summarize_empty(self) -> None:
        self.assertEqual(summarize([])["count"], 0)
        self.assertIsNone(summarize([])["median"])

    def test_median_p90(self) -> None:
        stats = summarize([10, 20, 30, 40, 50, 60, 70, 80, 90, 100])
        self.assertEqual(stats["min"], 10)
        self.assertEqual(stats["max"], 100)
        self.assertEqual(stats["median"], 55)
        self.assertEqual(stats["p90"], 91)


class ParserTests(unittest.TestCase):
    def test_am_start_w(self) -> None:
        parsed = parse_am_start_w(
            "Starting: Intent { cmp=com.slclash.app.dev/com.follow.clash.MainActivity }\n"
            "Status: ok\n"
            "LaunchState: COLD\n"
            "Activity: com.slclash.app.dev/com.follow.clash.MainActivity\n"
            "TotalTime: 812\n"
            "WaitTime: 820\n"
            "ThisTime: 800\n"
        )
        self.assertEqual(parsed["total_time_ms"], 812)
        self.assertEqual(parsed["wait_time_ms"], 820)
        self.assertEqual(parsed["this_time_ms"], 800)
        self.assertEqual(parsed["status"], "ok")

    def test_meminfo_app_summary(self) -> None:
        raw = """
** MEMINFO in pid 4321 [com.slclash.app.dev] **
                   Pss  Private
  Native Heap    11111     10000
  Dalvik Heap     2222      2000
 App Summary
                       Pss(KB)
                        ------
           Java Heap:     4096
         Native Heap:    12000
                Code:     8000
               TOTAL:    28000       TOTAL SWAP PSS:     12
"""
        parsed = parse_meminfo(raw)
        self.assertEqual(parsed["pid"], 4321)
        self.assertEqual(parsed["java_heap_kb"], 4096)
        self.assertEqual(parsed["native_heap_kb"], 12000)
        self.assertEqual(parsed["total_pss_kb"], 28000)
        self.assertTrue(parsed["parse_ok"])

    def test_gfxinfo(self) -> None:
        raw = """
Total frames rendered: 120
Janky frames: 6 (5.00%)
50th percentile: 8ms
90th percentile: 12ms
95th percentile: 16ms
99th percentile: 24ms
"""
        parsed = parse_gfxinfo(raw)
        self.assertEqual(parsed["total_frames"], 120)
        self.assertEqual(parsed["janky_frames"], 6)
        self.assertEqual(parsed["janky_percent"], 5.0)
        self.assertEqual(parsed["p90_ms"], 12)
        self.assertTrue(parsed["parse_ok"])

    def test_phase4_events_keep_repeat_nav_marks(self) -> None:
        raw = (
            "I/flutter: [PHASE4] mark=nav_begin elapsed_ms=10 seq=1 source=dashboard target=proxies kind=tab\n"
            "I/flutter: [PHASE4] mark=nav_scroll_to_top elapsed_ms=12 seq=1 page=dashboard elements=180 positions=2 duration_us=900\n"
            "I/flutter: [PHASE4] mark=nav_complete elapsed_ms=40 seq=1 source=dashboard target=proxies total_ms=312 "
            "target_first_build_latency_ms=21 first_build_ms=21 "
            "worst_frame_ms=18.5 over_budget=2 budget_ms=8.333 refresh_hz=120.00 visit=first keep_alive=true "
            "build_p50_ms=3.1 raster_p50_ms=2.2 total_p50_ms=6.0\n"
            "I/flutter: [PHASE4] mark=nav_complete elapsed_ms=80 seq=2 source=proxies target=dashboard total_ms=410 visit=revisit\n"
        )
        events = parse_phase4_events(raw)
        self.assertEqual(len(events), 4)
        self.assertEqual(events[0]["seq"], 1)
        self.assertEqual(events[2]["total_ms"], 312)
        self.assertEqual(events[2]["keep_alive"], True)
        self.assertAlmostEqual(events[2]["budget_ms"], 8.333)
        nullish = parse_phase4_events(
            "I/flutter: [PHASE4] mark=nav_complete elapsed_ms=40 seq=3 "
            "first_build_ms=null keep_alive=false visit=unknown\n"
        )
        self.assertIsNone(nullish[0]["first_build_ms"])
        self.assertFalse(nullish[0]["keep_alive"])
        grouped = group_nav_transitions(events)
        self.assertEqual(len(grouped), 2)
        stats = summarize_nav(grouped)
        self.assertEqual(stats["count"], 2)
        self.assertEqual(stats["total_ms"]["min"], 312)
        self.assertEqual(events[2]["target_first_build_latency_ms"], 21)
        self.assertEqual(stats["target_first_build_latency_ms"]["min"], 21)
        self.assertAlmostEqual(stats["build_p50_ms"]["median"], 3.1)

    def test_display_refresh_hz(self) -> None:
        parsed = parse_display_refresh_hz(
            "DisplayDeviceInfo{..., refreshRate=120.00001, renderFrameRate=120.0, fps=60.0}"
        )
        self.assertEqual(parsed["refresh_hz"], 120.00001)
        self.assertAlmostEqual(parsed["budget_ms"], 1000.0 / 120.00001, places=4)

    def test_phase4_logcat_and_pidof(self) -> None:
        marks = parse_phase4_logcat(
            "I/flutter: [PHASE4] mark=first_frame elapsed_ms=410\n"
            "I/flutter: [PHASE4] mark=core_skipped elapsed_ms=1500\n"
            "I/flutter: [PHASE4] mark=main_ready elapsed_ms=1800\n"
        )
        self.assertEqual(marks["first_frame"], 410)
        self.assertEqual(marks["main_ready"], 1800)
        self.assertEqual(marks["core_skipped"], 1500)
        self.assertEqual(parse_pidof("1234 5678"), 1234)
        self.assertIsNone(parse_pidof(""))


class TunAndVpnAssessmentTests(unittest.TestCase):
    def test_parse_tun_interfaces_ignores_substring_false_positives(self) -> None:
        raw = (
            "1: lo: <LOOPBACK,UP> mtu 65536\n"
            "2: wlan0: <BROADCAST,UP> mtu 1500\n"
            "3: fortune0: <BROADCAST> mtu 1500\n"
            "12: tun0: <POINTOPOINT,UP> mtu 1500\n"
            "13: tun1: <POINTOPOINT,UP> mtu 1500\n"
        )
        self.assertEqual(parse_tun_interfaces(raw), ["tun0", "tun1"])

    def test_remote_pid_alone_is_not_vpn_ready(self) -> None:
        state = assess_vpn_state(
            tun_ifaces=[],
            vpn_service_running=False,
            remote_pid=99,
            connectivity_vpn=False,
        )
        self.assertTrue(state["start_observable"])
        self.assertIsNone(state["vpn_ready"])
        self.assertEqual(state["confidence"], "unconfirmed")

    def test_vpn_ready_requires_service_and_tun(self) -> None:
        state = assess_vpn_state(
            tun_ifaces=["tun0"],
            vpn_service_running=True,
            remote_pid=99,
            connectivity_vpn=True,
        )
        self.assertTrue(state["vpn_ready"])
        self.assertTrue(state["start_observable"])

    def test_vpn_stop_cleared(self) -> None:
        cleared = assess_vpn_state(
            tun_ifaces=[],
            vpn_service_running=False,
            remote_pid=None,
            connectivity_vpn=False,
        )
        self.assertTrue(vpn_stop_cleared(cleared))
        not_cleared = assess_vpn_state(
            tun_ifaces=["tun0"],
            vpn_service_running=False,
            remote_pid=1,
            connectivity_vpn=False,
        )
        self.assertFalse(vpn_stop_cleared(not_cleared))

    def test_proc_net_dev_tun_ignores_tunl0(self) -> None:
        found = parse_tun_from_proc_net_dev(
            "  tunl0: 0 0\n  tun0: 100 2\n  wlan0: 1 1\n"
        )
        self.assertEqual(found, ["tun0"])
        self.assertEqual(parse_tun_from_sys_class_net("lo tun0 tunl0 wlan0"), ["tun0"])

    def test_connectivity_vpn_requires_typed_signal(self) -> None:
        self.assertFalse(connectivity_has_vpn_network("some app named vpnhelper"))
        self.assertTrue(
            connectivity_has_vpn_network("NetworkAgentInfo{ ni{[type: VPN]} transport=VPN }")
        )


class StartupMarkAggregationTests(unittest.TestCase):
    def test_aggregates_all_measure_runs(self) -> None:
        rows = [
            {"phase4_marks": {"first_frame": 400, "main_ready": 1600, "core_skipped": 1500}},
            {"phase4_marks": {"first_frame": 420, "main_ready": 1700, "core_skipped": 1550}},
            {"phase4_marks": {"first_frame": 500, "main_ready": 2000, "core_ready": 1900}},
            {"phase4_marks": None},
        ]
        agg = aggregate_startup_marks(rows)
        self.assertEqual(agg["runs_with_marks"], 3)
        self.assertEqual(agg["stats"]["first_frame"]["count"], 3)
        self.assertEqual(agg["stats"]["first_frame"]["median"], 420)
        self.assertEqual(agg["core_outcome_counts"]["core_skipped"], 2)
        self.assertEqual(agg["core_outcome_counts"]["core_ready"], 1)
        self.assertNotIn("core_skipped", agg["stats"])

    def test_session_snapshot_extras(self) -> None:
        parsed = parse_phase4_session_fields(
            "I/flutter: [PHASE4] mark=session_snapshot elapsed_ms=120 session_id=42 state=RUNNING\n"
        )
        self.assertEqual(parsed["session_id"], 42)
        self.assertEqual(parsed["state"], "RUNNING")

    def test_parse_remote_session_presence(self) -> None:
        parsed = parse_remote_session_presence(
            "\n".join(
                [
                    "v1",
                    "pid=8094",
                    "state=RUNNING",
                    "sessionId=1787118002461",
                    "startedAt=1787118003000",
                    "smartPaused=false",
                ]
            )
        )
        self.assertTrue(parsed["parse_ok"])
        self.assertEqual(parsed["pid"], 8094)
        self.assertEqual(parsed["state"], "RUNNING")
        self.assertEqual(parsed["session_id"], 1787118002461)
        self.assertEqual(parsed["started_at"], 1787118003000)
        self.assertFalse(parsed["smart_paused"])

    def test_parse_remote_session_presence_rejects_partial(self) -> None:
        parsed = parse_remote_session_presence("v1\npid=1\n")
        self.assertFalse(parsed["parse_ok"])
        self.assertIsNone(parsed["session_id"])

    def test_ui_kill_commands_never_force_stop(self) -> None:
        commands = ui_process_kill_commands("com.slclash.app.profile", 99)
        self.assertTrue(commands)
        for command in commands:
            self.assertNotIn("force-stop", command)


class RunningReattachGateTests(unittest.TestCase):
    def _ok_kwargs(self) -> dict:
        return {
            "remote_before": 8094,
            "kill": {"ok": True, "ui_pid_after": None},
            "ui_pid_before": 1001,
            "remote_mid": 8094,
            "remote_post": 8094,
            "session_before": {"session_id": 42, "state": "RUNNING"},
            "session_post": {"session_id": 42, "state": "RUNNING"},
            "vpn_ready_before": True,
            "vpn_ready_post": True,
        }

    def test_formal_round_passes_all_gates(self) -> None:
        ok, reason = assess_running_reattach_round(**self._ok_kwargs())
        self.assertTrue(ok)
        self.assertIsNone(reason)

    def test_kill_failure_is_not_formal(self) -> None:
        kwargs = self._ok_kwargs()
        kwargs["kill"] = {"ok": False, "ui_pid_after": 1001}
        ok, reason = assess_running_reattach_round(**kwargs)
        self.assertFalse(ok)
        self.assertEqual(reason, "kill_ui_keep_remote_failed")

    def test_old_ui_pid_must_disappear(self) -> None:
        kwargs = self._ok_kwargs()
        kwargs["kill"] = {"ok": True, "ui_pid_after": 1001}
        ok, reason = assess_running_reattach_round(**kwargs)
        self.assertFalse(ok)
        self.assertEqual(reason, "old_ui_pid_still_alive")

    def test_remote_pid_must_stay(self) -> None:
        kwargs = self._ok_kwargs()
        kwargs["remote_mid"] = 9000
        ok, reason = assess_running_reattach_round(**kwargs)
        self.assertFalse(ok)
        self.assertEqual(reason, "remote_pid_changed")

    def test_session_id_must_exist_and_stay(self) -> None:
        missing = self._ok_kwargs()
        missing["session_before"] = {"session_id": 0, "state": "RUNNING"}
        ok, reason = assess_running_reattach_round(**missing)
        self.assertFalse(ok)
        self.assertEqual(reason, "session_id_missing_before")

        changed = self._ok_kwargs()
        changed["session_post"] = {"session_id": 43, "state": "RUNNING"}
        ok, reason = assess_running_reattach_round(**changed)
        self.assertFalse(ok)
        self.assertEqual(reason, "session_id_changed")

        absent = self._ok_kwargs()
        absent["session_post"] = {"session_id": None, "state": "RUNNING"}
        ok, reason = assess_running_reattach_round(**absent)
        self.assertFalse(ok)
        self.assertEqual(reason, "session_id_missing_after")

    def test_state_and_vpn_ready_must_stay_running(self) -> None:
        paused = self._ok_kwargs()
        paused["session_post"] = {"session_id": 42, "state": "PAUSED"}
        ok, reason = assess_running_reattach_round(**paused)
        self.assertFalse(ok)
        self.assertEqual(reason, "state_not_running")

        vpn = self._ok_kwargs()
        vpn["vpn_ready_post"] = False
        ok, reason = assess_running_reattach_round(**vpn)
        self.assertFalse(ok)
        self.assertEqual(reason, "vpn_ready_lost")

    def test_missing_logcat_session_mark_is_not_used(self) -> None:
        parsed = parse_phase4_session_fields("I/flutter: [PHASE4] mark=main_ready elapsed_ms=200\n")
        self.assertIsNone(parsed["session_id"])
        self.assertIsNone(parsed["state"])
        ok, reason = assess_running_reattach_round(**self._ok_kwargs())
        self.assertTrue(ok)
        self.assertIsNone(reason)


class DeviceErrorTests(unittest.TestCase):
    def test_no_device(self) -> None:
        with patch("adbutil.Adb.devices", return_value=[]):
            with self.assertRaises(HarnessError) as ctx:
                select_device("adb", None)
            self.assertEqual(ctx.exception.code, "no_device")

    def test_multiple_devices(self) -> None:
        with patch("adbutil.Adb.devices", return_value=["A", "B"]):
            with patch.dict("os.environ", {}, clear=False):
                import os

                os.environ.pop("ANDROID_SERIAL", None)
                with self.assertRaises(HarnessError) as ctx:
                    select_device("adb", None)
                self.assertEqual(ctx.exception.code, "multiple_devices")

    def test_explicit_serial(self) -> None:
        with patch("adbutil.Adb.devices", return_value=["A", "B"]):
            self.assertEqual(select_device("adb", "B"), "B")

    def test_env_serial_preferred(self) -> None:
        with patch("adbutil.Adb.devices", return_value=["A", "B"]):
            with patch.dict("os.environ", {"ANDROID_SERIAL": "A"}):
                self.assertEqual(select_device("adb", None), "A")


class CompareAndSummaryTests(unittest.TestCase):
    def test_vpn_failure_is_not_success(self) -> None:
        failed = {
            "ok": False,
            "vpn": {
                "ok": False,
                "vpn_ready": None,
                "start_to_ready_ms": None,
                "stop_success": False,
                "stop_to_cleared_ms": None,
            },
        }
        self.assertFalse(failed["ok"])
        self.assertIsNone(failed["vpn"]["start_to_ready_ms"])

    def test_compare_includes_startup_memory_jank_vpn(self) -> None:
        baseline = {
            "cold_start": {
                "stats": {"median": 800, "p90": 900, "min": 700, "max": 1000},
                "startup_marks": {
                    "stats": {
                        "first_frame": {"median": 400, "p90": 450},
                        "main_ready": {"median": 1600, "p90": 1800},
                        "core_ready": {"median": 1500, "p90": 1700},
                    }
                },
            },
            "memory": {"total_pss_kb": {"app": 100, "remote": 50, "combined": 150}},
            "jank": {"summary": {"janky_percent": 5.0, "p90_ms": 12, "total_frames": 120, "parse_ok": True}},
            "vpn": {
                "start_to_observable_ms": 1000,
                "start_to_ready_ms": 1500,
                "stop_to_cleared_ms": 400,
            },
        }
        current = {
            "cold_start": {
                "stats": {"median": 850, "p90": 920, "min": 710, "max": 980},
                "startup_marks": {
                    "stats": {
                        "first_frame": {"median": 410, "p90": 460},
                        "main_ready": {"median": 1650, "p90": 1850},
                        "core_ready": {"median": 1550, "p90": 1750},
                    }
                },
            },
            "memory": {"total_pss_kb": {"app": 110, "remote": 55, "combined": 165}},
            "jank": {"summary": {"janky_percent": 6.0, "p90_ms": 14, "total_frames": 130, "parse_ok": True}},
            "vpn": {
                "start_to_observable_ms": 1100,
                "start_to_ready_ms": 1600,
                "stop_to_cleared_ms": 450,
            },
        }
        delta = compare_results(baseline, current)
        self.assertEqual(delta["cold_start_median_ms"]["delta"], 50)
        self.assertEqual(delta["first_frame_median_ms"]["delta"], 10)
        self.assertEqual(delta["main_ready_median_ms"]["delta"], 50)
        self.assertEqual(delta["core_ready_median_ms"]["delta"], 50)
        self.assertEqual(delta["memory_app_pss_kb"]["delta"], 10)
        self.assertEqual(delta["memory_remote_pss_kb"]["delta"], 5)
        self.assertEqual(delta["memory_combined_pss_kb"]["delta"], 15)
        self.assertEqual(delta["jank_janky_percent"]["delta"], 1.0)
        self.assertEqual(delta["vpn_start_to_ready_ms"]["delta"], 100)
        self.assertEqual(delta["vpn_stop_to_cleared_ms"]["delta"], 50)

    def test_compare_skips_jank_when_no_frames(self) -> None:
        baseline = {
            "cold_start": {"stats": {}},
            "memory": {"total_pss_kb": {}},
            "jank": {
                "valid": False,
                "summary": {"total_frames": 0, "janky_percent": 0.0, "p90_ms": 4950, "parse_ok": True},
            },
            "vpn": {},
        }
        current = {
            "cold_start": {"stats": {}},
            "memory": {"total_pss_kb": {}},
            "jank": {
                "valid": False,
                "summary": {"total_frames": 0, "janky_percent": 0.0, "p90_ms": 12, "parse_ok": True},
            },
            "vpn": {},
        }
        delta = compare_results(baseline, current)
        self.assertIsNone(delta["jank_janky_percent"]["delta"])
        self.assertEqual(delta["jank_janky_percent"]["skipped"], "jank_invalid_no_frames")
        self.assertIsNone(delta["jank_p90_ms"]["delta"])

    def test_jank_validity_requires_frames(self) -> None:
        self.assertFalse(jank_is_valid({"total_frames": 0, "parse_ok": True}))
        self.assertFalse(jank_is_valid({"total_frames": None, "parse_ok": True}))
        self.assertTrue(jank_is_valid({"total_frames": 10, "parse_ok": True}))

    def test_provenance_fingerprint_changes_when_dirty(self) -> None:
        clean = provenance_from_git_outputs("abc", "", "", "")
        dirty = provenance_from_git_outputs("abc", " M lib/foo.dart\n", "1\t0\tlib/foo.dart\n", "")
        self.assertFalse(clean["dirty"])
        self.assertTrue(dirty["dirty"])
        self.assertNotEqual(clean["worktree_fingerprint"], dirty["worktree_fingerprint"])
        self.assertEqual(clean["git_head"], "abc")

    def test_submodule_only_porcelain_is_not_source_dirty(self) -> None:
        only_sub = provenance_from_git_outputs("abc", " m core/Clash.Meta\n", "", "")
        self.assertFalse(only_sub["dirty"])
        self.assertTrue(only_sub["submodule_dirty"])
        file_dirty = provenance_from_git_outputs("abc", " M lib/foo.dart\n", "", "")
        self.assertTrue(file_dirty["dirty"])
        self.assertFalse(file_dirty["submodule_dirty"])

    def test_summary_markdown_includes_key_metrics(self) -> None:
        result = {
            "ok": True,
            "timestamp": "2026-08-19T00:00:00Z",
            "commit": "abc",
            "phase4_product_baseline": "b7e08b6e",
            "device": "Phone",
            "build": {"package": "com.slclash.app.dev", "version_name": "1.0", "version_code": "1"},
            "env": {"android_version": "15", "flutter_pid": 1, "remote_pid": None},
            "errors": [],
            "cold_start": {
                "ok": True,
                "stats": {"count": 10, "min": 700, "max": 1000, "median": 812, "p90": 940},
                "startup_marks": {
                    "stats": {
                        "first_frame": {"count": 10, "median": 410, "p90": 480},
                        "main_ready": {"count": 10, "median": 1800, "p90": 2100},
                        "core_ready": {"count": 0, "median": None, "p90": None},
                    },
                    "core_outcome_counts": {"core_skipped": 10, "core_ready": 0},
                },
                "unreliable": [],
                "notes": [],
            },
            "memory": {
                "ok": True,
                "total_pss_kb": {"app": 180000, "remote": None, "combined": 180000},
                "app": {"java_heap_kb": 1, "native_heap_kb": 2},
                "notes": [],
                "unreliable": [],
            },
            "jank": {
                "ok": True,
                "summary": {
                    "total_frames": 120,
                    "janky_frames": 6,
                    "janky_percent": 5.0,
                    "p50_ms": 8,
                    "p90_ms": 12,
                    "p95_ms": 16,
                    "p99_ms": 24,
                },
                "unreliable": ["idle_only_no_ui_automation"],
                "notes": ["idle"],
            },
            "vpn": {
                "ok": False,
                "start_observable": True,
                "start_to_observable_ms": 800,
                "vpn_ready": None,
                "start_to_ready_ms": None,
                "stop_success": True,
                "stop_to_cleared_ms": 300,
                "unreliable": ["vpn_ready_unconfirmed_partial_signals_only"],
                "notes": ["partial"],
            },
            "background": {
                "ok": True,
                "vpn_active": False,
                "vpn_inactive": True,
                "foreground": {
                    "app_focused": True,
                    "flutter_pid": 1,
                    "remote_pid": None,
                    "memory": {"total_pss_kb": 100},
                    "vpn_state": {"vpn_ready": False},
                },
                "background": {
                    "app_focused": False,
                    "flutter_pid": 1,
                    "remote_pid": None,
                    "memory": {"total_pss_kb": 90},
                    "vpn_state": {"vpn_ready": False},
                },
                "unreliable": ["no_battery_mah"],
                "notes": [],
            },
        }
        md = render_markdown(result)
        for needle in (
            "cold start TotalTime ms",
            "first_frame ms",
            "main_ready ms",
            "app PSS kb",
            "core/remote PSS kb",
            "combined PSS kb",
            "janky frames",
            "start_to_observable_ms",
            "start_to_ready_ms",
            "stop_to_cleared_ms",
            "vpn_active",
            "vpn_inactive",
        ):
            self.assertIn(needle, md)

    def test_baseline_doc_omits_raw_dumpsys(self) -> None:
        result = {
            "timestamp": "2026-08-19T00:00:00Z",
            "commit": "abc",
            "phase4_product_baseline": "b7e08b6e",
            "device": "Phone",
            "build": {
                "package": "com.slclash.app.dev",
                "version_name": "1.0",
                "version_code": "1",
                "mode": "profile",
                "role": "profiling",
                "formal_eligible": True,
            },
            "env": {"android_version": "15", "model": "Phone"},
            "cold_start": {
                "stats": {"median": 812, "p90": 940, "min": 700, "max": 1000, "count": 10},
                "startup_marks": {
                    "stats": {
                        "first_frame": {"median": 410, "p90": 480, "count": 10},
                        "main_ready": {"median": 1800, "p90": 2100, "count": 10},
                    },
                    "core_outcome_counts": {"core_skipped": 10},
                },
                "unreliable": [],
            },
            "memory": {"total_pss_kb": {"app": 1, "remote": None, "combined": 1}, "unreliable": []},
            "jank": {
                "summary": {"janky_percent": 5.0, "p90_ms": 12, "total_frames": 10, "janky_frames": 1},
                "unreliable": ["idle_only_no_ui_automation"],
            },
            "vpn": {
                "vpn_ready": None,
                "start_to_ready_ms": None,
                "start_to_observable_ms": 100,
                "stop_success": True,
                "stop_to_cleared_ms": 50,
                "unreliable": ["vpn_ready_unconfirmed_partial_signals_only"],
            },
            "background": {"vpn_active": False, "vpn_inactive": True, "unreliable": ["no_battery_mah"]},
        }
        md = render_baseline_markdown(result)
        self.assertIn("Phase 4A.0 baseline", md)
        self.assertNotIn("dumpsys", md.lower())
        self.assertIn("first_frame", md)


class SchemaTests(unittest.TestCase):
    def test_example_has_required_keys(self) -> None:
        example = json.loads(
            (ROOT / "schema" / "example-result.json").read_text(encoding="utf-8")
        )
        for key in (
            "commit",
            "device",
            "build",
            "timestamp",
            "cold_start",
            "memory",
            "jank",
            "vpn",
            "background",
        ):
            self.assertIn(key, example)
        self.assertIn("startup_marks", example["cold_start"])
        self.assertIn("vpn_ready", example["vpn"])
        self.assertIn("stop_success", example["vpn"])


class NavigationReportTests(unittest.TestCase):
    def test_nav_baseline_doc_uses_frame_timing_not_idle_gfxinfo(self) -> None:
        md = render_navigation_baseline_markdown(
            {
                "timestamp": "2026-08-19T00:00:00Z",
                "commit": "abc",
                "phase4_product_baseline": "b7e08b6e",
                "device": "Phone",
                "build": {
                    "package": "com.slclash.app.profile",
                    "mode": "profile",
                    "role": "profiling",
                    "formal_eligible": True,
                    "git_head": "ee800121",
                    "dirty": False,
                    "worktree_fingerprint": "abc123",
                },
                "env": {"android_version": "16", "sdk": 36, "model": "Phone"},
                "navigation": {
                    "ok": True,
                    "pages": ["dashboard", "proxies", "profiles", "tools"],
                    "dart_refresh_hz": 120.0,
                    "dart_budget_ms": 8.333,
                    "display": {"refresh_hz": 120.0, "budget_ms": 8.333},
                    "workloads": {
                        "A_dashboard_proxy": {
                            "pair": ["dashboard", "proxies"],
                            "round_trips": 10,
                            "transitions": {
                                "total_ms": {"median": 320, "p90": 400, "count": 20}
                            },
                        }
                    },
                    "hotspots": [
                        {
                            "source": "dashboard",
                            "target": "proxies",
                            "visit": "first",
                            "total_ms": 480,
                        }
                    ],
                    "unreliable": [],
                },
            }
        )
        self.assertIn("Phase 4B.0.1 navigation baseline (formal 4B.1 BEFORE)", md)
        self.assertIn("Idle gfxinfo is not this baseline", md)
        self.assertIn("target_first_build_latency_ms", md)
        self.assertIn("not the CPU duration", md)
        self.assertIn("dirty: `False`", md)
        self.assertIn("Measured ranking", md)
        self.assertIn("8.333", md)
        self.assertIn("dashboard→proxies", md)
        dirty_md = render_navigation_baseline_markdown(
            {
                "timestamp": "2026-08-19T00:00:00Z",
                "commit": "abc",
                "phase4_product_baseline": "b7e08b6e",
                "device": "Phone",
                "build": {
                    "package": "com.slclash.app.profile",
                    "mode": "profile",
                    "role": "profiling",
                    "formal_eligible": True,
                    "git_head": "abc",
                    "dirty": True,
                },
                "env": {},
                "navigation": {"ok": True, "unreliable": ["worktree_dirty"]},
            }
        )
        self.assertIn("UNRELIABLE", dirty_md)


if __name__ == "__main__":
    unittest.main()
