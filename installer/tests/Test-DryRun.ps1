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
#   -PreCreate        files to put in the install folder first (paths inside it), like a folder that is not empty
#   -AfterUninstall   a script block that runs when the uninstaller is done; it gets the install folder
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
        [string[]]$PreCreate = @(),
        [scriptblock]$AfterUninstall = $null,
        [switch]$StopShortcut,
        [string]$DryRunSwitch = '/DRYRUN'
    )
    Write-Host ''
    Write-Host "=== $Name"
    $problemsBefore = $script:problems.Count
    $dir = Join-Path $work $Name
    foreach ($relative in $PreCreate) {
        $path = Join-Path $dir $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
        Set-Content -Path $path -Value 'test'
    }
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
    if ($AfterUninstall) { & $AfterUninstall $dir }
    if ($script:problems.Count -gt $problemsBefore -and $u.Log) {
        Write-Host '--- uninstall log ---'
        Write-Host $u.Log
    }
}

# --- the folder way ---------------------------------------------------------
Test-Case -Name 'folder' -InstallArgs @('/METHOD=folder', '/PORT=5690') `
    -ExpectInLog @('Method: folder\s+Port: 5690', 'SHASUMS256\.txt', 'npm\.cmd" install n8n@2 ', 'would write .*\\\.npmrc', 'would write .*\\start-n8n\.cmd')

# A folder that only holds what an earlier install left (the data an uninstall keeps, and the cache n8n makes next to it)
# is fine to install into; a folder with anything else in it needs a yes from the person (a silent install answers no
# and stops). The uninstaller keeps the data and removes the cache.
Test-Case -Name 'folder-with-kept-data' -InstallArgs @('/METHOD=folder') -PreCreate @('.n8n\config', '.cache\n8n\cache.json') `
    -ExpectNotInLog @('already has other files') `
    -AfterUninstall {
        param($dir)
        Check (Test-Path "$dir\.n8n\config") 'the data is kept'
        Check (-not (Test-Path "$dir\.cache")) 'the cache of n8n is gone'
    }
Test-Case -Name 'folder-with-other-files' -InstallArgs @('/METHOD=folder') -PreCreate @('my notes.txt', '.n8n\config') -ExpectExit 1 `
    -ExpectInLog @('already has other files in it, for example "my notes\.txt"')

# When the look at the ports does not work, nobody is told that a port is free: the log says it was not looked at.
Test-Case -Name 'folder-port-check-fails' -InstallArgs @('/METHOD=folder', '/FAKENETSTAT="Access is denied."') `
    -ExpectInLog @('! Setup could not check whether port \d+ \(or any other\) is free: netstat\.exe ended with code 1 and said: Access is denied\.')

# --- the user-account way, with a Node.js that fits and one that does not ---
Test-Case -Name 'global' -InstallArgs @('/METHOD=global', '/FAKENODE=22.11.0') `
    -ExpectInLog @('npm install -g n8n@2 --allow-scripts=sqlite3')

# A way that cannot be used says why, in the words of what was actually found: the Node.js that is there, or what Node.js
# said when it did not run. A silent install gets the same sentences as its error message, and nothing is skipped quietly.
Test-Case -Name 'global-old-node' -InstallArgs @('/METHOD=global', '/FAKENODE=18.0.0') -ExpectExit 1 `
    -ExpectInLog @('The install method "global" cannot be used\. Your Node\.js \(18\.0\.0\) is not one that n8n 2\.x is tested with here\.',
        'Use /METHOD=folder instead')
Test-Case -Name 'global-no-node' -InstallArgs @('/METHOD=global', '/FAKENODE=') -ExpectExit 1 `
    -ExpectInLog @('The install method "global" cannot be used\. Node\.js was not found on this computer\.', 'Use /METHOD=folder instead')
Test-Case -Name 'global-node-fails' -InstallArgs @('/METHOD=global', '/FAKENODEMSG="It ended with code 3 and said: the application failed to start"') -ExpectExit 1 `
    -ExpectInLog @('Setup could not check Node\.js\. It ended with code 3 and said: the application failed to start\.',
        'Use /METHOD=folder instead')

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

# When Docker cannot be used, the install stops and says why. "said:" is what Docker itself answered (the probe script
# passes it on), the other messages are what Setup worked out: nothing is left to guess.
Test-Case -Name 'docker-missing' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=missing') -ExpectExit 1 `
    -ExpectInLog @('The install method "docker" cannot be used\. Docker was not found on this computer\.', 'install Docker Desktop from docker\.com')
