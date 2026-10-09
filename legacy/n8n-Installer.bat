@echo off
REM n8n Installation Wizard for Windows
REM Interactive step-by-step installer with full customization

chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

REM Catch all exits
set "SCRIPTDIR=%~dp0"
if not defined SCRIPTDIR set "SCRIPTDIR=%CD%"

goto START

:END_SCRIPT
echo.
echo [DEBUG] Script ended unexpectedly at this point
pause
exit /b 1

:START
cls
echo.
echo  ══════════════════════════════════════════════════════════════
echo      n8n Installation Wizard for Windows
echo      Community Edition - Version 0.2
echo  ══════════════════════════════════════════════════════════════
echo.
echo  IMPORTANT NOTICE:
echo  This is an UNOFFICIAL community-made installer.
echo  NOT affiliated with n8n.io or n8n GmbH.
echo.
echo  Created by: https://github.com/web3Leander
echo  n8n Official: https://n8n.io
echo.
echo  Press any key to continue...
pause >nul

cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 1 of 4: Verifying System Requirements
echo  ────────────────────────────────────────
echo.

REM Step 1: Check prerequisites
echo  Checking Node.js...
where node >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [✗] Node.js is not detected
    echo.
    echo      Please install Node.js before continuing.
    echo      Download: https://nodejs.org/
    echo.
    echo      Recommended: Node.js 22.x LTS
    echo      Supported:   Node.js 20.19+ or 22.x LTS
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
set "NODE_VERSION_NUMBER=%NODE_VERSION:~1%"
for /f "tokens=1,2 delims=." %%a in ("%NODE_VERSION_NUMBER%") do (
    set "NODE_MAJOR=%%a"
    set "NODE_MINOR=%%b"
)
if not defined NODE_MINOR set "NODE_MINOR=0"

REM Node.js 22.x LTS is the ceiling. It ships npm 10, which is the pairing this
REM installer targets. Newer Node ships newer npm, and npm 12 blocks dependency
REM install scripts, which leaves sqlite3 without its native binary.
set "NODE_SUPPORTED=NO"
if "%NODE_MAJOR%"=="20" (
    if %NODE_MINOR% GEQ 19 set "NODE_SUPPORTED=YES"
) else if "%NODE_MAJOR%"=="22" (
    set "NODE_SUPPORTED=YES"
)

if "%NODE_SUPPORTED%"=="YES" (
    echo  [✓] Node.js %NODE_VERSION% - Supported by n8n 2.x
) else (
    echo  [^^!] Node.js %NODE_VERSION% - Unsupported for native n8n 2.x installs
)

echo.
echo  Checking npm...
where npm >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [✗] npm is not detected
    echo.
    echo      npm should be installed with Node.js.
    echo      Download: https://nodejs.org/
    echo.
    pause
    exit /b 1
)

for /f "tokens=*" %%i in ('npm --version') do set NPM_VERSION=%%i
echo  [✓] npm %NPM_VERSION%

echo.
echo  Checking Docker...
where docker >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    set "DOCKER_AVAILABLE=NO"
) else (
    REM Check if Docker is running
    docker ps >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        set "DOCKER_AVAILABLE=NO"
    ) else (
        for /f "tokens=*" %%i in ('docker --version') do set DOCKER_VERSION=%%i
        echo  [✓] !DOCKER_VERSION!
        set "DOCKER_AVAILABLE=YES"
    )
)

echo.
echo  Checking WSL...
set "WSL_AVAILABLE=NO"
set "WSL_DISTRO_COUNT=0"
set "WSL_LIST_FILE=%TEMP%\n8n_wsl_distros.txt"
if exist "%WSL_LIST_FILE%" del "%WSL_LIST_FILE%" >nul 2>&1
REM wsl.exe ships in System32 on every Win10/11 host, so its presence proves
REM nothing. Only a parsed distro list confirms WSL is actually usable.
REM All wsl.exe builtin output is UTF-16LE, hence the PowerShell decoding shim.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; [Console]::OutputEncoding=[Text.Encoding]::Unicode; $names=@(wsl.exe -l -q) | ForEach-Object { ($_ -replace [char]0,'').Trim() } | Where-Object { $_ -and $_ -notmatch '^(docker-desktop|rancher-desktop)' }; $vlines=@(wsl.exe -l -v) | ForEach-Object { (($_ -replace [char]0,'').Trim()) -replace '^\*\s*','' }; $out=@(); foreach($d in $names){ $ver='2'; $st='Unknown'; foreach($r in $vlines){ if($r.StartsWith($d + ' ')){ $p=@($r -split '\s+'); if($p.Length -ge 3){ $st=$p[$p.Length-2]; $ver=$p[$p.Length-1] }; break } }; $out += ('{0}|{1}|{2}' -f $d,$ver,$st) }; if($out.Count -gt 0){ [IO.File]::WriteAllLines('%WSL_LIST_FILE%', $out, (New-Object Text.UTF8Encoding $false)) }" 2>nul
if exist "%WSL_LIST_FILE%" (
    for /f "usebackq delims=" %%D in ("%WSL_LIST_FILE%") do set /a WSL_DISTRO_COUNT+=1
)
if !WSL_DISTRO_COUNT! GEQ 1 (
    set "WSL_AVAILABLE=YES"
    echo  [✓] WSL: !WSL_DISTRO_COUNT! Linux distribution^(s^) detected
)

if "%NODE_SUPPORTED%"=="NO" (
    if "%DOCKER_AVAILABLE%"=="YES" (
        echo.
        echo  [^^!] Native npm installations are disabled with Node.js %NODE_VERSION%
        echo      Supported: Node.js 20.19+ or 22.x LTS
        echo      You can still use the Docker installation option.
    ) else if "!WSL_AVAILABLE!"=="YES" (
        echo.
        echo  [^^!] Native npm installations are disabled with Node.js %NODE_VERSION%
        echo      Supported: Node.js 20.19+ or 22.x LTS
        echo      You can still use the WSL2 installation option.
    ) else (
        echo.
        echo  [✗] No supported installation method is available
        echo      Native installs require Node.js 20.19+ or 22.x LTS.
        echo      Docker Desktop is not available or not running.
        echo.
        echo      Install Node.js 22 LTS or start Docker Desktop, then rerun.
        echo.
        pause
        exit /b 1
    )
)

REM Check for updates (informational only)
echo.
echo  Checking for updates...
echo.

REM Get latest Node.js LTS version (approximate check)
if "%NODE_SUPPORTED%"=="YES" (
    if "%NODE_MAJOR%"=="22" (
        echo  [✓] Node.js %NODE_VERSION% - Supported LTS
    ) else (
        echo  [^^!] Node.js %NODE_VERSION% - Supported; Node.js 22.x LTS available
        echo      Visit: https://nodejs.org/
    )
) else (
    echo  [^^!] Node.js %NODE_VERSION% - Native npm installs unavailable
    echo      Recommended: Node.js 22.x LTS
    echo      Visit: https://nodejs.org/
)

REM Get highest supported npm version. npm is capped at 10.x to match the npm
REM that ships with Node.js 22 LTS. npm 12 blocks dependency install scripts,
REM which leaves sqlite3 without its native binary and stops n8n from starting.
echo.
if "%NODE_SUPPORTED%"=="YES" (
    for /f "tokens=*" %%i in ('npm view npm@next-10 version 2^>nul') do set NPM_MAX=%%i

    if defined NPM_MAX (
        if "!NPM_VERSION!"=="!NPM_MAX!" (
            echo  [✓] npm !NPM_VERSION! - Highest supported version
        ) else (
            echo  [^^!] npm !NPM_VERSION! - Supported version available: !NPM_MAX!
            echo.
            set /p "UPDATE_NPM=      Install npm !NPM_MAX! now? (Y/N): "
            if /i "!UPDATE_NPM!"=="Y" (
                echo.
                echo      Installing npm !NPM_MAX!...
                call npm install -g npm@!NPM_MAX! --loglevel=error --no-fund --no-audit
                if !ERRORLEVEL! EQU 0 (
                    echo.
                    echo      [✓] npm updated successfully
                    for /f "tokens=*" %%i in ('npm --version') do set NPM_VERSION=%%i
                    echo      [✓] npm is now version !NPM_VERSION!
                ) else (
                    echo.
                    echo      [✗] npm update failed, continuing
                )
            )
        )
    ) else (
        echo  [✓] npm %NPM_VERSION% - version check unavailable, continuing
    )
) else (
    echo  [^^!] npm update check skipped because native installs are disabled
)

echo.
echo  ════════════════════════════════════════
echo   Prerequisites Verified
echo  ════════════════════════════════════════
echo.
if "%NODE_SUPPORTED%"=="YES" (
    echo   Node.js: %NODE_VERSION%
) else (
    echo   Node.js: %NODE_VERSION% ^(native unsupported^)
)
echo   npm:     %NPM_VERSION%
if "%DOCKER_AVAILABLE%"=="YES" (
    echo   Docker:  Available
) else (
    echo   Docker:  Not available ^(optional^)
)
if "!WSL_AVAILABLE!"=="YES" (
    echo   WSL:     !WSL_DISTRO_COUNT! Linux distribution^(s^)
)

REM Check if default port 5678 is in use
echo.
echo  Checking default port 5678...
netstat -an 2>nul | findstr /C:":5678 " | findstr /C:"LISTENING" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    echo  [^^!] Warning: Port 5678 is already in use
    echo      You will need to choose a different port during setup
    set "DEFAULT_PORT_IN_USE=YES"
) else (
    echo  [✓] Port 5678 is available
    set "DEFAULT_PORT_IN_USE=NO"
)

echo.
set /p "CONTINUE=  Ready to proceed? (Y/N): "
if /i not "%CONTINUE%"=="Y" (
    echo.
    echo  Installation cancelled.
    pause
    exit /b 0
)

cls

REM Step 2: Installation setup
:CUSTOM_INSTALL
cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 2 of 4: Installation Setup
echo  ────────────────────────────────────────
echo.

REM Sub-step: n8n installation type
:ASK_N8N_TYPE
echo  n8n Program Installation
echo  ────────────────────────────────────────
echo.
echo  1. Global Installation
echo     • npm install -g n8n
echo     • n8n command available system-wide
echo     • Standard installation method
echo     • NOTE: Will overwrite existing global n8n
echo.
echo  2. Folder-Specific Installation
echo     • Install to a folder you choose
echo     • Completely isolated installation
echo     • Won't affect global n8n installation
echo     • Useful for testing or multiple versions
echo.
if "%DOCKER_AVAILABLE%"=="YES" (
    echo  3. Docker Installation
    echo     • Run n8n in a Docker container
    echo     • Completely isolated and portable
    echo     • Easy updates and backups
    echo     • Requires Docker Desktop
    echo.
)
if "!WSL_AVAILABLE!"=="YES" (
    echo  4. WSL2 ^(Linux^) Installation
    echo     • Installs n8n inside a WSL Linux distribution
    echo     • Native Linux SQLite performance and file I/O
    echo     • No Windows path length or file locking limits
    echo     • Reachable from Windows at http://localhost
    echo.
)
if "!WSL_AVAILABLE!"=="YES" (
    if "%DOCKER_AVAILABLE%"=="YES" (
        set /p "N8N_TYPE=  Your choice (1, 2, 3, or 4): "
    ) else (
        set /p "N8N_TYPE=  Your choice (1, 2, or 4): "
    )
) else if "%DOCKER_AVAILABLE%"=="YES" (
    set /p "N8N_TYPE=  Your choice (1, 2, or 3): "
) else (
    set /p "N8N_TYPE=  Your choice (1 or 2): "
)

