from __future__ import annotations

from stats import summarize


def group_nav_transitions(events: list[dict]) -> list[dict]:
    by_seq: dict[int, dict] = {}
    for event in events:
        mark = str(event.get("mark") or "")
        if not mark.startswith("nav_"):
            continue
        seq = event.get("seq")
        if not isinstance(seq, int):
            continue
        rec = by_seq.setdefault(
            seq,
            {"seq": seq, "events": [], "complete": None, "scrolls": []},
        )
        rec["events"].append(event)
        if mark == "nav_complete":
            rec["complete"] = event
        elif mark == "nav_scroll_to_top":
            rec["scrolls"].append(event)
    return [by_seq[key] for key in sorted(by_seq)]


def _complete(transition: dict) -> dict:
    return transition.get("complete") or {}


def filter_transitions(
    transitions: list[dict],
    *,
    source: str | None = None,
    target: str | None = None,
    visit: str | None = None,
    kind: str | None = None,
    pair: tuple[str, str] | None = None,
) -> list[dict]:
    out = []
    for transition in transitions:
        complete = _complete(transition)
        if not complete:
            continue
        if source is not None and complete.get("source") != source:
            continue
        if target is not None and complete.get("target") != target:
            continue
        if visit is not None and complete.get("visit") != visit:
            continue
        if kind is not None and complete.get("kind") != kind:
            continue
        if pair is not None and (
            complete.get("source") != pair[0] or complete.get("target") != pair[1]
        ):
            continue
        out.append(transition)
    return out


def _nums(transitions: list[dict], key: str) -> list[float]:
    values: list[float] = []
    for transition in transitions:
        raw = _complete(transition).get(key)
        if isinstance(raw, (int, float)):
            values.append(float(raw))
    return values


def summarize_nav(transitions: list[dict]) -> dict:
    totals = _nums(transitions, "total_ms")
    first_build = _nums(transitions, "first_build_ms")
    first_frame = _nums(transitions, "first_frame_ms")
    worst = _nums(transitions, "worst_frame_ms")
    over = _nums(transitions, "over_budget")
    frames = _nums(transitions, "frame_count")
    scroll_us = _nums(transitions, "scroll_us")
    scroll_elements = _nums(transitions, "scroll_elements")
    scroll_positions = _nums(transitions, "scroll_positions")
    return {
        "count": len(transitions),
        "total_ms": summarize(totals),
        "first_build_ms": summarize(first_build),
        "first_frame_ms": summarize(first_frame),
        "worst_frame_ms": summarize(worst),
        "over_budget": summarize(over),
        "frame_count": summarize(frames),
        "scroll_us": summarize(scroll_us),
        "scroll_elements": summarize(scroll_elements),
        "scroll_positions": summarize(scroll_positions),
    }


def mount_hotspots(transitions: list[dict]) -> list[dict]:
    ranked = []
    for transition in transitions:
        complete = _complete(transition)
        total = complete.get("total_ms")
        if not isinstance(total, (int, float)):
            continue
        ranked.append(
            {
                "seq": complete.get("seq"),
                "source": complete.get("source"),
                "target": complete.get("target"),
                "visit": complete.get("visit"),
                "keep_alive": complete.get("keep_alive"),
                "total_ms": total,
                "first_build_ms": complete.get("first_build_ms"),
                "worst_frame_ms": complete.get("worst_frame_ms"),
                "over_budget": complete.get("over_budget"),
                "scroll_us": complete.get("scroll_us"),
                "scroll_elements": complete.get("scroll_elements"),
                "frame_count": complete.get("frame_count"),
            }
        )
    ranked.sort(key=lambda row: float(row["total_ms"]), reverse=True)
    return ranked[:12]
