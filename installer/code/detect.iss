// ---------------------------------------------------------------------------
// detect.iss - what is available on this computer
// ---------------------------------------------------------------------------

var
  GDetected: Boolean;

  GDockerState: String;       // ready, windows, stopped, missing
  GDockerVersion: String;

  GNodeVersion: String;       // like 22.11.0, or '' when Node.js is not installed
  GNodeMajor: Integer;
  GNodeMinor: Integer;
  GNodeOk: Boolean;           // a Node.js that n8n 2.x runs on and this installer has tested
  GNpmVersion: String;

  GWslCount: Integer;
  GWslName: array of String;
  GWslVersion: array of String;
  GWslState: array of String;

procedure DetectDocker;
var
  Lines: TArrayOfString;
  Head, Tail: String;
begin
  GDockerState := 'missing';
  GDockerVersion := '';
  // Test hook: with /DRYRUN, /FAKEDOCKER=ready|windows|stopped|missing pretends to have asked Docker.
  if GDryRun and SwitchGiven('FAKEDOCKER') then
  begin
    GDockerState := Switch('FAKEDOCKER', 'missing');
    GDockerVersion := '27.0.0';
    Exit;
  end;
  if RunHelperCapture('docker-probe.ps1', '', Lines) < 0 then Exit;
  SplitOnce(FirstNonEmpty(Lines), '|', Head, Tail);
  if (Head = 'ready') or (Head = 'windows') or (Head = 'stopped') or (Head = 'missing') then
    GDockerState := Head;
  GDockerVersion := Tail;
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
  GNpmVersion := '';
  // Test hook: with /DRYRUN, /FAKENODE=22.11.0 pretends that Node.js is installed.
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
  if CaptureCmd('node --version', Lines, Code) and (Code = 0) then
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
  end;
  if (GNodeVersion <> '') and CaptureCmd('npm --version', Lines, Code) and (Code = 0) then
    GNpmVersion := FirstNonEmpty(Lines);
end;

procedure DetectWsl;
var
  Lines: TArrayOfString;
  I, N: Integer;
  Name, Rest, Ver, State: String;
begin
  GWslCount := 0;
  SetArrayLength(GWslName, 0);
  SetArrayLength(GWslVersion, 0);
  SetArrayLength(GWslState, 0);
  // Test hook: with /DRYRUN, /FAKEWSL="Ubuntu|2|Running;Debian|1|Stopped" pretends to have listed distributions.
  if GDryRun and SwitchGiven('FAKEWSL') then
  begin
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
    if not FileExists(ExpandConstant('{sys}\wsl.exe')) then Exit;
    RunHelperCapture('wsl-list.ps1', '', Lines);
  end;
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    if Trim(Lines[I]) = '' then Continue;
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
  DetectNode;
  FileLog('  Node.js: ' + GNodeVersion + '  npm: ' + GNpmVersion + '  usable: ' + B2S(GNodeOk));
  DetectWsl;
  FileLog('  WSL distributions: ' + IntToStr(GWslCount));
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

// True when something on this computer is already listening on the TCP port.
function PortInUse(const Port: Integer): Boolean;
var
  Lines: TArrayOfString;
  Code, I: Integer;
  L, Proto, Local, Foreign: String;
begin
  Result := False;
  if not CaptureTool(ExpandConstant('{sys}\netstat.exe'), '-ano', Lines, Code) then Exit;
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