Test-Case -Name 'docker-installed-not-found' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=missing', '/FAKEDOCKERMSG=installed') -ExpectExit 1 `
    -ExpectInLog @('Docker Desktop is installed, but Setup cannot find its docker\.exe\.', 'Sign out of Windows')
Test-Case -Name 'docker-stopped' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=stopped') -ExpectExit 1 `
    -ExpectInLog @('Docker is installed, but it is not ready\.', 'Start Docker Desktop', 'then run the installer again')
Test-Case -Name 'docker-stopped-said' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=stopped', '/FAKEDOCKERMSG="said: error during connect: the pipe docker_engine was not found"') -ExpectExit 1 `
    -ExpectInLog @('Docker is installed, but it is not ready\. Docker said: error during connect: the pipe docker_engine was not found\.',
        'Start Docker Desktop', '(?m)^\s+error during connect: the pipe docker_engine was not found\s*$')
Test-Case -Name 'docker-stopped-no-answer' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=stopped', '/FAKEDOCKERMSG="Docker did not answer within 15 seconds."') -ExpectExit 1 `
    -ExpectInLog @('Docker is installed, but it is not ready\. Docker did not answer within 15 seconds\.') -ExpectNotInLog @('Docker said:')
Test-Case -Name 'docker-check-failed' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=error', '/FAKEDOCKERMSG="The check printed nothing and ended with code 1."') -ExpectExit 1 `
    -ExpectInLog @('Setup could not find out whether Docker is ready\. The check printed nothing and ended with code 1\.', 'to try once more')
Test-Case -Name 'docker-windows-containers' -InstallArgs @('/METHOD=docker', '/FAKEDOCKER=windows') -ExpectExit 1 `
    -ExpectInLog @('Docker is set to Windows containers, and n8n needs Linux containers\.', 'Switch it to Linux containers')

# --- when a program fails, the install stops with a message and an error code ---
Test-Case -Name 'failing-program' -InstallArgs @('/METHOD=folder') -DryRunSwitch '/DRYRUN=fail' -ExpectExit 3 `
    -ExpectInLog @('FAILED: npm could not install n8n')

# --- Linux inside Windows (WSL2) ---------------------------------------------
# GitHub's computers have no Linux distribution to install into. Setup is told which distributions exist
# (/FAKEWSL=name|version|state;...) and what its look inside Linux would have found (/FAKEWSLUSER, /FAKEWSLNODE,
# /FAKEWSLNVM, /FAKEWSLPREFIX, /FAKEWSLN8N, /FAKEWSLOS, /FAKEWSLSTUCK; they are listed at the top of installer\code\wsl.iss).
# What it would hand to wsl.exe is checked in the log.
$fakeWsl = '/FAKEWSL=Ubuntu|2|Running;Debian|1|Stopped'
Test-Case -Name 'wsl' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu') -StopShortcut `
    -ExpectInLog @('Linux user: ken\s+Home folder: /home/ken',
        'wsl\.exe -d Ubuntu -u root --exec sh -c "[^"]*npm install -g n8n@2 --allow-scripts=sqlite3',
        'set "N8N_LISTEN=0\.0\.0\.0"',
        '--exec sh -c "exec pkill -f /usr/bin/n8n\.start"',
        '\\\\wsl\$\\Ubuntu\\home\\ken\\\.n8n') `
    -ExpectNotInLog @('nodesource', 'sudo') `
    -UninstallIn @('pkill -f /usr/bin/n8n\.start', 'wsl\.exe -d Ubuntu -u root --exec sh -c "[^"]*npm uninstall -g n8n') `
    -UninstallNotIn @('rm -rf')
Test-Case -Name 'wsl-own-port' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/PORT=5690') -StopShortcut `
    -ExpectInLog @('Method: wsl\s+Port: 5690',
        'set "N8N_PORT=5690"',
        'http://localhost:5690')
Test-Case -Name 'wsl-adds-node' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNODE=none') -StopShortcut `
    -ExpectInLog @('Node\.js is not installed inside Ubuntu',
        'wsl\.exe -d Ubuntu -u root --exec sh -c "[^"]*apt-get install -y -qq nodejs',
        'curl -fsSL https://deb\.nodesource\.com/setup_22\.x -o /tmp/n8n-nodesource\.sh',
        'Node\.js 22\.20\.0')
