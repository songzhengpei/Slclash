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


def _latency_nums(transitions: list[dict]) -> list[float]:
    values: list[float] = []
    for transition in transitions:
        complete = _complete(transition)
        raw = complete.get("target_first_build_latency_ms")
        if raw is None:
            raw = complete.get("first_build_ms")
        if isinstance(raw, (int, float)):
            values.append(float(raw))
    return values


def summarize_nav(transitions: list[dict]) -> dict:
    """Per-transition FrameTiming + latency summaries.

    target_first_build_latency_ms is wait until target root build() is called,
    not the CPU duration of that build.
    build_*/raster_*/total_span_* are Flutter FrameTiming percentiles already
    computed per transition, then summarized across transitions.
    """
    return {
        "count": len(transitions),
        "total_ms": summarize(_nums(transitions, "total_ms")),
        "target_first_build_latency_ms": summarize(_latency_nums(transitions)),
        "first_build_ms": summarize(_latency_nums(transitions)),
        "first_frame_ms": summarize(_nums(transitions, "first_frame_ms")),
        "scroll_command_ms": summarize(_nums(transitions, "scroll_command_ms")),
        "scroll_animation_complete_ms": summarize(
            _nums(transitions, "scroll_animation_complete_ms")
        ),
        "worst_frame_ms": summarize(_nums(transitions, "worst_frame_ms")),
        "over_budget": summarize(_nums(transitions, "over_budget")),
        "frame_count": summarize(_nums(transitions, "frame_count")),
        "build_p50_ms": summarize(_nums(transitions, "build_p50_ms")),
        "build_p90_ms": summarize(_nums(transitions, "build_p90_ms")),
        "build_p99_ms": summarize(_nums(transitions, "build_p99_ms")),
        "raster_p50_ms": summarize(_nums(transitions, "raster_p50_ms")),
        "raster_p90_ms": summarize(_nums(transitions, "raster_p90_ms")),
        "raster_p99_ms": summarize(_nums(transitions, "raster_p99_ms")),
        "total_span_p50_ms": summarize(_nums(transitions, "total_p50_ms")),
        "total_span_p90_ms": summarize(_nums(transitions, "total_p90_ms")),
        "total_span_p99_ms": summarize(_nums(transitions, "total_p99_ms")),
        "scroll_us": summarize(_nums(transitions, "scroll_us")),
        "scroll_elements": summarize(_nums(transitions, "scroll_elements")),
        "scroll_positions": summarize(_nums(transitions, "scroll_positions")),
    }


def mount_hotspots(transitions: list[dict]) -> list[dict]:
    ranked = []
    for transition in transitions:
        complete = _complete(transition)
        total = complete.get("total_ms")
        if not isinstance(total, (int, float)):
            continue
        latency = complete.get("target_first_build_latency_ms")
        if latency is None:
            latency = complete.get("first_build_ms")
        ranked.append(
            {
                "seq": complete.get("seq"),
                "source": complete.get("source"),
                "target": complete.get("target"),
                "visit": complete.get("visit"),
                "keep_alive": complete.get("keep_alive"),
                "total_ms": total,
                "target_first_build_latency_ms": latency,
                "worst_frame_ms": complete.get("worst_frame_ms"),
                "build_p99_ms": complete.get("build_p99_ms"),
                "raster_p99_ms": complete.get("raster_p99_ms"),
                "over_budget": complete.get("over_budget"),
                "scroll_us": complete.get("scroll_us"),
                "scroll_elements": complete.get("scroll_elements"),
                "frame_count": complete.get("frame_count"),
            }
        )
    ranked.sort(key=lambda row: float(row["total_ms"]), reverse=True)
    return ranked[:12]
