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

# Runs a program, waits for it for at most $Seconds seconds and says what happened:
#   Problem   why Windows could not start it ('' when it started)
#   TimedOut  it did not finish in time and was stopped
#   Code      its exit code
#   Out, Err  what it printed, and what it wrote to its error output, as bytes
# This is not Start-Process, on purpose: in Windows PowerShell 5.1 the exit code of a program that Start-Process started
# comes back empty, and a check that reads "exit code is not 0" then takes every Docker for a stopped one.
function Invoke-Program([string]$Path, [string]$Arguments, [int]$Seconds) {
    $ErrorActionPreference = 'Stop'
    $result = [pscustomobject]@{ Problem = ''; TimedOut = $false; Code = -1; Out = (New-Object byte[] 0); Err = (New-Object byte[] 0) }
    $p = $null
    try {
        $info = New-Object System.Diagnostics.ProcessStartInfo
        $info.FileName = $Path
        $info.Arguments = $Arguments
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardInput = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $p = [System.Diagnostics.Process]::Start($info)
        $out = New-Object System.IO.MemoryStream
        $err = New-Object System.IO.MemoryStream
        $outTask = $p.StandardOutput.BaseStream.CopyToAsync($out)
        $errTask = $p.StandardError.BaseStream.CopyToAsync($err)
        $p.StandardInput.Close()      # nothing to read: a program that waits for a key press ends instead
        if (-not $p.WaitForExit($Seconds * 1000)) {
            try { $p.Kill() } catch { }
            $result.TimedOut = $true
            return $result
        }
        # It has ended. What it printed may still be on its way, so give it a moment.
        [void][System.Threading.Tasks.Task]::WaitAll([System.Threading.Tasks.Task[]]@($outTask, $errTask), 3000)
        $result.Code = $p.ExitCode
        $result.Out = $out.ToArray()
        $result.Err = $err.ToArray()
    }
    catch {
        $result.Problem = $_.Exception.Message
    }
    finally {
        if ($p) { $p.Dispose() }
    }
    return $result
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

$run = Invoke-Program $docker 'version --format {{.Server.Version}}|{{.Server.Os}}' $TimeoutSec
if ($run.Problem) {
    $answer = 'stopped|Windows could not start docker.exe: ' + (Tidy $run.Problem 250)
} elseif ($run.TimedOut) {
    $answer = "stopped|Docker did not answer within $TimeoutSec seconds."
} else {
    $line = ''
    foreach ($l in ([Text.Encoding]::UTF8.GetString($run.Out) -split "`r?`n")) {
        if ($l.Trim()) { $line = $l.Trim(); break }
    }
    $said = [Text.Encoding]::UTF8.GetString($run.Err).Trim()
    if ($run.Code -eq 0 -and $line -match '^[^|]+\|[a-z]+$') {
        $parts = $line.Split('|')
        if ($parts[1] -eq 'linux') { $answer = "ready|$($parts[0])" } else { $answer = "windows|$($parts[0])" }
    } elseif ($said) {
        $answer = 'stopped|said: ' + (Tidy $said)
    } elseif ($line) {
        $answer = 'stopped|Docker answered something unexpected: ' + (Tidy $line 200)
    } else {
        $answer = "stopped|docker.exe ended with code $($run.Code) and gave no message."
    }
}
$answer
exit 0
