// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a en locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'en';

  static String m0(version, date) =>
      "Mihomo Core ${version} · Released ${date}";

  static String m1(count) => "${count}d ago";

  static String m2(label) =>
      "Are you sure you want to delete the selected ${label}?";

  static String m3(label) =>
      "Are you sure you want to delete the current ${label}?";

  static String m4(label) => "${label} details";

  static String m5(percent) => "Downloading APK · ${percent}%";

  static String m6(label) => "${label} cannot be empty";

  static String m7(label) => "Current ${label} already exists";

  static String m8(variant) => "Follow system Material You · ${variant}";

  static String m9(count) => " · green streak ${count}";

  static String m10(count, rate, delay, streak) =>
      "${count} checks · ${rate}%${delay}${streak}";

  static String m11(count) => "${count}h ago";

  static String m12(target) => "${target} is an invalid policy";

  static String m13(proxyName) => "${proxyName} is an invalid proxy";

  static String m14(providerName) =>
      "${providerName} is an invalid proxy provider";

  static String m15(subRule) => "${subRule} is an invalid SUB_RULE";

  static String m16(time) => "Last ${time}";

  static String m17(appName) =>
      "1. Open Settings > Privacy & Security\n2. Choose Location Services\n3. Enable ${appName}\n\nReturn to app after setup.";

  static String m18(count) => "${count}m ago";

  static String m19(mode) => "${mode} mode";

  static String m20(count) => "${count}mo ago";

  static String m21(filter) => "No ${filter} results";

  static String m22(label) => "No ${label} yet";

  static String m23(label) => "${label} must be a number";

  static String m24(label) => "${label} must be between 1024 and 49151";

  static String m25(name) => "Restore ${name}";

  static String m26(count) => "${count} items have been selected";

  static String m27(region) => "Unlocked (${region})";

  static String m28(label) => "${label} must be a url";

  static String m29(count) => "${count}y ago";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "about": MessageLookupByLibrary.simpleMessage("About"),
    "aboutDescription": MessageLookupByLibrary.simpleMessage(
      "SlClash: Android proxy client based on FlClash & Mihomo core.",
    ),
    "accessControl": MessageLookupByLibrary.simpleMessage("Access control"),
    "accessControlAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Allow selected apps only",
    ),
    "accessControlDesc": MessageLookupByLibrary.simpleMessage(
      "Choose which apps use the VPN",
    ),
    "accessControlNotAllowDesc": MessageLookupByLibrary.simpleMessage(
      "Selected apps excluded from VPN",
    ),
    "accessControlSettings": MessageLookupByLibrary.simpleMessage(
      "Access Control Settings",
    ),
    "account": MessageLookupByLibrary.simpleMessage("Account"),
    "action": MessageLookupByLibrary.simpleMessage("Action"),
    "action_mode": MessageLookupByLibrary.simpleMessage("Switch mode"),
    "action_proxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "action_start": MessageLookupByLibrary.simpleMessage("Start/Stop"),
    "action_tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "action_view": MessageLookupByLibrary.simpleMessage("Show/Hide"),
    "add": MessageLookupByLibrary.simpleMessage("Add"),
    "addNetwork": MessageLookupByLibrary.simpleMessage("Add Network"),
    "addProfile": MessageLookupByLibrary.simpleMessage("Add Profile"),
    "addProfileTitle": MessageLookupByLibrary.simpleMessage("Add profile"),
    "addProxies": MessageLookupByLibrary.simpleMessage("Add proxies"),
    "addProxyGroup": MessageLookupByLibrary.simpleMessage("Add proxy group"),
    "addProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Add proxy providers",
    ),
    "addRule": MessageLookupByLibrary.simpleMessage("Add rule"),
    "addSsid": MessageLookupByLibrary.simpleMessage("Add SSID"),
    "addedRules": MessageLookupByLibrary.simpleMessage("Added rules"),
    "additionalParameters": MessageLookupByLibrary.simpleMessage(
      "Additional parameters",
    ),
    "address": MessageLookupByLibrary.simpleMessage("Address"),
    "addressHelp": MessageLookupByLibrary.simpleMessage(
      "WebDAV server address",
    ),
    "addressTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a valid WebDAV address",
    ),
    "adjustFilters": MessageLookupByLibrary.simpleMessage(
      "Adjust the filters.",
    ),
    "advancedConfig": MessageLookupByLibrary.simpleMessage("Advanced settings"),
    "advancedConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Advanced config options",
    ),
    "agree": MessageLookupByLibrary.simpleMessage("Agree"),
    "allGreenLowLatency": MessageLookupByLibrary.simpleMessage(
      "Healthy & fast",
    ),
    "allowBypass": MessageLookupByLibrary.simpleMessage("Allow bypass"),
    "allowBypassDesc": MessageLookupByLibrary.simpleMessage(
      "Let selected apps bypass VPN",
    ),
    "allowLan": MessageLookupByLibrary.simpleMessage("Allow LAN access"),
    "allowLanDesc": MessageLookupByLibrary.simpleMessage(
      "Let devices on your LAN use this proxy",
    ),
    "allowUnknownAppInstall": MessageLookupByLibrary.simpleMessage(
      "Allow SlClash to install unknown apps, then tap Install.",
    ),
    "apkInstallAfterDownload": MessageLookupByLibrary.simpleMessage(
      "System installer will open after download.",
    ),
    "app": MessageLookupByLibrary.simpleMessage("App"),
    "appAccessControl": MessageLookupByLibrary.simpleMessage(
      "App access control",
    ),
    "appendSystemDns": MessageLookupByLibrary.simpleMessage("Add system DNS"),
    "appendSystemDnsTip": MessageLookupByLibrary.simpleMessage(
      "Add system DNS to config",
    ),
    "application": MessageLookupByLibrary.simpleMessage("Application"),
    "applicationDesc": MessageLookupByLibrary.simpleMessage(
      "Startup and app behavior",
    ),
    "authorized": MessageLookupByLibrary.simpleMessage("Authorized"),
    "auto": MessageLookupByLibrary.simpleMessage("Auto"),
    "autoCheckUpdate": MessageLookupByLibrary.simpleMessage("Check updates"),
    "autoCheckUpdateDesc": MessageLookupByLibrary.simpleMessage(
      "Check when the app starts",
    ),
    "autoCloseConnections": MessageLookupByLibrary.simpleMessage(
      "Close old connections",
    ),
    "autoCloseConnectionsDesc": MessageLookupByLibrary.simpleMessage(
      "After switching nodes",
    ),
    "autoLaunch": MessageLookupByLibrary.simpleMessage("Start automatically"),
    "autoLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Start SlClash when the device starts",
    ),
    "autoRun": MessageLookupByLibrary.simpleMessage("Auto-connect"),
    "autoRunDesc": MessageLookupByLibrary.simpleMessage(
      "Connect when SlClash opens",
    ),
    "autoSetSystemDns": MessageLookupByLibrary.simpleMessage(
      "Auto set system DNS",
    ),
    "autoUpdate": MessageLookupByLibrary.simpleMessage("Auto update"),
    "autoUpdateInterval": MessageLookupByLibrary.simpleMessage(
      "Update interval (min)",
    ),
    "backup": MessageLookupByLibrary.simpleMessage("Backup"),
    "backupAndRestore": MessageLookupByLibrary.simpleMessage(
      "Backup & Restore",
    ),
    "backupAndRestoreDesc": MessageLookupByLibrary.simpleMessage(
      "WebDAV or file sync",
    ),
    "backupSuccess": MessageLookupByLibrary.simpleMessage("Backup success"),
    "basicConfig": MessageLookupByLibrary.simpleMessage("Basic settings"),
    "basicConfigDesc": MessageLookupByLibrary.simpleMessage(
      "Core defaults and behavior",
    ),
    "basicInfo": MessageLookupByLibrary.simpleMessage("Basic info"),
    "basicStrategy": MessageLookupByLibrary.simpleMessage("Basic strategy"),
    "batteryOptimizationDesc": MessageLookupByLibrary.simpleMessage(
      "Disable battery optimization for background. Tap to settings.",
    ),
    "batteryOptimizationStatusTip": MessageLookupByLibrary.simpleMessage(
      "Status may not always be accurate.",
    ),
    "bind": MessageLookupByLibrary.simpleMessage("Bind"),
    "blacklistMode": MessageLookupByLibrary.simpleMessage("Blacklist mode"),
    "blocked": MessageLookupByLibrary.simpleMessage("Blocked"),
    "blueWhiteMonochrome": MessageLookupByLibrary.simpleMessage("Blue-white"),
    "blueWhiteMonochromeStyle": MessageLookupByLibrary.simpleMessage(
      "Blue-white monochrome",
    ),
    "bypassDomain": MessageLookupByLibrary.simpleMessage("Bypass list"),
    "bypassDomainDesc": MessageLookupByLibrary.simpleMessage(
      "For system proxy only",
    ),
    "cache": MessageLookupByLibrary.simpleMessage("Cache"),
    "cacheCorrupt": MessageLookupByLibrary.simpleMessage(
      "Cache corrupted. Clear it?",
    ),
    "cached": MessageLookupByLibrary.simpleMessage("Cached"),
    "cancel": MessageLookupByLibrary.simpleMessage("Cancel"),
    "cancelSelectAll": MessageLookupByLibrary.simpleMessage(
      "Cancel select all",
    ),
    "changelog": MessageLookupByLibrary.simpleMessage("Changelog"),
    "changelog204Item1": MessageLookupByLibrary.simpleMessage(
      "Local exports and WebDAV backups now use the native V1 package.",
    ),
    "changelog204Item2": MessageLookupByLibrary.simpleMessage(
      "SlClash exports can import into Clash Verge Rev to overwrite profiles.",
    ),
    "changelog204Item3": MessageLookupByLibrary.simpleMessage(
      "Restore updates profiles only, other settings unchanged.",
    ),
    "changelog205Item1": MessageLookupByLibrary.simpleMessage(
      "SlClash and Clash Verge Rev profile backups now support two-way import.",
    ),
    "changelog205Item2": MessageLookupByLibrary.simpleMessage(
      "Fixed the first backup failing when Unified Profile Center was not used.",
    ),
    "changelog205Item3": MessageLookupByLibrary.simpleMessage(
      "Improved compatibility and overwrite restore to avoid duplicates.",
    ),
    "changelog207Item1": MessageLookupByLibrary.simpleMessage(
      "Refined the global type hierarchy, text rendering, and information layout.",
    ),
    "changelog207Item2": MessageLookupByLibrary.simpleMessage(
      "Enabled two-way profile backup import between SlClash and Clash Verge Rev.",
    ),
    "changelog207Item3": MessageLookupByLibrary.simpleMessage(
      "Reduced unnecessary error prompts and interruptions.",
    ),
    "changelog207Item4": MessageLookupByLibrary.simpleMessage(
      "Improved runtime flow and overall stability.",
    ),
    "checkNetworkAndRetry": MessageLookupByLibrary.simpleMessage(
      "Check your network and try again.",
    ),
    "checkResultsAppearHere": MessageLookupByLibrary.simpleMessage(
      "Results appear here",
    ),
    "checkUpdate": MessageLookupByLibrary.simpleMessage("Check for updates"),
    "checkUpdateError": MessageLookupByLibrary.simpleMessage(
      "Already up to date",
    ),
    "checking": MessageLookupByLibrary.simpleMessage("Checking"),
    "chinaRouteCandidates": MessageLookupByLibrary.simpleMessage("CN route"),
    "clearData": MessageLookupByLibrary.simpleMessage("Clear Data"),
    "clipboardExport": MessageLookupByLibrary.simpleMessage("Export clipboard"),
    "clipboardImport": MessageLookupByLibrary.simpleMessage("Clipboard import"),
    "collapse": MessageLookupByLibrary.simpleMessage("Collapse"),
    "color": MessageLookupByLibrary.simpleMessage("Color"),
    "colorSchemes": MessageLookupByLibrary.simpleMessage("Color schemes"),
    "columns": MessageLookupByLibrary.simpleMessage("Columns"),
    "compatible": MessageLookupByLibrary.simpleMessage("Compatibility mode"),
    "concurrency": MessageLookupByLibrary.simpleMessage("Workers"),
    "configDataDetected": MessageLookupByLibrary.simpleMessage(
      "Data found in config",
    ),
    "confirm": MessageLookupByLibrary.simpleMessage("Confirm"),
    "confirmClearAllData": MessageLookupByLibrary.simpleMessage(
      "Clear all data?",
    ),
    "confirmDeleteProxyGroup": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to delete the current proxy group?",
    ),
    "confirmExitWindow": MessageLookupByLibrary.simpleMessage(
      "Exit current window?",
    ),
    "confirmFactoryReset": MessageLookupByLibrary.simpleMessage(
      "Factory reset? This cannot be undone.",
    ),
    "confirmForceCrashCore": MessageLookupByLibrary.simpleMessage(
      "Force crash core?",
    ),
    "confirmOverwriteTip": MessageLookupByLibrary.simpleMessage(
      "Existing data will be overwritten",
    ),
    "connected": MessageLookupByLibrary.simpleMessage("Connected"),
    "connecting": MessageLookupByLibrary.simpleMessage("Connecting..."),
    "connection": MessageLookupByLibrary.simpleMessage("Connection"),
    "connections": MessageLookupByLibrary.simpleMessage("Connections"),
    "connectionsDesc": MessageLookupByLibrary.simpleMessage(
      "Active connections",
    ),
    "connectivity": MessageLookupByLibrary.simpleMessage("Connectivity"),
    "content": MessageLookupByLibrary.simpleMessage("Content"),
    "contentColor": MessageLookupByLibrary.simpleMessage("Color"),
    "contentNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Content cannot be empty",
    ),
    "contentScheme": MessageLookupByLibrary.simpleMessage("Content"),
    "controlGlobalAddedRules": MessageLookupByLibrary.simpleMessage(
      "Control global added rules",
    ),
    "copy": MessageLookupByLibrary.simpleMessage("Copy"),
    "copyDetails": MessageLookupByLibrary.simpleMessage("Copy details"),
    "copyEnvVar": MessageLookupByLibrary.simpleMessage(
      "Copying environment variables",
    ),
    "copyLink": MessageLookupByLibrary.simpleMessage("Copy link"),
    "copySuccess": MessageLookupByLibrary.simpleMessage("Copy success"),
    "core": MessageLookupByLibrary.simpleMessage("Core"),
    "coreReleaseInfo": m0,
    "coreStatus": MessageLookupByLibrary.simpleMessage("Core status"),
    "country": MessageLookupByLibrary.simpleMessage("Country"),
    "crashTest": MessageLookupByLibrary.simpleMessage("Crash test"),
    "create": MessageLookupByLibrary.simpleMessage("Create"),
    "createProfile": MessageLookupByLibrary.simpleMessage("Create Profile"),
    "creationTime": MessageLookupByLibrary.simpleMessage("Creation time"),
    "currentProfileHasNoNodes": MessageLookupByLibrary.simpleMessage(
      "No nodes to display",
    ),
    "currentlyUsed": MessageLookupByLibrary.simpleMessage("In use"),
    "custom": MessageLookupByLibrary.simpleMessage("Custom"),
    "cut": MessageLookupByLibrary.simpleMessage("Cut"),
    "dark": MessageLookupByLibrary.simpleMessage("Dark"),
    "darkMonochrome": MessageLookupByLibrary.simpleMessage("Dark monochrome"),
    "darkMonochromeStyle": MessageLookupByLibrary.simpleMessage(
      "Dark monochrome",
    ),
    "dashboard": MessageLookupByLibrary.simpleMessage("Home"),
    "dataChangedSave": MessageLookupByLibrary.simpleMessage(
      "Data changed. Save?",
    ),
    "daysAgo": m1,
    "defaultNameserver": MessageLookupByLibrary.simpleMessage(
      "Default nameserver",
    ),
    "defaultNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resolve DNS server",
    ),
    "defaultText": MessageLookupByLibrary.simpleMessage("Default"),
    "delay": MessageLookupByLibrary.simpleMessage("Delay"),
    "delayTest": MessageLookupByLibrary.simpleMessage("Delay Test"),
    "delete": MessageLookupByLibrary.simpleMessage("Delete"),
    "deleteMultipTip": m2,
    "deleteTip": m3,
    "desc": MessageLookupByLibrary.simpleMessage(
      "Multi-platform proxy client based on ClashMeta. Simple, open-source, ad-free.",
    ),
    "destination": MessageLookupByLibrary.simpleMessage("Destination"),
    "destinationGeoIP": MessageLookupByLibrary.simpleMessage(
      "Destination GeoIP",
    ),
    "destinationIPASN": MessageLookupByLibrary.simpleMessage(
      "Destination IPASN",
    ),
    "details": m4,
    "detectionTip": MessageLookupByLibrary.simpleMessage(
      "Third-party API, for reference only",
    ),
    "developerMode": MessageLookupByLibrary.simpleMessage("Developer mode"),
    "developerModeEnableTip": MessageLookupByLibrary.simpleMessage(
      "Developer mode is enabled.",
    ),
    "direct": MessageLookupByLibrary.simpleMessage("Direct"),
    "disableUDP": MessageLookupByLibrary.simpleMessage("Disable UDP"),
    "disclaimer": MessageLookupByLibrary.simpleMessage("Disclaimer"),
    "disclaimerDesc": MessageLookupByLibrary.simpleMessage(
      "For non-commercial use only. Commercial use is prohibited.",
    ),
    "disconnected": MessageLookupByLibrary.simpleMessage("Disconnected"),
    "discoverNewVersion": MessageLookupByLibrary.simpleMessage(
      "New version available",
    ),
    "dnsDesc": MessageLookupByLibrary.simpleMessage("DNS settings"),
    "dnsHijacking": MessageLookupByLibrary.simpleMessage("DNS hijacking"),
    "dnsMode": MessageLookupByLibrary.simpleMessage("DNS mode"),
    "doYouWantToPass": MessageLookupByLibrary.simpleMessage(
      "Do you want to pass",
    ),
    "domain": MessageLookupByLibrary.simpleMessage("Domain"),
    "download": MessageLookupByLibrary.simpleMessage("Download"),
    "downloadUpdate": MessageLookupByLibrary.simpleMessage("Download update"),
    "downloadingApk": MessageLookupByLibrary.simpleMessage("Downloading APK"),
    "downloadingApkProgress": m5,
    "dynamicColor": MessageLookupByLibrary.simpleMessage("Dynamic color"),
    "edit": MessageLookupByLibrary.simpleMessage("Edit"),
    "editGlobalRules": MessageLookupByLibrary.simpleMessage(
      "Edit global rules",
    ),
    "editNetwork": MessageLookupByLibrary.simpleMessage("Edit Network"),
    "editProxy": MessageLookupByLibrary.simpleMessage("Edit proxy"),
    "editProxyGroup": MessageLookupByLibrary.simpleMessage("Edit proxy group"),
    "editRule": MessageLookupByLibrary.simpleMessage("Edit rule"),
    "editSsid": MessageLookupByLibrary.simpleMessage("Edit SSID"),
    "emptyTip": m6,
    "en": MessageLookupByLibrary.simpleMessage("English"),
    "entries": MessageLookupByLibrary.simpleMessage(" entries"),
    "errorDetails": MessageLookupByLibrary.simpleMessage("Error details"),
    "errorDetailsCopied": MessageLookupByLibrary.simpleMessage(
      "Error details copied to clipboard",
    ),
    "exclude": MessageLookupByLibrary.simpleMessage("Hide from Recents"),
    "excludeDesc": MessageLookupByLibrary.simpleMessage(
      "Hide from Android\'s Recents list",
    ),
    "excludeProxyFilter": MessageLookupByLibrary.simpleMessage(
      "Exclude proxy filter",
    ),
    "excludeSsids": MessageLookupByLibrary.simpleMessage("Exclude SSIDs"),
    "excludeSsidsDesc": MessageLookupByLibrary.simpleMessage(
      "Auto-switch when connected to excluded SSID.",
    ),
    "excludeType": MessageLookupByLibrary.simpleMessage("Exclude type"),
    "existsTip": m7,
    "exit": MessageLookupByLibrary.simpleMessage("Exit"),
    "expand": MessageLookupByLibrary.simpleMessage("Expand"),
    "expandCurrentProfileNodes": MessageLookupByLibrary.simpleMessage(
      "Show profile nodes",
    ),
    "expectedStatus": MessageLookupByLibrary.simpleMessage("Expected status"),
    "expired": MessageLookupByLibrary.simpleMessage("Expired"),
    "exportFile": MessageLookupByLibrary.simpleMessage("Export file"),
    "exportLogs": MessageLookupByLibrary.simpleMessage("Export logs"),
    "exportSuccess": MessageLookupByLibrary.simpleMessage("Export Success"),
    "expressiveScheme": MessageLookupByLibrary.simpleMessage("Expressive"),
    "externalController": MessageLookupByLibrary.simpleMessage(
      "ExternalController",
    ),
    "externalControllerDesc": MessageLookupByLibrary.simpleMessage(
      "Control Clash kernel on port 9090",
    ),
    "externalFetch": MessageLookupByLibrary.simpleMessage("External fetch"),
    "externalLink": MessageLookupByLibrary.simpleMessage("External link"),
    "factoryReset": MessageLookupByLibrary.simpleMessage("Factory Reset"),
    "factoryResetDesc": MessageLookupByLibrary.simpleMessage(
      "Clear all data, restore defaults",
    ),
    "fakeipFilter": MessageLookupByLibrary.simpleMessage("Fakeip filter"),
    "fakeipRange": MessageLookupByLibrary.simpleMessage("Fakeip range"),
    "fallback": MessageLookupByLibrary.simpleMessage("Fallback"),
    "fallbackDesc": MessageLookupByLibrary.simpleMessage("Use offshore DNS"),
    "fallbackFilter": MessageLookupByLibrary.simpleMessage("Fallback filter"),
    "fetchingProviderNodes": MessageLookupByLibrary.simpleMessage(
      "Fetching provider nodes...",
    ),
    "fidelityScheme": MessageLookupByLibrary.simpleMessage("Fidelity"),
    "file": MessageLookupByLibrary.simpleMessage("File"),
    "fileDesc": MessageLookupByLibrary.simpleMessage("Directly upload profile"),
    "fileIsUpdate": MessageLookupByLibrary.simpleMessage(
      "File modified. Save changes?",
    ),
    "findProcessMode": MessageLookupByLibrary.simpleMessage("Find process"),
    "findProcessModeDesc": MessageLookupByLibrary.simpleMessage(
      "May reduce performance when enabled",
    ),
    "followMaterialYou": m8,
    "fontFamily": MessageLookupByLibrary.simpleMessage("FontFamily"),
    "forceRestartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Force restart core?",
    ),
    "fruitSaladScheme": MessageLookupByLibrary.simpleMessage("FruitSalad"),
    "general": MessageLookupByLibrary.simpleMessage("General"),
    "geodataLoader": MessageLookupByLibrary.simpleMessage(
      "Geo Low Memory Mode",
    ),
    "geodataLoaderDesc": MessageLookupByLibrary.simpleMessage(
      "Use Geo low memory loader",
    ),
    "geoipCode": MessageLookupByLibrary.simpleMessage("Geoip code"),
    "global": MessageLookupByLibrary.simpleMessage("Global"),
    "go": MessageLookupByLibrary.simpleMessage("Go"),
    "goDownload": MessageLookupByLibrary.simpleMessage("Download"),
    "goToConfigureScript": MessageLookupByLibrary.simpleMessage(
      "Go to configure script",
    ),
    "gptUnlock": MessageLookupByLibrary.simpleMessage("GPT access"),
    "greenStreak": m9,
    "hasCacheChange": MessageLookupByLibrary.simpleMessage("Cache changes?"),
    "health": MessageLookupByLibrary.simpleMessage("Health"),
    "healthHistorySummary": m10,
    "healthMonitoring": MessageLookupByLibrary.simpleMessage("Health monitor"),
    "hideFromList": MessageLookupByLibrary.simpleMessage("Hide from list"),
    "historicallyStable": MessageLookupByLibrary.simpleMessage("Stable"),
    "host": MessageLookupByLibrary.simpleMessage("Host"),
    "hostsDesc": MessageLookupByLibrary.simpleMessage("Add Hosts"),
    "hotkeyConflict": MessageLookupByLibrary.simpleMessage("Hotkey conflict"),
    "hotkeyManagement": MessageLookupByLibrary.simpleMessage(
      "Hotkey Management",
    ),
    "hotkeyManagementDesc": MessageLookupByLibrary.simpleMessage(
      "Use keyboard to control applications",
    ),
    "hoursAgo": m11,
    "icon": MessageLookupByLibrary.simpleMessage("Icon"),
    "iconRecords": MessageLookupByLibrary.simpleMessage("Icon records"),
    "iconStyle": MessageLookupByLibrary.simpleMessage("Icon style"),
    "iconUrl": MessageLookupByLibrary.simpleMessage("Icon URL"),
    "ignoreBatteryOptimization": MessageLookupByLibrary.simpleMessage(
      "Ignore Battery Optimization",
    ),
    "import": MessageLookupByLibrary.simpleMessage("Import"),
    "importFile": MessageLookupByLibrary.simpleMessage("Import from file"),
    "importFromURL": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "importUrl": MessageLookupByLibrary.simpleMessage("Import from URL"),
    "includeAllProxies": MessageLookupByLibrary.simpleMessage(
      "Include all proxies",
    ),
    "includeAllProxiesTip": MessageLookupByLibrary.simpleMessage(
      "Import all proxies (excluding groups). Add groups below.",
    ),
    "includeAllProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Include all proxy providers",
    ),
    "includeAllProxyProvidersTip": MessageLookupByLibrary.simpleMessage(
      "Overrides imported proxy providers",
    ),
    "infiniteTime": MessageLookupByLibrary.simpleMessage("Long term effective"),
    "init": MessageLookupByLibrary.simpleMessage("Init"),
    "initFailed": MessageLookupByLibrary.simpleMessage("Initialization failed"),
    "initFailedDescription": MessageLookupByLibrary.simpleMessage(
      "Critical error on startup. Cannot continue.",
    ),
    "inputCorrectHotkey": MessageLookupByLibrary.simpleMessage(
      "Please enter the correct hotkey",
    ),
    "inputProxyGroupName": MessageLookupByLibrary.simpleMessage(
      "Input proxy group name",
    ),
    "inputRuleContent": MessageLookupByLibrary.simpleMessage(
      "Input rule content",
    ),
    "intelligentSelected": MessageLookupByLibrary.simpleMessage(
      "Intelligent selection",
    ),
    "internet": MessageLookupByLibrary.simpleMessage("Internet"),
    "interval": MessageLookupByLibrary.simpleMessage("Interval"),
    "intranetIP": MessageLookupByLibrary.simpleMessage("Intranet IP"),
    "invalidBackupFile": MessageLookupByLibrary.simpleMessage(
      "Invalid backup file",
    ),
    "invalidPolicy": m12,
    "invalidProxy": m13,
    "invalidProxyProvider": m14,
    "invalidSubRule": m15,
    "ipcidr": MessageLookupByLibrary.simpleMessage("Ipcidr"),
    "ipv6Desc": MessageLookupByLibrary.simpleMessage(
      "Receive IPv6 traffic when enabled",
    ),
    "ipv6InboundDesc": MessageLookupByLibrary.simpleMessage(
      "Allow IPv6 inbound",
    ),
    "justNow": MessageLookupByLibrary.simpleMessage("Just now"),
    "keepAliveIntervalDesc": MessageLookupByLibrary.simpleMessage(
      "Tcp keep alive interval",
    ),
    "key": MessageLookupByLibrary.simpleMessage("Key"),
    "language": MessageLookupByLibrary.simpleMessage("Language"),
    "lastCheckedAt": m16,
    "layout": MessageLookupByLibrary.simpleMessage("Layout"),
    "light": MessageLookupByLibrary.simpleMessage("Light"),
    "list": MessageLookupByLibrary.simpleMessage("List"),
    "listen": MessageLookupByLibrary.simpleMessage("Listen"),
    "loadTest": MessageLookupByLibrary.simpleMessage("Load test"),
    "loading": MessageLookupByLibrary.simpleMessage("Loading..."),
    "local": MessageLookupByLibrary.simpleMessage("Local"),
    "localBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Save a local backup",
    ),
    "localFile": MessageLookupByLibrary.simpleMessage("Local file"),
    "locateCurrentNode": MessageLookupByLibrary.simpleMessage(
      "Locate current node",
    ),
    "locationPermission": MessageLookupByLibrary.simpleMessage(
      "Location Permission",
    ),
    "locationPermissionDeniedMessage": MessageLookupByLibrary.simpleMessage(
      "Location denied. Enable in Settings to get Wi-Fi name.",
    ),
    "locationPermissionDesc": MessageLookupByLibrary.simpleMessage(
      "Wi-Fi name requires location permission.",
    ),
    "locationPermissionGuide": m17,
    "locationPermissionRequired": MessageLookupByLibrary.simpleMessage(
      "Location Permission Required",
    ),
    "log": MessageLookupByLibrary.simpleMessage("Log"),
    "logLevel": MessageLookupByLibrary.simpleMessage("Log level"),
    "logcat": MessageLookupByLibrary.simpleMessage("Logcat"),
    "logcatDesc": MessageLookupByLibrary.simpleMessage(
      "Disabling will hide the log entry",
    ),
    "logs": MessageLookupByLibrary.simpleMessage("Logs"),
    "logsDesc": MessageLookupByLibrary.simpleMessage("App logs"),
    "logsTest": MessageLookupByLibrary.simpleMessage("Logs test"),
    "loopback": MessageLookupByLibrary.simpleMessage("Loopback unlock tool"),
    "loopbackDesc": MessageLookupByLibrary.simpleMessage(
      "Used for UWP loopback unlocking",
    ),
    "loose": MessageLookupByLibrary.simpleMessage("Loose"),
    "manual": MessageLookupByLibrary.simpleMessage("Manual"),
    "matchSourceIp": MessageLookupByLibrary.simpleMessage("Match source IP"),
    "maxFailedTimes": MessageLookupByLibrary.simpleMessage("Max failed times"),
    "mediaCheck": MessageLookupByLibrary.simpleMessage("Media check"),
    "mediaCheckByProfileDesc": MessageLookupByLibrary.simpleMessage(
      "Manual per profile · Cached",
    ),
    "mediaCheckDesc": MessageLookupByLibrary.simpleMessage(
      "Manual check · Cached results",
    ),
    "memoryInfo": MessageLookupByLibrary.simpleMessage("Memory info"),
    "messageTest": MessageLookupByLibrary.simpleMessage("Message test"),
    "messageTestTip": MessageLookupByLibrary.simpleMessage(
      "This is a message.",
    ),
    "min": MessageLookupByLibrary.simpleMessage("Min"),
    "minimizeOnExit": MessageLookupByLibrary.simpleMessage("Minimize on exit"),
    "minimizeOnExitDesc": MessageLookupByLibrary.simpleMessage(
      "Modify the default system exit event",
    ),
    "minutesAgo": m18,
    "mixedPort": MessageLookupByLibrary.simpleMessage("Mixed Port"),
    "mode": MessageLookupByLibrary.simpleMessage("Mode"),
    "modeDescription": m19,
    "monochrome": MessageLookupByLibrary.simpleMessage("Mono"),
    "monochromeScheme": MessageLookupByLibrary.simpleMessage("Monochrome"),
    "monthsAgo": m20,
    "more": MessageLookupByLibrary.simpleMessage("More"),
    "name": MessageLookupByLibrary.simpleMessage("Name"),
    "nameserver": MessageLookupByLibrary.simpleMessage("Nameserver"),
    "nameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resolve domain names",
    ),
    "nameserverPolicy": MessageLookupByLibrary.simpleMessage(
      "Nameserver policy",
    ),
    "nameserverPolicyDesc": MessageLookupByLibrary.simpleMessage(
      "Set nameserver policy",
    ),
    "network": MessageLookupByLibrary.simpleMessage("Network"),
    "networkAddress": MessageLookupByLibrary.simpleMessage("Network Address"),
    "networkAddressHint": MessageLookupByLibrary.simpleMessage(
      "e.g. 192.168.1.0/24 or 10.0.0.1",
    ),
    "networkDesc": MessageLookupByLibrary.simpleMessage(
      "VPN and routing settings",
    ),
    "networkDetection": MessageLookupByLibrary.simpleMessage("IP check"),
    "networkException": MessageLookupByLibrary.simpleMessage(
      "Network error. Check connection and retry.",
    ),
    "networkOverview": MessageLookupByLibrary.simpleMessage("Network"),
    "networkSpeed": MessageLookupByLibrary.simpleMessage("Network speed"),
    "networkType": MessageLookupByLibrary.simpleMessage("Network type"),
    "networksEmpty": MessageLookupByLibrary.simpleMessage(
      "No trusted networks configured",
    ),
    "neutralScheme": MessageLookupByLibrary.simpleMessage("Neutral"),
    "neverExpires": MessageLookupByLibrary.simpleMessage("Never"),
    "newVersion": MessageLookupByLibrary.simpleMessage("New version"),
    "noAvailableBackups": MessageLookupByLibrary.simpleMessage(
      "No backups available",
    ),
    "noAvailableNodesInProfile": MessageLookupByLibrary.simpleMessage(
      "No available nodes in profile",
    ),
    "noCache": MessageLookupByLibrary.simpleMessage("No cache"),
    "noData": MessageLookupByLibrary.simpleMessage("No data"),
    "noFilteredResults": m21,
    "noHistory": MessageLookupByLibrary.simpleMessage("No history"),
    "noHotKey": MessageLookupByLibrary.simpleMessage("No HotKey"),
    "noInfo": MessageLookupByLibrary.simpleMessage("No info"),
    "noLongerRemind": MessageLookupByLibrary.simpleMessage(
      "Don\'t remind again",
    ),
    "noMatchingProxyGroups": MessageLookupByLibrary.simpleMessage(
      "No matching groups",
    ),
    "noNetwork": MessageLookupByLibrary.simpleMessage("No network"),
    "noNetworkApp": MessageLookupByLibrary.simpleMessage("No network APP"),
    "noNodesToCheck": MessageLookupByLibrary.simpleMessage("No nodes to check"),
    "noProfiles": MessageLookupByLibrary.simpleMessage("No profiles"),
    "noProxyGroups": MessageLookupByLibrary.simpleMessage("No proxy groups"),
    "noRecords": MessageLookupByLibrary.simpleMessage("No records"),
    "noResolve": MessageLookupByLibrary.simpleMessage("No resolve IP"),
    "noResolveHostname": MessageLookupByLibrary.simpleMessage(
      "No resolve hostname",
    ),
    "nodeCheckup": MessageLookupByLibrary.simpleMessage("Node check"),
    "nodeList": MessageLookupByLibrary.simpleMessage("Node list"),
    "nodes": MessageLookupByLibrary.simpleMessage("Nodes"),
    "none": MessageLookupByLibrary.simpleMessage("none"),
    "notChecked": MessageLookupByLibrary.simpleMessage("Not run"),
    "notEnoughHistory": MessageLookupByLibrary.simpleMessage(
      "Not enough history",
    ),
    "notReady": MessageLookupByLibrary.simpleMessage("Not ready"),
    "notSelectedTip": MessageLookupByLibrary.simpleMessage(
      "The current proxy group cannot be selected.",
    ),
    "nullProfileDesc": MessageLookupByLibrary.simpleMessage(
      "No profiles yet. Add one to get started.",
    ),
    "nullTip": m22,
    "numberTip": m23,
    "onDemand": MessageLookupByLibrary.simpleMessage("On Demand"),
    "onDemandDesc": MessageLookupByLibrary.simpleMessage(
      "Configure running state for scenarios",
    ),
    "onlyIcon": MessageLookupByLibrary.simpleMessage("Icon"),
    "onlyStatisticsProxy": MessageLookupByLibrary.simpleMessage(
      "Proxy traffic only",
    ),
    "onlyStatisticsProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Exclude traffic sent through DIRECT",
    ),
    "openResourceAutoUpdateSettings": MessageLookupByLibrary.simpleMessage(
      "Open auto-update settings",
    ),
    "optional": MessageLookupByLibrary.simpleMessage("Optional"),
    "options": MessageLookupByLibrary.simpleMessage("Options"),
    "other": MessageLookupByLibrary.simpleMessage("Other"),
    "otherContributors": MessageLookupByLibrary.simpleMessage(
      "Other contributors",
    ),
    "outboundMode": MessageLookupByLibrary.simpleMessage("Outbound mode"),
    "outboundTraffic": MessageLookupByLibrary.simpleMessage("Route"),
    "override": MessageLookupByLibrary.simpleMessage("Override"),
    "overrideDns": MessageLookupByLibrary.simpleMessage("Override DNS"),
    "overrideDnsDesc": MessageLookupByLibrary.simpleMessage(
      "Override profile DNS",
    ),
    "overrideMode": MessageLookupByLibrary.simpleMessage("Override mode"),
    "overrideScript": MessageLookupByLibrary.simpleMessage("Override script"),
    "overwriteTypeCustom": MessageLookupByLibrary.simpleMessage("Custom"),
    "overwriteTypeCustomDesc": MessageLookupByLibrary.simpleMessage(
      "Custom mode: fully customize groups & rules",
    ),
    "palette": MessageLookupByLibrary.simpleMessage("Palette"),
    "password": MessageLookupByLibrary.simpleMessage("Password"),
    "paste": MessageLookupByLibrary.simpleMessage("Paste"),
    "pausing": MessageLookupByLibrary.simpleMessage("Pausing"),
    "pleaseBindWebDAV": MessageLookupByLibrary.simpleMessage(
      "Please bind WebDAV",
    ),
    "pleaseEnterScriptName": MessageLookupByLibrary.simpleMessage(
      "Please enter a script name",
    ),
    "pleaseInputAdminPassword": MessageLookupByLibrary.simpleMessage(
      "Enter admin password",
    ),
    "pleaseUploadValidQrcode": MessageLookupByLibrary.simpleMessage(
      "Please upload a valid QR code",
    ),
    "port": MessageLookupByLibrary.simpleMessage("Port"),
    "portConflictTip": MessageLookupByLibrary.simpleMessage(
      "Please enter a different port",
    ),
    "portTip": m24,
    "possiblyRoutedToChina": MessageLookupByLibrary.simpleMessage(
      "Possibly routed to China",
    ),
    "preferH3Desc": MessageLookupByLibrary.simpleMessage(
      "Prioritize DOH http/3",
    ),
    "prerequisites": MessageLookupByLibrary.simpleMessage("Prerequisites"),
    "pressKeyboard": MessageLookupByLibrary.simpleMessage(
      "Please press the keyboard.",
    ),
    "preview": MessageLookupByLibrary.simpleMessage("Preview"),
    "process": MessageLookupByLibrary.simpleMessage("Process"),
    "profile": MessageLookupByLibrary.simpleMessage("Profile"),
    "profileAutoUpdateIntervalInvalidValidationDesc":
        MessageLookupByLibrary.simpleMessage("Invalid interval format"),
    "profileAutoUpdateIntervalNullValidationDesc":
        MessageLookupByLibrary.simpleMessage("Enter interval time (min)"),
    "profileHasUpdate": MessageLookupByLibrary.simpleMessage(
      "Profile modified. Disable auto update?",
    ),
    "profileManagement": MessageLookupByLibrary.simpleMessage(
      "Profile management",
    ),
    "profileNameNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Enter profile name",
    ),
    "profileSort": MessageLookupByLibrary.simpleMessage("Sort profiles"),
    "profileUrlInvalidValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Invalid profile URL",
    ),
    "profileUrlNullValidationDesc": MessageLookupByLibrary.simpleMessage(
      "Enter profile URL",
    ),
    "profiles": MessageLookupByLibrary.simpleMessage("Profiles"),
    "profilesRestored": MessageLookupByLibrary.simpleMessage(
      "Profile data restored.",
    ),
    "profilesRestoredProxyNotLoaded": MessageLookupByLibrary.simpleMessage(
      "Profiles restored, proxy not loaded yet.",
    ),
    "profilesSort": MessageLookupByLibrary.simpleMessage("Sort profiles"),
    "project": MessageLookupByLibrary.simpleMessage("Project"),
    "providerLoadFailed": MessageLookupByLibrary.simpleMessage(
      "Provider failed to load",
    ),
    "providerNotReady": MessageLookupByLibrary.simpleMessage(
      "Provider is not ready",
    ),
    "providers": MessageLookupByLibrary.simpleMessage("Providers"),
    "proxies": MessageLookupByLibrary.simpleMessage("Proxies"),
    "proxiesEmpty": MessageLookupByLibrary.simpleMessage("Proxies is empty"),
    "proxyChains": MessageLookupByLibrary.simpleMessage("Proxy chains"),
    "proxyCoreCannotReadProvider": MessageLookupByLibrary.simpleMessage(
      "Proxy core unavailable. Cannot read Provider nodes.",
    ),
    "proxyCoreCannotValidateBackup": MessageLookupByLibrary.simpleMessage(
      "Proxy core unavailable. Cannot validate backup subscriptions.",
    ),
    "proxyCoreUnavailable": MessageLookupByLibrary.simpleMessage(
      "Proxy core is unavailable",
    ),
    "proxyDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Selected proxies are abnormal",
    ),
    "proxyFilter": MessageLookupByLibrary.simpleMessage("Proxy filter"),
    "proxyGroup": MessageLookupByLibrary.simpleMessage("Proxy group"),
    "proxyGroupDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Current proxy group is abnormal",
    ),
    "proxyGroupEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy group is empty",
    ),
    "proxyGroupNameDuplicate": MessageLookupByLibrary.simpleMessage(
      "Duplicate group name",
    ),
    "proxyGroupNameEmpty": MessageLookupByLibrary.simpleMessage(
      "Group name required",
    ),
    "proxyNameserver": MessageLookupByLibrary.simpleMessage("Proxy nameserver"),
    "proxyNameserverDesc": MessageLookupByLibrary.simpleMessage(
      "Resolve proxy node domains",
    ),
    "proxyPort": MessageLookupByLibrary.simpleMessage("ProxyPort"),
    "proxyProviderDetectedAbnormal": MessageLookupByLibrary.simpleMessage(
      "Selected proxy providers are abnormal",
    ),
    "proxyProviders": MessageLookupByLibrary.simpleMessage("Proxy providers"),
    "proxyProvidersEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy providers is empty",
    ),
    "proxyProvidersNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Proxy providers cannot be empty",
    ),
    "proxyType": MessageLookupByLibrary.simpleMessage("Proxy type"),
    "pruneCache": MessageLookupByLibrary.simpleMessage("Prune cache"),
    "pureBlackMode": MessageLookupByLibrary.simpleMessage("Pure black mode"),
    "qrcode": MessageLookupByLibrary.simpleMessage("QR code"),
    "qrcodeDesc": MessageLookupByLibrary.simpleMessage(
      "Scan QR code to obtain profile",
    ),
    "quickFill": MessageLookupByLibrary.simpleMessage("Quick fill"),
    "rainbowScheme": MessageLookupByLibrary.simpleMessage("Rainbow"),
    "reading": MessageLookupByLibrary.simpleMessage("Reading"),
    "readingBackups": MessageLookupByLibrary.simpleMessage(
      "Reading backups...",
    ),
    "readingCurrentProfileNodes": MessageLookupByLibrary.simpleMessage(
      "Reading profile nodes...",
    ),
    "reconnect": MessageLookupByLibrary.simpleMessage("Reconnect"),
    "reconnectPrompt": MessageLookupByLibrary.simpleMessage(
      "Please reconnect.",
    ),
    "redirPort": MessageLookupByLibrary.simpleMessage("Redir Port"),
    "redo": MessageLookupByLibrary.simpleMessage("redo"),
    "refreshProxyGroups": MessageLookupByLibrary.simpleMessage(
      "Refresh proxy groups",
    ),
    "reload": MessageLookupByLibrary.simpleMessage("Reload"),
    "remote": MessageLookupByLibrary.simpleMessage("Remote"),
    "remoteBackupDesc": MessageLookupByLibrary.simpleMessage(
      "Back up to WebDAV",
    ),
    "remoteDestination": MessageLookupByLibrary.simpleMessage(
      "Remote destination",
    ),
    "remove": MessageLookupByLibrary.simpleMessage("Remove"),
    "rename": MessageLookupByLibrary.simpleMessage("Rename"),
    "request": MessageLookupByLibrary.simpleMessage("Request"),
    "requests": MessageLookupByLibrary.simpleMessage("Requests"),
    "requestsDesc": MessageLookupByLibrary.simpleMessage("Recent requests"),
    "reset": MessageLookupByLibrary.simpleMessage("Reset"),
    "resetPageChangesTip": MessageLookupByLibrary.simpleMessage(
      "Page has changes. Reset?",
    ),
    "resetTip": MessageLookupByLibrary.simpleMessage("Make sure to reset"),
    "resourceAutoDailyStatus": MessageLookupByLibrary.simpleMessage(
      "Auto: daily",
    ),
    "resourceAutoSevenDaysStatus": MessageLookupByLibrary.simpleMessage(
      "Auto: every 7 days",
    ),
    "resourceAutoThreeDaysStatus": MessageLookupByLibrary.simpleMessage(
      "Auto: every 3 days",
    ),
    "resourceAutoUpdate": MessageLookupByLibrary.simpleMessage(
      "Automatic resource updates",
    ),
    "resourceDailyDesc": MessageLookupByLibrary.simpleMessage(
      "Update on first daily open",
    ),
    "resourceManualOnly": MessageLookupByLibrary.simpleMessage(
      "Manual update only",
    ),
    "resourceSevenDaysDesc": MessageLookupByLibrary.simpleMessage(
      "Update every 7 days",
    ),
    "resourceThreeDaysDesc": MessageLookupByLibrary.simpleMessage(
      "Update every 3 days",
    ),
    "resourceUpdateDaily": MessageLookupByLibrary.simpleMessage("Daily"),
    "resourceUpdateEverySevenDays": MessageLookupByLibrary.simpleMessage(
      "Every 7 days",
    ),
    "resourceUpdateEveryThreeDays": MessageLookupByLibrary.simpleMessage(
      "Every 3 days",
    ),
    "resourceUpdateOff": MessageLookupByLibrary.simpleMessage("Off"),
    "resourceUpdateTriggerHint": MessageLookupByLibrary.simpleMessage(
      "Triggers on first open of Resources page",
    ),
    "resources": MessageLookupByLibrary.simpleMessage("Resources"),
    "resourcesDesc": MessageLookupByLibrary.simpleMessage("Resource files"),
    "respectRules": MessageLookupByLibrary.simpleMessage("Respect rules"),
    "respectRulesDesc": MessageLookupByLibrary.simpleMessage(
      "Follow rules; requires proxy nameserver",
    ),
    "restart": MessageLookupByLibrary.simpleMessage("Restart"),
    "restartCoreTip": MessageLookupByLibrary.simpleMessage(
      "Are you sure you want to restart the core?",
    ),
    "restore": MessageLookupByLibrary.simpleMessage("Restore"),
    "restoreAllData": MessageLookupByLibrary.simpleMessage("Restore all data"),
    "restoreException": MessageLookupByLibrary.simpleMessage(
      "Recovery exception",
    ),
    "restoreFromFileDesc": MessageLookupByLibrary.simpleMessage(
      "Restore via file",
    ),
    "restoreFromWebDAVDesc": MessageLookupByLibrary.simpleMessage(
      "Restore via WebDAV",
    ),
    "restoreNamedBackup": m25,
    "restoreOnlyConfig": MessageLookupByLibrary.simpleMessage(
      "Restore config files only",
    ),
    "restoreProfilesOnlyDesc": MessageLookupByLibrary.simpleMessage(
      "Restores subscriptions & nodes only. Other settings unchanged.",
    ),
    "restoreProfilesOnlyWarning": MessageLookupByLibrary.simpleMessage(
      "Restores profiles only. Other settings unchanged.",
    ),
    "restoreStrategy": MessageLookupByLibrary.simpleMessage("Restore strategy"),
    "restoreStrategy_compatible": MessageLookupByLibrary.simpleMessage(
      "Compatible",
    ),
    "restoreStrategy_override": MessageLookupByLibrary.simpleMessage(
      "Override",
    ),
    "restoreSuccess": MessageLookupByLibrary.simpleMessage("Restore success"),
    "resume": MessageLookupByLibrary.simpleMessage("Resume"),
    "resuming": MessageLookupByLibrary.simpleMessage("Resuming"),
    "routeAddress": MessageLookupByLibrary.simpleMessage("Route address"),
    "routeAddressDesc": MessageLookupByLibrary.simpleMessage(
      "Set listen route address",
    ),
    "routeMode": MessageLookupByLibrary.simpleMessage("Route mode"),
    "routeMode_bypassPrivate": MessageLookupByLibrary.simpleMessage(
      "Bypass private routes",
    ),
    "routeMode_config": MessageLookupByLibrary.simpleMessage("Use config"),
    "routedToChina": MessageLookupByLibrary.simpleMessage("Routed to China"),
    "rule": MessageLookupByLibrary.simpleMessage("Rule"),
    "ruleActionAndDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule AND",
    ),
    "ruleActionDomainDesc": MessageLookupByLibrary.simpleMessage(
      "Match full domain",
    ),
    "ruleActionDomainKeywordDesc": MessageLookupByLibrary.simpleMessage(
      "Match domain keyword",
    ),
    "ruleActionDomainRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Wildcard match (* and ? only)",
    ),
    "ruleActionDomainSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match domain suffix",
    ),
    "ruleActionDscpDesc": MessageLookupByLibrary.simpleMessage(
      "Match DSCP mark (tproxy UDP only)",
    ),
    "ruleActionDstPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match request target port range",
    ),
    "ruleActionGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP\'s country code",
    ),
    "ruleActionGeositeDesc": MessageLookupByLibrary.simpleMessage(
      "Match domains within Geosite",
    ),
    "ruleActionInNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound name",
    ),
    "ruleActionInPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound port",
    ),
    "ruleActionInTypeDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound type",
    ),
    "ruleActionInUserDesc": MessageLookupByLibrary.simpleMessage(
      "Match inbound username (/ separated)",
    ),
    "ruleActionIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP\'s ASN",
    ),
    "ruleActionIpCidr6Desc": MessageLookupByLibrary.simpleMessage(
      "Match IP range (alias for IP-CIDR)",
    ),
    "ruleActionIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP address range",
    ),
    "ruleActionIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match IP suffix range",
    ),
    "ruleActionMatchDesc": MessageLookupByLibrary.simpleMessage(
      "Match all requests, no conditions needed",
    ),
    "ruleActionNetworkDesc": MessageLookupByLibrary.simpleMessage(
      "Match TCP or UDP",
    ),
    "ruleActionNotDesc": MessageLookupByLibrary.simpleMessage(
      "Logical rule NOT",
    ),
    "ruleActionOrDesc": MessageLookupByLibrary.simpleMessage("Logical rule OR"),
    "ruleActionProcessNameDesc": MessageLookupByLibrary.simpleMessage(
      "Match process name (package on Android)",
    ),
    "ruleActionProcessNameRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match process name regex (package on Android)",
    ),
    "ruleActionProcessPathDesc": MessageLookupByLibrary.simpleMessage(
      "Match using full process path",
    ),
    "ruleActionProcessPathRegexDesc": MessageLookupByLibrary.simpleMessage(
      "Match using process path regex",
    ),
    "ruleActionRuleSetDesc": MessageLookupByLibrary.simpleMessage(
      "Reference rule set (requires rule-providers)",
    ),
    "ruleActionSrcGeoipDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP\'s country code",
    ),
    "ruleActionSrcIpAsnDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP\'s ASN",
    ),
    "ruleActionSrcIpCidrDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP address range",
    ),
    "ruleActionSrcIpSuffixDesc": MessageLookupByLibrary.simpleMessage(
      "Match source IP suffix range",
    ),
    "ruleActionSrcPortDesc": MessageLookupByLibrary.simpleMessage(
      "Match request source port range",
    ),
    "ruleActionSubRuleDesc": MessageLookupByLibrary.simpleMessage(
      "Match sub-rule (use parentheses carefully)",
    ),
    "ruleActionUidDesc": MessageLookupByLibrary.simpleMessage(
      "Match Linux USER ID",
    ),
    "ruleEmpty": MessageLookupByLibrary.simpleMessage("Rule is empty"),
    "ruleName": MessageLookupByLibrary.simpleMessage("Rule name"),
    "ruleProviders": MessageLookupByLibrary.simpleMessage("Rule providers"),
    "ruleSet": MessageLookupByLibrary.simpleMessage("Rule set"),
    "ruleTarget": MessageLookupByLibrary.simpleMessage("Rule target"),
    "running": MessageLookupByLibrary.simpleMessage("Running"),
    "save": MessageLookupByLibrary.simpleMessage("Save"),
    "saveChanges": MessageLookupByLibrary.simpleMessage(
      "Do you want to save the changes?",
    ),
    "script": MessageLookupByLibrary.simpleMessage("Script"),
    "scriptModeDesc": MessageLookupByLibrary.simpleMessage(
      "Script mode: use external scripts to override config",
    ),
    "search": MessageLookupByLibrary.simpleMessage("Search"),
    "seconds": MessageLookupByLibrary.simpleMessage("Seconds"),
    "selectAll": MessageLookupByLibrary.simpleMessage("Select all"),
    "selectBackup": MessageLookupByLibrary.simpleMessage("Select backup"),
    "selectProfile": MessageLookupByLibrary.simpleMessage("Select profile"),
    "selectProxies": MessageLookupByLibrary.simpleMessage("Select proxies"),
    "selectProxyProviders": MessageLookupByLibrary.simpleMessage(
      "Select proxy providers",
    ),
    "selectRestoreStrategy": MessageLookupByLibrary.simpleMessage(
      "Select a restore method.",
    ),
    "selectRuleSet": MessageLookupByLibrary.simpleMessage(
      "Please select rule set",
    ),
    "selectSplitStrategy": MessageLookupByLibrary.simpleMessage(
      "Please select split strategy",
    ),
    "selectSubRule": MessageLookupByLibrary.simpleMessage(
      "Please select sub rule",
    ),
    "selectTestItem": MessageLookupByLibrary.simpleMessage("Select check"),
    "selected": MessageLookupByLibrary.simpleMessage("Selected"),
    "selectedCountTitle": m26,
    "settings": MessageLookupByLibrary.simpleMessage("Settings"),
    "show": MessageLookupByLibrary.simpleMessage("Show"),
    "shrink": MessageLookupByLibrary.simpleMessage("Shrink"),
    "silentLaunch": MessageLookupByLibrary.simpleMessage("Start in background"),
    "silentLaunchDesc": MessageLookupByLibrary.simpleMessage(
      "Start in the background",
    ),
    "size": MessageLookupByLibrary.simpleMessage("Size"),
    "smartAutoStop": MessageLookupByLibrary.simpleMessage("Smart Pause"),
    "smartAutoStopDesc": MessageLookupByLibrary.simpleMessage(
      "Pause on trusted networks; resume when leaving",
    ),
    "smartStopped": MessageLookupByLibrary.simpleMessage("Smart Stopped"),
    "socksPort": MessageLookupByLibrary.simpleMessage("Socks Port"),
    "sort": MessageLookupByLibrary.simpleMessage("Sort"),
    "source": MessageLookupByLibrary.simpleMessage("Source"),
    "sourceIp": MessageLookupByLibrary.simpleMessage("Source IP"),
    "specialProxy": MessageLookupByLibrary.simpleMessage("Special proxy"),
    "specialRules": MessageLookupByLibrary.simpleMessage("special rules"),
    "speedStatistics": MessageLookupByLibrary.simpleMessage("Speed statistics"),
    "splitStrategy": MessageLookupByLibrary.simpleMessage("Split strategy"),
    "splitStrategyNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Split strategy cannot be empty",
    ),
    "ssidsEmpty": MessageLookupByLibrary.simpleMessage("SSIDs is empty"),
    "stackMode": MessageLookupByLibrary.simpleMessage("Stack mode"),
    "stackTrace": MessageLookupByLibrary.simpleMessage("Stack trace"),
    "standard": MessageLookupByLibrary.simpleMessage("Standard"),
    "standardModeDesc": MessageLookupByLibrary.simpleMessage(
      "Standard mode: override basic config, add rules",
    ),
    "start": MessageLookupByLibrary.simpleMessage("Start"),
    "startVpn": MessageLookupByLibrary.simpleMessage("Starting VPN..."),
    "starting": MessageLookupByLibrary.simpleMessage("Starting"),
    "status": MessageLookupByLibrary.simpleMessage("Status"),
    "statusDesc": MessageLookupByLibrary.simpleMessage(
      "System DNS when disabled",
    ),
    "stop": MessageLookupByLibrary.simpleMessage("Stop"),
    "stopVpn": MessageLookupByLibrary.simpleMessage("Stopping VPN..."),
    "stopping": MessageLookupByLibrary.simpleMessage("Stopping"),
    "style": MessageLookupByLibrary.simpleMessage("Style"),
    "subRule": MessageLookupByLibrary.simpleMessage("Sub rule"),
    "subRuleEmpty": MessageLookupByLibrary.simpleMessage("Sub rule is empty"),
    "subRuleNotEmpty": MessageLookupByLibrary.simpleMessage(
      "Sub rule cannot be empty",
    ),
    "submit": MessageLookupByLibrary.simpleMessage("Submit"),
    "subscriptions": MessageLookupByLibrary.simpleMessage("Subscriptions"),
    "suspended": MessageLookupByLibrary.simpleMessage("Suspended..."),
    "switching": MessageLookupByLibrary.simpleMessage("Switching"),
    "sync": MessageLookupByLibrary.simpleMessage("Sync"),
    "syncingProxyGroups": MessageLookupByLibrary.simpleMessage(
      "Syncing proxy groups",
    ),
    "system": MessageLookupByLibrary.simpleMessage("System"),
    "systemApp": MessageLookupByLibrary.simpleMessage("System APP"),
    "systemProxy": MessageLookupByLibrary.simpleMessage("System proxy"),
    "systemProxyDesc": MessageLookupByLibrary.simpleMessage(
      "Set system HTTP proxy",
    ),
    "tab": MessageLookupByLibrary.simpleMessage("Tab"),
    "tabAnimation": MessageLookupByLibrary.simpleMessage("Tab animation"),
    "tabAnimationDesc": MessageLookupByLibrary.simpleMessage(
      "Mobile view only",
    ),
    "tapToAuthorize": MessageLookupByLibrary.simpleMessage("Tap to authorize"),
    "tcpConcurrent": MessageLookupByLibrary.simpleMessage("TCP concurrent"),
    "tcpConcurrentDesc": MessageLookupByLibrary.simpleMessage(
      "Allow TCP concurrency",
    ),
    "testAllLatencies": MessageLookupByLibrary.simpleMessage(
      "Test all latencies",
    ),
    "testInterval": MessageLookupByLibrary.simpleMessage("Test interval"),
    "testLatency": MessageLookupByLibrary.simpleMessage("Test latency"),
    "testUrl": MessageLookupByLibrary.simpleMessage("Test url"),
    "testWhenUsed": MessageLookupByLibrary.simpleMessage("Test when used"),
    "textScale": MessageLookupByLibrary.simpleMessage("Text size"),
    "theme": MessageLookupByLibrary.simpleMessage("Theme"),
    "themeColor": MessageLookupByLibrary.simpleMessage("Theme color"),
    "themeDesc": MessageLookupByLibrary.simpleMessage("Appearance and colors"),
    "themeMode": MessageLookupByLibrary.simpleMessage("Theme mode"),
    "tight": MessageLookupByLibrary.simpleMessage("Tight"),
    "time": MessageLookupByLibrary.simpleMessage("Time"),
    "timedOut": MessageLookupByLibrary.simpleMessage("Timed out"),
    "timeout": MessageLookupByLibrary.simpleMessage("Timeout"),
    "tip": MessageLookupByLibrary.simpleMessage("tip"),
    "toggle": MessageLookupByLibrary.simpleMessage("Toggle"),
    "tonal": MessageLookupByLibrary.simpleMessage("Tonal"),
    "tonalSpotScheme": MessageLookupByLibrary.simpleMessage("TonalSpot"),
    "tools": MessageLookupByLibrary.simpleMessage("Tools"),
    "tproxyPort": MessageLookupByLibrary.simpleMessage("Tproxy Port"),
    "trafficUsage": MessageLookupByLibrary.simpleMessage("Usage"),
    "trustedNetworks": MessageLookupByLibrary.simpleMessage("Trusted Networks"),
    "trustedNetworksDesc": MessageLookupByLibrary.simpleMessage(
      "Add trusted IPs or CIDR subnets",
    ),
    "tryAgainLater": MessageLookupByLibrary.simpleMessage(
      "Please try again later.",
    ),
    "tun": MessageLookupByLibrary.simpleMessage("TUN"),
    "tunDesc": MessageLookupByLibrary.simpleMessage(
      "Routes device traffic through the VPN",
    ),
    "turnOff": MessageLookupByLibrary.simpleMessage("Turn Off"),
    "turnOn": MessageLookupByLibrary.simpleMessage("Turn On"),
    "unavailable": MessageLookupByLibrary.simpleMessage("Unavailable"),
    "undo": MessageLookupByLibrary.simpleMessage("undo"),
    "unifiedDelay": MessageLookupByLibrary.simpleMessage("Unified delay"),
    "unifiedDelayDesc": MessageLookupByLibrary.simpleMessage(
      "Remove handshake delays",
    ),
    "unknown": MessageLookupByLibrary.simpleMessage("Unknown"),
    "unknownNetworkError": MessageLookupByLibrary.simpleMessage(
      "Unknown network error",
    ),
    "unlocked": MessageLookupByLibrary.simpleMessage("Unlocked"),
    "unlockedRegions": MessageLookupByLibrary.simpleMessage("Unlocked"),
    "unlockedWithRegion": m27,
    "unnamed": MessageLookupByLibrary.simpleMessage("Unnamed"),
    "update": MessageLookupByLibrary.simpleMessage("Update"),
    "updateFrequency": MessageLookupByLibrary.simpleMessage("Update frequency"),
    "upload": MessageLookupByLibrary.simpleMessage("Upload"),
    "upstreamProject": MessageLookupByLibrary.simpleMessage("Upstream project"),
    "url": MessageLookupByLibrary.simpleMessage("URL"),
    "urlDesc": MessageLookupByLibrary.simpleMessage(
      "Obtain profile through URL",
    ),
    "urlTip": m28,
    "useHosts": MessageLookupByLibrary.simpleMessage("Use hosts"),
    "useSystemHosts": MessageLookupByLibrary.simpleMessage("Use system hosts"),
    "value": MessageLookupByLibrary.simpleMessage("Value"),
    "versionAndProjectLinks": MessageLookupByLibrary.simpleMessage(
      "Version & project links",
    ),
    "vibrantScheme": MessageLookupByLibrary.simpleMessage("Vibrant"),
    "view": MessageLookupByLibrary.simpleMessage("View"),
    "vpnConfigChangeDetected": MessageLookupByLibrary.simpleMessage(
      "VPN config changed",
    ),
    "vpnEnableDesc": MessageLookupByLibrary.simpleMessage(
      "Route all traffic through VPN",
    ),
    "vpnTip": MessageLookupByLibrary.simpleMessage(
      "Changes take effect after restarting the VPN",
    ),
    "webDAVConfiguration": MessageLookupByLibrary.simpleMessage(
      "WebDAV configuration",
    ),
    "whitelistMode": MessageLookupByLibrary.simpleMessage("Whitelist mode"),
    "yearsAgo": m29,
    "youtubeRoutedToChina": MessageLookupByLibrary.simpleMessage(
      "YouTube via China",
    ),
    "zh_CN": MessageLookupByLibrary.simpleMessage("Simplified Chinese"),
  };
}