if "%N8N_TYPE%"=="1" (
    if not "%NODE_SUPPORTED%"=="YES" (
        echo.
        echo  [✗] Global installation requires Node.js 20.19+ or 22.x LTS.
        echo      Detected: %NODE_VERSION%
        echo      Install Node.js 22 LTS or choose Docker if available.
        echo.
        pause
        goto CUSTOM_INSTALL
    )
    set "N8N_INSTALL_TYPE=GLOBAL"
    set "N8N_INSTALL_PATH=Global npm packages"
    
    REM Check if n8n is already installed globally
    where n8n >nul 2>&1
    if !ERRORLEVEL! EQU 0 (
        for /f "tokens=*" %%i in ('n8n --version 2^>nul') do set EXISTING_N8N=%%i
        if defined EXISTING_N8N (
            echo.
            echo  ════════════════════════════════════════
            echo   WARNING: Existing Installation Detected
            echo  ════════════════════════════════════════
            echo.
            echo  An existing global n8n installation was found:
            echo  Version: !EXISTING_N8N!
            echo.
            echo  Installing globally will OVERWRITE the n8n program.
            echo.
            echo  IMPORTANT:
            echo  • Your workflows, credentials, and settings are
            echo    stored in your data folder and will be preserved
            echo  • The n8n program itself will be replaced
            echo.
            echo  ════════════════════════════════════════
            echo   CONFIRMATION REQUIRED
            echo  ════════════════════════════════════════
            echo.
            echo  To proceed with overwriting the existing installation,
            echo  you must type: DELETE
            echo.
            echo  Type DELETE in CAPITAL LETTERS to confirm, or
            echo  type anything else to cancel and go back.
            echo.
            set /p "OVERWRITE_CONFIRM=  Type DELETE to confirm: "
            if not "!OVERWRITE_CONFIRM!"=="DELETE" (
                echo.
                echo  Installation cancelled. Returning to selection...
                timeout /t 2 /nobreak >nul
                cls
                echo.
                echo  ════════════════════════════════════════
                echo      n8n Installation Wizard
                echo  ════════════════════════════════════════
                echo.
                echo  Step 2 of 4: Installation Setup
                echo  ────────────────────────────────────────
                echo.
                goto ASK_N8N_TYPE
            )
            echo.
            echo  Confirmation accepted. Proceeding...
            timeout /t 2 /nobreak >nul
        )
    )
    
    echo.
    echo  [✓] Selected: Global installation
) else if "%N8N_TYPE%"=="2" (
    if not "%NODE_SUPPORTED%"=="YES" (
        echo.
        echo  [✗] Folder-specific installation requires Node.js 20.19+ or 22.x LTS.
        echo      Detected: %NODE_VERSION%
        echo      Install Node.js 22 LTS or choose Docker if available.
        echo.
        pause
        goto CUSTOM_INSTALL
    )
    set "N8N_INSTALL_TYPE=FOLDER"
    echo.
    echo  Enter the full folder path for n8n installation.
    echo.
    echo  Example:  C:\tools\n8n
    echo        or  D:\apps\n8n
    echo.
    set /p "N8N_INSTALL_PATH=  Path: "
    if not exist "!N8N_INSTALL_PATH!" (
        echo.
        echo  [^^!] Folder does not exist: !N8N_INSTALL_PATH!
        echo.
        set /p "CREATE_N8N_DIR=  Create this folder? (Y/N): "
        if /i not "!CREATE_N8N_DIR!"=="Y" (
            echo.
            echo  Please enter a valid folder path.
            timeout /t 2 /nobreak >nul
            cls
            echo.
            echo  ════════════════════════════════════════
            echo      n8n Installation Wizard
            echo  ════════════════════════════════════════
            echo.
            echo  Step 2 of 4: Installation Setup
            echo  ────────────────────────────────────────
            echo.
            goto ASK_N8N_TYPE
        )
        mkdir "!N8N_INSTALL_PATH!" 2>nul
        if !ERRORLEVEL! NEQ 0 (
            echo.
            echo  [✗] Could not create folder!
            pause
            cls
            echo.
            echo  ════════════════════════════════════════
            echo      n8n Installation Wizard
            echo  ════════════════════════════════════════
            echo.
            echo  Step 2 of 4: Installation Setup
            echo  ────────────────────────────────────────
            echo.
            goto ASK_N8N_TYPE
        )
    ) else (
        REM Folder exists - check if n8n is already installed there
        if exist "!N8N_INSTALL_PATH!\node_modules\n8n" (
            echo.
            echo  ════════════════════════════════════════
            echo   WARNING: Existing Installation Detected
            echo  ════════════════════════════════════════
            echo.
            echo  n8n is already installed in this folder:
            echo  !N8N_INSTALL_PATH!
            echo.
            echo  Reinstalling will OVERWRITE the n8n program files.
            echo.
            echo  IMPORTANT:
            echo  • Your workflows, credentials, and settings in the
            echo    .n8n data folder will be preserved
            echo  • Only the n8n program files will be replaced
            echo.
            echo  ════════════════════════════════════════
            echo   CONFIRMATION REQUIRED
            echo  ════════════════════════════════════════
            echo.
            echo  To proceed with overwriting the existing installation,
            echo  you must type: DELETE
            echo.
            echo  Type DELETE in CAPITAL LETTERS to confirm, or
            echo  type anything else to cancel and go back.
            echo.
            set /p "FOLDER_OVERWRITE_CONFIRM=  Type DELETE to confirm: "
            if not "!FOLDER_OVERWRITE_CONFIRM!"=="DELETE" (
                echo.
                echo  Installation cancelled. Returning to selection...
                timeout /t 2 /nobreak >nul
                cls
                echo.
                echo  ════════════════════════════════════════
                echo      n8n Installation Wizard
                echo  ════════════════════════════════════════
                echo.
                echo  Step 2 of 4: Installation Setup
                echo  ────────────────────────────────────────
                echo.
                goto ASK_N8N_TYPE
            )
            echo.
            echo  Confirmation accepted. Proceeding...
            timeout /t 2 /nobreak >nul
        )
    )
    echo.
    echo  [✓] Selected: Folder installation
    echo      Location: !N8N_INSTALL_PATH!
) else if "%N8N_TYPE%"=="3" (
    if not "%DOCKER_AVAILABLE%"=="YES" (
        echo.
        echo  [✗] Docker is not available. Please choose option 1 or 2.
        timeout /t 2 /nobreak >nul
        cls
        echo.
        echo  ════════════════════════════════════════
        echo      n8n Installation Wizard
        echo  ════════════════════════════════════════
        echo.
        echo  Step 2 of 4: Installation Setup
        echo  ────────────────────────────────────────
        echo.
        goto ASK_N8N_TYPE
    )
    set "N8N_INSTALL_TYPE=DOCKER"
    set "N8N_INSTALL_PATH=Docker Container"
    echo.
    echo  [✓] Selected: Docker installation
) else if "%N8N_TYPE%"=="4" (
    if not "!WSL_AVAILABLE!"=="YES" (
        echo.
        echo  [✗] WSL is not available. Please choose another option.
        timeout /t 2 /nobreak >nul
        cls
        echo.
        echo  ════════════════════════════════════════
        echo      n8n Installation Wizard
        echo  ════════════════════════════════════════
        echo.
        echo  Step 2 of 4: Installation Setup
        echo  ────────────────────────────────────────
        echo.
        goto ASK_N8N_TYPE
    )
    goto WSL_FLOW
) else (
    echo.
    if "!WSL_AVAILABLE!"=="YES" (
        echo  [✗] Invalid choice. Please try again.
    ) else if "%DOCKER_AVAILABLE%"=="YES" (
        echo  [✗] Invalid choice. Please enter 1, 2, or 3.
    ) else (
        echo  [✗] Invalid choice. Please enter 1 or 2.
    )
    timeout /t 2 /nobreak >nul
    cls
    echo.
    echo  ════════════════════════════════════════
    echo      n8n Installation Wizard
    echo  ════════════════════════════════════════
    echo.
    echo  Step 2 of 4: Installation Setup
    echo  ────────────────────────────────────────
    echo.
    goto ASK_N8N_TYPE
)

REM Set data path based on installation type
if "!N8N_INSTALL_TYPE!"=="GLOBAL" (
    set "N8N_DATA_PATH=%USERPROFILE%\.n8n"
    set "TARGET_DRIVE=%SYSTEMDRIVE%"
    set "REQUIRED_MB=2048"
    set "REQUIRED_GB_STR=2 GB"
) else if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    set "N8N_DATA_PATH=Docker Volume"
    set "TARGET_DRIVE=%SYSTEMDRIVE%"
    set "REQUIRED_MB=3072"
    set "REQUIRED_GB_STR=3 GB"
) else (
    set "N8N_DATA_PATH=!N8N_INSTALL_PATH!"
    set "TARGET_DRIVE=!N8N_INSTALL_PATH:~0,2!"
    set "REQUIRED_MB=2048"
    set "REQUIRED_GB_STR=2 GB"
)

REM Check disk space on target drive (2GB for native, 3GB for Docker image + volume)
echo.
echo  Checking disk space on !TARGET_DRIVE!...
for /f "tokens=3" %%a in ('dir !TARGET_DRIVE!\ 2^>nul ^| findstr /C:"bytes free"') do set "FREE_SPACE_STR=%%a"
set "FREE_SPACE_STR=!FREE_SPACE_STR:,=!"
set /a "FREE_SPACE_MB=!FREE_SPACE_STR:~0,-6!" 2>nul
if !FREE_SPACE_MB! GEQ !REQUIRED_MB! (
    echo  [✓] Disk space on !TARGET_DRIVE!: !FREE_SPACE_MB! MB available
) else if !FREE_SPACE_MB! GEQ 1 (
    echo  [^^!] Warning: Low disk space on !TARGET_DRIVE! ^(!FREE_SPACE_MB! MB^)
    echo      n8n installation requires approximately !REQUIRED_GB_STR!
    echo.
    set /p "CONTINUE_LOW_SPACE=  Continue anyway? (Y/N): "
    if /i not "!CONTINUE_LOW_SPACE!"=="Y" (
        echo.
        echo  Returning to installation setup...
        timeout /t 2 /nobreak >nul
        cls
        echo.
        echo  ════════════════════════════════════════
        echo      n8n Installation Wizard
        echo  ════════════════════════════════════════
        echo.
        echo  Step 2 of 4: Installation Setup
        echo  ────────────────────────────────────────
        echo.
        goto ASK_N8N_TYPE
    )
) else (
    REM Fallback if calculation failed - just note we couldn't check
    echo  [i] Disk space: Could not determine ^(ensure !REQUIRED_GB_STR! free on !TARGET_DRIVE!^)
)

echo.
if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  [i] n8n data will be stored in Docker volume
) else (
    echo  [i] n8n will store data at: !N8N_DATA_PATH!\.n8n\
    echo      ^(n8n automatically creates the .n8n subfolder^)
)
echo.
set "CONFIRM_N8N="
set /p "CONFIRM_N8N=  Confirm choice? (Y/N): "
if /i not "!CONFIRM_N8N!"=="Y" (
    cls
    echo.
    echo  ════════════════════════════════════════
    echo      n8n Installation Wizard
    echo  ════════════════════════════════════════
    echo.
    echo  Step 2 of 4: Installation Setup
    echo  ────────────────────────────────────────
    echo.
    goto ASK_N8N_TYPE
)

REM Sub-step: Docker Configuration (if Docker installation selected)
if not "!N8N_INSTALL_TYPE!"=="DOCKER" goto SKIP_DOCKER_CONFIG

:ASK_DOCKER_CONFIG
echo.
echo.
echo  Docker Configuration
echo  ────────────────────────────────────────
echo.
echo  Configure Docker container settings.
echo.

REM Container name
echo  Container Name:
echo  • Press Enter for default: n8n
echo  • Or enter a custom name (no spaces)
echo.
set "DOCKER_CONTAINER_INPUT="
set /p "DOCKER_CONTAINER_INPUT=  Container name (default: n8n): "
if "!DOCKER_CONTAINER_INPUT!"=="" set "DOCKER_CONTAINER=n8n"
if defined DOCKER_CONTAINER_INPUT set "DOCKER_CONTAINER=!DOCKER_CONTAINER_INPUT!"

REM Check if container with this name already exists
docker ps -a --format "{{.Names}}" 2>nul | findstr /X /C:"!DOCKER_CONTAINER!" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    echo.
    echo  ════════════════════════════════════════
    echo   WARNING: Container Already Exists
    echo  ════════════════════════════════════════
    echo.
    echo  A Docker container named "!DOCKER_CONTAINER!" already exists.
    echo.
    echo  Options:
    echo  1. Remove the existing container and create new
    echo  2. Choose a different container name
    echo.
    set "CONTAINER_ACTION="
    set /p "CONTAINER_ACTION=  Your choice (1 or 2): "
    if "!CONTAINER_ACTION!"=="1" (
        echo.
        echo  Stopping and removing existing container...
        docker stop !DOCKER_CONTAINER! >nul 2>&1
        docker rm !DOCKER_CONTAINER! >nul 2>&1
        if !ERRORLEVEL! EQU 0 (
            echo  [✓] Existing container removed
        ) else (
            echo  [✗] Failed to remove container. Please remove manually:
            echo      docker rm -f !DOCKER_CONTAINER!
            pause
            goto ASK_DOCKER_CONFIG
        )
    ) else (
        echo.
        echo  Please enter a different container name.
        timeout /t 2 /nobreak >nul
        cls
        echo.
        echo  ════════════════════════════════════════
        echo      n8n Installation Wizard
        echo  ════════════════════════════════════════
        echo.
        echo  Step 2 of 4: Installation Setup
        echo  ────────────────────────────────────────
        echo.
        goto ASK_DOCKER_CONFIG
    )
)

echo.
REM Volume name
echo  Data Volume Name:
echo  • Press Enter for default: n8n_data
echo  • Or enter a custom volume name
echo.
set "DOCKER_VOLUME_INPUT="
set /p "DOCKER_VOLUME_INPUT=  Volume name (default: n8n_data): "
if "!DOCKER_VOLUME_INPUT!"=="" set "DOCKER_VOLUME=n8n_data"
if defined DOCKER_VOLUME_INPUT set "DOCKER_VOLUME=!DOCKER_VOLUME_INPUT!"

REM Auto-detect timezone from Windows and convert to IANA format
for /f "tokens=*" %%t in ('powershell -Command "[System.TimeZoneInfo]::Local.Id"') do set "WIN_TZ=%%t"
set "DOCKER_TIMEZONE=UTC"
REM Map common Windows timezones to IANA format
if "!WIN_TZ!"=="Pacific Standard Time" set "DOCKER_TIMEZONE=America/Los_Angeles"
if "!WIN_TZ!"=="Mountain Standard Time" set "DOCKER_TIMEZONE=America/Denver"
if "!WIN_TZ!"=="Central Standard Time" set "DOCKER_TIMEZONE=America/Chicago"
if "!WIN_TZ!"=="Eastern Standard Time" set "DOCKER_TIMEZONE=America/New_York"
if "!WIN_TZ!"=="Atlantic Standard Time" set "DOCKER_TIMEZONE=America/Halifax"
if "!WIN_TZ!"=="GMT Standard Time" set "DOCKER_TIMEZONE=Europe/London"
if "!WIN_TZ!"=="W. Europe Standard Time" set "DOCKER_TIMEZONE=Europe/Amsterdam"
if "!WIN_TZ!"=="Central Europe Standard Time" set "DOCKER_TIMEZONE=Europe/Budapest"
if "!WIN_TZ!"=="Central European Standard Time" set "DOCKER_TIMEZONE=Europe/Warsaw"
if "!WIN_TZ!"=="Romance Standard Time" set "DOCKER_TIMEZONE=Europe/Paris"
if "!WIN_TZ!"=="FLE Standard Time" set "DOCKER_TIMEZONE=Europe/Kiev"
if "!WIN_TZ!"=="Russian Standard Time" set "DOCKER_TIMEZONE=Europe/Moscow"
if "!WIN_TZ!"=="India Standard Time" set "DOCKER_TIMEZONE=Asia/Kolkata"
if "!WIN_TZ!"=="China Standard Time" set "DOCKER_TIMEZONE=Asia/Shanghai"
if "!WIN_TZ!"=="Tokyo Standard Time" set "DOCKER_TIMEZONE=Asia/Tokyo"
if "!WIN_TZ!"=="Singapore Standard Time" set "DOCKER_TIMEZONE=Asia/Singapore"
if "!WIN_TZ!"=="AUS Eastern Standard Time" set "DOCKER_TIMEZONE=Australia/Sydney"
if "!WIN_TZ!"=="New Zealand Standard Time" set "DOCKER_TIMEZONE=Pacific/Auckland"

