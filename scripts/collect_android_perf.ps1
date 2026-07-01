param(
    [string]$AdbPath = "D:\Code\Tools\Android\Sdk\platform-tools\adb.exe",
    [string]$Package = "com.slclash.app.dev",
    [string]$OutDir = ".perf-captures",
    [switch]$ResetBatteryStats,
    [switch]$SkipBatteryStats,
    [switch]$SkipTop
)

$ErrorActionPreference = "Stop"

function Invoke-AdbText {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$AdbArgs)
    $output = & $AdbPath @AdbArgs 2>&1
    return ($output | Out-String).TrimEnd()
}

function Write-Section {
    param(
        [string]$Path,
        [string]$Title,
        [string]$Content
    )
    Add-Content -LiteralPath $Path -Value ""
    Add-Content -LiteralPath $Path -Value "===== $Title ====="
    Add-Content -LiteralPath $Path -Value $Content
}

if (!(Test-Path -LiteralPath $AdbPath)) {
    throw "ADB not found: $AdbPath"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$captureDir = Join-Path $OutDir $timestamp
New-Item -ItemType Directory -Force -Path $captureDir | Out-Null

$summaryPath = Join-Path $captureDir "summary.txt"
$mainPackage = $Package
$remotePackage = "$Package`:remote"

Set-Content -LiteralPath $summaryPath -Value "SlClash Android perf capture $timestamp"
Write-Section $summaryPath "adb devices" (Invoke-AdbText devices -l)
Write-Section $summaryPath "process list" (Invoke-AdbText shell "ps -A | grep '$Package' || true")

$mainPid = (Invoke-AdbText shell "pidof $mainPackage || true").Trim()
$remotePid = (Invoke-AdbText shell "pidof '$remotePackage' || true").Trim()

Write-Section $summaryPath "pids" "main=$mainPid`nremote=$remotePid"

foreach ($entry in @(
    @{ Name = "main"; Package = $mainPackage; Pid = $mainPid },
    @{ Name = "remote"; Package = $remotePackage; Pid = $remotePid }
)) {
    $name = $entry.Name
    $pkg = $entry.Package
    $processPid = $entry.Pid

    Write-Section $summaryPath "$name meminfo" (Invoke-AdbText shell "dumpsys meminfo '$pkg' || true")

    if ($processPid) {
        Write-Section $summaryPath "$name threads" (Invoke-AdbText shell "ps -T -p $processPid || true")
        Write-Section $summaryPath "$name thread count" (Invoke-AdbText shell "ls /proc/$processPid/task 2>/dev/null | wc -l || true")
        if (!$SkipTop) {
            Write-Section $summaryPath "$name top threads" (Invoke-AdbText shell "top -H -b -n 1 -p $processPid || true")
        }
    }
}

Write-Section $summaryPath "cpuinfo" (Invoke-AdbText shell "dumpsys cpuinfo | grep follow.clash || true")

if (!$SkipBatteryStats) {
    if ($ResetBatteryStats) {
        Write-Section $summaryPath "batterystats reset" (Invoke-AdbText shell "dumpsys batterystats --reset || true")
    }
    $batteryPath = Join-Path $captureDir "batterystats.txt"
    Set-Content -LiteralPath $batteryPath -Value (Invoke-AdbText shell "dumpsys batterystats || true")
    Write-Section $summaryPath "batterystats" "Saved to $batteryPath"
}

Write-Host "Perf capture saved: $summaryPath"
