from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path


def _classify_porcelain(porcelain: str) -> tuple[list[str], list[str]]:
    source: list[str] = []
    submodules: list[str] = []
    for raw in porcelain.splitlines():
        line = raw.rstrip("\n")
        if not line.strip():
            continue
        path = line[3:] if len(line) >= 4 else line
        xy = line[:2] if len(line) >= 2 else ""
        # Git uses lowercase `m` for submodule-only porcelain; ` M` is a normal file.
        submodule = path.startswith("core/Clash.Meta") or "m" in xy
        if submodule:
            submodules.append(line)
        else:
            source.append(line)
    return source, submodules


def provenance_from_git_outputs(
    head: str,
    porcelain: str,
    numstat: str = "",
    cached: str = "",
) -> dict:
    """Fingerprint source tree so APK-vs-HEAD mismatch is visible in results."""
    source_lines, submodule_lines = _classify_porcelain(porcelain)
    payload = f"{head}\n{porcelain}\n{numstat}\n{cached}".encode("utf-8")
    return {
        "git_head": head or "unknown",
        "dirty": bool(source_lines),
        "submodule_dirty": bool(submodule_lines),
        "worktree_fingerprint": hashlib.sha256(payload).hexdigest()[:16],
    }


def collect_git_provenance(repo: Path) -> dict:
    return provenance_from_git_outputs(
        _git(["rev-parse", "HEAD"], repo).strip() or "unknown",
        _git(["status", "--porcelain"], repo),
        _git(["diff", "--numstat", "HEAD"], repo),
        _git(["diff", "--cached", "--numstat"], repo),
    )


def _git(args: list[str], repo: Path) -> str:
    try:
        proc = subprocess.run(
            ["git", *args],
            cwd=repo,
            capture_output=True,
            text=True,
            timeout=10,
        )
        if proc.returncode == 0:
            return proc.stdout
    except OSError:
        pass
    return ""