echo.
echo  [✓] Docker Configuration:
echo      Container: !DOCKER_CONTAINER!
echo      Volume:    !DOCKER_VOLUME!
echo      Timezone:  !DOCKER_TIMEZONE! (auto-detected)
echo.
set "CONFIRM_DOCKER="
set /p "CONFIRM_DOCKER=  Confirm Docker settings? (Y/N): "
if /i not "!CONFIRM_DOCKER!"=="Y" (
    cls
    echo.
    echo  ════════════════════════════════════════
    echo      n8n Installation Wizard
    echo  ════════════════════════════════════════
    echo.
    echo  Step 2 of 4: Installation Setup
    echo  ────────────────────────────────────────
    echo.
    goto ASK_DOCKER_CONFIG
)

:SKIP_DOCKER_CONFIG
REM Sub-step: Network Configuration
echo.
echo.
:ASK_NETWORK_CONFIG
echo  n8n Network Configuration
echo  ────────────────────────────────────────
echo.
if "!DEFAULT_PORT_IN_USE!"=="YES" (
    echo  [^^!] Note: Port 5678 is in use - please choose a different port
    echo.
)
if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  Configure the port for n8n to run on.
    echo  Docker will map this port to the container.
    echo.
    echo  Port Number:
    echo  • Press Enter for default: 5678
    echo  • Or enter a custom port (1024-65535)
    echo    Examples: 8080, 3000, 5000
    echo.
    set "N8N_PORT_INPUT="
    set /p "N8N_PORT_INPUT=  Port (default: 5678): "
    if "!N8N_PORT_INPUT!"=="" set "N8N_PORT=5678"
    if defined N8N_PORT_INPUT set "N8N_PORT=!N8N_PORT_INPUT!"
    
    set "N8N_HOST=localhost"
    
    echo.
    echo  [✓] Network Configuration:
    echo      Port: !N8N_PORT!
    echo      URL:  http://localhost:!N8N_PORT!
    goto CONFIRM_NETWORK
)

echo  Configure the host and port for n8n to run on.
    echo.
    echo  Host/IP Address:
    echo  • Press Enter for default: 127.0.0.1 (localhost only)
    echo  • Or enter a custom IP address
    echo    Examples: 0.0.0.0 (all interfaces), 192.168.1.100 (specific local IP)
    echo.
    set "N8N_HOST_INPUT="
    set /p "N8N_HOST_INPUT=  Host (default: 127.0.0.1): "
    if "!N8N_HOST_INPUT!"=="" set "N8N_HOST=127.0.0.1"
    if defined N8N_HOST_INPUT (
        if not "!N8N_HOST_INPUT!"=="" set "N8N_HOST=!N8N_HOST_INPUT!"
    )

    echo.
    echo  Port Number:
    echo  • Press Enter for default: 5678
    echo  • Or enter a custom port (1024-65535)
    echo    Examples: 8080, 3000, 5000
    echo.
    set "N8N_PORT_INPUT="
    set /p "N8N_PORT_INPUT=  Port (default: 5678): "
    if "!N8N_PORT_INPUT!"=="" set "N8N_PORT=5678"
    if defined N8N_PORT_INPUT (
        if not "!N8N_PORT_INPUT!"=="" set "N8N_PORT=!N8N_PORT_INPUT!"
    )

    echo.
    echo  [✓] Network Configuration:
    echo      Host: !N8N_HOST!
    echo      Port: !N8N_PORT!
    echo      URL:  http://!N8N_HOST!:!N8N_PORT!

:CONFIRM_NETWORK
echo.
set "CONFIRM_NETWORK="
set /p "CONFIRM_NETWORK=  Confirm network settings? (Y/N): "
if /i not "!CONFIRM_NETWORK!"=="Y" (
    cls
    echo.
    echo  ════════════════════════════════════════
    echo      n8n Installation Wizard
    echo  ════════════════════════════════════════
    echo.
    echo  Step 2 of 4: Installation Setup
    echo  ────────────────────────────────────────
    echo.
    goto ASK_NETWORK_CONFIG
)

REM Auto-update option (not for Docker - Docker has its own update mechanism)
if not "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo.
    echo.
    echo  Auto-Update Configuration
    echo  ────────────────────────────────────────
    echo.
    echo  Would you like start_n8n.bat to check for updates?
    echo  • Each time you start n8n, it will check for newer versions
    echo  • You will be prompted before any update is installed
    echo.
    set /p "ENABLE_AUTO_UPDATE=  Enable auto-update check? (Y/N, default: N): "
    if /i "!ENABLE_AUTO_UPDATE!"=="Y" (
        set "AUTO_UPDATE=YES"
        echo.
        echo  [✓] Auto-update check enabled
    ) else (
        set "AUTO_UPDATE=NO"
        echo.
        echo  [✓] Auto-update check disabled
    )
)

REM Desktop shortcut option (not for Docker)
set "CREATE_SHORTCUT=NO"
set "SHORTCUT_PATH="
if not "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo.
    echo.
    echo  Desktop Shortcut
    echo  ────────────────────────────────────────
    echo.
    echo  Create a desktop shortcut for start_n8n.bat?
    echo.
    echo    [1] Current user only ^(%USERNAME%^)
    echo    [2] All users ^(Public Desktop^)
    echo    [N] No shortcut
    echo.
    set /p "SHORTCUT_CHOICE=  Your choice (1/2/N, default: N): "
    if "!SHORTCUT_CHOICE!"=="1" (
        set "CREATE_SHORTCUT=YES"
        set "SHORTCUT_PATH=%USERPROFILE%\Desktop"
        echo.
        echo  [✓] Shortcut will be created for %USERNAME%
    ) else if "!SHORTCUT_CHOICE!"=="2" (
        set "CREATE_SHORTCUT=YES"
        set "SHORTCUT_PATH=%PUBLIC%\Desktop"
        echo.
        echo  [✓] Shortcut will be created for all users
    ) else (
        echo.
        echo  [✓] No shortcut will be created
    )
)

REM Final confirmation
cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 2 of 4: Installation Summary
echo  ────────────────────────────────────────
echo.
echo  n8n Installation: !N8N_INSTALL_TYPE!
echo  Installation Path: !N8N_INSTALL_PATH!
echo  Data Directory: !N8N_DATA_PATH!
echo  Host: !N8N_HOST!
echo  Port: !N8N_PORT!
echo  Access URL: http://!N8N_HOST!:!N8N_PORT!
if not "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  Auto-Update Check: !AUTO_UPDATE!
    echo  Desktop Shortcut: !CREATE_SHORTCUT!
)
echo.
set /p "FINAL_CONFIRM=  Proceed with installation? (Y/N): "
if /i not "!FINAL_CONFIRM!"=="Y" (
    echo.
    echo Returning to Installation Setup...
    timeout /t 2 /nobreak >nul
    goto CUSTOM_INSTALL
)
goto EXECUTE_INSTALL

:EXECUTE_INSTALL
REM Execute installation
cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 3 of 4: Installing n8n
echo  ────────────────────────────────────────
echo.

REM Ensure data directory exists (not needed for Docker)
if not "!N8N_INSTALL_TYPE!"=="DOCKER" (
    if not exist "!N8N_DATA_PATH!" (
        echo  Creating data directory...
        mkdir "!N8N_DATA_PATH!" 2>nul
        if !ERRORLEVEL! NEQ 0 (
            echo  [✗] Could not create data directory: !N8N_DATA_PATH!
            pause
            exit /b 1
        )
        echo  [✓] Data directory created
        echo.
    )
)

if "!N8N_INSTALL_TYPE!"=="GLOBAL" goto INSTALL_GLOBAL
if "!N8N_INSTALL_TYPE!"=="FOLDER" goto INSTALL_FOLDER
if "!N8N_INSTALL_TYPE!"=="DOCKER" goto INSTALL_DOCKER

REM If we get here, something went wrong
echo.
echo  [✗] Error: Installation type not recognized
echo  Type: [!N8N_INSTALL_TYPE!]
echo.
pause
exit /b 1

:INSTALL_GLOBAL
echo  Running: npm install -g n8n
echo  This may take a few minutes...
echo.
REM --allow-scripts is required on npm 12+, which blocks dependency install
REM scripts by default. Without it sqlite3 never builds. Older npm ignores it.
REM --loglevel=error hides npm's deprecation warning spam but still shows errors.
call npm install -g n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit
echo.
echo  Verifying installation...
where n8n >nul 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [✗] Installation failed! n8n command not found.
    echo  Please check the error messages above.
    pause
    exit /b 1
)
echo  [✓] n8n installed globally
goto CREATE_START_SCRIPT

:INSTALL_FOLDER
echo  Running: npm install n8n in !N8N_INSTALL_PATH!
echo  This may take a few minutes...
echo.
REM cd /d leaves ERRORLEVEL untouched on success, so test the path instead.
if not exist "!N8N_INSTALL_PATH!\" (
    echo.
    echo  [✗] Could not change to directory: !N8N_INSTALL_PATH!
    pause
    exit /b 1
)
cd /d "!N8N_INSTALL_PATH!"
call npm install n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit
echo.
echo  Verifying installation...
if not exist "!N8N_INSTALL_PATH!\node_modules\n8n" (
    echo.
    echo  [✗] Installation failed! n8n not found in node_modules.
    echo  Please check the error messages above or review: !LOG_FILE!
    pause
    exit /b 1
)
echo  [✓] n8n installed to folder

REM Add to PATH if folder installation
set "N8N_BIN=!N8N_INSTALL_PATH!\node_modules\.bin"
echo.
echo  Adding !N8N_BIN! to PATH...

echo %PATH% | find /i "!N8N_BIN!" >nul
if !ERRORLEVEL! EQU 0 (
    echo  [✓] Already in PATH
) else (
    for /f "skip=2 tokens=3*" %%a in ('reg query HKCU\Environment /v PATH 2^>nul') do set "CURRENT_PATH=%%b"
    if "!CURRENT_PATH!"=="" (
        setx PATH "!N8N_BIN!"
    ) else (
        setx PATH "!N8N_BIN!;!CURRENT_PATH!"
    )
    echo  [✓] Added to PATH (restart terminal to use)
)
goto CREATE_START_SCRIPT

:INSTALL_DOCKER
echo  Creating Docker volume: !DOCKER_VOLUME!
echo.
docker volume create !DOCKER_VOLUME! 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [✗] Failed to create Docker volume
    pause
    exit /b 1
)
echo  [✓] Docker volume created
echo.

echo  Pulling n8n Docker image...
echo  This may take a few minutes...
echo.
docker pull docker.n8n.io/n8nio/n8n 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [✗] Failed to pull n8n Docker image
    pause
    exit /b 1
)
echo  [✓] n8n Docker image downloaded
echo.

echo  Starting n8n container: !DOCKER_CONTAINER!
echo.
docker run -d --name !DOCKER_CONTAINER! --restart unless-stopped -p !N8N_PORT!:5678 -e GENERIC_TIMEZONE="!DOCKER_TIMEZONE!" -e TZ="!DOCKER_TIMEZONE!" -v !DOCKER_VOLUME!:/home/node/.n8n docker.n8n.io/n8nio/n8n 2>&1
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [✗] Failed to start n8n container
    echo  Note: If container already exists, run: docker rm !DOCKER_CONTAINER!
    pause
    exit /b 1
)
echo  [✓] n8n container started successfully
echo.

REM Wait a moment for container to start
echo  Waiting for container to initialize...
timeout /t 5 /nobreak >nul

REM Verify container is running
docker ps --filter name=!DOCKER_CONTAINER! --filter status=running | find "!DOCKER_CONTAINER!" >nul
if !ERRORLEVEL! NEQ 0 (
    echo.
    echo  [^^!] Warning: Container may not be running properly
    echo  Check logs with: docker logs !DOCKER_CONTAINER!
)
goto CREATE_START_SCRIPT

:CREATE_START_SCRIPT
REM n8n 2.x runs a Task Broker on a second port, default 5679. Two instances
REM would fight over it, so it is derived from the UI port instead.
set /a N8N_BROKER_PORT=!N8N_PORT!+1
REM Create start script and README
echo.
echo  Creating start script and documentation...

