from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path


def provenance_from_git_outputs(
    head: str,
    porcelain: str,
    numstat: str = "",
    cached: str = "",
) -> dict:
    """Fingerprint source tree so APK-vs-HEAD mismatch is visible in results."""
    dirty = bool(porcelain.strip())
    payload = f"{head}\n{porcelain}\n{numstat}\n{cached}".encode("utf-8")
    return {
        "git_head": head or "unknown",
        "dirty": dirty,
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
