# Checks one way of installing n8n from start to finish, on a real Windows computer:
#   install -> start n8n -> it answers -> stop -> install again over it (data kept)
#   -> uninstall (data kept) -> install again -> uninstall and delete the data
#
# It runs the real installer silently, so it needs nothing but PowerShell. GitHub Actions runs it for
# the "folder" and "global" methods; you can run it on your own computer too:
#
#   powershell -File installer\tests\Test-Install.ps1 -Installer .\n8n-Installer.exe -Method folder -Dir C:\n8n-test
#
# Methods: folder, global (needs Node.js 22 installed), docker (needs Docker Desktop in Linux mode),
#          wsl (needs a WSL2 distribution, give its name in -WslDistro).
# A test install uses port 5688 by default, so it does not disturb an n8n on the usual port 5678.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Installer,
    [Parameter(Mandatory = $true)][ValidateSet('folder', 'global', 'docker', 'wsl')][string]$Method,
    [Parameter(Mandatory = $true)][string]$Dir,
    [int]$Port = 5688,
    [int]$StartTimeoutSec = 300,
    [int]$PageTimeoutSec = 120,
    [int]$SetupTimeoutSec = 1500,
    [string]$WslDistro = ''
)

$ErrorActionPreference = 'Stop'
$Installer = (Resolve-Path -Path $Installer).Path
$work = if ($env:RUNNER_TEMP) { $env:RUNNER_TEMP } else { $env:TEMP }
$logDir = Join-Path $env:LOCALAPPDATA 'n8n-installer\logs'
$script:problems = @()

function Say([string]$text) { Write-Host ''; Write-Host "=== $text" }

function Check([bool]$ok, [string]$what) {
    if ($ok) { Write-Host "  ok    $what" }
    else { Write-Host "  FAIL  $what"; $script:problems += $what }
}

function Show-Logs {
    Write-Host ''
    Write-Host '--- installer logs ---'
    if (Test-Path $logDir) {
        Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime | Select-Object -Last 3 | ForEach-Object {
            Write-Host "----- $($_.FullName)"
            Get-Content $_.FullName -Tail 80
        }
    }
    Get-ChildItem $work -Filter 'setup-*.log' -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Host "----- $($_.FullName)"
        Get-Content $_.FullName -Tail 60
    }
}

function Stop-Here([string]$why) {
    Write-Host "::error::$why"
    Show-Logs
    exit 1
}

# What a program is busy with: the programs it started (with the processor time they used so far, so a busy one can
# be told from one that is stuck) and the last line of the installer's own log.
function Show-Activity([int]$rootId, [double]$elapsedSec) {
    $all = @(Get-CimInstance Win32_Process)
    $family = New-Object 'System.Collections.Generic.HashSet[int]'
    [void]$family.Add($rootId)
    do {
        $grew = $false
        foreach ($proc in $all) {
            if ($family.Contains([int]$proc.ParentProcessId) -and $family.Add([int]$proc.ProcessId)) { $grew = $true }
        }
    } while ($grew)
    Write-Host ("  [{0:n0} min] still running; programs it started:" -f ($elapsedSec / 60))
    foreach ($proc in $all) {
        if ($proc.ProcessId -eq $rootId -or -not $family.Contains([int]$proc.ProcessId)) { continue }
        $cpu = ''
        try { $cpu = '{0:n1}s' -f (Get-Process -Id $proc.ProcessId -ErrorAction Stop).CPU } catch { }
        $line = "$($proc.CommandLine)"
        if ($line.Length -gt 150) { $line = $line.Substring(0, 150) + '...' }
        Write-Host ('    {0,6} (from {1,6})  cpu {2,8}  {3}' -f $proc.ProcessId, $proc.ParentProcessId, $cpu, $line)
    }
    $latest = $null
    if (Test-Path $logDir) {
        $latest = Get-ChildItem $logDir -Filter 'install-*.log' | Sort-Object LastWriteTime | Select-Object -Last 1
    }
    if ($latest) {
        $tail = @(Get-Content -Path $latest.FullName -Tail 2 -ErrorAction SilentlyContinue) -join ' | '
        Write-Host "    last lines of $($latest.Name): $tail"
    }
}