if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    REM Docker installation - no scripts needed, use Docker Desktop
    set "N8N_INSTALL_PATH=%SCRIPTDIR%"
) else (
    REM Set start script location based on install type
    if "!N8N_INSTALL_TYPE!"=="GLOBAL" (
        REM Global install - save start script to user profile n8n folder
        if not exist "%USERPROFILE%\n8n" mkdir "%USERPROFILE%\n8n"
        set "START_SCRIPT=%USERPROFILE%\n8n\start_n8n.bat"
        set "N8N_INSTALL_PATH=%USERPROFILE%\n8n"
    ) else (
        set "START_SCRIPT=!N8N_INSTALL_PATH!\start_n8n.bat"
    )

    if "!N8N_INSTALL_TYPE!"=="FOLDER" (
        REM Folder installation - use npx
        (
            echo @echo off
            echo setlocal enabledelayedexpansion
            echo set N8N_USER_FOLDER=!N8N_DATA_PATH!
            echo set N8N_PORT=!N8N_PORT!
            echo set N8N_RUNNERS_BROKER_PORT=!N8N_BROKER_PORT!
            echo set N8N_PROTOCOL=http
            echo set N8N_HOST=!N8N_HOST!
            echo set N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
            echo set N8N_UNVERIFIED_PACKAGES_ENABLED=true
            echo REM set EXECUTIONS_DATA_PRUNE=true
            echo REM set EXECUTIONS_DATA_MAX_AGE=168
            echo REM set WEBHOOK_URL=https://n8n.example.com/
            echo.
            echo cd /d "!N8N_INSTALL_PATH!"
            if "!AUTO_UPDATE!"=="YES" (
                echo.
                echo echo Checking for n8n updates...
                echo for /f "tokens=*" %%%%i in ^('npm view n8n version 2^^^>nul'^) do set LATEST=%%%%i
                echo for /f "tokens=*" %%%%i in ^('npx n8n --version 2^^^>nul'^) do set CURRENT=%%%%i
                echo if not "^^!CURRENT^^!"=="^^!LATEST^^!" ^(
                echo     echo.
                echo     echo   Update available: ^^!CURRENT^^! -^^^> ^^!LATEST^^!
                echo     echo.
                echo     set /p "DO_UPDATE=  Update now? [Y/N]: "
                echo     if /i "^^!DO_UPDATE^^!"=="Y" ^(
                echo         echo.
                echo         echo   Updating n8n...
                echo         npm update n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit
                echo         echo.
                echo         echo   [OK] Update complete
                echo         echo.
                echo     ^)
                echo ^) else ^(
                echo     echo   [OK] n8n is up to date [v^^!CURRENT^^!]
                echo ^)
                echo echo.
            )
            echo echo Starting n8n...
            echo echo Access n8n at: http://!N8N_HOST!:!N8N_PORT!
            echo echo.
            echo npx n8n start
            echo.
            echo REM Keeps the window open if n8n exits, so the error stays readable
            echo pause
        ) > "!START_SCRIPT!"
    ) else (
        REM Global installation - direct command
        (
            echo @echo off
            echo setlocal enabledelayedexpansion
            echo set N8N_USER_FOLDER=!N8N_DATA_PATH!
            echo set N8N_PORT=!N8N_PORT!
            echo set N8N_RUNNERS_BROKER_PORT=!N8N_BROKER_PORT!
            echo set N8N_PROTOCOL=http
            echo set N8N_HOST=!N8N_HOST!
            echo set N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
            echo set N8N_UNVERIFIED_PACKAGES_ENABLED=true
            echo REM set EXECUTIONS_DATA_PRUNE=true
            echo REM set EXECUTIONS_DATA_MAX_AGE=168
            echo REM set WEBHOOK_URL=https://n8n.example.com/
            echo.
            if "!AUTO_UPDATE!"=="YES" (
                echo echo Checking for n8n updates...
                echo for /f "tokens=*" %%%%i in ^('npm view n8n version 2^^^>nul'^) do set LATEST=%%%%i
                echo for /f "tokens=*" %%%%i in ^('n8n --version 2^^^>nul'^) do set CURRENT=%%%%i
                echo if not "^^!CURRENT^^!"=="^^!LATEST^^!" ^(
                echo     echo.
                echo     echo   Update available: ^^!CURRENT^^! -^^^> ^^!LATEST^^!
                echo     echo.
                echo     set /p "DO_UPDATE=  Update now? [Y/N]: "
                echo     if /i "^^!DO_UPDATE^^!"=="Y" ^(
                echo         echo.
                echo         echo   Updating n8n globally...
                echo         npm update -g n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit
                echo         echo.
                echo         echo   [OK] Update complete
                echo         echo.
                echo     ^)
                echo ^) else ^(
                echo     echo   [OK] n8n is up to date [v^^!CURRENT^^!]
                echo ^)
                echo echo.
            )
            echo echo Starting n8n...
            echo echo Access n8n at: http://!N8N_HOST!:!N8N_PORT!
            echo echo.
            echo n8n start
            echo.
            echo REM Keeps the window open if n8n exits, so the error stays readable
            echo pause
        ) > "!START_SCRIPT!"
    )

    echo  [OK] Start script created: !START_SCRIPT!
)

REM Create desktop shortcut if requested
if "!CREATE_SHORTCUT!"=="YES" (
    echo.
    echo  Creating desktop shortcut...
    set "SHORTCUT_FILE=!SHORTCUT_PATH!\Start n8n.lnk"
    
    REM Use PowerShell to create the shortcut
    powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('!SHORTCUT_FILE!'); $s.TargetPath = '!START_SCRIPT!'; $s.WorkingDirectory = '!N8N_INSTALL_PATH!'; $s.Description = 'Start n8n Workflow Automation'; $s.Save()" 2>nul
    
    if exist "!SHORTCUT_FILE!" (
        echo  [OK] Desktop shortcut created: !SHORTCUT_FILE!
    ) else (
        echo  [^^!] Could not create desktop shortcut
    )
)

REM Create README file
echo.
echo  Creating README file...
set "README_FILE=!N8N_INSTALL_PATH!\README.txt"
echo  README path: !README_FILE!

echo ════════════════════════════════════════════════════════════════ > "!README_FILE!"
echo  n8n - Workflow Automation Platform >> "!README_FILE!"
echo  Windows Installation - Community Edition >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo IMPORTANT NOTICE: >> "!README_FILE!"
echo ───────────────── >> "!README_FILE!"
echo  This is an UNOFFICIAL community-made installer for n8n on Windows. >> "!README_FILE!"
echo  This installer is NOT affiliated with, endorsed by, or connected to >> "!README_FILE!"
echo  n8n.io or n8n GmbH in any way. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  For official n8n support, please visit: >> "!README_FILE!"
echo  • https://community.n8n.io >> "!README_FILE!"
echo  • https://docs.n8n.io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  For installer issues or contributions: >> "!README_FILE!"
echo  • GitHub: https://github.com/web3Leander >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo Installation Details: >> "!README_FILE!"
echo ───────────────────── >> "!README_FILE!"
echo  Installation Type: !N8N_INSTALL_TYPE! >> "!README_FILE!"
if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  Container Name:    !DOCKER_CONTAINER! >> "!README_FILE!"
    echo  Docker Volume:     !DOCKER_VOLUME! >> "!README_FILE!"
    echo  Timezone:          !DOCKER_TIMEZONE! >> "!README_FILE!"
    echo  Network Port:      !N8N_PORT! >> "!README_FILE!"
) else (
    echo  Installation Path: !N8N_INSTALL_PATH! >> "!README_FILE!"
    echo  Data Directory:    !N8N_DATA_PATH!\.n8n (created on first run) >> "!README_FILE!"
    echo  Start Script:      !START_SCRIPT! >> "!README_FILE!"
    echo  Network Host:      !N8N_HOST! >> "!README_FILE!"
    echo  Network Port:      !N8N_PORT! >> "!README_FILE!"
)
echo  Installation Date: %DATE% %TIME% >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  QUICK START GUIDE >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  Managing Your n8n Docker Container: >> "!README_FILE!"
    echo  ───────────────────────────────── >> "!README_FILE!"
    echo  • Start:   docker start !DOCKER_CONTAINER! >> "!README_FILE!"
    echo  • Stop:    docker stop !DOCKER_CONTAINER! >> "!README_FILE!"
    echo  • Restart: docker restart !DOCKER_CONTAINER! >> "!README_FILE!"
    echo  • Or use Docker Desktop to manage the container >> "!README_FILE!"
    echo. >> "!README_FILE!"
    echo  Accessing n8n: >> "!README_FILE!"
    echo  ───────────── >> "!README_FILE!"
    echo  1. Make sure the container is running >> "!README_FILE!"
    echo  2. Open your browser to: http://localhost:!N8N_PORT! >> "!README_FILE!"
    echo  3. Follow the setup wizard to create your account >> "!README_FILE!"
    echo  4. Start building your first workflow! >> "!README_FILE!"
    echo. >> "!README_FILE!"
    echo  Useful Docker Commands: >> "!README_FILE!"
    echo  ────────────────────── >> "!README_FILE!"
    echo  • View container status: docker ps -a >> "!README_FILE!"
    echo  • View logs:             docker logs -f !DOCKER_CONTAINER! >> "!README_FILE!"
    echo  • Access container:      docker exec -it !DOCKER_CONTAINER! sh >> "!README_FILE!"
    echo  • Remove container:      docker rm -f !DOCKER_CONTAINER! >> "!README_FILE!"
    echo  • Backup data volume:    docker volume inspect !DOCKER_VOLUME! >> "!README_FILE!"
) else (
    echo  1. Double-click or run: !START_SCRIPT! >> "!README_FILE!"
    echo  2. Wait for n8n to start (you'll see "Editor is now accessible") >> "!README_FILE!"
    echo  3. Open your browser to: http://!N8N_HOST!:!N8N_PORT! >> "!README_FILE!"
    echo  4. Follow the setup wizard to create your account >> "!README_FILE!"
    echo  5. Start building your first workflow! >> "!README_FILE!"
)
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  USEFUL COMMANDS >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Start n8n:     Double-click start_n8n.bat or run from terminal >> "!README_FILE!"
echo  Stop n8n:      Press Ctrl+C in the terminal window running n8n >> "!README_FILE!"
echo  Access UI:     http://!N8N_HOST!:!N8N_PORT! >> "!README_FILE!"
echo  View logs:     Check terminal window where n8n is running >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  ENVIRONMENT VARIABLES >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  The following environment variables are configured in your >> "!README_FILE!"
echo  start_n8n.bat script: >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  N8N_USER_FOLDER:  !N8N_DATA_PATH! >> "!README_FILE!"
echo  N8N_HOST:         !N8N_HOST! >> "!README_FILE!"
echo  N8N_PORT:         !N8N_PORT! >> "!README_FILE!"
echo  N8N_PROTOCOL:     http >> "!README_FILE!"
echo  N8N_UNVERIFIED_PACKAGES_ENABLED: true ^(allows UI community package installs^) >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Optional environment variables in start_n8n.bat ^(uncomment to enable^): >> "!README_FILE!"
echo  • EXECUTIONS_DATA_PRUNE=true       ^(enables automatic execution data pruning^) >> "!README_FILE!"
echo  • EXECUTIONS_DATA_MAX_AGE=168      ^(prunes executions older than 7 days^) >> "!README_FILE!"
echo  • WEBHOOK_URL=https://n8n.example.com/  ^(for reverse proxies and external webhooks^) >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  IMPORTANT: n8n automatically creates a .n8n subfolder inside >> "!README_FILE!"
echo  N8N_USER_FOLDER for storing all data. Your actual data will be at: >> "!README_FILE!"
echo  !N8N_DATA_PATH!\.n8n\ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  This folder contains your workflows, credentials, settings, and >> "!README_FILE!"
echo  database. It will be created automatically when you first run n8n. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  ENCRYPTION KEY BACKUP REMINDER: >> "!README_FILE!"
echo  • n8n saves its auto-generated encryption key in !N8N_DATA_PATH!\.n8n\config >> "!README_FILE!"
echo  • ALWAYS back up this file before upgrades or moving instances! >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  SECURITY AND TASK RUNNERS >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  • This installation includes 100%% of n8n Community Edition features. >> "!README_FILE!"
echo  • Code nodes run as internal child processes, which is standard for >> "!README_FILE!"
echo    personal, local development, and trusted single-user setups. >> "!README_FILE!"
echo  • For multi-tenant production setups with untrusted workflow authors, >> "!README_FILE!"
echo    refer to n8n's external task runners guide: https://docs.n8n.io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  OFFICIAL n8n RESOURCES >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Official Website:     https://n8n.io >> "!README_FILE!"
echo  Documentation:        https://docs.n8n.io >> "!README_FILE!"
echo  Community Forum:      https://community.n8n.io >> "!README_FILE!"
echo  GitHub Repository:    https://github.com/n8n-io/n8n >> "!README_FILE!"
echo  Workflow Templates:   https://n8n.io/workflows >> "!README_FILE!"
echo  YouTube Channel:      https://www.youtube.com/@n8n-io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  TROUBLESHOOTING >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  n8n won't start: >> "!README_FILE!"
echo  • Check that port !N8N_PORT! is not already in use >> "!README_FILE!"
echo  • Try running: netstat -ano ^| findstr :!N8N_PORT! >> "!README_FILE!"
echo  • Make sure Node.js is properly installed >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Can't access the web interface: >> "!README_FILE!"
echo  • Verify n8n is running (check the terminal window) >> "!README_FILE!"
echo  • Try accessing: http://localhost:!N8N_PORT! >> "!README_FILE!"
echo  • Check Windows Firewall settings if using non-localhost IP >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Port already in use: >> "!README_FILE!"
echo  • Edit start_n8n.bat and change N8N_PORT to a different port >> "!README_FILE!"
echo  • Common alternatives: 3000, 5000, 8080 >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Need to move your data: >> "!README_FILE!"
echo  • Your data is stored in: !N8N_DATA_PATH!\.n8n\ >> "!README_FILE!"
echo  • To move to a new location, copy the entire .n8n folder >> "!README_FILE!"
echo  • Update N8N_USER_FOLDER in start_n8n.bat to the new base path >> "!README_FILE!"
echo  • Do NOT include .n8n in the path - n8n adds it automatically >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  For more help: >> "!README_FILE!"
echo  • Visit the n8n community: https://community.n8n.io >> "!README_FILE!"
echo  • Check the docs: https://docs.n8n.io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  SYSTEM INFORMATION >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Installation Date: %DATE% %TIME% >> "!README_FILE!"
echo  Installer Version: 0.2 >> "!README_FILE!"
echo  Node.js Version:   Run 'node --version' to check >> "!README_FILE!"
echo  npm Version:       Run 'npm --version' to check >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  CREDITS >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  This community installer was created by: >> "!README_FILE!"
echo  • GitHub: https://github.com/web3Leander >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  n8n is developed and maintained by n8n GmbH: >> "!README_FILE!"
echo  • GitHub: https://github.com/n8n-io/n8n >> "!README_FILE!"
echo  • Website: https://n8n.io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  DISCLAIMER: This installer is an unofficial, community-created >> "!README_FILE!"
echo  tool and is not affiliated with n8n.io or n8n GmbH. For official >> "!README_FILE!"
echo  support, please use the official n8n channels listed above. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"

echo  [✓] README created: !README_FILE!

goto INSTALLATION_COMPLETE

:INSTALLATION_COMPLETE
cls
echo.
echo  ════════════════════════════════════════════════════════
echo      n8n Installation Wizard
echo      Installation Complete!
echo  ════════════════════════════════════════════════════════
echo.
echo  Step 4 of 4: Installation Complete
echo  ────────────────────────────────────────
echo.
if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  [✓] n8n installed to: Docker Container
    echo  [✓] Container name: !DOCKER_CONTAINER!
    echo  [✓] Data volume: !DOCKER_VOLUME!
    echo  [✓] README file: !N8N_INSTALL_PATH!\README.txt
) else if "!N8N_INSTALL_TYPE!"=="GLOBAL" (
    for /f "tokens=*" %%i in ('n8n --version 2^>nul') do set N8N_VERSION=%%i
    if defined N8N_VERSION (
        echo  [✓] n8n !N8N_VERSION! installed globally
    ) else (
        echo  [✓] n8n installed globally
    )
    echo  [✓] n8n command available system-wide
) else (
    echo  [✓] n8n installed to: !N8N_INSTALL_PATH!
    echo  [✓] Restart terminal for PATH changes
)
if not "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  [✓] Data directory: !N8N_DATA_PATH!
    echo  [✓] Start script: !START_SCRIPT!
    echo  [✓] README file: !N8N_INSTALL_PATH!\README.txt
)
echo.
echo  ────────────────────────────────────────
echo.
echo  Thank you for using this community installer!
echo.
echo  Installer by: https://github.com/web3Leander
echo  n8n by n8n GmbH: https://n8n.io
echo.
echo  REMINDER: This is an unofficial community tool.
echo  For n8n support, visit: https://community.n8n.io
echo.
echo  ────────────────────────────────────────
echo.
echo  Next Steps:
if "!N8N_INSTALL_TYPE!"=="DOCKER" (
    echo  1. Container is running - manage via Docker Desktop
    echo  2. Open http://localhost:!N8N_PORT! in your browser
    echo  3. Create your first workflow
) else if "!N8N_INSTALL_TYPE!"=="FOLDER" (
    echo  1. Close and reopen your terminal
    echo  2. Run: !START_SCRIPT!
    echo  3. Open http://!N8N_HOST!:!N8N_PORT! in your browser
    echo  4. Create your first workflow
) else (
    echo  1. Run: !START_SCRIPT!
    echo  2. Open http://!N8N_HOST!:!N8N_PORT! in your browser
    echo  3. Create your first workflow
)
echo.
echo  For more information, see README.txt in the installation folder
echo.
pause
exit /b 0

