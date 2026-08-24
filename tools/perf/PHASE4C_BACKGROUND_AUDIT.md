# Phase 4C background scheduler audit

Android background work is classified by the guarantee it needs, rather than
by the mechanism that happens to trigger it today.

| Chain | Class | Owner after Phase 4C | Guarantee |
| --- | --- | --- | --- |
| VPN ownership and `RUNNING/PAUSED/STOPPED` | A: lifecycle critical | `:remote` service | Native foreground-service lifetime |
| Smart Pause and manual override | A: lifecycle critical | `RemoteService` + physical network observer | Event driven; independent of Flutter |
| Physical handover / close stale connections | A: lifecycle critical | Native network coordinator | Stable network-handle changes only |
| DNS update | A: lifecycle critical | Native network observer | Same physical snapshot as Smart Pause |
| Profile auto update | B: eventually consistent | Flutter timer + persisted profile timestamps | Best effort while alive; overdue catch-up on resume |
| Health observation | D: best effort | Flutter one-shot timer | Existing overdue foreground/core reconnect recovery |
| Local/public IP and connectivity display | C: UI freshness | Flutter | Refresh on connectivity/resume; no lifecycle authority |
| UI traffic, memory, latency and animation timers | C | Flutter widgets/providers | Foreground presentation only |

No WorkManager job was added. Profile refresh does not require exact execution
while the app is cached, and health observation is intentionally best effort;
making either periodic in the background would add wakeups without improving
VPN correctness. There is no polling, wake lock, alarm heartbeat, or Flutter
keepalive in the native lifecycle path.

`NET_CAPABILITY_FOREGROUND` was removed from the native request. It describes
whether a network is available to foreground apps and can exclude the physical
underlay when the app UI is cached. `NOT_VPN`, `INTERNET`, and `NOT_RESTRICTED`
retain the intended Wi-Fi/cellular set while excluding the app's VPN.