Test-Case -Name 'wsl-old-node' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNODE=18.19.1') -StopShortcut `
    -ExpectInLog @('Ubuntu has Node\.js 18\.19\.1, which n8n 2\.x does not run on', 'setup_22\.x')
Test-Case -Name 'wsl-old-node-stays' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNODE=18.19.1', '/FAKEWSLSTUCK') -ExpectExit 3 `
    -ExpectInLog @('FAILED: Node\.js 22 was added, but Ubuntu still uses Node\.js 18\.19\.1')
Test-Case -Name 'wsl-alpine-without-node' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNODE=none', '/FAKEWSLOS=alpine') -ExpectExit 3 `
    -ExpectInLog @('FAILED: Node\.js is not installed inside Ubuntu', 'Alpine Linux may give a newer Node\.js') `
    -ExpectNotInLog @('apk add')
Test-Case -Name 'wsl-fedora-adds-node' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNODE=none', '/FAKEWSLOS=fedora') -StopShortcut `
    -ExpectInLog @('rpm\.nodesource\.com/setup_22\.x', 'dnf install -y -q nodejs')
Test-Case -Name 'wsl-nvm-user' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNVM', '/FAKEWSLNODE=18.19.1') -StopShortcut `
    -ExpectInLog @('wsl\.exe -d Ubuntu --exec bash -c "[^"]*nvm install 22',
        'n8n is installed for ken only',
        'wsl\.exe -d Ubuntu --exec sh -c "[^"]*npm install -g n8n@2 --allow-scripts=sqlite3') `
    -ExpectNotInLog @('-u root') `
    -UninstallNotIn @('-u root')
Test-Case -Name 'wsl-own-npm-folder' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLPREFIX=/home/ken/.npm-global') -StopShortcut `
    -ExpectInLog @('PATH=/usr/bin:/home/ken/\.npm-global/bin:/usr/local/bin:/usr/bin:/bin:\$PATH', 'wsl\.exe -d Ubuntu --exec sh -c "[^"]*npm install -g n8n@2 --allow-scripts=sqlite3')
Test-Case -Name 'wsl-root-user' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLUSER=root') -StopShortcut `
    -ExpectInLog @('Linux user: root\s+Home folder: /root', 'cd /root; export N8N_USER_FOLDER=/root') `
    -UninstallArgs @('/DELETEDATA=1') `
    -UninstallIn @('--exec rm -rf /root/\.n8n')
Test-Case -Name 'wsl-wsl1' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Debian') -StopShortcut `
    -ExpectInLog @('Debian runs on WSL 1', 'set "N8N_LISTEN=127\.0\.0\.1"') `
    -ExpectNotInLog @('set "N8N_LISTEN=0\.0\.0\.0"')
Test-Case -Name 'wsl-lan-ignored' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/LAN=1') -StopShortcut `
    -ExpectInLog @('/LAN is ignored for Linux inside Windows', 'set "N8N_LISTEN=0\.0\.0\.0"') `
    -ExpectNotInLog @('true; export N8N_SECURE_COOKIE=false;')
Test-Case -Name 'wsl-delete-data' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu') -StopShortcut `
    -UninstallArgs @('/DELETEDATA=1') `
    -UninstallIn @('--exec rm -rf /home/ken/\.n8n', 'Deleting /home/ken/\.n8n inside Ubuntu')
Test-Case -Name 'wsl-existing-n8n' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLN8N=2.40.0') -ExpectExit 1 `
    -ExpectInLog @('n8n 2\.40\.0 \(/usr/bin/n8n\) is already installed inside Ubuntu')
Test-Case -Name 'wsl-unknown-distro' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Nope') -ExpectExit 1 `
    -ExpectInLog @('"Nope" was not found in WSL')
Test-Case -Name 'wsl-name-with-space' -InstallArgs @('/METHOD=wsl', '/FAKEWSL="My Distro|2|Running"', '/WSLDISTRO="My Distro"') -ExpectExit 1 `
    -ExpectInLog @('The Linux distribution "My Distro" has a name with spaces')
# Without a Linux distribution the install stops and says why: that WSL is not there at all, that it listed none (with
# what it said, when it said something), or that the check did not work.
Test-Case -Name 'wsl-no-distro' -InstallArgs @('/METHOD=wsl', '/FAKEWSL=') -ExpectExit 1 `
    -ExpectInLog @('The install method "wsl" cannot be used\. WSL did not list a Linux distribution\.', 'wsl --install -d Ubuntu')