REM ════════════════════════════════════════════════════════════════
REM  WSL2 INSTALLATION FLOW (Option 4)
REM  Self-contained: shares no code with options 1, 2 or 3.
REM ════════════════════════════════════════════════════════════════
:WSL_FLOW
set "N8N_INSTALL_TYPE=WSL"
set "WSL_PROBE_FILE=%TEMP%\n8n_wsl_probe.txt"
set "WSL_PATH_HINT=/usr/local/bin"
set "WSL_NODE_ATTEMPTED=NO"

:ASK_WSL_DISTRO
cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 2 of 4: Choose WSL Distribution
echo  ────────────────────────────────────────
echo.
set "WSL_IDX=0"
for /f "usebackq tokens=1,2,3 delims=|" %%A in ("%WSL_LIST_FILE%") do (
    set /a WSL_IDX+=1
    set "WSL_NAME_!WSL_IDX!=%%A"
    set "WSL_VER_!WSL_IDX!=%%B"
    if "%%B"=="1" (
        echo   !WSL_IDX!. %%A  [WSL1 - %%C]
    ) else (
        echo   !WSL_IDX!. %%A  [WSL2 - %%C]
    )
)
echo.
echo   B. Back to installation menu
echo.
set "WSL_PICK="
set /p "WSL_PICK=  Select distribution (1-!WSL_IDX!, or B): "
if /i "!WSL_PICK!"=="B" goto CUSTOM_INSTALL

set "WSL_DISTRO="
set "WSL_VERSION="
for /l %%N in (1,1,!WSL_IDX!) do (
    if "!WSL_PICK!"=="%%N" (
        set "WSL_DISTRO=!WSL_NAME_%%N!"
        set "WSL_VERSION=!WSL_VER_%%N!"
    )
)
if not defined WSL_DISTRO (
    echo.
    echo  [✗] Invalid choice. Please try again.
    timeout /t 2 /nobreak >nul
    goto ASK_WSL_DISTRO
)

REM wsl.exe does not strip quotes from -d, so a quoted name is looked up
REM verbatim and fails. That means a name containing a space is unreachable.
if not "!WSL_DISTRO: =!"=="!WSL_DISTRO!" (
    echo.
    echo  [✗] "!WSL_DISTRO!" contains a space and cannot be targeted by wsl.exe
    echo      Rename or re-import the distribution without spaces to use it.
    echo.
    pause
    goto ASK_WSL_DISTRO
)

if "!WSL_VERSION!"=="1" (
    echo.
    echo  [^^!] !WSL_DISTRO! is running on WSL1
    echo      WSL2 is strongly recommended: WSL1 has known SQLite file
    echo      locking and networking differences that affect n8n.
    echo.
    echo      To upgrade later:  wsl --set-version !WSL_DISTRO! 2
    echo.
    set "WSL1_OK="
    set /p "WSL1_OK=  Continue with WSL1 anyway? (Y/N): "
    if /i not "!WSL1_OK!"=="Y" goto ASK_WSL_DISTRO
)

:WSL_PROBE
echo.
echo  Inspecting !WSL_DISTRO!...
echo  ^(this can take a few seconds if the distribution is stopped^)
if exist "%WSL_PROBE_FILE%" del "%WSL_PROBE_FILE%" >nul 2>&1
for %%K in (WSLUSER WSLHOME OSID OSLIKE HASBASH NODEPATH NODEVER NPMVER NPMPREFIX N8NPATH N8NVER) do set "WSLP_%%K="

REM Probed as the DEFAULT USER, because that user's PATH is what the generated
REM launcher will actually run under. Sentinel values keep every key non-empty.
REM No double quotes and no # inside the sh string: both break batch or sh.
REM --exec is mandatory: without it wsl.exe runs the command through the distro
REM default shell, which expands the whole string first. That turns every $VAR
REM into an empty string and explodes $PATH on "Program Files (x86)".
REM The resolved node bin dir is prepended before probing npm and n8n, so this
REM sees exactly what the generated launcher will see.
wsl -d !WSL_DISTRO! --exec sh -c "PATH=!WSL_PATH_HINT!:$PATH; export PATH; echo WSLUSER=$(whoami); echo WSLHOME=$HOME; if [ -r /etc/os-release ]; then . /etc/os-release; fi; echo OSID=${ID:-none}; echo OSLIKE=${ID_LIKE:-none}; BH=$(command -v bash 2>/dev/null); echo HASBASH=${BH:-none}; NP=$(command -v node 2>/dev/null); NP=${NP:-none}; if [ $NP = none ]; then echo NODEPATH=none; else RP=$(readlink -f $NP); echo NODEPATH=$RP; PATH=$(dirname $RP):$PATH; export PATH; fi; echo NODEVER=$(node -v 2>/dev/null || echo none); echo NPMVER=$(npm -v 2>/dev/null || echo none); echo NPMPREFIX=$(npm config get prefix 2>/dev/null || echo none); NB=$(command -v n8n 2>/dev/null); echo N8NPATH=${NB:-none}; echo N8NVER=$(n8n --version 2>/dev/null || echo none)" <nul > "%WSL_PROBE_FILE%" 2>nul

if not exist "%WSL_PROBE_FILE%" (
    echo.
    echo  [✗] Could not run commands inside !WSL_DISTRO!
    echo      Try starting it once manually:  wsl -d !WSL_DISTRO!
    echo.
    pause
    goto ASK_WSL_DISTRO
)

for /f "usebackq tokens=1,* delims==" %%K in ("%WSL_PROBE_FILE%") do set "WSLP_%%K=%%L"

if not defined WSLP_WSLUSER (
    echo.
    echo  [✗] !WSL_DISTRO! did not respond as expected.
    echo      Try starting it once manually:  wsl -d !WSL_DISTRO!
    echo.
    pause
    goto ASK_WSL_DISTRO
)

REM Node version rule mirrors the Windows gate exactly: 20.19+ or 22.x
set "WSL_NODE_OK=NO"
set "WSL_NODE_MAJOR="
set "WSL_NODE_MINOR="
if not defined WSLP_NODEVER set "WSLP_NODEVER=none"
if not defined WSLP_NODEPATH set "WSLP_NODEPATH=none"
if not defined WSLP_NPMPREFIX set "WSLP_NPMPREFIX=none"
if not defined WSLP_NPMVER set "WSLP_NPMVER=none"
if not defined WSLP_N8NPATH set "WSLP_N8NPATH=none"
if not defined WSLP_N8NVER set "WSLP_N8NVER=none"
if not defined WSLP_OSID set "WSLP_OSID=none"
if not defined WSLP_OSLIKE set "WSLP_OSLIKE=none"
if not defined WSLP_HASBASH set "WSLP_HASBASH=none"
if not "!WSLP_NODEVER!"=="none" (
    set "WSL_NV=!WSLP_NODEVER:~1!"
    for /f "tokens=1,2 delims=." %%a in ("!WSL_NV!") do (
        set "WSL_NODE_MAJOR=%%a"
        set "WSL_NODE_MINOR=%%b"
    )
)
if not defined WSL_NODE_MINOR set "WSL_NODE_MINOR=0"
if "!WSL_NODE_MAJOR!"=="20" (
    if !WSL_NODE_MINOR! GEQ 19 set "WSL_NODE_OK=YES"
) else if "!WSL_NODE_MAJOR!"=="22" (
    set "WSL_NODE_OK=YES"
)

REM Ownership decides root vs user install. A Node managed under the user's home
REM (nvm) must never be written to as root, or the user's Node tree ends up
REM root-owned and broken.
set "WSL_USE_ROOT=YES"
set "WSL_NVM=NO"
if "!WSLP_NPMPREFIX:~0,6!"=="/home/" set "WSL_USE_ROOT=NO"
set "WSL_TMPCHK=!WSLP_NPMPREFIX:/nvm/=!"
if not "!WSL_TMPCHK!"=="!WSLP_NPMPREFIX!" set "WSL_USE_ROOT=NO"
set "WSL_TMPCHK=!WSLP_NODEPATH:/nvm/=!"
if not "!WSL_TMPCHK!"=="!WSLP_NODEPATH!" set "WSL_NVM=YES"
if "!WSLP_WSLUSER!"=="root" set "WSL_USE_ROOT=YES"

REM nvm cannot run without bash, so the nvm route is only genuinely available
REM when both are present.
set "WSL_NVM_OK=NO"
if "!WSL_NVM!"=="YES" if not "!WSLP_HASBASH!"=="none" set "WSL_NVM_OK=YES"

REM Package family is resolved here, not at install time, so the menu can be
REM honest about what it will actually deliver.
set "WSL_PKG_OK=NO"
if /i "!WSLP_OSID!"=="ubuntu" set "WSL_PKG_OK=DEB"
if /i "!WSLP_OSID!"=="debian" set "WSL_PKG_OK=DEB"
if /i "!WSLP_OSLIKE!"=="debian" set "WSL_PKG_OK=DEB"
if /i "!WSLP_OSID!"=="alpine" set "WSL_PKG_OK=APK"
if /i "!WSLP_OSID!"=="fedora" set "WSL_PKG_OK=RPM"
if /i "!WSLP_OSID!"=="rhel" set "WSL_PKG_OK=RPM"
if /i "!WSLP_OSLIKE!"=="fedora" set "WSL_PKG_OK=RPM"
if /i "!WSLP_OSID!"=="arch" set "WSL_PKG_OK=PAC"
if /i "!WSLP_OSID!"=="opensuse-leap" set "WSL_PKG_OK=ZYP"
if /i "!WSLP_OSID!"=="opensuse-tumbleweed" set "WSL_PKG_OK=ZYP"

REM Only NodeSource pins 22.x. apk, pacman and zypper ship current Node, which
REM this installer would then reject, so do not promise 22 LTS there.
set "WSL_PKG_N22=NO"
if "!WSL_PKG_OK!"=="DEB" set "WSL_PKG_N22=YES"
if "!WSL_PKG_OK!"=="RPM" set "WSL_PKG_N22=YES"

set "WSL_NODE_OFFER=NO"
if "!WSL_USE_ROOT!"=="YES" if not "!WSL_PKG_OK!"=="NO" set "WSL_NODE_OFFER=YES"
if "!WSL_USE_ROOT!"=="NO" if "!WSL_NVM_OK!"=="YES" set "WSL_NODE_OFFER=YES"

set "WSL_NODEBIN=/usr/local/bin"
if not "!WSLP_NODEPATH!"=="none" set "WSL_NODEBIN=!WSLP_NODEPATH:~0,-5!"

if "!WSL_NODE_OK!"=="YES" goto WSL_CHECK_EXISTING