# Starts a program and waits for it, but not for ever: a program that hangs is stopped, so the logs get printed
# instead of the whole run timing out without a word. Every minute it says what the program is busy with.
# Returns its exit code (124 when it had to be stopped).
function Invoke-Timed([string]$file, [string[]]$arguments, [int]$seconds) {
    $p = Start-Process -FilePath $file -ArgumentList $arguments -PassThru
    $clock = [Diagnostics.Stopwatch]::StartNew()
    $nextReport = 60
    while (-not $p.WaitForExit(5000)) {
        if ($clock.Elapsed.TotalSeconds -ge $seconds) {
            Write-Host "::error::$(Split-Path -Leaf $file) did not finish within $seconds seconds. It is stopped now."
            Show-Activity $p.Id $clock.Elapsed.TotalSeconds
            & taskkill.exe /PID $p.Id /T /F | Out-Null
            return 124
        }
        if ($clock.Elapsed.TotalSeconds -ge $nextReport) {
            Show-Activity $p.Id $clock.Elapsed.TotalSeconds
            $nextReport += 60
        }
    }
    Write-Host ("  {0} finished after {1:n0} seconds" -f (Split-Path -Leaf $file), $clock.Elapsed.TotalSeconds)
    return $p.ExitCode
}

function Invoke-Setup([string]$name, [string[]]$extra) {
    $log = Join-Path $work "setup-$name.log"
    $setupArgs = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/SP-', "/LOG=`"$log`"",
        "/METHOD=$Method", "/DIR=`"$Dir`"", "/PORT=$Port", '/DESKTOP=0') + $extra
    if ($WslDistro) { $setupArgs += "/WSLDISTRO=$WslDistro" }
    if ($Method -eq 'folder') { $setupArgs += '/ADDPATH=1' }
    Write-Host "Running: $Installer $($setupArgs -join ' ')"
    $code = Invoke-Timed $Installer $setupArgs $SetupTimeoutSec
    Write-Host "Setup exit code: $code"
    return $code
}

function Invoke-Uninstall([string[]]$extra) {
    return Invoke-Timed "$Dir\unins000.exe" (@('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') + $extra) 600
}

# Runs a program and returns what it printed. Its exit code is left in $script:nativeExit. Programs that write
# to the error stream do not stop the script (Windows PowerShell 5.1 would otherwise treat that as an error).
function Invoke-Native([scriptblock]$command) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = & $command 2>&1 } finally { $ErrorActionPreference = $saved }
    $script:nativeExit = $LASTEXITCODE
    return $out
}

# The entry of this install in Windows Settings, Apps (the uninstaller registers it for the current user).
function Get-UninstallEntry {
    $root = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    if (-not (Test-Path $root)) { return $null }
    foreach ($key in Get-ChildItem $root) {
        $item = Get-ItemProperty -Path $key.PSPath
        if ($item.InstallLocation -and ($item.InstallLocation.TrimEnd('\') -ieq $Dir.TrimEnd('\'))) { return $item }
    }
    return $null
}

function Test-Health {
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:$Port/healthz" -UseBasicParsing -TimeoutSec 5
        return ($r.StatusCode -eq 200)
    }
    catch { return $false }
}

function Wait-Health([int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Health) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

function Wait-Gone([int]$seconds) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        if (-not (Test-Health)) { return $true }
        Start-Sleep -Seconds 2
    }
    return $false
}

# Where n8n keeps its data for this method (folder and global installs; Docker and WSL keep it elsewhere).
$dataDir = $null
if ($Method -eq 'folder') { $dataDir = Join-Path $Dir '.n8n' }
if ($Method -eq 'global') { $dataDir = Join-Path $env:USERPROFILE '.n8n' }

$leaf = Split-Path -Leaf $Dir
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$leaf"
$env:N8N_NO_BROWSER = '1'
$env:N8N_NO_PAUSE = '1'

function Start-N8n {
    if ($Method -eq 'docker') {
        $null = Start-Process -FilePath $env:ComSpec -ArgumentList '/c', "`"$Dir\start-n8n.cmd`"" -Wait -WindowStyle Hidden
        return $null
    }
    return Start-Process -FilePath $env:ComSpec -ArgumentList '/c', "`"$Dir\start-n8n.cmd`"" -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $work 'n8n-out.log') -RedirectStandardError (Join-Path $work 'n8n-err.log')
}

function Stop-N8n($proc) {
    # Docker and Linux (WSL2) keep n8n running outside the window that started it, so they have a stop script.
    if ($Method -eq 'docker' -or $Method -eq 'wsl') {
        $null = Start-Process -FilePath $env:ComSpec -ArgumentList '/c', "`"$Dir\stop-n8n.cmd`"" -Wait -WindowStyle Hidden
    }
    if ($proc -and -not $proc.HasExited) {
        & taskkill.exe /PID $proc.Id /T /F | Out-Null
    }
    $null = Wait-Gone 40
}