Test-Case -Name 'wsl-said' -InstallArgs @('/METHOD=wsl', '/FAKEWSL=', '/FAKEWSLMSG="WSL said: The Windows Subsystem for Linux has no installed distributions."') -ExpectExit 1 `
    -ExpectInLog @('WSL did not list a Linux distribution\. WSL said: The Windows Subsystem for Linux has no installed distributions\.',
        'wsl --install -d Ubuntu')
Test-Case -Name 'wsl-exe-missing' -InstallArgs @('/METHOD=wsl', '/FAKEWSLEXE=missing') -ExpectExit 1 `
    -ExpectInLog @('WSL is not installed on this computer\.', 'wsl --install -d Ubuntu', 'wsl\.exe is not on this computer')
Test-Case -Name 'wsl-failing-program' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu') -DryRunSwitch '/DRYRUN=fail' -ExpectExit 3 `
    -ExpectInLog @('FAILED: npm could not install n8n inside Ubuntu')
# When nvm cannot download the list of Node.js versions from nodejs.org it only says "Version '22' not found" (and ends with
# code 3), as if there were no such version. Setup then asks Linux the same question with the messages switched on
# (/FAKEWSLNET= is Linux's answer) and says what came back. /FAKETOOLSAID= is what the failing nvm printed.
Test-Case -Name 'wsl-nvm-no-internet' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNVM', '/FAKEWSLNODE=24.11.0', '/FAKEWSLNET="curl: (6) Could not resolve host: nodejs.org"', '/FAKETOOLSAID="Version ''22'' not found - try `nvm ls-remote` to browse available versions."') -DryRunSwitch '/DRYRUN=fail' -ExpectExit 3 `
    -ExpectInLog @('FAILED: nvm could not install Node\.js 22 for ken inside Ubuntu \(exit code 1\)',
        'Version ''22'' not found - try',
        'Ubuntu could not download the list of Node\.js versions from nodejs\.org, which nvm',
        'curl said: \(6\) Could not resolve host: nodejs\.org\.',
        'try  curl -I https://nodejs\.org  there',
        'wsl\.exe -d Ubuntu --exec sh -c "[^"]*curl -fsS -L --max-time 20 -o /dev/null https://nodejs\.org/dist/index\.tab') `
    -ExpectNotInLog @('can download from nodejs\.org')
Test-Case -Name 'wsl-nvm-no-curl' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNVM', '/FAKEWSLNODE=24.11.0', '/FAKEWSLNET=none') -DryRunSwitch '/DRYRUN=fail' -ExpectExit 3 `
    -ExpectInLog @('Ubuntu has neither curl nor wget, and nvm needs one of them', 'sudo apt install curl')
Test-Case -Name 'wsl-nvm-fails-with-internet' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNVM', '/FAKEWSLNODE=24.11.0') -DryRunSwitch '/DRYRUN=fail' -ExpectExit 3 `
    -ExpectInLog @('Ubuntu can download from nodejs\.org, so the problem is something else', 'run  nvm install 22  there') `
    -ExpectNotInLog @('could not download the list of Node')
Test-Case -Name 'wsl-nvm-script-missing' -InstallArgs @('/METHOD=wsl', $fakeWsl, '/WSLDISTRO=Ubuntu', '/FAKEWSLNVM', '/FAKEWSLNODE=24.11.0', '/FAKETOOLSAID=NVM_SCRIPT_NOT_FOUND') -DryRunSwitch '/DRYRUN=fail' -ExpectExit 3 `
    -ExpectInLog @('FAILED: nvm could not install Node\.js 22 for ken inside Ubuntu',
        'is managed by nvm, but the program of nvm \(nvm\.sh\) was not found in /home/ken/\.nvm\. Install Node\.js 22 yourself') `
    -ExpectNotInLog @('index\.tab', 'NVM_SCRIPT_NOT_FOUND\s*$')

Write-Host ''
Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
if ($script:problems.Count -gt 0) {
    Write-Host "::error::$($script:problems.Count) check(s) failed"
    $script:problems | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host 'All checks passed.'