:WSL_NODE_DECISION
cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 2 of 4: Node.js inside !WSL_DISTRO!
echo  ────────────────────────────────────────
echo.
if "!WSLP_NODEVER!"=="none" (
    echo   Node.js found:  none
) else (
    echo   Node.js found:  !WSLP_NODEVER!
    echo   npm found:      !WSLP_NPMVER!
    echo   Real path:      !WSLP_NODEPATH!
)
echo   n8n requires:   Node.js 20.19+ or 22.x LTS
if "!WSL_USE_ROOT!"=="YES" (
    echo   Managed by:     the system
) else (
    echo   Managed by:     the user !WSLP_WSLUSER!
)
if "!WSL_NODE_ATTEMPTED!"=="YES" (
    echo.
    echo   [^^!] The last attempt did not change the detected version.
    echo       See the messages above for why. Option 2 still works.
)
echo.
echo  ────────────────────────────────────────
echo.
if "!WSL_USE_ROOT!"=="YES" (
    if "!WSL_PKG_N22!"=="YES" (
        echo   1. Install Node.js 22 LTS inside !WSL_DISTRO!   [recommended]
        echo      Installs system-wide as root from the official NodeSource
        echo      repository. Nothing else is changed.
    ) else if "!WSL_PKG_OK!"=="NO" (
        echo   1. Not offered for this setup
        echo      !WSL_DISTRO! identifies itself as "!WSLP_OSID!", which this
        echo      installer has no Node.js provisioning steps for.
    ) else (
        echo   1. Install Node.js from the !WSL_DISTRO! package manager
        echo      This distribution does not ship a Node.js 22 LTS package, so
        echo      you may get a newer version. It is re-checked afterwards and
        echo      you will be told if it is still unsupported.
    )
) else if "!WSL_NVM_OK!"=="YES" (
    echo   1. Install Node.js 22 LTS via nvm               [recommended]
    echo      Runs as !WSLP_WSLUSER!, not root. Your other versions are kept.
) else if "!WSL_NVM!"=="YES" (
    echo   1. Not offered for this setup
    echo      Node.js here is managed by nvm, which needs bash, and bash was
    echo      not found in !WSL_DISTRO!.
) else (
    echo   1. Not offered for this setup
    echo      Node.js here is managed inside !WSLP_WSLUSER!'s home folder but
    echo      nvm was not detected, so the installer will not touch it.
)
echo.
echo   2. Continue anyway with what is installed
echo      n8n may refuse to start or fail to build its database driver.
echo.
echo   3. Choose a different distribution
echo.
echo   4. Back to the installation menu
echo.
set "WSL_NODE_PICK="
set /p "WSL_NODE_PICK=  Your choice (1-4): "
if "!WSL_NODE_PICK!"=="3" goto ASK_WSL_DISTRO
if "!WSL_NODE_PICK!"=="4" goto CUSTOM_INSTALL
if "!WSL_NODE_PICK!"=="2" goto WSL_CHECK_EXISTING
if not "!WSL_NODE_PICK!"=="1" (
    echo.
    echo  [✗] Invalid choice. Please try again.
    timeout /t 2 /nobreak >nul
    goto WSL_NODE_DECISION
)
if not "!WSL_NODE_OFFER!"=="YES" (
    echo.
    echo  [✗] Option 1 is not available for this setup.
    timeout /t 3 /nobreak >nul
    goto WSL_NODE_DECISION
)

:WSL_INSTALL_NODE
echo.
echo  Installing Node.js 22 LTS inside !WSL_DISTRO!...
echo  This may take a few minutes.
echo.
if "!WSL_USE_ROOT!"=="NO" goto WSL_INSTALL_NODE_NVM
goto WSL_INSTALL_NODE_PKG

REM Emitted at nesting level 0: a literal ! inside an if-block would be paired
REM with the next one and everything between them silently deleted.
:WSL_INSTALL_NODE_NVM
REM nvm is a shell function that requires bash; under dash it silently fails to
REM resolve versions. nvm layout is <root>/versions/node/<ver>/bin/node.
REM The default alias is deliberately left alone - the launcher pins the full
REM PATH, so repointing the user's global default Node would be a needless
REM change to their environment.
wsl -d !WSL_DISTRO! --exec bash -c "NR=$(dirname $(dirname $(dirname $(dirname $(dirname !WSLP_NODEPATH!))))); if [ -s $NR/nvm.sh ]; then NRFOUND=1; else NR=$HOME/.nvm; fi; if [ -s $NR/nvm.sh ]; then . $NR/nvm.sh; nvm install 22; else echo NVM_SCRIPT_NOT_FOUND; exit 1; fi"
REM nvm only adjusts PATH in interactive shells, so ask it where 22 landed
REM instead of hoping a later 'command -v node' picks it up.
set "WSL_NEWBIN="
for /f "usebackq tokens=*" %%P in (`wsl -d !WSL_DISTRO! --exec bash -c "NR=$(dirname $(dirname $(dirname $(dirname $(dirname !WSLP_NODEPATH!))))); if [ -s $NR/nvm.sh ]; then NRFOUND=1; else NR=$HOME/.nvm; fi; . $NR/nvm.sh >/dev/null 2>&1; NW=$(nvm which 22 2>/dev/null); NW=${NW:-none}; if [ $NW = none ]; then echo none; else dirname $NW; fi" ^<nul`) do set "WSL_NEWBIN=%%P"
if defined WSL_NEWBIN if not "!WSL_NEWBIN!"=="none" set "WSL_PATH_HINT=!WSL_NEWBIN!"
goto WSL_NODE_RECHECK

:WSL_INSTALL_NODE_PKG
if "!WSL_PKG_OK!"=="DEB" (
    wsl -d !WSL_DISTRO! -u root --exec sh -c "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq curl ca-certificates python3 make g++ && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && apt-get install -y -qq nodejs"
) else if "!WSL_PKG_OK!"=="RPM" (
    wsl -d !WSL_DISTRO! -u root --exec sh -c "curl -fsSL https://rpm.nodesource.com/setup_22.x | bash - && dnf install -y -q nodejs gcc-c++ make python3"
) else if "!WSL_PKG_OK!"=="APK" (
    wsl -d !WSL_DISTRO! -u root --exec sh -c "apk add --no-cache nodejs npm python3 make g++ curl ca-certificates"
) else if "!WSL_PKG_OK!"=="PAC" (
    wsl -d !WSL_DISTRO! -u root --exec sh -c "pacman -Sy --noconfirm nodejs npm python make gcc curl ca-certificates"
) else if "!WSL_PKG_OK!"=="ZYP" (
    wsl -d !WSL_DISTRO! -u root --exec sh -c "zypper --non-interactive install nodejs npm python3 make gcc-c++ curl ca-certificates"
) else (
    echo  [✗] Unrecognised distribution: !WSLP_OSID!
    echo      The installer does not know how to provision Node.js here.
    echo.
    pause
    goto WSL_NODE_DECISION
)
set "WSL_PATH_HINT=/usr/bin"
goto WSL_NODE_RECHECK

:WSL_NODE_RECHECK
set "WSL_NODE_ATTEMPTED=YES"
echo.
echo  Re-checking Node.js inside !WSL_DISTRO!...
goto WSL_PROBE

:WSL_CHECK_EXISTING
if "!WSLP_N8NPATH!"=="none" goto WSL_ASK_PORT
cls
echo.
echo  ════════════════════════════════════════
echo   WARNING: Existing Installation Detected
echo  ════════════════════════════════════════
echo.
echo  n8n is already installed inside !WSL_DISTRO!:
echo  Version: !WSLP_N8NVER!
echo  Path:    !WSLP_N8NPATH!
echo.
echo  Reinstalling will OVERWRITE the n8n program.
echo.
echo  IMPORTANT:
echo  • Your workflows, credentials, and settings are
echo    stored in your data folder and will be preserved
echo  • The n8n program itself will be replaced
echo.
echo  ════════════════════════════════════════
echo   CONFIRMATION REQUIRED
echo  ════════════════════════════════════════
echo.
echo  To proceed with overwriting the existing installation,
echo  you must type: DELETE
echo.
echo  Type DELETE in CAPITAL LETTERS to confirm, or
echo  type anything else to cancel and go back.
echo.
set "WSL_OVERWRITE_CONFIRM="
set /p "WSL_OVERWRITE_CONFIRM=  Type DELETE to confirm: "
if not "!WSL_OVERWRITE_CONFIRM!"=="DELETE" (
    echo.
    echo  Installation cancelled. Returning to selection...
    timeout /t 2 /nobreak >nul
    goto ASK_WSL_DISTRO
)
echo.
echo  Confirmation accepted. Proceeding...
timeout /t 2 /nobreak >nul

:WSL_ASK_PORT
cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 2 of 4: Network Configuration
echo  ────────────────────────────────────────
echo.
if "!DEFAULT_PORT_IN_USE!"=="YES" (
    echo  [^^!] Note: Port 5678 is in use - please choose a different port
    echo.
)
echo  n8n will listen on 127.0.0.1 inside !WSL_DISTRO! and is reachable
echo  from Windows at http://localhost - WSL2 forwards it automatically.
echo.
echo  Port Number:
echo  • Press Enter for default: 5678
echo  • Or enter a custom port ^(1024-65535^)
echo.
set "N8N_PORT_INPUT="
set /p "N8N_PORT_INPUT=  Port (default: 5678): "
if "!N8N_PORT_INPUT!"=="" set "N8N_PORT=5678"
if defined N8N_PORT_INPUT set "N8N_PORT=!N8N_PORT_INPUT!"
set "N8N_HOST=127.0.0.1"

echo.
echo  Auto-Update Configuration
echo  ────────────────────────────────────────
echo.
echo  Would you like start_n8n_wsl.bat to check for updates?
echo  • Each time you start n8n, it will check for newer versions
echo  • You will be prompted before any update is installed
echo.
set "ENABLE_AUTO_UPDATE="
set /p "ENABLE_AUTO_UPDATE=  Enable auto-update check? (Y/N, default: N): "
if /i "!ENABLE_AUTO_UPDATE!"=="Y" (
    set "AUTO_UPDATE=YES"
) else (
    set "AUTO_UPDATE=NO"
)

echo.
echo  Desktop Shortcut
echo  ────────────────────────────────────────
echo.
echo  Create a desktop shortcut for start_n8n_wsl.bat?
echo.
echo    [1] Current user only ^(%USERNAME%^)
echo    [2] All users ^(Public Desktop^)
echo    [N] No shortcut
echo.
set "CREATE_SHORTCUT=NO"
set "SHORTCUT_PATH="
set "SHORTCUT_CHOICE="
set /p "SHORTCUT_CHOICE=  Your choice (1/2/N, default: N): "
if "!SHORTCUT_CHOICE!"=="1" (
    set "CREATE_SHORTCUT=YES"
    set "SHORTCUT_PATH=%USERPROFILE%\Desktop"
) else if "!SHORTCUT_CHOICE!"=="2" (
    set "CREATE_SHORTCUT=YES"
    set "SHORTCUT_PATH=%PUBLIC%\Desktop"
)

cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 2 of 4: Installation Summary
echo  ────────────────────────────────────────
echo.
echo  n8n Installation: WSL2 ^(Linux^)
echo  Distribution:     !WSL_DISTRO!
echo  Linux User:       !WSLP_WSLUSER!
echo  Node.js:          !WSLP_NODEVER!
echo  npm:              !WSLP_NPMVER!
if "!WSL_USE_ROOT!"=="YES" (
    echo  Install As:       root ^(system-wide^)
) else (
    echo  Install As:       !WSLP_WSLUSER! ^(user-managed Node.js^)
)
echo  Data Directory:   !WSLP_WSLHOME!/.n8n
echo  Access URL:       http://localhost:!N8N_PORT!
echo  Auto-Update Check: !AUTO_UPDATE!
echo  Desktop Shortcut: !CREATE_SHORTCUT!
echo.
set "WSL_FINAL="
set /p "WSL_FINAL=  Proceed with installation? (Y/N): "
if /i not "!WSL_FINAL!"=="Y" (
    echo.
    echo  Returning to Installation Setup...
    timeout /t 2 /nobreak >nul
    goto CUSTOM_INSTALL
)

:WSL_DO_INSTALL
cls
echo.
echo  ════════════════════════════════════════
echo      n8n Installation Wizard
echo  ════════════════════════════════════════
echo.
echo  Step 3 of 4: Installing n8n in !WSL_DISTRO!
echo  ────────────────────────────────────────
echo.
echo  Running: npm install -g n8n
echo  This may take a few minutes...
echo.
REM PATH is injected explicitly rather than relying on a login shell: sh -lc on
REM Debian derivatives reads ~/.profile and misses an nvm setup from ~/.bashrc.
if "!WSL_USE_ROOT!"=="YES" (
    wsl -d !WSL_DISTRO! -u root --exec sh -c "export PATH=!WSL_NODEBIN!:/usr/local/bin:/usr/bin:/bin:$PATH; npm install -g n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit"
) else (
    wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_NODEBIN!:$PATH; npm install -g n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit"
)

echo.
echo  Verifying installation...
set "WSL_N8N_FINAL="
for /f "usebackq tokens=*" %%V in (`wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_NODEBIN!:/usr/local/bin:/usr/bin:/bin:$PATH; n8n --version 2>/dev/null" ^<nul`) do set "WSL_N8N_FINAL=%%V"
if not defined WSL_N8N_FINAL (
    echo.
    echo  [✗] Installation failed! n8n command not found inside !WSL_DISTRO!
    echo  Please check the error messages above.
    echo.
    pause
    exit /b 1
)
echo  [✓] n8n !WSL_N8N_FINAL! installed inside !WSL_DISTRO!

