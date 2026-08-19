from __future__ import annotations

from statistics import median


def percentile(values: list[float], p: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return float(ordered[0])
    k = (len(ordered) - 1) * (p / 100.0)
    lo = int(k)
    hi = min(lo + 1, len(ordered) - 1)
    frac = k - lo
    return float(ordered[lo] * (1 - frac) + ordered[hi] * frac)


def summarize(values: list[float]) -> dict:
    if not values:
        return {
            "count": 0,
            "min": None,
            "max": None,
            "median": None,
            "p50": None,
            "p90": None,
            "p99": None,
        }
    nums = [float(v) for v in values]
    return {
        "count": len(nums),
        "min": min(nums),
        "max": max(nums),
        "median": float(median(nums)),
        "p50": percentile(nums, 50),
        "p90": percentile(nums, 90),
        "p99": percentile(nums, 99),
    }
