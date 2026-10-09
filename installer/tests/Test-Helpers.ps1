# Runs the two helper scripts that look at the computer (docker-probe.ps1 and wsl-list.ps1) against stand-ins for
# docker.exe and wsl.exe, and checks that every way the real ones can answer gives the right line: when they work,
# when they say something is wrong, when they print nonsense, when they fail without a word, and when they never answer.
# Nothing may fail quietly: whatever happened is in the line the installer gets, so that it can show it.
#
# On Windows, run it with Windows PowerShell 5.1, which is what the installer uses on a user's computer:
#   powershell -NoProfile -ExecutionPolicy Bypass -File installer\tests\Test-Helpers.ps1
# It also runs with PowerShell 7 on Linux, except for the cases that need wsl.exe's UTF-16 output, which are left out there.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
$scripts = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts'
$work = Join-Path ([IO.Path]::GetTempPath()) ('n8n-helpers-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$script:problems = @()

# The program that runs the helper scripts and the stand-in: the one this script runs in.
$shell = (Get-Process -Id $PID).Path

# The stand-in. It answers as the environment variables FAKE_* say, so one file serves every case:
#   FAKE_OUT, FAKE_CODE     what it prints and its exit code
#   FAKE_OUT_V, FAKE_CODE_V the same when it is asked with -v (wsl -l -v), if they are given
#   FAKE_UTF16=1            print as UTF-16, like wsl.exe does
#   FAKE_ERR                what it writes to its error output
#   FAKE_SLEEP              seconds to wait before it does anything (to look like a program that never answers)
@'
$text = $env:FAKE_OUT
$code = $env:FAKE_CODE
if ($args -contains '-v') {
    if ($env:FAKE_OUT_V) { $text = $env:FAKE_OUT_V }
    if ($env:FAKE_CODE_V) { $code = $env:FAKE_CODE_V }
}
if ($env:FAKE_SLEEP) { Start-Sleep -Seconds ([int]$env:FAKE_SLEEP) }
if ($text) {
    if ($env:FAKE_UTF16) { $bytes = [Text.Encoding]::Unicode.GetBytes($text) } else { $bytes = [Text.Encoding]::UTF8.GetBytes($text) }
    $out = [Console]::OpenStandardOutput()
    $out.Write($bytes, 0, $bytes.Length)
    $out.Flush()
}
if ($env:FAKE_ERR) { [Console]::Error.Write($env:FAKE_ERR) }
exit ([int]$code)
'@ | Set-Content -Path (Join-Path $work 'fake.ps1') -Encoding ascii

if ($onWindows) {
    $fake = Join-Path $work 'fake.cmd'
    "@echo off`r`n`"$shell`" -NoProfile -ExecutionPolicy Bypass -File `"%~dp0fake.ps1`" %*`r`nexit /b %ERRORLEVEL%`r`n" | Set-Content -Path $fake -Encoding ascii
}
else {
    $fake = Join-Path $work 'fake'
    "#!/bin/sh`nexec '$shell' -NoProfile -File `"`$(dirname `"`$0`")/fake.ps1`" `"`$@`"`n" | Set-Content -Path $fake -Encoding ascii -NoNewline
    & chmod +x $fake
}

# Runs a helper script with the stand-in set up as the FAKE_* variables say and returns what it printed (one string
# per line). The variables are put back afterwards.
function Invoke-Helper([string]$script, [string[]]$arguments, [hashtable]$fakes) {
    $names = 'FAKE_OUT', 'FAKE_OUT_V', 'FAKE_UTF16', 'FAKE_ERR', 'FAKE_CODE', 'FAKE_CODE_V', 'FAKE_SLEEP'
    $saved = @{}
    foreach ($n in $names) { $saved[$n] = [Environment]::GetEnvironmentVariable($n, 'Process') }
    try {
        foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $fakes[$n], 'Process') }
        $started = Get-Date
        $flags = @('-NoProfile'); if ($onWindows) { $flags += @('-ExecutionPolicy', 'Bypass') }
        $lines = @(& $shell @flags -File (Join-Path $scripts $script) @arguments)
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Lines = $lines; Code = $code; Seconds = ((Get-Date) - $started).TotalSeconds }
    }
    finally {
        foreach ($n in $names) { [Environment]::SetEnvironmentVariable($n, $saved[$n], 'Process') }
    }
}

function Check([string]$name, $result, [string]$expected) {
    $got = ($result.Lines -join "`n")
    if ($result.Code -eq 0 -and $got -match $expected) { Write-Host "  ok    $name" }
    else { Write-Host "  FAIL  $name`n        expected /$expected/ and exit code 0, got exit code $($result.Code): [$got]"; $script:problems += $name }
}

