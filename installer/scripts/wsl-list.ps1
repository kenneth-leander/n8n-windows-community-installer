# Lists the Linux distributions installed in WSL, one per line as: name|version|state
# (docker-desktop and rancher-desktop are skipped, they are not general-purpose distros).
# When it finds none, it prints one line instead, !<why>, so that the installer can say what WSL said or did.
# wsl.exe writes UTF-16, so its output is decoded here.
# -WslPath is for the tests, which point it at a stand-in for wsl.exe.
param([int]$TimeoutSec = 15, [string]$WslPath = '')
$ErrorActionPreference = 'SilentlyContinue'

# One short line of plain ASCII, with no | in it. The end of a long message is kept.
function Tidy([string]$Text, [int]$Max = 300) {
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
# comes back empty, which makes every answer look like a failure.
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

# The lines in what wsl.exe wrote: UTF-16, or UTF-8 when WSL was asked for that.
function Read-WslBytes([byte[]]$Bytes) {
    if ($Bytes.Length -eq 0) { return @() }
    if ($Bytes -contains 0) { $text = [Text.Encoding]::Unicode.GetString($Bytes) } else { $text = [Text.Encoding]::UTF8.GetString($Bytes) }
    return @($text -split "`r?`n" | ForEach-Object { ($_ -replace '[\u0000\uFEFF]', '').Trim() } | Where-Object { $_ })
}

# Runs wsl.exe with the arguments. Returns Lines (what it printed, then what it wrote to its error output), its exit
# code, and Note: why it could not be run or did not finish, or '' when it ran and finished.
function Invoke-Wsl([string]$WslArguments) {
    $run = Invoke-Program $wsl $WslArguments $TimeoutSec
    $result = [pscustomobject]@{ Lines = @(); Code = $run.Code; Note = '' }
    if ($run.Problem) {
        $result.Note = 'Windows could not start wsl.exe: ' + (Tidy $run.Problem 200)
    } elseif ($run.TimedOut) {
        $result.Note = "WSL did not answer within $TimeoutSec seconds."
    } else {
        $result.Lines = @(Read-WslBytes $run.Out) + @(Read-WslBytes $run.Err)
    }
    return $result
}

$wsl = $WslPath
if (-not $wsl) {
    $found = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if ($found) { $wsl = $found.Source }
}
if (-not $wsl) { '!wsl.exe was not found.'; exit 0 }

$names = Invoke-Wsl '-l -q'
if ($names.Note) { '!' + $names.Note; exit 0 }
$table = Invoke-Wsl '-l -v'
if ($table.Note) { '!' + $table.Note; exit 0 }
$rows = @($table.Lines | ForEach-Object { $_ -replace '^\*\s*', '' })

$listed = 0
$own = @()
if ($names.Code -eq 0) {
    foreach ($d in $names.Lines) {
        if ($d -match '^(docker-desktop|rancher-desktop)') { $own += $d; continue }
        $ver = ''; $state = ''
        foreach ($r in $rows) {
            if ($r.StartsWith($d + ' ') -and $r -match '\s([12])\s*$') {
                $ver = $Matches[1]
                $state = (($r.Substring($d.Length) -replace '\s+[12]\s*$', '')).Trim()
                break
            }
        }
        # Older Windows has no table with versions (wsl -l -v is not understood); everything there is WSL 1.
        if (-not $ver -and $table.Code -ne 0 -and $d -match '^[A-Za-z0-9][A-Za-z0-9._-]*$') { $ver = '1' }
        if ($ver) {
            if (-not $state) { $state = 'Unknown' }
            '{0}|{1}|{2}' -f (Tidy $d 60), $ver, (Tidy $state 40)
            $listed++
        }
    }
}

if ($listed -eq 0) {
    if ($own.Count -gt 0 -and $own.Count -eq $names.Lines.Count) {
        '!WSL has only ' + ($own -join ' and ') + ', which Docker Desktop or Rancher Desktop use for themselves, and no Linux distribution of your own.'
    } elseif ($names.Lines.Count -gt 0) {
        '!WSL said: ' + (Tidy ($names.Lines -join ' '))
    } elseif ($table.Lines.Count -gt 0) {
        '!WSL said: ' + (Tidy ($table.Lines -join ' '))
    } else {
        "!wsl.exe ended with code $($names.Code) and printed nothing."
    }
}
exit 0
