// ---------------------------------------------------------------------------
// run.iss - starting other programs, with their output shown live
// ---------------------------------------------------------------------------

function SetEnvironmentVariableW(lpName, lpValue: String): Boolean;
  external 'SetEnvironmentVariableW@kernel32.dll stdcall';

var
  GBusy: Boolean;          // a long step is running: Cancel is switched off
  GQuiet: Boolean;         // keep tool output in the log file only (npm prints a lot)
  GLineCount: Integer;
  GLastLines: array [0..9] of String;   // the last few lines, to show in an error

procedure RememberLine(const S: String);
var
  I: Integer;
begin
  for I := 0 to 8 do
    GLastLines[I] := GLastLines[I + 1];
  GLastLines[9] := S;
end;

function LastLinesText: String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to 9 do
    if Trim(GLastLines[I]) <> '' then
      Result := Result + GLastLines[I] + #13#10;
end;

procedure ClearLastLines;
var
  I: Integer;
begin
  for I := 0 to 9 do
    GLastLines[I] := '';
end;

procedure OnToolOutput(const S: String; const Error, FirstLine: Boolean);
begin
  if Error then
  begin
    FileLog('! output problem: ' + S);
    Exit;
  end;
  Inc(GLineCount);
  RememberLine(S);
  if GQuiet then
    FileLog('  ' + S)
  else
    LogLine('  ' + S);
end;

// Test mode only: /SLOW=seconds makes every step last that long, so a screenshot can catch it.
procedure DryRunPause;
var
  Code: Integer;
begin
  if GDryRun and SwitchGiven('SLOW') then
    Exec(ExpandConstant('{cmd}'), '/C ping -n ' + IntToStr(StrToIntDef(Switch('SLOW', '1'), 1) + 1) + ' 127.0.0.1 >nul',
      '', SW_HIDE, ewWaitUntilTerminated, Code);
end;

// Runs a program, shows what it prints, and returns its exit code (-1 if it could not be started).
function RunTool(const Exe, Params, WorkDir: String): Integer;
var
  Code: Integer;
begin
  FileLog('> ' + Exe + ' ' + Params);
  GLineCount := 0;
  ClearLastLines;
  if GDryRun then
  begin
    // Test mode: say what would run. /DRYRUN=fail makes every program "fail", to try the error paths.
    LogLine('  (dry run) would run: ' + Exe + ' ' + Params);
    if Switch('DRYRUN', '') = 'fail' then
    begin
      RememberLine('(dry run) pretend error output');
      Result := 1;
    end
    else
      Result := 0;
    Exit;
  end;
  Code := -1;
  try
    if not ExecAndLogOutput(Exe, Params, WorkDir, SW_SHOWNORMAL, ewWaitUntilTerminated, Code, @OnToolOutput) then
    begin
      LogLine('! Could not start ' + Exe + ': ' + SysErrorMessage(Code));
      Code := -1;
    end;
  except
    LogLine('! ' + GetExceptionMessage);
    Code := -1;
  end;
  FileLog('  (exit code ' + IntToStr(Code) + ')');
  Result := Code;
end;

// Runs one command line through cmd.exe. Needed for .cmd files such as npm.cmd.
function RunCmd(const CommandLine, WorkDir: String): Integer;
begin
  Result := RunTool(ExpandConstant('{cmd}'), '/S /C "' + CommandLine + '"', WorkDir);
end;

// Runs a program and returns everything it printed, line by line (stdout and stderr apart).
function CaptureTool(const Exe, Params: String; var Lines: TArrayOfString; var ExitCode: Integer): Boolean;
var
  Output: TExecOutput;
begin
  Result := False;
  ExitCode := -1;
  SetArrayLength(Lines, 0);
  try
    Result := ExecAndCaptureOutput(Exe, Params, '', SW_HIDE, ewWaitUntilTerminated, ExitCode, Output);
    if Result then
      Lines := Output.StdOut;
  except
    FileLog('! ' + GetExceptionMessage);
  end;
end;

function CaptureCmd(const CommandLine: String; var Lines: TArrayOfString; var ExitCode: Integer): Boolean;
begin
  Result := CaptureTool(ExpandConstant('{cmd}'), '/S /C "' + CommandLine + '"', Lines, ExitCode);
end;

// First non-empty line of the output, or ''.
function FirstNonEmpty(const Lines: TArrayOfString): String;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to GetArrayLength(Lines) - 1 do
    if Trim(Lines[I]) <> '' then
    begin
      Result := Trim(Lines[I]);
      Exit;
    end;
end;

// ---------------------------------------------------------------------------
// PowerShell helper scripts that ship inside the installer (installer\scripts)
// ---------------------------------------------------------------------------

function PowerShellExe: String;
begin
  Result := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
end;

function PsParams(const Script, Args: String): String;
begin
  Result := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File ' + Q(ExpandConstant('{tmp}\' + Script));
  if Args <> '' then
    Result := Result + ' ' + Args;
end;

// Runs one of the helper scripts and returns what it printed.
function RunHelperCapture(const Script, Args: String; var Lines: TArrayOfString): Integer;
var
  Code: Integer;
begin
  ExtractTemporaryFile(Script);
  if not CaptureTool(PowerShellExe, PsParams(Script, Args), Lines, Code) then
    Code := -1;
  Result := Code;
end;

// Runs one of the helper scripts with its output shown live.
function RunHelperLive(const Script, Args: String): Integer;
begin
  ExtractTemporaryFile(Script);
  Result := RunTool(PowerShellExe, PsParams(Script, Args), '');
end;

// ---------------------------------------------------------------------------
// Environment for the programs we start
// ---------------------------------------------------------------------------

procedure SetEnv(const Name, Value: String);
begin
  SetEnvironmentVariableW(Name, Value);
end;

procedure PutOnPath(const Dir: String);
begin
  SetEnv('PATH', Dir + ';' + GetEnv('PATH'));
end;
