// ---------------------------------------------------------------------------
// detect.iss - what is available on this computer
// ---------------------------------------------------------------------------

var
  GDetected: Boolean;

  GDockerState: String;       // ready, windows, stopped, missing, or error when the check itself did not work
  GDockerVersion: String;
  GDockerDetail: String;      // in words: what Docker said, or why the check did not work ('' when there is nothing to add)
  GDockerSaid: Boolean;       // GDockerDetail is Docker's own message, not something Setup worked out

  GNodeVersion: String;       // like 22.11.0, or '' when Node.js is not installed
  GNodeMajor: Integer;
  GNodeMinor: Integer;
  GNodeOk: Boolean;           // a Node.js that n8n 2.x runs on and this installer has tested
  GNodeDetail: String;        // when Node.js is there but did not run: what it said
  GNpmVersion: String;

  GWslHasExe: Boolean;        // wsl.exe is on this computer
  GWslProblem: String;        // when listing the distributions did not work: why
  GWslCount: Integer;
  GWslName: array of String;
  GWslVersion: array of String;
  GWslState: array of String;

// The first useful line of what the last captured program wrote to its error output, or ''.
function FirstErrorLine: String;
var
  I: Integer;
  S: String;
begin
  Result := '';
  for I := 0 to GetArrayLength(GCaptureErrors) - 1 do
  begin
    S := Trim(ReplaceAll(GCaptureErrors[I], #0, ''));
    // PowerShell sometimes wraps its error output in XML, which says nothing.
    if (S <> '') and (Copy(S, 1, 2) <> '#<') and (Copy(S, 1, 5) <> '<Objs') then
    begin
      Result := S;
      Exit;
    end;
  end;
end;

// The text after the | in what the probe printed. It starts with "said: " when it is Docker's own message.
procedure SetDockerDetail(const Text: String);
begin
  GDockerSaid := Copy(Text, 1, 6) = 'said: ';
  if GDockerSaid then
    GDockerDetail := Copy(Text, 7, Length(Text))
  else
    GDockerDetail := Text;
end;

procedure DetectDocker;
var
  Lines: TArrayOfString;
  Code: Integer;
  Line, Head, Tail: String;
begin
  GDockerState := 'missing';
  GDockerVersion := '';
  GDockerDetail := '';
  GDockerSaid := False;
  // Test hook: with /DRYRUN, /FAKEDOCKER=ready|windows|stopped|missing|error pretends to have asked Docker,
  // and /FAKEDOCKERMSG="..." is what it pretends the probe added ("said: ..." for Docker's own words).
  if GDryRun and SwitchGiven('FAKEDOCKER') then
  begin
    GDockerState := Switch('FAKEDOCKER', 'missing');
    GDockerVersion := '27.0.0';
    SetDockerDetail(Switch('FAKEDOCKERMSG', ''));
    Exit;
  end;
  Code := RunHelperCapture('docker-probe.ps1', '', Lines);
  Line := FirstNonEmpty(Lines);
  if Code < 0 then
  begin
    GDockerState := 'error';
    GDockerDetail := 'PowerShell could not be started to ask Docker.';
    Exit;
  end;
  SplitOnce(Line, '|', Head, Tail);
  if (Head = 'ready') or (Head = 'windows') then
  begin
    GDockerState := Head;
    GDockerVersion := Tail;
  end
  else if (Head = 'stopped') or (Head = 'missing') then
  begin
    GDockerState := Head;
    SetDockerDetail(Tail);
  end
  else
  begin
    // The check ran but did not give an answer we know. Say so, instead of guessing "not installed".
    GDockerState := 'error';
    if Line = '' then
      GDockerDetail := 'The check printed nothing and ended with code ' + IntToStr(Code) + '.'
    else
      GDockerDetail := 'The check printed "' + EndOf(Line, 150) + '" and ended with code ' + IntToStr(Code) + '.';
    if FirstErrorLine <> '' then
      GDockerDetail := GDockerDetail + ' It also said: ' + EndOf(FirstErrorLine, 200);
  end;
end;

procedure DetectNode;
var
  Lines: TArrayOfString;
  Code: Integer;
  V, Major, Minor: String;
begin
  GNodeVersion := '';
  GNodeMajor := 0;
  GNodeMinor := 0;
  GNodeOk := False;
  GNodeDetail := '';
  GNpmVersion := '';
  // Test hook: with /DRYRUN, /FAKENODE=22.11.0 pretends that Node.js is installed.
  // /FAKENODEMSG="..." pretends that Node.js is there but fails with that message.
  if GDryRun and SwitchGiven('FAKENODE') then
  begin
    GNodeVersion := Switch('FAKENODE', '');
    SplitOnce(GNodeVersion, '.', Major, V);
    SplitOnce(V, '.', Minor, V);
    GNodeMajor := StrToIntDef(Major, 0);
    GNodeMinor := StrToIntDef(Minor, 0);
    GNodeOk := (GNodeMajor = 22) or ((GNodeMajor = 20) and (GNodeMinor >= 19));
    GNpmVersion := '10.9.2';
    Exit;
  end;
  if GDryRun and SwitchGiven('FAKENODEMSG') then
  begin
    GNodeDetail := Switch('FAKENODEMSG', '');
    Exit;
  end;
  // 2>&1 so that what Node.js says when it fails is captured as well. cmd.exe answers 9009 when it finds no such program.
  if not CaptureCmd('node --version 2>&1', Lines, Code) then
    GNodeDetail := 'Windows could not start a command prompt to look for it.'
  else if (Code <> 0) and (Code <> 9009) then
  begin
    GNodeDetail := 'It ended with code ' + IntToStr(Code);
    if FirstNonEmpty(Lines) <> '' then
      GNodeDetail := GNodeDetail + ' and said: ' + StartOf(FirstNonEmpty(Lines), 300);
  end
  else if Code = 0 then
  begin
    V := FirstNonEmpty(Lines);
    if (Length(V) > 1) and (V[1] = 'v') then Delete(V, 1, 1);
    SplitOnce(V, '.', Major, V);
    SplitOnce(V, '.', Minor, V);
    GNodeMajor := StrToIntDef(Major, 0);
    GNodeMinor := StrToIntDef(Minor, 0);
    if GNodeMajor > 0 then
      GNodeVersion := Major + '.' + Minor + '.' + V;
    // n8n 2.x runs on Node.js 20.19+ and 22. This installer settled on 22 LTS, see settings.iss.
    GNodeOk := (GNodeMajor = 22) or ((GNodeMajor = 20) and (GNodeMinor >= 19));
    if GNodeVersion = '' then
      GNodeDetail := 'It printed "' + StartOf(FirstNonEmpty(Lines), 100) + '" instead of a version number.';
  end;
  if (GNodeVersion <> '') and CaptureCmd('npm --version', Lines, Code) and (Code = 0) then
    GNpmVersion := FirstNonEmpty(Lines);
end;

procedure DetectWsl;
var
  Lines: TArrayOfString;
  Code, I, N: Integer;
  Name, Rest, Ver, State: String;
begin
  GWslCount := 0;
  GWslHasExe := True;
  GWslProblem := '';
  SetArrayLength(GWslName, 0);
  SetArrayLength(GWslVersion, 0);
  SetArrayLength(GWslState, 0);
  // Test hooks: with /DRYRUN, /FAKEWSL="Ubuntu|2|Running;Debian|1|Stopped" pretends to have listed distributions,
  // /FAKEWSLMSG="..." is what WSL pretends to have said when it listed none, and /FAKEWSLEXE=missing pretends
  // that wsl.exe is not on this computer.
  if GDryRun and (Switch('FAKEWSLEXE', '') = 'missing') then
  begin
    GWslHasExe := False;
    Exit;
  end;
  if GDryRun and SwitchGiven('FAKEWSL') then
  begin
    GWslProblem := Switch('FAKEWSLMSG', '');
    Rest := Switch('FAKEWSL', '');
    while Rest <> '' do
    begin
      SplitOnce(Rest, ';', Name, Rest);
      N := GetArrayLength(Lines);
      SetArrayLength(Lines, N + 1);
      Lines[N] := Name;
    end;
  end
  else
  begin
    if not FileExists(ExpandConstant('{sys}\wsl.exe')) then
    begin
      GWslHasExe := False;
      Exit;
    end;
    Code := RunHelperCapture('wsl-list.ps1', '', Lines);
    if Code <> 0 then
    begin
      // Nothing listed is a normal answer (no distribution). A check that did not run is not, so it is reported.
      SetArrayLength(Lines, 0);
      if Code < 0 then
        GWslProblem := 'PowerShell could not be started to ask WSL.'
      else
      begin
        GWslProblem := 'The check ended with code ' + IntToStr(Code) + '.';
        if FirstErrorLine <> '' then
          GWslProblem := GWslProblem + ' It said: ' + EndOf(FirstErrorLine, 200);
      end;
    end;
  end;
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    if Trim(Lines[I]) = '' then Continue;
    // A line that starts with ! is the helper script saying why it found no distribution: what WSL said, or did not do.
    if Copy(Trim(Lines[I]), 1, 1) = '!' then
    begin
      GWslProblem := Copy(Trim(Lines[I]), 2, 500);
      Continue;
    end;
    SplitOnce(Trim(Lines[I]), '|', Name, Rest);
    SplitOnce(Rest, '|', Ver, State);
    if Name = '' then Continue;
    N := GWslCount;
    SetArrayLength(GWslName, N + 1);
    SetArrayLength(GWslVersion, N + 1);
    SetArrayLength(GWslState, N + 1);
    GWslName[N] := Name;
    GWslVersion[N] := Ver;
    GWslState[N] := State;
    GWslCount := N + 1;
  end;
end;

procedure DetectEverything;
begin
  FileLog('Checking this computer...');
  DetectDocker;
  FileLog('  Docker: ' + GDockerState + ' ' + GDockerVersion);
  if GDockerDetail <> '' then FileLog('    ' + GDockerDetail);
  DetectNode;
  FileLog('  Node.js: ' + GNodeVersion + '  npm: ' + GNpmVersion + '  usable: ' + B2S(GNodeOk));
  if GNodeDetail <> '' then FileLog('    ' + GNodeDetail);
  DetectWsl;
  FileLog('  WSL distributions: ' + IntToStr(GWslCount));
  if not GWslHasExe then FileLog('    wsl.exe is not on this computer.');
  if GWslProblem <> '' then FileLog('    ' + GWslProblem);
  GDetected := True;
end;

function DockerReady: Boolean;
begin
  Result := GDockerState = 'ready';
end;

// ---------------------------------------------------------------------------
// Ports and disk space
// ---------------------------------------------------------------------------

// Takes the first space-separated word off the front of S.
function NextWord(var S: String): String;
var
  P: Integer;
begin
  S := Trim(S);
  P := Pos(' ', S);
  if P = 0 then
  begin
    Result := S;
    S := '';
  end
  else
  begin
    Result := Copy(S, 1, P - 1);
    S := Trim(Copy(S, P + 1, Length(S)));
  end;
end;

var
  GPortProblem: String;        // when the last look at the ports did not work: why ('' when it worked)
  GPortProblemLogged: String;  // the problem that is already in the log, so that it is written down once

// True when something on this computer is already listening on the TCP port. When netstat does not work the answer is
// False and GPortProblem says why, so that nobody is told a port is free when nobody has looked.
// Test mode: /FAKENETSTAT="<what netstat said>" pretends that netstat failed with that message.
function PortInUse(const Port: Integer): Boolean;
var
  Lines: TArrayOfString;
  Code, I: Integer;
  L, Proto, Local, Foreign, Said: String;
begin
  Result := False;
  GPortProblem := '';
  if GDryRun and (Switch('FAKENETSTAT', '') <> '') then
    GPortProblem := 'netstat.exe ended with code 1 and said: ' + Switch('FAKENETSTAT', '')
  else if not CaptureTool(ExpandConstant('{sys}\netstat.exe'), '-ano', Lines, Code) then
    GPortProblem := 'Windows could not start netstat.exe'
  else if Code <> 0 then
  begin
    GPortProblem := 'netstat.exe ended with code ' + IntToStr(Code);
    Said := FirstErrorLine;
    if Said = '' then Said := FirstNonEmpty(Lines);
    if Said <> '' then
      GPortProblem := GPortProblem + ' and said: ' + StartOf(Said, 150);
  end;
  if GPortProblem <> '' then
  begin
    if GPortProblem <> GPortProblemLogged then
      FileLog('! Setup could not check whether port ' + IntToStr(Port) + ' (or any other) is free: ' + AsSentence(GPortProblem));
    GPortProblemLogged := GPortProblem;
    Exit;
  end;
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    L := Trim(Lines[I]);
    Proto := NextWord(L);
    if Proto <> 'TCP' then Continue;
    Local := NextWord(L);
    Foreign := NextWord(L);
    // A listening socket has no remote end: its foreign address is 0.0.0.0:0 or [::]:0.
    // This test does not depend on the language Windows is set to.
    if (Copy(Foreign, Length(Foreign) - 1, 2) = ':0') and
       (Copy(Local, Length(Local) - Length(IntToStr(Port)), Length(IntToStr(Port)) + 1) = ':' + IntToStr(Port)) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// The first port from Start up that nothing is listening on, together with the one after it
// (n8n uses a second port for its task runner).
function FirstFreePort(const Start: Integer): Integer;
var
  P: Integer;
begin
  P := Start;
  while (P < Start + 40) and (PortInUse(P) or PortInUse(P + 1)) do
    Inc(P);
  Result := P;
end;

function FreeSpaceMB(const Dir: String): Integer;
var
  Free, Total: Int64;
  Drive: String;
begin
  Result := -1;
  Drive := ExtractFileDrive(Dir);
  if Drive = '' then Exit;
  if GetSpaceOnDisk64(Drive + '\', Free, Total) then
    Result := Free div (1024 * 1024);
end;
