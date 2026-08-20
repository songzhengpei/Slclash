# Synthetic Selector fixtures (Phase 4C.1B)

Profile/perf-only YAML. Do **not** import these into the daily `com.slclash.app` user profile.

| File | Nodes |
|---|---|
| `selector_20.yaml` | 20 |
| `selector_100.yaml` | 100 |
| `selector_300.yaml` | 300 |
| `selector_500.yaml` | 500 |

Generate:

```powershell
python tools/perf/fixtures/generate_selector.py
```

The list path under test is still `Group → proxiesListState → ProxiesListView._buildItems → ListView.builder`.