Write-Host '=== docker-probe.ps1'
$probe = @('-DockerPath', $fake)
Check 'Docker is ready' (Invoke-Helper 'docker-probe.ps1' $probe @{ FAKE_OUT = '27.3.1|linux' }) '^ready\|27\.3\.1$'
Check 'Docker is set to Windows containers' (Invoke-Helper 'docker-probe.ps1' $probe @{ FAKE_OUT = '27.3.1|windows' }) '^windows\|27\.3\.1$'
Check 'Docker says it cannot connect' (Invoke-Helper 'docker-probe.ps1' $probe @{ FAKE_ERR = 'error during connect: open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.'; FAKE_CODE = '1' }) `
    '^stopped\|said: error during connect: open //\./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified\.$'
Check 'Docker prints nonsense' (Invoke-Helper 'docker-probe.ps1' $probe @{ FAKE_OUT = 'hello' }) '^stopped\|Docker answered something unexpected: hello$'
Check 'Docker fails without a word' (Invoke-Helper 'docker-probe.ps1' $probe @{ FAKE_CODE = '3' }) '^stopped\|docker\.exe ended with code 3 and gave no message\.$'
$r = Invoke-Helper 'docker-probe.ps1' ($probe + @('-TimeoutSec', '3')) @{ FAKE_SLEEP = '40' }
Check 'Docker never answers' $r '^stopped\|Docker did not answer within 3 seconds\.$'
if ($r.Seconds -gt 30) { Write-Host "  FAIL  Docker never answers: the probe took $([int]$r.Seconds) seconds"; $script:problems += 'probe time' }
$notAProgram = Join-Path $work 'not-a-program.txt'
Set-Content -Path $notAProgram -Value 'text'
Check 'docker.exe cannot be started' (Invoke-Helper 'docker-probe.ps1' @('-DockerPath', $notAProgram) @{}) '^stopped\|Windows could not start docker\.exe: '
# With docker.exe off the PATH, the answer is "missing" (and "missing|installed" on a computer that has Docker Desktop in its usual folder).
$savedPath = $env:PATH
try {
    if ($onWindows) { $env:PATH = "$env:SystemRoot\System32" } else { $env:PATH = '/usr/bin:/bin' }
    Check 'Docker is not installed' (Invoke-Helper 'docker-probe.ps1' @() @{}) '^missing(\|installed)?$'
}
finally { $env:PATH = $savedPath }

Write-Host '=== wsl-list.ps1'
$list = @('-WslPath', $fake, '-TimeoutSec', '5')
$table = "  NAME              STATE           VERSION`r`n* Ubuntu            Running         2`r`n  docker-desktop    Stopped         2`r`n"
$tableTwo = "  NAME              STATE           VERSION`r`n* Ubuntu-22.04      Running         2`r`n  Debian            Stopped         1`r`n"
$none = "Windows Subsystem for Linux has no installed distributions.`r`nUse 'wsl.exe --list --online' to list available distributions`r`nand 'wsl.exe --install <Distro>' to install.`r`n"
$notInstalled = "The Windows Subsystem for Linux is not installed. You can install by running 'wsl.exe --install'.`r`nFor more information please visit https://aka.ms/wslinstall`r`n"
# On Linux, PowerShell turns the stand-in's UTF-16 into something else on its way into a file, so those cases only run on Windows.
if ($onWindows) {
    Check 'one distribution' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_UTF16 = '1'; FAKE_OUT = "Ubuntu`r`ndocker-desktop`r`n"; FAKE_OUT_V = $table }) '^Ubuntu\|2\|Running$'
    Check 'two distributions, one on WSL 1' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_UTF16 = '1'; FAKE_OUT = "Ubuntu-22.04`r`nDebian`r`n"; FAKE_OUT_V = $tableTwo }) '^Ubuntu-22\.04\|2\|Running\nDebian\|1\|Stopped$'
    Check 'no distribution: WSL says so' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_UTF16 = '1'; FAKE_OUT = $none; FAKE_CODE = '1' }) '^!WSL said: Windows Subsystem for Linux has no installed distributions\.'
    Check 'WSL is not installed (only its stub is)' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_UTF16 = '1'; FAKE_OUT = $notInstalled; FAKE_CODE = '1' }) '^!WSL said: The Windows Subsystem for Linux is not installed\.'
    Check 'the same message with exit code 0 is not a distribution either' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_UTF16 = '1'; FAKE_OUT = $notInstalled }) '^!WSL said: The Windows Subsystem for Linux is not installed\.'
    Check 'only the distributions of Docker Desktop' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_UTF16 = '1'; FAKE_OUT = "docker-desktop`r`ndocker-desktop-data`r`n"; FAKE_OUT_V = $table }) '^!WSL has only docker-desktop and docker-desktop-data'
    Check 'an old Windows that does not know wsl -l -v' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_UTF16 = '1'; FAKE_OUT = "Ubuntu`r`n"; FAKE_OUT_V = "Invalid command line option: -v`r`n"; FAKE_CODE_V = '1' }) '^Ubuntu\|1\|Unknown$'
}
Check 'one distribution (UTF-8 output)' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_OUT = "Ubuntu`nDebian`n"; FAKE_OUT_V = "  NAME    STATE    VERSION`n* Ubuntu  Running  2`n  Debian  Stopped  1`n" }) '^Ubuntu\|2\|Running\nDebian\|1\|Stopped$'
Check 'WSL fails with a message' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_ERR = 'something went wrong'; FAKE_CODE = '2' }) '^!WSL said: something went wrong$'
Check 'WSL fails without a word' (Invoke-Helper 'wsl-list.ps1' $list @{ FAKE_CODE = '2' }) '^!wsl\.exe ended with code 2 and printed nothing\.$'
$r = Invoke-Helper 'wsl-list.ps1' @('-WslPath', $fake, '-TimeoutSec', '3') @{ FAKE_SLEEP = '40' }
Check 'WSL never answers' $r '^!WSL did not answer within 3 seconds\.$'
if ($r.Seconds -gt 30) { Write-Host "  FAIL  WSL never answers: the helper took $([int]$r.Seconds) seconds"; $script:problems += 'wsl time' }
Check 'wsl.exe cannot be started' (Invoke-Helper 'wsl-list.ps1' @('-WslPath', $notAProgram) @{}) '^!Windows could not start wsl\.exe: '

Remove-Item -Path $work -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
if ($script:problems.Count -gt 0) {
    Write-Host "::error::$($script:problems.Count) check(s) failed"
    $script:problems | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
Write-Host 'All helper checks passed.'
