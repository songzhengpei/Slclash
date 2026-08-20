"""Generate profile-only Selector fixtures. Do not import into daily user profiles."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent


def render(n: int) -> str:
    names = [f"n{i:04d}" for i in range(1, n + 1)]
    proxies = "\n".join(f"  - name: {name}\n    type: direct" for name in names)
    members = ", ".join(names)
    return (
        f"# Phase 4C.1B synthetic Selector fixture ({n} leaves). Perf/profile only.\n"
        "proxies:\n"
        f"{proxies}\n"
        "proxy-groups:\n"
        "  - name: PERF\n"
        "    type: select\n"
        f"    proxies: [{members}]\n"
        "rules:\n"
        "  - MATCH,PERF\n"
    )


def main() -> None:
    for n in (20, 100, 300, 500):
        path = ROOT / f"selector_{n}.yaml"
        path.write_text(render(n), encoding="utf-8")
        print(path)


if __name__ == "__main__":
    main()
