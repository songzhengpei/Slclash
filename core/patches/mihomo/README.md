# Mihomo patches

`proxy-only-traffic.patch` preserves SlClash's proxy-only upload/download
counters on top of an official Mihomo release.

The Android build applies this patch automatically. The scheduled Mihomo
update workflow also applies and validates it before pushing an update branch.
If a future Mihomo release changes the touched code, update the patch against
that release and rerun the core tests before merging.
