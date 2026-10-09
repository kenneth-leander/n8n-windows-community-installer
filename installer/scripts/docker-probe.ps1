# Asks Docker whether it is ready to run n8n. Prints exactly one line:
#   ready|<docker version>      Docker is running and set to Linux containers
#   windows|<docker version>    Docker is running but set to Windows containers
#   stopped|said: <text>        docker.exe is there but did not answer: the engine is not running or refused the
#                               connection. The text after "said: " is Docker's own message.
#   stopped|<what happened>     docker.exe is there but did not answer, and the reason is not Docker's words: it took too
#                               long, Windows could not start it, or it printed something that makes no sense
#   missing                     docker.exe was not found
#   missing|installed           Docker Desktop is installed, but docker.exe cannot be found from here (Windows has not
#                               yet told this program where it is, which a new sign-in fixes)
# Nothing fails quietly: whatever went wrong is in the line, as one line of plain ASCII.
# -DockerPath is for the tests, which point it at a stand-in for docker.exe.
param([int]$TimeoutSec = 15, [string]$DockerPath = '')
$ErrorActionPreference = 'SilentlyContinue'

# One short line of plain ASCII. The end of a long message is kept, as that is where Docker says what is wrong.
function Tidy([string]$Text, [int]$Max = 400) {
    $t = ($Text -replace '\s+', ' ').Trim()
    $t = $t -replace '[^\x20-\x7E]', '?'
    $t = $t -replace '\|', '/'
    if ($t.Length -gt $Max) { $t = '...' + $t.Substring($t.Length - ($Max - 3)) }
    return $t
}

$docker = $DockerPath
if (-not $docker) {
    $found = Get-Command docker.exe -ErrorAction SilentlyContinue
    if ($found) { $docker = $found.Source }
}
if (-not $docker) {
    if ($env:ProgramFiles -and (Test-Path (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'))) {
        'missing|installed'
    } else {
        'missing'
    }
    exit 0
}

$out = [IO.Path]::GetTempFileName()
$err = [IO.Path]::GetTempFileName()
$answer = ''
try {
    $p = $null
    $startError = ''
    try {
        $p = Start-Process -FilePath $docker -NoNewWindow -PassThru -ErrorAction Stop `
            -ArgumentList @('version', '--format', '{{.Server.Version}}|{{.Server.Os}}') `
            -RedirectStandardOutput $out -RedirectStandardError $err
    } catch {
        $startError = $_.Exception.Message
    }
    if (-not $p) {
        $answer = 'stopped|Windows could not start docker.exe: ' + (Tidy $startError 250)
    } elseif (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch { }
        $answer = "stopped|Docker did not answer within $TimeoutSec seconds."
    } else {
        $p.WaitForExit()
        $line = ''
        if (Test-Path $out) { $line = ((Get-Content -Path $out -TotalCount 1) | Out-String).Trim() }
        $said = ''
        if (Test-Path $err) { $said = ((Get-Content -Path $err) | Out-String).Trim() }
        if ($p.ExitCode -eq 0 -and $line -match '^[^|]+\|[a-z]+$') {
            $parts = $line.Split('|')
            if ($parts[1] -eq 'linux') { $answer = "ready|$($parts[0])" } else { $answer = "windows|$($parts[0])" }
        } elseif ($said) {
            $answer = 'stopped|said: ' + (Tidy $said)
        } elseif ($line) {
            $answer = 'stopped|Docker answered something unexpected: ' + (Tidy $line 200)
        } else {
            $answer = "stopped|docker.exe ended with code $($p.ExitCode) and gave no message."
        }
    }
}
finally {
    Remove-Item -Path $out, $err -Force -ErrorAction SilentlyContinue
}
$answer
exit 0
