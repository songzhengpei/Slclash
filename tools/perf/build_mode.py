from __future__ import annotations

import re

# Role published in harness results / baseline docs.
ROLE_BY_MODE = {
    "debug": "diagnostic_only",
    "profile": "profiling",
    "release": "production",
}

PACKAGE_BY_MODE = {
    "debug": "com.slclash.app.dev",
    "profile": "com.slclash.app.profile",
    "release": "com.slclash.app",
}

FORMAL_ROLES = frozenset({"profiling", "production"})


def default_package_for_mode(mode: str | None) -> str:
    """Sideload package for a Flutter build mode. Profile never shares production id."""
    if mode in PACKAGE_BY_MODE:
        return PACKAGE_BY_MODE[mode]
    return PACKAGE_BY_MODE["debug"]


def role_for_mode(mode: str) -> str:
    try:
        return ROLE_BY_MODE[mode]
    except KeyError as exc:
        raise ValueError(f"unknown build mode: {mode}") from exc


def is_formal_eligible(mode: str | None = None, role: str | None = None) -> bool:
    if role is None:
        if mode is None:
            return False
        role = role_for_mode(mode)
    return role in FORMAL_ROLES


def parse_package_debuggable(dumpsys_package_output: str) -> bool | None:
    """Return True/False when DEBUGGABLE can be inferred; None if unknown."""
    # Common shapes:
    #   flags=[ DEBUGGABLE HAS_CODE ALLOW_CLEAR_USER_DATA ]
    #   pkgFlags=[...]
    #   applicationInfo=ApplicationInfo{... flags=0x...}
    for line in dumpsys_package_output.splitlines():
        stripped = line.strip()
        if "flags=[" in stripped or "pkgFlags=[" in stripped:
            upper = stripped.upper()
            if "DEBUGGABLE" in upper:
                return True
            # Explicit flags list without DEBUGGABLE → treat as non-debuggable
            if "flags=[" in stripped or "pkgFlags=[" in stripped:
                return False
    # Fallback: hex flags on ApplicationInfo (0x2 = FLAG_DEBUGGABLE)
    match = re.search(r"\bflags=0x([0-9a-fA-F]+)\b", dumpsys_package_output)
    if match:
        value = int(match.group(1), 16)
        return bool(value & 0x2)
    return None


def resolve_build_mode(
    *,
    explicit: str | None,
    debuggable: bool | None,
) -> dict:
    """Resolve Flutter/Android build mode and harness role.

    CLI `--build-mode` is authoritative when set. Otherwise:
    - debuggable True  → debug / diagnostic_only
    - debuggable False → release / production (profile must be declared via CLI)
    - debuggable None  → unknown (not formal-eligible)
    """
    notes: list[str] = []
    if explicit:
        mode = explicit
        if mode not in ROLE_BY_MODE:
            raise ValueError(f"unknown build mode: {mode}")
        if debuggable is True and mode != "debug":
            notes.append(
                f"package is DEBUGGABLE but --build-mode={mode} was declared; "
                "using declared mode"
            )
        if debuggable is False and mode == "debug":
            notes.append(
                "package is not DEBUGGABLE but --build-mode=debug was declared; "
                "using declared mode"
            )
        detection = "cli"
    elif debuggable is True:
        mode = "debug"
        detection = "debuggable_flag"
    elif debuggable is False:
        mode = "release"
        detection = "non_debuggable_default_release"
        notes.append(
            "Non-debuggable package defaults to release/production. "
            "Pass --build-mode profile for profiling APKs."
        )
    else:
        mode = "unknown"
        detection = "unavailable"
        notes.append("Could not infer DEBUGGABLE from dumpsys package")

    if mode == "unknown":
        role = "unknown"
        formal = False
    else:
        role = role_for_mode(mode)
        formal = is_formal_eligible(role=role)

    return {
        "mode": mode,
        "role": role,
        "formal_eligible": formal,
        "debuggable": debuggable,
        "detection": detection,
        "notes": notes,
    }
