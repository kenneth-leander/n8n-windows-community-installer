# Walks the installer through every way of installing n8n in test mode (/DRYRUN) and checks what it would have done.
#
# In test mode nothing is downloaded or installed: the installer only writes down which programs it would start.
# This is how the Docker and Linux (WSL2) ways are covered on GitHub's computers, which cannot run them for real.
# The uninstaller understands /DRYRUN too, so it is tried as well.
#
#   powershell -File installer\tests\Test-DryRun.ps1 -Installer .\n8n-Installer.exe
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Installer
)

$ErrorActionPreference = 'Stop'
$Installer = (Resolve-Path -Path $Installer).Path
$base = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$work = Join-Path $base ('n8n-dry-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$logDir = Join-Path $env:LOCALAPPDATA 'n8n-installer\logs'
$script:problems = @()
New-Item -ItemType Directory -Path $work -Force | Out-Null

function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Host "  ok    $what" }
    else { Write-Host "  FAIL  $what"; $script:problems += $what }
}

# Runs a block with an environment variable set (programs it starts get it too) and puts the old value back afterwards.
function Invoke-WithEnv([string]$name, [string]$value, [scriptblock]$block) {
    $saved = [Environment]::GetEnvironmentVariable($name, 'Process')
    [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    try { & $block } finally { [Environment]::SetEnvironmentVariable($name, $saved, 'Process') }
}

# The entry of an install folder in Windows Settings, Apps.
function Get-UninstallEntry([string]$dir) {
    $root = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    if (-not (Test-Path $root)) { return $null }
    foreach ($key in Get-ChildItem $root) {
        $item = Get-ItemProperty -Path $key.PSPath
        if ($item.InstallLocation -and ($item.InstallLocation.TrimEnd('\') -ieq $dir.TrimEnd('\'))) { return $item }
    }
    return $null
}

# Runs a program, waits for it, and returns its exit code and what it wrote in its own log (empty if none).
# $waitFor, when given, is a script block that says when the program has really finished (the uninstaller hands over
# to a second process, so waiting for the first one is not always enough).
function Invoke-Logged([string]$exe, [string[]]$arguments, [string]$logPrefix, [scriptblock]$waitFor = $null) {
    $known = @()
    if (Test-Path $logDir) { $known = @(Get-ChildItem $logDir -Filter '*.log' | ForEach-Object { $_.Name }) }
    $p = Start-Process -FilePath $exe -ArgumentList $arguments -Wait -PassThru
    if ($waitFor) {
        $deadline = (Get-Date).AddSeconds(60)
        while (-not (& $waitFor) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 1 }
    }
    $text = ''
    if (Test-Path $logDir) {
        $file = Get-ChildItem $logDir -Filter "$logPrefix-*.log" | Where-Object { $known -notcontains $_.Name } |
            Sort-Object LastWriteTime | Select-Object -Last 1
        if ($file) { $text = Get-Content -Path $file.FullName -Raw }
    }
    Start-Sleep -Seconds 1      # the next log gets a file name of its own (the names count seconds)
    return [pscustomobject]@{ ExitCode = $p.ExitCode; Log = $text }
}

# One try: install in test mode, check the exit code and the log, then uninstall in test mode and check that too.
#   -InstallArgs      the switches that choose the way and its settings
#   -ExpectExit       the exit code Setup has to end with (non-zero means it has to refuse or fail, so no uninstall follows)
#   -ExpectInLog      pieces of text (regular expressions) the install log has to contain
#   -ExpectNotInLog   pieces of text it must not contain
#   -UninstallArgs    extra switches for the uninstaller, like /DELETEDATA=1
#   -UninstallIn      pieces of text the uninstall log has to contain (-UninstallNotIn: must not contain)
function Test-Case {
    param(
        [string]$Name,
        [string[]]$InstallArgs,
        [int]$ExpectExit = 0,
        [string[]]$ExpectInLog = @(),
        [string[]]$ExpectNotInLog = @(),
        [string[]]$UninstallArgs = @(),
        [string[]]$UninstallIn = @(),
        [string[]]$UninstallNotIn = @(),
        [switch]$StopShortcut,
        [string]$DryRunSwitch = '/DRYRUN'
    )
    Write-Host ''
    Write-Host "=== $Name"
    $problemsBefore = $script:problems.Count
    $dir = Join-Path $work $Name
    $setupArgs = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', $DryRunSwitch, '/SHOWFILES', "/DIR=`"$dir`"") + $InstallArgs
    $r = Invoke-Logged $Installer $setupArgs 'install'
    Check ($r.ExitCode -eq $ExpectExit) "the installer ended with exit code $ExpectExit (it was $($r.ExitCode))"
    foreach ($pattern in $ExpectInLog) { Check ($r.Log -match $pattern) "the log says: $pattern" }
    foreach ($pattern in $ExpectNotInLog) { Check ($r.Log -notmatch $pattern) "the log does not say: $pattern" }
    # The files the installer would write (start script, readme, ...) have every @@MARKER@@ of their template filled in.
    Check ($r.Log -notmatch '@@[A-Z0-9_]+@@') 'no @@MARKER@@ is left in the files it would write'
    if ($ExpectExit -eq 0) { Check ($r.Log -match 'start-n8n\.cmd would contain') 'the start script is written' }
    if ($script:problems.Count -gt $problemsBefore -and $r.Log) {
        Write-Host '--- install log ---'
        Write-Host $r.Log
    }
    if ($ExpectExit -ne 0) { return }

    Check (Test-Path "$dir\unins000.exe") 'the uninstaller is there'
    Check ($null -ne (Get-UninstallEntry $dir)) 'Apps & features lists it'
    $menu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$Name"
    foreach ($item in 'Start n8n.lnk', 'Open n8n in my web browser.url', 'Read me.lnk', 'Uninstall n8n.lnk') {
        Check (Test-Path (Join-Path $menu $item)) "the Start menu has: $item"
    }
    Check ((Test-Path (Join-Path $menu 'Stop n8n.lnk')) -eq [bool]$StopShortcut) "the Start menu has a Stop n8n entry: $([bool]$StopShortcut)"
    $uninstallArgs = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/DRYRUN') + $UninstallArgs
    $u = Invoke-Logged "$dir\unins000.exe" $uninstallArgs 'uninstall' { $null -eq (Get-UninstallEntry $dir) }
    Check ($u.ExitCode -eq 0) "the uninstaller ended with exit code 0 (it was $($u.ExitCode))"
    foreach ($pattern in $UninstallIn) { Check ($u.Log -match $pattern) "the uninstall log says: $pattern" }
    foreach ($pattern in $UninstallNotIn) { Check ($u.Log -notmatch $pattern) "the uninstall log does not say: $pattern" }
    Check ($null -eq (Get-UninstallEntry $dir)) 'Apps & features no longer lists it'
    Check (-not (Test-Path "$dir\n8n-installer.ini")) 'the install record is gone'
    Check (-not (Test-Path $menu)) 'the Start menu entries are gone'
    if ($script:problems.Count -gt $problemsBefore -and $u.Log) {
        Write-Host '--- uninstall log ---'
        Write-Host $u.Log
    }
}

# --- the folder way ---------------------------------------------------------
Test-Case -Name 'folder' -InstallArgs @('/METHOD=folder', '/PORT=5690') `
    -ExpectInLog @('Method: folder\s+Port: 5690', 'SHASUMS256\.txt', 'npm\.cmd" install n8n@2 ', 'would write .*\\\.npmrc', 'would write .*\\start-n8n\.cmd')

# --- the user-account way, with a Node.js that fits and one that does not ---
Test-Case -Name 'global' -InstallArgs @('/METHOD=global', '/FAKENODE=22.11.0') `
    -ExpectInLog @('npm install -g n8n@2 --allow-scripts=sqlite3')
Test-Case -Name 'global-old-node' -InstallArgs @('/METHOD=global', '/FAKENODE=18.0.0') -ExpectExit 1 `
    -ExpectInLog @('cannot be used')

# Where npm keeps its global programs decides how the start script runs n8n: from the usual folder inside the user
# profile it runs the program by its address in %APPDATA%; from anywhere else it relies on the n8n command.
Invoke-WithEnv 'npm_config_prefix' (Join-Path $env:APPDATA 'npm') {
    Test-Case -Name 'global-usual-folder' -InstallArgs @('/METHOD=global', '/FAKENODE=22.11.0') `
        -ExpectInLog @('call node "%APPDATA%\\npm\\node_modules\\n8n\\bin\\n8n" start')
}
Invoke-WithEnv 'npm_config_prefix' (Join-Path $work 'npm-elsewhere') {
    Test-Case -Name 'global-other-folder' -InstallArgs @('/METHOD=global', '/FAKENODE=22.11.0') `
        -ExpectInLog @('call n8n start') -ExpectNotInLog @('call node "%APPDATA%')
}

# --- Docker -----------------------------------------------------------------
Test-Case -Name 'docker' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=ready') -StopShortcut `
    -ExpectInLog @('docker pull docker\.n8n\.io/n8nio/n8n:\d+\.\d+\.\d+',
        'docker volume create n8n_data',
        'docker run -d --name n8n --restart unless-stopped -p 127\.0\.0\.1:5678:5678 ',
        '-v n8n_data:/home/node/\.n8n ') `
    -ExpectNotInLog @('N8N_SECURE_COOKIE') `
    -UninstallIn @('docker rm -f n8n', 'docker rmi docker\.n8n\.io/n8nio/n8n:') `
    -UninstallNotIn @('docker volume rm')
Test-Case -Name 'docker-own-names' -StopShortcut `
    -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=ready', '/PORT=5690', '/DOCKERNAME=my-n8n', '/DOCKERVOLUME=my_data', '/TZ=Europe/Oslo') `
    -ExpectInLog @('--name my-n8n ', '-p 127\.0\.0\.1:5690:5678 ', 'GENERIC_TIMEZONE=Europe/Oslo', 'WEBHOOK_URL=http://localhost:5690/', '-v my_data:/home/node/\.n8n ') `
    -UninstallArgs @('/DELETEDATA=1') -UninstallIn @('docker rm -f my-n8n', 'docker volume rm my_data')
Test-Case -Name 'docker-network' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=ready', '/LAN=1') -StopShortcut `
    -ExpectInLog @('-p 5678:5678 ', 'N8N_SECURE_COOKIE=false') -ExpectNotInLog @('127\.0\.0\.1:5678:5678')
Test-Case -Name 'docker-missing' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=missing') -ExpectExit 1 -ExpectInLog @('cannot be used')
Test-Case -Name 'docker-stopped' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=stopped') -ExpectExit 1 -ExpectInLog @('not running')
Test-Case -Name 'docker-windows-containers' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=windows') -ExpectExit 1 -ExpectInLog @('Linux containers')

# --- when a program fails, the install stops with a message and an error code ---
Test-Case -Name 'failing-program' -InstallArgs @('/METHOD=folder') -DryRunSwitch '/DRYRUN=fail' -ExpectExit 3 `
    -ExpectInLog @('FAILED: npm could not install n8n')

# {WSL-CASES}

Write-Host ''
Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
if ($script:problems.Count -gt 0) {
    Write-Host "::error::$($script:problems.Count) check(s) failed"
    $script:problems | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host 'All checks passed.'
