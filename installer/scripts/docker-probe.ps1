# Asks Docker whether it is ready to run n8n. Prints exactly one line:
#   ready|<docker version>   Docker is running and set to Linux containers
#   windows|<docker version> Docker is running but set to Windows containers
#   stopped                  Docker is installed but not running (or too slow to answer)
#   missing                  Docker is not installed
param([int]$TimeoutSec = 15)
$ErrorActionPreference = 'SilentlyContinue'

$docker = Get-Command docker.exe -ErrorAction SilentlyContinue
if (-not $docker) { 'missing'; exit 0 }

$out = [IO.Path]::GetTempFileName()
$err = [IO.Path]::GetTempFileName()
try {
    $p = Start-Process -FilePath $docker.Source -NoNewWindow -PassThru `
        -ArgumentList @('version', '--format', '{{.Server.Version}}|{{.Server.Os}}') `
        -RedirectStandardOutput $out -RedirectStandardError $err
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        'stopped'
        exit 0
    }
    $p.WaitForExit()
    $line = ''
    if (Test-Path $out) { $line = ((Get-Content -Path $out -TotalCount 1) | Out-String).Trim() }
    if ($p.ExitCode -ne 0 -or $line -notmatch '^[^|]+\|[a-z]+$') { 'stopped'; exit 0 }
    $parts = $line.Split('|')
    if ($parts[1] -eq 'linux') { "ready|$($parts[0])" } else { "windows|$($parts[0])" }
}
finally {
    Remove-Item -Path $out, $err -Force -ErrorAction SilentlyContinue
}
