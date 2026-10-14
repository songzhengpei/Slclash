# Mihomo patches

`proxy-only-traffic.patch` preserves SlClash's proxy-only upload/download
counters on top of an official Mihomo release.

The Android build applies this patch automatically. The scheduled Mihomo
update workflow also applies and validates it before publishing its review result.
It creates a Draft PR even when validation fails, with a failing commit status,
the validation outcome, and a link to the full workflow logs. Failed proposals
must be fixed and revalidated before being marked ready for human review.
If a future Mihomo release changes the touched code, update the patch against
that release and rerun the core tests before merging.

The connection-constructor hunks deliberately start after the deadline-wrapper
selection. This preserves the proxy-only counters on 1.19.30/1.19.31 and the
new `ipstackConn` handling in 1.19.32 without replacing upstream logic.
