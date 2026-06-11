@echo off
REM ============================================================
REM  SlClash Dev Environment - Run this before building
REM  Usage: dev-env.bat        (interactive shell)
REM         dev-env.bat && ... (chain with build command)
REM ============================================================

set PROJECT_DIR=%~dp0
set GRADLE_USER_HOME=%PROJECT_DIR%.dev-tools\gradle
set GOPATH=%PROJECT_DIR%.dev-tools\go-pkg
set GOMODCACHE=%PROJECT_DIR%.dev-tools\go-pkg\mod
set PUB_CACHE=%PROJECT_DIR%.dev-tools\pub-cache

set PATH=D:\Code\Tools\Go\go\bin;D:\Code\Tools\flutter\bin;D:\Code\Tools\Android\Sdk\platform-tools;%PATH%
set ANDROID_HOME=D:\Code\Tools\Android\Sdk
set ANDROID_NDK=D:\Code\Tools\Android\Sdk\ndk\28.2.13676358

echo [SlClash] Dev environment loaded.
echo   GRADLE_USER_HOME = %GRADLE_USER_HOME%
echo   GOPATH           = %GOPATH%
echo   GOMODCACHE       = %GOMODCACHE%
echo   PUB_CACHE        = %PUB_CACHE%
echo   ANDROID_HOME     = %ANDROID_HOME%
echo   ANDROID_NDK      = %ANDROID_NDK%