# ---------------------------------------------------------------------------
if ($Method -eq 'global') {
    $prefixText = (Invoke-Native { & npm.cmd prefix -g } | Out-String).Trim()
    Write-Host "npm puts global packages in: $prefixText (its download cache: $((Invoke-Native { & npm.cmd config get cache } | Out-String).Trim()))"
}
Say "1. Install ($Method) into $Dir"
if ((Invoke-Setup 'install1' @()) -ne 0) { Stop-Here 'The installer did not finish (see the logs above).' }
Check (Test-Path "$Dir\start-n8n.cmd") 'start-n8n.cmd was written'
Check (Test-Path "$Dir\README.txt") 'README.txt was written'
Check (Test-Path "$Dir\n8n-installer.ini") 'the install record was written'
Check (Test-Path "$Dir\unins000.exe") 'the uninstaller is there'
Check (Test-Path "$startMenu\Start n8n.lnk") 'the Start menu entry exists'
$entry = Get-UninstallEntry
Check ($null -ne $entry) 'Apps & features lists this install'
if ($entry) { Write-Host "  listed as: $($entry.DisplayName)  (version $($entry.DisplayVersion))" }
$record = if (Test-Path "$Dir\n8n-installer.ini") { Get-Content "$Dir\n8n-installer.ini" -Raw } else { '' }
Check ($record -match "method=$Method") "the record says method=$Method"
if ($Method -eq 'folder') {
    Check (Test-Path "$Dir\node\node.exe") 'Node.js is in the folder'
    Check (Test-Path "$Dir\node_modules\n8n\package.json") 'n8n is in the folder'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    Check ($userPath -like "*$Dir\bin*") 'the n8n command folder was added to the PATH of the user'
}

Say '2. Start n8n and wait for it to answer'
$proc = Start-N8n
if (-not (Wait-Health $StartTimeoutSec)) {
    Get-Content (Join-Path $work 'n8n-out.log') -Tail 40 -ErrorAction SilentlyContinue
    Get-Content (Join-Path $work 'n8n-err.log') -Tail 40 -ErrorAction SilentlyContinue
    Stop-N8n $proc
    Stop-Here "n8n did not answer on port $Port within $StartTimeoutSec seconds."
}
Check $true "n8n answers on http://localhost:$Port/healthz"
# n8n answers /healthz a little before its web pages are ready (the page is a 404 for a few seconds), so wait for it.
$pageError = 'no answer yet'
$deadline = (Get-Date).AddSeconds($PageTimeoutSec)
$pageOk = $false
while (-not $pageOk -and (Get-Date) -lt $deadline) {
    try {
        $page = Invoke-WebRequest -Uri "http://localhost:$Port/" -UseBasicParsing -TimeoutSec 20
        if ($page.StatusCode -eq 200 -and $page.Content -match 'n8n') { $pageOk = $true }
        else { $pageError = "status $($page.StatusCode), and no n8n in the page" }
    }
    catch { $pageError = $_.Exception.Message }
    if (-not $pageOk) { Start-Sleep -Seconds 3 }
}
if ($pageOk) { Check $true 'the n8n web page loads' }
else { Check $false "the n8n web page loads (last answer: $pageError)" }

