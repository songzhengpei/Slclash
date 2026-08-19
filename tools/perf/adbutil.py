from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Sequence


class HarnessError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def resolve_adb(explicit: str | None = None) -> str:
    if explicit:
        return explicit
    env = os.environ.get("ADB") or os.environ.get("ANDROID_ADB")
    if env:
        return env
    android_home = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    if android_home:
        candidate = Path(android_home) / "platform-tools" / (
            "adb.exe" if os.name == "nt" else "adb"
        )
        if candidate.exists():
            return str(candidate)
    default_win = Path(r"D:\Code\Tools\Android\Sdk\platform-tools\adb.exe")
    if default_win.exists():
        return str(default_win)
    found = shutil.which("adb")
    if found:
        return found
    raise HarnessError("no_adb", "adb not found on PATH, ANDROID_HOME, or ADB")


class Adb:
    def __init__(self, adb_path: str, serial: str | None = None) -> None:
        self.adb_path = adb_path
        self.serial = serial

    def _base(self) -> list[str]:
        cmd = [self.adb_path]
        if self.serial:
            cmd.extend(["-s", self.serial])
        return cmd

    def run(
        self,
        args: Sequence[str],
        *,
        timeout: float = 30,
        check: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            self._base() + list(args),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )

    def shell(self, command: str, *, timeout: float = 30) -> subprocess.CompletedProcess[str]:
        return self.run(["shell", command], timeout=timeout)

    def devices(self) -> list[str]:
        proc = subprocess.run(
            [self.adb_path, "devices"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=15,
        )
        if proc.returncode != 0:
            raise HarnessError("adb_failed", proc.stderr.strip() or "adb devices failed")
        serials: list[str] = []
        for line in proc.stdout.splitlines()[1:]:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) >= 2 and parts[1] == "device":
                serials.append(parts[0])
        return serials


def select_device(adb_path: str, serial: str | None) -> str:
    probe = Adb(adb_path)
    serials = probe.devices()
    env_serial = serial or os.environ.get("ANDROID_SERIAL")
    if not serials:
        raise HarnessError("no_device", "no adb device in 'device' state")
    if env_serial:
        if env_serial not in serials:
            raise HarnessError(
                "device_not_found",
                f"ANDROID_SERIAL={env_serial} is not among {serials}",
            )
        return env_serial
    if len(serials) > 1:
        raise HarnessError(
            "multiple_devices",
            f"multiple devices {serials}; set ANDROID_SERIAL or --serial",
        )
    return serials[0]
