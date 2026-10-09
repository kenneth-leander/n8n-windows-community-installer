// ---------------------------------------------------------------------------
// install.iss - the installing itself: shared steps, and the common files
// every install gets (settings record, launcher scripts, readme)
// ---------------------------------------------------------------------------

var
  GN8nVersion: String;        // the n8n version that ended up installed, when known
  GAppDirExisted: Boolean;    // {app} was there before this run, so a failed run must not remove it
  GReplacing: Boolean;        // this run replaces an earlier install of this folder
  GHadPrivateNode: Boolean;   // the folder already held its own Node.js before this run
  GDockerImage: String;       // the image that was really pulled, like docker.n8n.io/n8nio/n8n:2.42.5

// Provided by the WSL module: where the data of a WSL install shows up in Windows, for display.
function WslDataDisplay: String; forward;

function AppDir: String;
begin
  Result := CutBackslash(ExpandConstant('{app}'));
end;

// What the user sees while a step runs.
procedure Step(const Text: String);
begin
  // A blank line between steps, but not above the first one.
  if (GLogMemo <> nil) and (GLogMemo.Lines.Count = 0) then
    FileLog('')
  else
    LogLine('');
  LogLine('== ' + Text);
  WizardForm.StatusLabel.Caption := Text;
  WizardForm.FilenameLabel.Caption := '';
  DryRunPause;
end;

procedure Working(const On: Boolean);
begin
  if On then
    WizardForm.ProgressGauge.Style := npbstMarquee
  else
    WizardForm.ProgressGauge.Style := npbstNormal;
end;

// Shows how far a download or an unpacking has got.
function OnProgress(const Url, FileName: String; const Progress, ProgressMax: Int64): Boolean;
var
  Pct: Integer;
begin
  if ProgressMax > 0 then
  begin
    Pct := Progress * 100 div ProgressMax;
    WizardForm.FilenameLabel.Caption := IntToStr(Pct) + '%   ' + ExtractFileName(FileName);
  end
  else
    WizardForm.FilenameLabel.Caption := IntToStr(Progress div (1024 * 1024)) + ' MB   ' + ExtractFileName(FileName);
  Result := True;
end;

function OnUnpack(const ArchiveName, FileName: String; const Progress, ProgressMax: Int64): Boolean;
begin
  OnProgress(ArchiveName, FileName, Progress, ProgressMax);
  Result := True;
end;

// Downloads a file into the setup's temporary folder and returns where it is.
function Download(const Url, Name, Sha256: String): String;
begin
  FileLog('Downloading ' + Url);
  if GDryRun then
  begin
    LogLine('(dry run) would download ' + Url);
    Result := ExpandConstant('{tmp}\') + Name;
    Exit;
  end;
  DownloadTemporaryFile(Url, Name, Sha256, @OnProgress);
  Result := ExpandConstant('{tmp}\') + Name;
end;

procedure Fail(const Message: String);
begin
  RaiseException(Message);
end;

// ---------------------------------------------------------------------------
// Fill a template: @@NAME@@ markers are replaced, the file is written to Target.
// ---------------------------------------------------------------------------

var
  GKeys, GValues: array of String;

procedure ClearVars;
begin
  SetArrayLength(GKeys, 0);
  SetArrayLength(GValues, 0);
end;

procedure SetVar(const Key, Value: String);
var
  N: Integer;
begin
  N := GetArrayLength(GKeys);
  SetArrayLength(GKeys, N + 1);
  SetArrayLength(GValues, N + 1);
  GKeys[N] := Key;
  GValues[N] := Value;
end;

function Fill(const Text: String): String;
var
  I: Integer;
begin
  Result := Text;
  for I := 0 to GetArrayLength(GKeys) - 1 do
    Result := ReplaceAll(Result, '@@' + GKeys[I] + '@@', GValues[I]);
end;

procedure WriteFromTemplate(const Template, Target: String);
var
  Text: String;
begin
  Text := Fill(LoadTemplate(Template));
  if not GDryRun then
    ForceDirectories(ExtractFilePath(Target));
  SaveAsciiFile(Target, Text);
  if not GDryRun then
    FileLog('Wrote ' + Target);
end;

// The readme is plain text for people, so it can hold any characters: write it as UTF-8.
procedure WriteReadme(const Text: String);
var
  Lines: TArrayOfString;
  Remaining, Line: String;
  N: Integer;
begin
  SetArrayLength(Lines, 0);
  Remaining := ReplaceAll(Text, #13#10, #10);
  while Remaining <> '' do
  begin
    SplitOnce(Remaining, #10, Line, Remaining);
    N := GetArrayLength(Lines);
    SetArrayLength(Lines, N + 1);
    Lines[N] := Line;
  end;
  if GDryRun then
  begin
    LogLine('(dry run) would write the readme');
    Exit;
  end;
  SaveStringsToUTF8File(AppDir + '\README.txt', Lines, False);
end;

// ---------------------------------------------------------------------------
// Values every template can use
// ---------------------------------------------------------------------------

function ListenAddress: String;
begin
  if Cfg.Lan then Result := '0.0.0.0' else Result := '127.0.0.1';
end;

// Where n8n keeps the user's workflows and settings, in words.
function DataLocationText: String;
begin
  if Cfg.Method = MethodDocker then
    Result := 'the Docker volume "' + Cfg.DockerVolume + '"'
  else if Cfg.Method = MethodGlobal then
    Result := GlobalDataDir
  else if Cfg.Method = MethodWsl then
    Result := WslDataDisplay
  else
    Result := AppDir + '\.n8n';
end;

procedure SetCommonVars;
begin
  ClearVars;
  SetVar('PROJECT_URL', '{#AppUrl}');
  SetVar('DATA_DIR', DataLocationText);
  SetVar('DOCKER_NAME', Cfg.DockerName);
  SetVar('DOCKER_VOLUME', Cfg.DockerVolume);
  SetVar('IMAGE', GDockerImage);
  SetVar('TZ', Cfg.DockerTz);
  SetVar('DISTRO', Cfg.WslDistro);
  SetVar('VERSION', '{#AppVersion}');
  SetVar('METHOD', MethodTitle(Cfg.Method));
  SetVar('PORT', IntToStr(Cfg.Port));
  SetVar('BROKER_PORT', IntToStr(Cfg.Port + 1));
  SetVar('URL', LocalUrl(Cfg.Port));
  SetVar('LISTEN', ListenAddress);
  SetVar('APP_DIR', AppDir);
  SetVar('DATE', GetDateTimeString('yyyy-mm-dd hh:nn', '-', ':'));
  SetVar('N8N_VERSION', GN8nVersion);
  if Cfg.Lan then
    SetVar('SECURE_COOKIE', 'rem Other devices open n8n over plain http, so the login cookie cannot be marked secure.' + #13#10 + 'set "N8N_SECURE_COOKIE=false"')
  else
    SetVar('SECURE_COOKIE', 'rem n8n answers on this computer only (see N8N_LISTEN_ADDRESS above).');
end;

// ---------------------------------------------------------------------------
// The readme that sits next to the launcher
// ---------------------------------------------------------------------------

procedure WriteReadmeFile;
var
  MethodText: String;
begin
  SetCommonVars;
  if Cfg.Method = MethodDocker then MethodText := LoadTemplate('readme-docker.txt')
  else if Cfg.Method = MethodWsl then MethodText := LoadTemplate('readme-wsl.txt')
  else MethodText := LoadTemplate('readme-npm.txt');
  SetVar('METHOD_TEXT', Fill(MethodText));
  WriteReadme(Fill(LoadTemplate('README.txt')));
end;
