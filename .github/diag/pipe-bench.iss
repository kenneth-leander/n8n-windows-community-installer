; Temporary diagnostic: how fast and how reliably does ExecAndLogOutput read a program's output?
; Mirrors what the real installer does while npm runs (RunTool + OnToolOutput + a label that shows the latest line).
[Setup]
AppName=bench
AppVersion=1
CreateAppDir=no
Uninstallable=no
PrivilegesRequired=lowest
OutputDir=out
OutputBaseFilename=pipe-bench
DisableProgramGroupPage=yes
DisableReadyPage=yes
DisableDirPage=yes
DisableFinishedPage=yes
SetupLogging=yes
Compression=none

[Code]
function GetTickCount: DWORD;
  external 'GetTickCount@kernel32.dll stdcall';

var
  GCase: String;
  GLines: Integer;
  GWork: Integer;
  GLogPath: String;

function Switch(const Name: String): String;
var
  I: Integer;
  P: String;
begin
  Result := '';
  for I := 1 to ParamCount do
  begin
    P := ParamStr(I);
    if CompareText(Copy(P, 1, Length(Name) + 2), '/' + Name + '=') = 0 then
    begin
      Result := Copy(P, Length(Name) + 3, Length(P));
      Exit;
    end;
  end;
end;

procedure OnOut(const S: String; const Error, FirstLine: Boolean);
begin
  if Error then
  begin
    SaveStringToFile(GLogPath, '! output problem: ' + S + #13#10, True);
    Exit;
  end;
  Inc(GLines);
  if GWork >= 2 then
  begin
    Log('  ' + S);
    SaveStringToFile(GLogPath, '  ' + S + #13#10, True);
  end;
  if (GWork >= 3) and (Trim(S) <> '') then
    WizardForm.FilenameLabel.Caption := Copy(Trim(S), 1, 100);
end;

procedure Note(const S: String);
begin
  SaveStringToFile(GLogPath, GetDateTimeString('hh:nn:ss', '-', ':') + ' ' + S + #13#10, True);
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Code: Integer;
  T0: DWORD;
  Cmd: String;
  Ok: Boolean;
begin
  if CurStep <> ssInstall then Exit;
  GLogPath := ExpandConstant('{%TEMP}\bench-' + Switch('CASE') + '.log');
  DeleteFile(GLogPath);
  GWork := StrToIntDef(Switch('WORK'), 0);
  Cmd := Switch('CMD');
  if GWork >= 4 then
    WizardForm.ProgressGauge.Style := npbstMarquee;
  Note('case ' + Switch('CASE') + ' work level ' + IntToStr(GWork) + ': ' + Cmd);
  T0 := GetTickCount;
  Code := -1;
  Ok := ExecAndLogOutput(ExpandConstant('{cmd}'), '/S /C "' + Cmd + '"', '', SW_SHOWNORMAL, ewWaitUntilTerminated, Code, @OnOut);
  Note('finished: started=' + IntToStr(Ord(Ok)) + ' exit=' + IntToStr(Code) + ' lines=' + IntToStr(GLines) + ' ms=' + IntToStr(GetTickCount - T0));
end;
