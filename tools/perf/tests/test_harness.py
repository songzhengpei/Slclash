from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from adbutil import HarnessError, select_device  # noqa: E402
from parsers import (  # noqa: E402
    parse_am_start_w,
    parse_gfxinfo,
    parse_meminfo,
    parse_phase4_logcat,
    parse_pidof,
)
from report import compare_results  # noqa: E402
from stats import summarize  # noqa: E402


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

    def test_phase4_logcat_and_pidof(self) -> None:
        marks = parse_phase4_logcat(
            "I/flutter: [PHASE4] mark=first_frame elapsed_ms=410\n"
            "I/flutter: [PHASE4] mark=main_ready elapsed_ms=1800\n"
        )
        self.assertEqual(marks["first_frame"], 410)
        self.assertEqual(marks["main_ready"], 1800)
        self.assertEqual(parse_pidof("1234 5678"), 1234)
        self.assertIsNone(parse_pidof(""))


class DeviceErrorTests(unittest.TestCase):
    def test_no_device(self) -> None:
        with patch("adbutil.Adb.devices", return_value=[]):
            with self.assertRaises(HarnessError) as ctx:
                select_device("adb", None)
            self.assertEqual(ctx.exception.code, "no_device")

    def test_multiple_devices(self) -> None:
        with patch("adbutil.Adb.devices", return_value=["A", "B"]):
            with self.assertRaises(HarnessError) as ctx:
                select_device("adb", None)
            self.assertEqual(ctx.exception.code, "multiple_devices")

    def test_explicit_serial(self) -> None:
        with patch("adbutil.Adb.devices", return_value=["A", "B"]):
            self.assertEqual(select_device("adb", "B"), "B")


class CompareTests(unittest.TestCase):
    def test_vpn_failure_is_not_success(self) -> None:
        failed = {
            "ok": False,
            "vpn": {"ok": False, "start_to_observable_ms": None},
        }
        self.assertFalse(failed["ok"])
        self.assertIsNone(failed["vpn"]["start_to_observable_ms"])

    def test_compare_delta(self) -> None:
        baseline = {"cold_start": {"stats": {"median": 800, "p90": 900, "min": 700, "max": 1000}}}
        current = {"cold_start": {"stats": {"median": 850, "p90": 920, "min": 710, "max": 980}}}
        delta = compare_results(baseline, current)
        self.assertEqual(delta["cold_start_median_ms"]["delta"], 50)


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


if __name__ == "__main__":
    unittest.main()