# The helper that the Start n8n shortcut uses to open the browser.
if (Test-Path "$Dir\support\wait-n8n.ps1") {
    $null = Invoke-Native { & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$Dir\support\wait-n8n.ps1" -Url "http://localhost:$Port" -TimeoutSec 20 }
    Check ($script:nativeExit -eq 0) 'wait-n8n.ps1 sees n8n running'
}

if ($dataDir) {
    $deadline = (Get-Date).AddSeconds(60)
    while (-not (Test-Path "$dataDir\config") -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
    Check (Test-Path "$dataDir\config") "n8n made its data folder ($dataDir)"
}

Say '3. Stop n8n'
Stop-N8n $proc
Check (-not (Test-Health)) 'n8n no longer answers'

if ($Method -eq 'folder') {
    Say '3b. The n8n command'
    if (Test-Path "$Dir\bin\n8n.cmd") {
        $v = (Invoke-Native { & $env:ComSpec /c "`"$Dir\bin\n8n.cmd`" --version" } | Out-String).Trim()
        Write-Host "  n8n --version printed: $v"
        Check ($v -match '\d+\.\d+\.\d+') 'the n8n command runs'
    }
    else { Write-Host '  (no n8n command was added in this run)' }
}

$marker = $null
if ($dataDir -and (Test-Path "$dataDir\config")) {
    $marker = (Get-FileHash "$dataDir\config" -Algorithm SHA256).Hash
}

Say '4. Install again over the first install (an update); the data must stay'
if ((Invoke-Setup 'install2' @()) -ne 0) { Stop-Here 'The second install (update) did not finish.' }
if ($marker) {
    Check ((Get-FileHash "$dataDir\config" -Algorithm SHA256).Hash -eq $marker) 'the data (encryption key) is unchanged'
}
$proc = Start-N8n
Check (Wait-Health $StartTimeoutSec) 'n8n answers again after the update'
Stop-N8n $proc

Say '5. Uninstall and keep the data'
$code = Invoke-Uninstall @()
Check ($code -eq 0) "the uninstaller finished (exit code $code)"
Start-Sleep -Seconds 3
Check (-not (Test-Path "$startMenu\Start n8n.lnk")) 'the Start menu entry is gone'
Check ($null -eq (Get-UninstallEntry)) 'Apps & features no longer lists it'
Check (-not (Test-Path "$Dir\start-n8n.cmd")) 'start-n8n.cmd is gone'
if ($Method -eq 'folder') {
    Check (-not (Test-Path "$Dir\node")) 'Node.js is gone from the folder'
    Check (-not (Test-Path "$Dir\node_modules")) 'n8n is gone from the folder'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    Check (-not ($userPath -like "*$Dir\bin*")) 'the PATH of the user is clean again'
}
if ($Method -eq 'global') {
    $null = Invoke-Native { & npm.cmd ls -g n8n --depth=0 }
    Check ($script:nativeExit -ne 0) 'n8n is no longer installed in npm'
}
if ($dataDir) { Check (Test-Path "$dataDir\config") 'the data was kept' }
if ($Method -eq 'folder') {
    # Installing again into this folder must be possible without a question, so nothing but the data may be left in it.
    $left = @(Get-ChildItem -Path $Dir -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Write-Host "  left in the folder: $($left -join ', ')"
    $others = @($left | Where-Object { $_ -ne '.n8n' })
    Check ($others.Count -eq 0) "nothing but the data is left in the folder$(if ($others.Count) { ' (also there: ' + ($others -join ', ') + ')' })"
}

Say '6. Install once more, then uninstall and delete the data'
if ((Invoke-Setup 'install3' @()) -ne 0) { Stop-Here 'The third install did not finish.' }
$code = Invoke-Uninstall @('/DELETEDATA=1')
Check ($code -eq 0) "the uninstaller finished (exit code $code)"
Start-Sleep -Seconds 3
if ($dataDir) { Check (-not (Test-Path $dataDir)) 'the data was deleted' }
if ($Method -eq 'folder') {
    $left = @(Get-ChildItem -Path $Dir -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    Check ($left.Count -eq 0) "nothing is left in the folder$(if ($left.Count) { ' (there is: ' + ($left -join ', ') + ')' })"
}

Say 'Result'
if ($script:problems.Count -gt 0) {
    $script:problems | ForEach-Object { Write-Host "  FAILED: $_" }
    Show-Logs
    exit 1
}
Write-Host "All checks passed for the $Method install."
exit 0
