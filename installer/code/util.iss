// ---------------------------------------------------------------------------
// util.iss - small helpers shared by the rest of the installer code
// ---------------------------------------------------------------------------

function Q(const S: String): String;
begin
  Result := '"' + S + '"';
end;

function ReplaceAll(const S, FromText, ToText: String): String;
begin
  Result := S;
  StringChangeEx(Result, FromText, ToText, True);
end;

function B2S(const B: Boolean): String;
begin
  if B then Result := '1' else Result := '0';
end;

function S2B(const S: String): Boolean;
var
  T: String;
begin
  T := Lowercase(Trim(S));
  Result := (T = '1') or (T = 'true') or (T = 'yes') or (T = 'on');
end;

// A piece of text for a message: on one line, and no longer than Max characters. When it has to be cut, the end is kept
// (from the start of a word), as that is where a program says what is wrong.
function EndOf(const S: String; const Max: Integer): String;
var
  N, Limit: Integer;
begin
  Result := Trim(ReplaceAll(ReplaceAll(S, #13, ' '), #10, ' '));
  if Length(Result) <= Max then Exit;
  N := Length(Result) - Max + 4;
  Limit := N + Max div 3;
  while (N < Limit) and (Result[N - 1] <> ' ') do
    N := N + 1;
  Result := '...' + Copy(Result, N, Length(Result));
end;

// A piece of text for a message, cut to Max characters at the end of a word, with ... where something was left out.
// Used where the beginning says it best.
function StartOf(const S: String; const Max: Integer): String;
var
  N: Integer;
begin
  Result := Trim(ReplaceAll(ReplaceAll(S, #13, ' '), #10, ' '));
  if Length(Result) <= Max then Exit;
  N := Max - 3;
  while (N > Max div 2) and (Result[N + 1] <> ' ') do
    N := N - 1;
  Result := Copy(Result, 1, N) + '...';
end;

// Two pieces of text with one space between them (none when one of them is empty).
function JoinText(const A, B: String): String;
begin
  if A = '' then Result := B
  else if B = '' then Result := A
  else Result := A + ' ' + B;
end;

// The text with a full stop at the end, unless it already ends like a sentence.
function AsSentence(const S: String): String;
var
  C: Char;
begin
  Result := Trim(S);
  if Result = '' then Exit;
  C := Result[Length(Result)];
  if (C <> '.') and (C <> '!') and (C <> '?') then
    Result := Result + '.';
end;

// The text without the full stop at its end, for when it goes inside brackets.
function WithoutStop(const S: String): String;
begin
  Result := Trim(S);
  if (Result <> '') and (Result[Length(Result)] = '.') then
    Delete(Result, Length(Result), 1);
end;

// Remove one trailing backslash, unless the path is just a drive root like C:\
function CutBackslash(const S: String): String;
begin
  Result := Trim(S);
  while (Length(Result) > 3) and (Result[Length(Result)] = '\') do
    Delete(Result, Length(Result), 1);
end;

// Characters that are safe in container, volume and Linux distribution names.
function IsSafeName(const S: String): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := (Length(S) > 0) and (Length(S) <= 63);
  if not Result then Exit;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if not (((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or
            ((C >= '0') and (C <= '9')) or (C = '_') or (C = '.') or (C = '-')) then
    begin
      Result := False;
      Exit;
    end;
  end;
  if (S[1] = '-') or (S[1] = '.') or (S[1] = '_') then Result := False;
end;

function IsTagSafe(const S: String): Boolean;
begin
  // Docker image tags use the same characters as names, but may start with a letter, digit or underscore.
  Result := IsSafeName(S) or ((Length(S) > 0) and (S[1] = '_') and IsSafeName('x' + Copy(S, 2, 999)));
end;

function IsAllDigits(const S: String): Boolean;
var
  I: Integer;
begin
  Result := Length(S) > 0;
  for I := 1 to Length(S) do
    if (S[I] < '0') or (S[I] > '9') then
    begin
      Result := False;
      Exit;
    end;
end;

// Split S at the first occurrence of Sep: Head gets the text before it, Tail the rest.
procedure SplitOnce(const S, Sep: String; var Head, Tail: String);
var
  P: Integer;
begin
  P := Pos(Sep, S);
  if P = 0 then
  begin
    Head := S;
    Tail := '';
  end
  else
  begin
    Head := Copy(S, 1, P - 1);
    Tail := Copy(S, P + Length(Sep), Length(S));
  end;
end;

// A short, stable code for an install folder. Two different folders get two
// different codes, so each one is its own entry in Apps & features.
function InstanceIdForDir(const Dir: String): String;
var
  I: Integer;
  H: Int64;
  S: String;
begin
  S := Lowercase(CutBackslash(Dir));
  if S = '' then
  begin
    // Nothing chosen yet. The AppId only matters for real once the folder is known.
    Result := '';
    Exit;
  end;
  H := 2166136261;                       // FNV-1a, 32 bit
  for I := 1 to Length(S) do
  begin
    H := H xor Ord(S[I]);
    H := (H * 16777619) mod 4294967296;
  end;
  Result := Lowercase(Format('%.8x', [H]));
end;

// ---------------------------------------------------------------------------
// Command line switches, for silent installs:  n8n-Installer.exe /VERYSILENT /METHOD=folder
// ---------------------------------------------------------------------------

// Reads /NAME=value from the command line. A bare /NAME counts as '1'.
function Switch(const Name, Default: String): String;
var
  I: Integer;
  P, Key: String;
begin
  Result := Default;
  Key := '/' + Uppercase(Name);
  for I := 1 to ParamCount do
  begin
    P := ParamStr(I);
    if Uppercase(Copy(P, 1, Length(Key) + 1)) = Key + '=' then
    begin
      Result := Copy(P, Length(Key) + 2, Length(P));
      Exit;
    end;
    if Uppercase(P) = Key then
    begin
      Result := '1';
      Exit;
    end;
  end;
end;

function SwitchGiven(const Name: String): Boolean;
var
  I: Integer;
  P, Key: String;
begin
  Result := False;
  Key := '/' + Uppercase(Name);
  for I := 1 to ParamCount do
  begin
    P := Uppercase(ParamStr(I));
    if (P = Key) or (Copy(P, 1, Length(Key) + 1) = Key + '=') then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

// Simple version compare of dotted numbers: returns -1, 0 or 1.
function CompareDotted(const A, B: String): Integer;
var
  RestA, RestB, HeadA, HeadB: String;
  NA, NB: Integer;
begin
  RestA := A;
  RestB := B;
  Result := 0;
  while (Result = 0) and ((RestA <> '') or (RestB <> '')) do
  begin
    SplitOnce(RestA, '.', HeadA, RestA);
    SplitOnce(RestB, '.', HeadB, RestB);
    NA := StrToIntDef(HeadA, 0);
    NB := StrToIntDef(HeadB, 0);
    if NA < NB then Result := -1
    else if NA > NB then Result := 1;
  end;
end;

var
  GWizardReady: Boolean;     // the wizard exists; before that its controls cannot be asked
  GDryRun: Boolean;          // /DRYRUN: walk through everything, change nothing (for tests)

// ---------------------------------------------------------------------------
// Logging. Every line goes to Setup's own log (the /LOG= switch), to our own
// log file, and to the live log box on the Installing page when it exists.
// ---------------------------------------------------------------------------

function SendMessageW(hWnd: HWND; Msg: UINT; wParam: Longint; lParam: Longint): Longint;
  external 'SendMessageW@user32.dll stdcall';

var
  GLogFile: String;
  GLogMemo: TNewMemo;

function LogDir: String;
begin
  Result := ExpandConstant('{localappdata}\n8n-installer\logs');
end;

procedure OpenLogFile(const Kind: String);
begin
  ForceDirectories(LogDir);
  GLogFile := LogDir + '\' + Kind + '-' + GetDateTimeString('yyyymmdd-hhnnss', '-', ':') + '.log';
end;

procedure FileLog(const S: String);
begin
  Log(S);
  if GLogFile <> '' then
    SaveStringToFile(GLogFile, S + #13#10, True);
end;

procedure ShowInMemo(const S: String);
begin
  if GLogMemo <> nil then
  begin
    GLogMemo.Lines.Add(S);
    SendMessageW(GLogMemo.Handle, $0115, 7, 0);      // scroll to the bottom
  end;
end;

// A line the user should see in the live log box (and in the files).
procedure LogLine(const S: String);
begin
  FileLog(S);
  ShowInMemo(S);
end;

// A problem the user has to fix before going on. It is also written to the log, so a silent install leaves a trace.
// (MsgBox would ignore /SUPPRESSMSGBOXES and leave an unattended install waiting for a click.)
procedure Complain(const Text: String);
begin
  FileLog('! ' + Text);
  SuppressibleMsgBox(Text, mbError, MB_OK, IDOK);
end;

// A yes/no question. A silent run does not ask: it answers with Default, and the log says so.
function AskYesNo(const Text: String; const DefaultYes: Boolean): Boolean;
var
  Default: Integer;
begin
  if DefaultYes then Default := IDYES else Default := IDNO;
  Result := SuppressibleMsgBox(Text, mbConfirmation, MB_YESNO, Default) = IDYES;
  if WizardSilent then
    FileLog('? ' + Text + '  -> ' + B2S(Result));
end;

// ---------------------------------------------------------------------------
// Text files
// ---------------------------------------------------------------------------

// Read a small ASCII text file from the setup package (see [Files], dontcopy).
function LoadTemplate(const Name: String): String;
var
  Raw: AnsiString;
begin
  ExtractTemporaryFile(Name);
  if not LoadStringFromFile(ExpandConstant('{tmp}\' + Name), Raw) then
    RaiseException('Setup file is missing: ' + Name);
  Result := Raw;
  // The templates may have been checked out with either kind of line ending.
  Result := ReplaceAll(Result, #13#10, #10);
  Result := ReplaceAll(Result, #10, #13#10);
end;

procedure SaveAsciiFile(const Path, Text: String);
begin
  if GDryRun then
  begin
    LogLine('(dry run) would write ' + Path);
    Exit;
  end;
  if not SaveStringToFile(Path, Text, False) then
    RaiseException('Could not write ' + Path);
end;

// ---------------------------------------------------------------------------
// The record each install keeps about itself: {app}\n8n-installer.ini
// ---------------------------------------------------------------------------

function StateFile: String;
begin
  Result := ExpandConstant('{app}\n8n-installer.ini');
end;

procedure SaveState(const Key, Value: String);
begin
  SetIniString('install', Key, Value, StateFile);
end;

function LoadState(const Key, Default: String): String;
begin
  Result := GetIniString('install', Key, Default, StateFile);
end;

// ---------------------------------------------------------------------------
// Folders
// ---------------------------------------------------------------------------

// The name of the first thing in the folder that does not come from an install of this installer, or '' when the
// folder is empty or holds only things that come from one. Those are the installer's own files, what n8n makes next
// to its data (.cache) and the data that an uninstall keeps (.n8n).
function FirstOtherFileIn(const Dir: String): String;
var
  Found: TFindRec;
  Name, OwnNames: String;
begin
  Result := '';
  OwnNames := '|.n8n|.cache|node|node_modules|node_modules.old|bin|support|package.json|package-lock.json|.npmrc|' +
    'start-n8n.cmd|stop-n8n.cmd|n8n-env.cmd|readme.txt|n8n.ico|n8n-installer.ini|unins000.exe|unins000.dat|unins000.msg|';
  if FindFirst(Dir + '\*', Found) then
  begin
    try
      repeat
        Name := Lowercase(Found.Name);
        if (Name <> '.') and (Name <> '..') and (Pos('|' + Name + '|', OwnNames) = 0) and
           (Copy(Name, 1, 6) <> 'node-v') then   // Node.js unpacked by an install that was interrupted
        begin
          Result := Found.Name;
          Break;
        end;
      until not FindNext(Found);
    finally
      FindClose(Found);
    end;
  end;
end;

// ---------------------------------------------------------------------------
// The PATH of the current user (Windows keeps it in the registry)
// ---------------------------------------------------------------------------

function UserPathValue: String;
begin
  if not RegQueryStringValue(HKCU, 'Environment', 'Path', Result) then
    Result := '';
end;

procedure AddToUserPath(const Dir: String);
var
  Current: String;
begin
  Current := UserPathValue;
  if Pos(';' + Lowercase(Dir) + ';', ';' + Lowercase(Current) + ';') > 0 then Exit;
  if (Current <> '') and (Current[Length(Current)] <> ';') then
    Current := Current + ';';
  RegWriteExpandStringValue(HKCU, 'Environment', 'Path', Current + Dir);
end;

procedure RemoveFromUserPath(const Dir: String);
var
  Rest, Item, Kept: String;
begin
  Rest := UserPathValue;
  Kept := '';
  while Rest <> '' do
  begin
    SplitOnce(Rest, ';', Item, Rest);
    if (Item <> '') and (CompareText(CutBackslash(Item), CutBackslash(Dir)) <> 0) then
    begin
      if Kept <> '' then Kept := Kept + ';';
      Kept := Kept + Item;
    end;
  end;
  RegWriteExpandStringValue(HKCU, 'Environment', 'Path', Kept);
end;
