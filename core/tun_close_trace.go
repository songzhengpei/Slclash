package main

import "strings"

// Only diagnostic application sandboxes may emit close-stage timing. Match the
// complete Android files directory, not a package-name substring or suffix.
func tunCloseTraceAllowed(homeDir string) bool {
	parts := strings.Split(strings.TrimSuffix(homeDir, "/"), "/")
	var packageName string
	switch {
	case len(parts) == 5 && parts[0] == "" && parts[1] == "data" &&
		parts[2] == "data" && parts[4] == "files":
		packageName = parts[3]
	case len(parts) == 6 && parts[0] == "" && parts[1] == "data" &&
		(parts[2] == "user" || parts[2] == "user_de") && parts[5] == "files":
		if parts[3] == "" {
			return false
		}
		for _, digit := range parts[3] {
			if digit < '0' || digit > '9' {
				return false
			}
		}
		packageName = parts[4]
	default:
		return false
	}
	return packageName == "com.slclash.app.profile" || packageName == "com.slclash.app.dev"
}