:WSL_CREATE_LAUNCHER
echo.
echo  Creating start script and documentation...
REM Dedicated folder. A global install owns %USERPROFILE%\n8n, so sharing it
REM would let the two installs overwrite each other's files.
set "WSL_HOME_DIR=%USERPROFILE%\n8n-wsl"
if not exist "!WSL_HOME_DIR!" mkdir "!WSL_HOME_DIR!"
set "START_SCRIPT=!WSL_HOME_DIR!\start_n8n_wsl.bat"
REM WSL forwards every listener to Windows loopback, so n8n's Task Broker on
REM its default 5679 would block a native Windows install. Derive it instead.
set /a N8N_BROKER_PORT=!N8N_PORT!+1
set "WSL_RUNPATH=/usr/local/bin:/usr/bin:/bin:$PATH"
if not "!WSL_NODEBIN!"=="/usr/local/bin" set "WSL_RUNPATH=!WSL_NODEBIN!:/usr/local/bin:/usr/bin:/bin:$PATH"

REM The generated file deliberately contains no # and no literal ! - a # would
REM comment out the rest of the sh command, and ! would be eaten by delayed
REM expansion. Probed values are baked in so no nested quoting is needed.
(
    echo @echo off
    echo setlocal
    echo chcp 65001 ^>nul 2^>^&1
    echo TITLE n8n ^(WSL2 - !WSL_DISTRO!^)
    echo.
    echo REM Optional extras - add them inside the sh -c line below to enable:
    echo REM   export EXECUTIONS_DATA_PRUNE=true;
    echo REM   export EXECUTIONS_DATA_MAX_AGE=168;
    echo REM   export WEBHOOK_URL=https://n8n.example.com/;
    echo.
) > "!START_SCRIPT!"

REM Emitted at nesting level 0 with per-line appends. The generated script uses
REM goto labels and plain %VAR% instead of if-blocks with delayed expansion, so
REM no literal ! ever has to survive batch escaping. It also contains no #,
REM which would comment out the rest of the sh command.
if not "!AUTO_UPDATE!"=="YES" goto WSL_LAUNCHER_MAIN
echo setlocal enabledelayedexpansion>> "!START_SCRIPT!"
echo echo Checking for n8n updates...>> "!START_SCRIPT!"
echo for /f "usebackq tokens=*" %%%%i in (`wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; n8n --version 2>/dev/null"`) do set CURRENT=%%%%i>> "!START_SCRIPT!"
echo for /f "usebackq tokens=*" %%%%i in (`wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; npm view n8n version 2>/dev/null"`) do set LATEST=%%%%i>> "!START_SCRIPT!"
echo if "%%LATEST%%"=="" goto SKIPUPDATE>> "!START_SCRIPT!"
echo if "%%CURRENT%%"=="%%LATEST%%" goto UPTODATE>> "!START_SCRIPT!"
echo echo.>> "!START_SCRIPT!"
echo echo   Update available: %%CURRENT%% -^^^> %%LATEST%%>> "!START_SCRIPT!"
echo echo.>> "!START_SCRIPT!"
echo set /p "DO_UPDATE=  Update now? [Y/N]: ">> "!START_SCRIPT!"
echo if /i not "%%DO_UPDATE%%"=="Y" goto SKIPUPDATE>> "!START_SCRIPT!"
echo echo.>> "!START_SCRIPT!"
echo echo   Updating n8n...>> "!START_SCRIPT!"
if "!WSL_USE_ROOT!"=="YES" (
    echo wsl -d !WSL_DISTRO! -u root --exec sh -c "export PATH=!WSL_RUNPATH!; npm install -g n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit">> "!START_SCRIPT!"
) else (
    echo wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; npm install -g n8n --allow-scripts=sqlite3 --loglevel=error --no-fund --no-audit">> "!START_SCRIPT!"
)
echo echo.>> "!START_SCRIPT!"
echo echo   [OK] Update complete>> "!START_SCRIPT!"
echo goto SKIPUPDATE>> "!START_SCRIPT!"
echo :UPTODATE>> "!START_SCRIPT!"
echo echo   [OK] n8n is up to date [v%%CURRENT%%]>> "!START_SCRIPT!"
echo :SKIPUPDATE>> "!START_SCRIPT!"
echo echo.>> "!START_SCRIPT!"

:WSL_LAUNCHER_MAIN
echo echo Starting n8n inside WSL2 ^(!WSL_DISTRO!^)...>> "!START_SCRIPT!"
echo echo Access n8n at: http://localhost:!N8N_PORT!>> "!START_SCRIPT!"
echo echo.>> "!START_SCRIPT!"
REM N8N_HOST only sets the advertised URL. N8N_LISTEN_ADDRESS is the bind
REM interface, and it must be the IPv4 wildcard: n8n otherwise binds the IPv6
REM wildcard, and the WSL relay then publishes the port on [::1] only, so
REM http://127.0.0.1 on Windows is refused.
echo wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; export N8N_USER_FOLDER=!WSLP_WSLHOME!; export N8N_PORT=!N8N_PORT!; export N8N_RUNNERS_BROKER_PORT=!N8N_BROKER_PORT!; export N8N_PROTOCOL=http; export N8N_HOST=localhost; export N8N_LISTEN_ADDRESS=0.0.0.0; export N8N_UNVERIFIED_PACKAGES_ENABLED=true; exec n8n start">> "!START_SCRIPT!"
echo.>> "!START_SCRIPT!"
echo pause>> "!START_SCRIPT!"

echo  [✓] Start script created: !START_SCRIPT!

if "!CREATE_SHORTCUT!"=="YES" (
    echo.
    echo  Creating desktop shortcut...
    set "SHORTCUT_FILE=!SHORTCUT_PATH!\Start n8n (WSL).lnk"
    powershell -NoProfile -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('!SHORTCUT_FILE!'); $s.TargetPath = '!START_SCRIPT!'; $s.WorkingDirectory = '!WSL_HOME_DIR!'; $s.Description = 'Start n8n in WSL2'; $s.Save()" 2>nul
    if exist "!SHORTCUT_FILE!" (
        echo  [OK] Desktop shortcut created: !SHORTCUT_FILE!
    ) else (
        echo  [^^!] Could not create desktop shortcut
    )
)

:WSL_CREATE_README
echo.
echo  Creating README file...
REM A global install writes its own README.txt into this same folder, so the
REM WSL one uses a distinct name instead of overwriting it.
set "README_FILE=!WSL_HOME_DIR!\README.txt"
set "WSL_WINHOME=!WSLP_WSLHOME:/=\!"

