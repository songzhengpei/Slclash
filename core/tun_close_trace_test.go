package main

import "testing"

func TestTunCloseTraceOnlyAllowsDiagnosticAndroidSandboxes(t *testing.T) {
	for _, homeDir := range []string{
		"/data/user/0/com.slclash.app.profile/files",
		"/data/user/10/com.slclash.app.dev/files",
		"/data/user_de/0/com.slclash.app.dev/files",
		"/data/data/com.slclash.app.profile/files/",
	} {
		t.Run(homeDir, func(t *testing.T) {
			if !tunCloseTraceAllowed(homeDir) {
				t.Fatal("diagnostic Android sandbox was rejected")
			}
		})
	}
	for _, homeDir := range []string{
		"",
		"/data/user/0/com.slclash.app/files",
		"/data/data/com.slclash.app/files",
		"/data/user/0/com.slclash.app.profile.other/files",
		"/data/user/0/prefix.com.slclash.app.dev/files",
		"/data/user/0/com.slclash.app.profile/files/extra",
		"/data/user/0/com.slclash.app.profile/files/../files",
		"/data/user/0/other/files/com.slclash.app.profile/files",
		"/data/user/../com.slclash.app.profile/files",
		"/data/user//com.slclash.app.profile/files",
		"/data/user/+1/com.slclash.app.profile/files",
		"/data/user/0/com.slclash.app.profile/files//",
		"/data/user/0/com.slclash.app.profile/files_backup",
		"/tmp/com.slclash.app.profile/files",
		"data/user/0/com.slclash.app.profile/files",
		`C:\data\user\0\com.slclash.app.profile\files`,
	} {
		t.Run(homeDir, func(t *testing.T) {
			if tunCloseTraceAllowed(homeDir) {
				t.Fatal("non-diagnostic or lookalike sandbox was allowed")
			}
		})
	}
}