echo ════════════════════════════════════════════════════════════════ > "!README_FILE!"
echo  n8n - Workflow Automation Platform >> "!README_FILE!"
echo  WSL2 ^(Linux^) Installation - Community Edition >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo IMPORTANT NOTICE: >> "!README_FILE!"
echo ───────────────── >> "!README_FILE!"
echo  This is an UNOFFICIAL community-made installer for n8n on Windows. >> "!README_FILE!"
echo  This installer is NOT affiliated with, endorsed by, or connected to >> "!README_FILE!"
echo  n8n.io or n8n GmbH in any way. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  For official n8n support, please visit: >> "!README_FILE!"
echo  • https://community.n8n.io >> "!README_FILE!"
echo  • https://docs.n8n.io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  For installer issues or contributions: >> "!README_FILE!"
echo  • GitHub: https://github.com/web3Leander >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo Installation Details: >> "!README_FILE!"
echo ───────────────────── >> "!README_FILE!"
echo  Installation Type: WSL2 ^(Linux^) >> "!README_FILE!"
echo  Distribution:      !WSL_DISTRO! >> "!README_FILE!"
echo  Linux User:        !WSLP_WSLUSER! >> "!README_FILE!"
echo  Node.js Version:   !WSLP_NODEVER! >> "!README_FILE!"
echo  npm Version:       !WSLP_NPMVER! >> "!README_FILE!"
echo  n8n Version:       !WSL_N8N_FINAL! >> "!README_FILE!"
echo  Data Directory:    !WSLP_WSLHOME!/.n8n >> "!README_FILE!"
echo  Start Script:      !START_SCRIPT! >> "!README_FILE!"
echo  Listen Address:    0.0.0.0 ^(inside the WSL VM only^) >> "!README_FILE!"
echo  Network Port:      !N8N_PORT! >> "!README_FILE!"
echo  Task Broker Port:  !N8N_BROKER_PORT! ^(n8n needs a second port^) >> "!README_FILE!"
echo  Installation Date: %DATE% %TIME% >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  QUICK START GUIDE >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  1. Double-click or run: !START_SCRIPT! >> "!README_FILE!"
echo  2. Wait for n8n to start ^(you'll see "Editor is now accessible"^) >> "!README_FILE!"
echo  3. Open your browser to: http://localhost:!N8N_PORT! >> "!README_FILE!"
echo  4. Follow the setup wizard to create your account >> "!README_FILE!"
echo  5. Start building your first workflow^^! >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  USEFUL COMMANDS >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Start n8n:     Double-click start_n8n_wsl.bat >> "!README_FILE!"
echo  Stop n8n:      Press Ctrl+C in the terminal window running n8n >> "!README_FILE!"
echo  Access UI:     http://localhost:!N8N_PORT! >> "!README_FILE!"
echo  Open a shell:  wsl -d !WSL_DISTRO! >> "!README_FILE!"
echo  Shut down WSL: wsl --shutdown >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  You are not tied to the launcher. These do the same thing: >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Start from Windows ^(one line^): >> "!README_FILE!"
echo    wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; export N8N_USER_FOLDER=!WSLP_WSLHOME!; export N8N_PORT=!N8N_PORT!; export N8N_LISTEN_ADDRESS=0.0.0.0; n8n start" >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Start from inside a WSL shell ^(run: wsl -d !WSL_DISTRO!^): >> "!README_FILE!"
echo    export PATH=!WSL_RUNPATH! >> "!README_FILE!"
echo    export N8N_USER_FOLDER=!WSLP_WSLHOME! >> "!README_FILE!"
echo    export N8N_PORT=!N8N_PORT! >> "!README_FILE!"
echo    export N8N_LISTEN_ADDRESS=0.0.0.0 >> "!README_FILE!"
echo    n8n start >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Keep the PATH line. Your interactive shell may select a different >> "!README_FILE!"
echo  Node.js than the one this installer used, and n8n would then either >> "!README_FILE!"
echo  not be found or run from the wrong version. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Stop n8n if the launcher window was closed without Ctrl+C: >> "!README_FILE!"
echo    wsl -d !WSL_DISTRO! --exec pkill -f "n8n start" >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Check it is listening: >> "!README_FILE!"
echo    wsl -d !WSL_DISTRO! --exec sh -c "ss -tulpn ^| grep !N8N_PORT!" >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Update n8n manually: >> "!README_FILE!"
if "!WSL_USE_ROOT!"=="YES" (
    echo    wsl -d !WSL_DISTRO! -u root --exec sh -c "export PATH=!WSL_RUNPATH!; npm install -g n8n@latest --allow-scripts=sqlite3" >> "!README_FILE!"
) else (
    echo    wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; npm install -g n8n@latest --allow-scripts=sqlite3" >> "!README_FILE!"
    echo    ^(installed under your user account, so root is not used^) >> "!README_FILE!"
)
echo. >> "!README_FILE!"
echo  The PATH matters here too. Without it npm may resolve to a different >> "!README_FILE!"
echo  Node.js version and install n8n somewhere the launcher never reads. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  YOUR DATA >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  n8n stores everything on the native Linux filesystem: >> "!README_FILE!"
echo    !WSLP_WSLHOME!/.n8n >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  From Windows Explorer you can reach it at: >> "!README_FILE!"
echo    \\wsl$\!WSL_DISTRO!!WSL_WINHOME!\.n8n >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  N8N_USER_FOLDER is set to !WSLP_WSLHOME! - n8n appends the .n8n >> "!README_FILE!"
echo  subfolder itself. Do NOT include .n8n in that value. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  IMPORTANT: Keep n8n data on the Linux filesystem. Storing it under >> "!README_FILE!"
echo  /mnt/c or any Windows drive causes SQLite locking errors and severe >> "!README_FILE!"
echo  slowdowns, because file locking does not cross that boundary safely. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  ENCRYPTION KEY BACKUP REMINDER: >> "!README_FILE!"
echo  • n8n saves its auto-generated encryption key in !WSLP_WSLHOME!/.n8n/config >> "!README_FILE!"
echo  • ALWAYS back up this file before upgrades or moving instances^^! >> "!README_FILE!"
echo  • Copy it out with: wsl -d !WSL_DISTRO! -- cat ~/.n8n/config >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  NETWORK ACCESS >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  n8n binds 0.0.0.0 inside the !WSL_DISTRO! VM. That VM sits behind NAT, so >> "!README_FILE!"
echo  this is still NOT reachable from other machines. WSL forwards the port to >> "!README_FILE!"
echo  Windows loopback only, so http://localhost:!N8N_PORT! just works. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  The IPv4 wildcard is deliberate. n8n defaults to the IPv6 wildcard, and >> "!README_FILE!"
echo  WSL then publishes the port on [::1] only, which makes http://127.0.0.1 >> "!README_FILE!"
echo  fail with ERR_CONNECTION_REFUSED while http://[::1] works. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  To deliberately expose it to your local network, a firewall rule is >> "!README_FILE!"
echo  NOT enough, because WSL2 runs behind NAT. You also need a portproxy. >> "!README_FILE!"
echo  Run these in an ADMINISTRATOR PowerShell, and understand the risk: >> "!README_FILE!"
echo. >> "!README_FILE!"
echo    wsl -d !WSL_DISTRO! -- hostname -I >> "!README_FILE!"
echo    netsh interface portproxy add v4tov4 listenport=!N8N_PORT! listenaddress=0.0.0.0 connectport=!N8N_PORT! connectaddress=^<WSL_IP^> >> "!README_FILE!"
echo    netsh advfirewall firewall add rule name="n8n WSL" dir=in action=allow protocol=TCP localport=!N8N_PORT! >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  The WSL IP changes on reboot unless mirrored networking is enabled. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  HOW TO UNINSTALL >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Run uninstall_n8n_wsl.bat, in this same folder. >> "!README_FILE!"
echo  It offers to back up your workflows first, and lets you choose >> "!README_FILE!"
echo  whether to keep or delete your data. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  It only removes what this installer created. It never touches your >> "!README_FILE!"
echo  Linux distribution, Node.js, or anything else you have installed. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  If you would rather do it by hand, these are the only steps needed: >> "!README_FILE!"
echo. >> "!README_FILE!"
echo    1. Press Ctrl+C in the window running n8n >> "!README_FILE!"
echo    2. Remove the n8n program: >> "!README_FILE!"
if "!WSL_USE_ROOT!"=="YES" (
    echo         wsl -d !WSL_DISTRO! -u root --exec sh -c "export PATH=!WSL_RUNPATH!; npm uninstall -g n8n" >> "!README_FILE!"
) else (
    echo         wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; npm uninstall -g n8n" >> "!README_FILE!"
)
echo    3. Delete the files in !WSL_HOME_DIR! if you want them gone >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Your workflows stay at !WSLP_WSLHOME!/.n8n until you delete that >> "!README_FILE!"
echo  folder yourself, so an uninstall is safe to reverse by reinstalling. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  TROUBLESHOOTING >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  n8n won't start: >> "!README_FILE!"
echo  • Check that port !N8N_PORT! is not already in use >> "!README_FILE!"
echo  • Try running: netstat -ano ^| findstr :!N8N_PORT! >> "!README_FILE!"
echo  • Verify n8n inside WSL: >> "!README_FILE!"
echo    wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; n8n --version" >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  "n8n: command not found" when starting: >> "!README_FILE!"
echo  • The launcher sets PATH explicitly. If you changed your Node.js >> "!README_FILE!"
echo    setup inside WSL, re-run the installer to regenerate the script. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Can't access the web interface: >> "!README_FILE!"
echo  • Confirm the launcher window is still open and running >> "!README_FILE!"
echo  • Try http://127.0.0.1:!N8N_PORT! as well as http://localhost:!N8N_PORT! >> "!README_FILE!"
echo  • If only http://[::1]:!N8N_PORT! works, N8N_LISTEN_ADDRESS was lost from >> "!README_FILE!"
echo    the launcher - it must stay set to 0.0.0.0 >> "!README_FILE!"
echo  • Restart the subsystem with: wsl --shutdown >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Database or permission errors: >> "!README_FILE!"
echo  • Check ownership: wsl -d !WSL_DISTRO! -- ls -la ~/.n8n >> "!README_FILE!"
echo  • Files must be owned by !WSLP_WSLUSER!, not root >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  For more help: >> "!README_FILE!"
echo  • Visit the n8n community: https://community.n8n.io >> "!README_FILE!"
echo  • Check the docs: https://docs.n8n.io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  SYSTEM INFORMATION >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  Installation Date: %DATE% %TIME% >> "!README_FILE!"
echo  Installer Version: 0.2 >> "!README_FILE!"
echo  WSL Distribution:  !WSL_DISTRO! >> "!README_FILE!"
echo  Linux Node.js:     !WSLP_NODEVER! >> "!README_FILE!"
echo  Linux npm:         !WSLP_NPMVER! >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo  CREDITS >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  This community installer was created by: >> "!README_FILE!"
echo  • GitHub: https://github.com/web3Leander >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  n8n is developed and maintained by n8n GmbH: >> "!README_FILE!"
echo  • GitHub: https://github.com/n8n-io/n8n >> "!README_FILE!"
echo  • Website: https://n8n.io >> "!README_FILE!"
echo. >> "!README_FILE!"
echo  DISCLAIMER: This installer is an unofficial, community-created >> "!README_FILE!"
echo  tool and is not affiliated with n8n.io or n8n GmbH. For official >> "!README_FILE!"
echo  support, please use the official n8n channels listed above. >> "!README_FILE!"
echo. >> "!README_FILE!"
echo ════════════════════════════════════════════════════════════════ >> "!README_FILE!"

echo  [✓] README created: !README_FILE!

:WSL_CREATE_UNINSTALLER
echo.
echo  Creating uninstaller...
set "UNINSTALL_SCRIPT=!WSL_HOME_DIR!\uninstall_n8n_wsl.bat"
set "WSL_BACKUP_DIR=%USERPROFILE%\Desktop\n8n-backup-!WSL_DISTRO!"

REM Emitted at nesting level 0. The generated file uses goto labels and plain
REM %VAR% so it needs no delayed expansion, and therefore contains no literal !
echo @echo off> "!UNINSTALL_SCRIPT!"
echo setlocal>> "!UNINSTALL_SCRIPT!"
echo chcp 65001 ^>nul 2^>^&1 >> "!UNINSTALL_SCRIPT!"
echo TITLE Uninstall n8n ^(WSL2 - !WSL_DISTRO!^)>> "!UNINSTALL_SCRIPT!"
echo.>> "!UNINSTALL_SCRIPT!"
echo :MENU>> "!UNINSTALL_SCRIPT!"
echo cls>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  ════════════════════════════════════════>> "!UNINSTALL_SCRIPT!"
echo echo   Uninstall n8n from WSL2 ^(!WSL_DISTRO!^)>> "!UNINSTALL_SCRIPT!"
echo echo  ════════════════════════════════════════>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  This removes only the n8n that the installer added to !WSL_DISTRO!.>> "!UNINSTALL_SCRIPT!"
echo echo  Node.js, the !WSL_DISTRO! distribution and everything else on your>> "!UNINSTALL_SCRIPT!"
echo echo  computer are left completely alone.>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo   1. Remove n8n, keep my workflows       [recommended]>> "!UNINSTALL_SCRIPT!"
echo echo   2. Remove n8n and delete my workflows>> "!UNINSTALL_SCRIPT!"
echo echo   3. Cancel>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo set "U=">> "!UNINSTALL_SCRIPT!"
echo set /p "U=  Your choice (1, 2 or 3): ">> "!UNINSTALL_SCRIPT!"
echo if "%%U%%"=="1" goto KEEP>> "!UNINSTALL_SCRIPT!"
echo if "%%U%%"=="2" goto WIPE>> "!UNINSTALL_SCRIPT!"
echo goto CANCEL>> "!UNINSTALL_SCRIPT!"
echo.>> "!UNINSTALL_SCRIPT!"
echo :KEEP>> "!UNINSTALL_SCRIPT!"
echo set "REMOVE_DATA=NO">> "!UNINSTALL_SCRIPT!"
echo goto RUN>> "!UNINSTALL_SCRIPT!"
echo.>> "!UNINSTALL_SCRIPT!"
echo :WIPE>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  This deletes your workflows, credentials and the encryption>> "!UNINSTALL_SCRIPT!"
echo echo  key that unlocks them. It cannot be undone.>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  Note: !WSLP_WSLHOME!/.n8n is the standard n8n folder for the>> "!UNINSTALL_SCRIPT!"
echo echo  Linux user !WSLP_WSLUSER!. If you run any other n8n as that user>> "!UNINSTALL_SCRIPT!"
echo echo  inside !WSL_DISTRO!, it shares this folder. Choose option 1 instead>> "!UNINSTALL_SCRIPT!"
echo echo  if you are unsure.>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo set "B=">> "!UNINSTALL_SCRIPT!"
echo set /p "B=  Back up to your Desktop first? (Y/N): ">> "!UNINSTALL_SCRIPT!"
echo if /i not "%%B%%"=="Y" goto WIPE_CONFIRM>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  Backing up...>> "!UNINSTALL_SCRIPT!"
echo powershell -NoProfile -Command "Copy-Item -LiteralPath '\\wsl$\!WSL_DISTRO!!WSL_WINHOME!\.n8n' -Destination '!WSL_BACKUP_DIR!' -Recurse -Force" 2^>nul>> "!UNINSTALL_SCRIPT!"
echo if not exist "!WSL_BACKUP_DIR!" goto BACKUP_FAILED>> "!UNINSTALL_SCRIPT!"
echo echo  [OK] Backup saved to !WSL_BACKUP_DIR!>> "!UNINSTALL_SCRIPT!"
echo goto WIPE_CONFIRM>> "!UNINSTALL_SCRIPT!"
echo.>> "!UNINSTALL_SCRIPT!"
echo :BACKUP_FAILED>> "!UNINSTALL_SCRIPT!"
echo echo  [X] Backup failed, so nothing has been deleted.>> "!UNINSTALL_SCRIPT!"
echo goto CANCEL>> "!UNINSTALL_SCRIPT!"
echo.>> "!UNINSTALL_SCRIPT!"
echo :WIPE_CONFIRM>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo set "C=">> "!UNINSTALL_SCRIPT!"
echo set /p "C=  Type DELETE in capital letters to confirm: ">> "!UNINSTALL_SCRIPT!"
echo if not "%%C%%"=="DELETE" goto CANCEL>> "!UNINSTALL_SCRIPT!"
echo set "REMOVE_DATA=YES">> "!UNINSTALL_SCRIPT!"
echo goto RUN>> "!UNINSTALL_SCRIPT!"
echo.>> "!UNINSTALL_SCRIPT!"
echo :RUN>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  Stopping n8n...>> "!UNINSTALL_SCRIPT!"
REM Matched on the full binary path, not just "n8n start", so another n8n
REM running in the same distro is never killed.
echo wsl -d !WSL_DISTRO! --exec pkill -f "!WSL_NODEBIN!/n8n start" ^>nul 2^>^&1 >> "!UNINSTALL_SCRIPT!"
echo echo  Removing the n8n program from !WSL_DISTRO!...>> "!UNINSTALL_SCRIPT!"
if "!WSL_USE_ROOT!"=="YES" (
    echo wsl -d !WSL_DISTRO! -u root --exec sh -c "export PATH=!WSL_RUNPATH!; npm uninstall -g n8n --loglevel=error --no-fund --no-audit">> "!UNINSTALL_SCRIPT!"
) else (
    echo wsl -d !WSL_DISTRO! --exec sh -c "export PATH=!WSL_RUNPATH!; npm uninstall -g n8n --loglevel=error --no-fund --no-audit">> "!UNINSTALL_SCRIPT!"
)
echo if "%%REMOVE_DATA%%"=="YES" wsl -d !WSL_DISTRO! --exec rm -rf !WSLP_WSLHOME!/.n8n>> "!UNINSTALL_SCRIPT!"
echo echo  Removing the Windows files...>> "!UNINSTALL_SCRIPT!"
echo if exist "!START_SCRIPT!" del "!START_SCRIPT!" ^>nul 2^>^&1 >> "!UNINSTALL_SCRIPT!"
echo if exist "!README_FILE!" del "!README_FILE!" ^>nul 2^>^&1 >> "!UNINSTALL_SCRIPT!"
echo if exist "%USERPROFILE%\Desktop\Start n8n (WSL).lnk" del "%USERPROFILE%\Desktop\Start n8n (WSL).lnk" ^>nul 2^>^&1 >> "!UNINSTALL_SCRIPT!"
echo if exist "%PUBLIC%\Desktop\Start n8n (WSL).lnk" del "%PUBLIC%\Desktop\Start n8n (WSL).lnk" ^>nul 2^>^&1 >> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  ════════════════════════════════════════>> "!UNINSTALL_SCRIPT!"
echo echo   Done>> "!UNINSTALL_SCRIPT!"
echo echo  ════════════════════════════════════════>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  n8n has been removed from !WSL_DISTRO!.>> "!UNINSTALL_SCRIPT!"
echo if "%%REMOVE_DATA%%"=="NO" echo  Your workflows are still in !WSLP_WSLHOME!/.n8n>> "!UNINSTALL_SCRIPT!"
echo echo  Node.js and the !WSL_DISTRO! distribution were not touched.>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  You can delete this file when you are finished.>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo pause>> "!UNINSTALL_SCRIPT!"
echo exit /b 0 >> "!UNINSTALL_SCRIPT!"
echo.>> "!UNINSTALL_SCRIPT!"
echo :CANCEL>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo echo  Cancelled. Nothing was changed.>> "!UNINSTALL_SCRIPT!"
echo echo.>> "!UNINSTALL_SCRIPT!"
echo pause>> "!UNINSTALL_SCRIPT!"
echo exit /b 0 >> "!UNINSTALL_SCRIPT!"

echo  [✓] Uninstaller created: !UNINSTALL_SCRIPT!

:WSL_COMPLETE
cls
echo.
echo  ════════════════════════════════════════════════════════
echo      n8n Installation Wizard
echo      Installation Complete!
echo  ════════════════════════════════════════════════════════
echo.
echo  Step 4 of 4: Installation Complete
echo  ────────────────────────────────────────
echo.
echo  [✓] n8n !WSL_N8N_FINAL! installed inside !WSL_DISTRO!
echo  [✓] Linux user: !WSLP_WSLUSER!
echo  [✓] Data directory: !WSLP_WSLHOME!/.n8n
echo  [✓] Start script: !START_SCRIPT!
echo  [✓] README file: !README_FILE!
echo  [✓] Uninstaller: !UNINSTALL_SCRIPT!
echo.
echo  ────────────────────────────────────────
echo.
echo  Thank you for using this community installer!
echo.
echo  Installer by: https://github.com/web3Leander
echo  n8n by n8n GmbH: https://n8n.io
echo.
echo  REMINDER: This is an unofficial community tool.
echo  For n8n support, visit: https://community.n8n.io
echo.
echo  ────────────────────────────────────────
echo.
echo  Next Steps:
echo  1. Run: !START_SCRIPT!
echo  2. Open http://localhost:!N8N_PORT! in your browser
echo  3. Create your first workflow
echo.
echo  For more information, see README.txt in !WSL_HOME_DIR!
echo.
pause
exit /b 0

REM Helper function to clear ERRORLEVEL
:CLEAR_ERROR
exit /b 0
