// ---------------------------------------------------------------------------
// events.iss - what the wizard does at each stage
// ---------------------------------------------------------------------------

var
  GInstallFailed: Boolean;
  GFailureText: String;

// ---------------------------------------------------------------------------
// Command line switches -> the controls
// ---------------------------------------------------------------------------

function CleanMethod(const M: String): String;
begin
  Result := Lowercase(Trim(M));
  if (Result <> MethodDocker) and (Result <> MethodWsl) and (Result <> MethodGlobal) and (Result <> MethodFolder) then
    Result := '';
end;

procedure ApplySwitches;
var
  M: String;
begin
  M := CleanMethod(Switch('METHOD', ''));
  GWantedMethod := M;
  if M <> '' then
  begin
    RbCustom.Checked := True;
    ChooseMethod(M);
  end;
  if SwitchGiven('PORT') then EdPort.Text := Switch('PORT', IntToStr(DefaultPort));
  if SwitchGiven('LAN') then CbLan.Checked := S2B(Switch('LAN', '0'));
  if SwitchGiven('DOCKERNAME') then EdDockerName.Text := Switch('DOCKERNAME', 'n8n');
  if SwitchGiven('DOCKERVOLUME') then EdDockerVolume.Text := Switch('DOCKERVOLUME', 'n8n_data');
  if SwitchGiven('DOCKERTAG') then EdDockerTag.Text := Switch('DOCKERTAG', '');
  if Switch('DOCKERVERSION', '2') = '3' then CbxDockerVersion.ItemIndex := ChannelNewest3;
  if SwitchGiven('TZ') then EdDockerTz.Text := Switch('TZ', 'UTC');
  GWantDistro := Switch('WSLDISTRO', '');
  // Silent installs do not put icons on the desktop unless asked.
  if WizardSilent then CbDesktop.Checked := S2B(Switch('DESKTOP', '0'))
  else if SwitchGiven('DESKTOP') then CbDesktop.Checked := S2B(Switch('DESKTOP', '1'));
  if SwitchGiven('ADDPATH') then CbPath.Checked := S2B(Switch('ADDPATH', '1'));
end;

// ---------------------------------------------------------------------------
// The live log on the Installing page
// ---------------------------------------------------------------------------

procedure BuildLogMemo;
var
  Page: TNewNotebookPage;
  Top: Integer;
begin
  Page := WizardForm.InstallingPage;
  GLogMemo := TNewMemo.Create(WizardForm);
  GLogMemo.Parent := Page;
  Top := WizardForm.ProgressGauge.Top + WizardForm.ProgressGauge.Height + ScaleY(12);
  GLogMemo.Left := 0;
  GLogMemo.Top := Top;
  GLogMemo.Width := Page.ClientWidth;
  GLogMemo.Height := Page.ClientHeight - Top;
  GLogMemo.Anchors := [akLeft, akTop, akRight, akBottom];
  GLogMemo.ReadOnly := True;
  GLogMemo.ScrollBars := ssVertical;
  GLogMemo.WordWrap := True;
  GLogMemo.Font.Name := 'Consolas';
  GLogMemo.Font.Size := 8;
end;

// ---------------------------------------------------------------------------
// Checks before moving on
// ---------------------------------------------------------------------------

// Can n8n live in the folder that is typed in the folder box?
function CheckInstallFolder: Boolean;
var
  Dir, Method: String;
begin
  Result := True;
  Dir := CutBackslash(WizardDirValue);
  if (Length(Dir) < 3) or (Dir[2] <> ':') or (Dir[3] <> '\') then
  begin
    Complain('Please choose a folder on one of your drives, for example C:\n8n.');
    Result := False;
    Exit;
  end;

  if FileExists(Dir + '\n8n-installer.ini') then
  begin
    Method := GetIniString('install', 'method', '', Dir + '\n8n-installer.ini');
    if (Method <> '') and (Method <> ChosenMethod) then
      Result := AskYesNo('This folder already holds an n8n installed the "' + MethodTitle(Method) + '" way.' + #13#10#13#10 +
        'Installing here will replace it. Your workflows and settings are kept. Continue?', False);
  end
  else if DirExists(Dir) and (ChosenMethod = MethodFolder) and not FileExists(Dir + '\node_modules\n8n\package.json') then
  begin
    // Something else lives here. n8n would add its own files next to them. (The data that an uninstall keeps does
    // not count: installing again into that folder picks it up.)
    if not DirHasOnlyN8nFiles(Dir) then
      Result := AskYesNo('This folder already has other files in it.' + #13#10#13#10 +
        'n8n will add its own files (node, node_modules, package.json and a few more) next to them. ' +
        'An empty folder is better. Use this folder anyway?', False);
  end;
end;

// The last look before anything is changed.
function CheckBeforeInstall: Boolean;
var
  Problem: String;
  Need, Have: Integer;
begin
  Result := True;
  Problem := ProblemWithConfig;
  if Problem <> '' then
  begin
    Complain(Problem);
    Result := False;
    Exit;
  end;

  if Cfg.Method = MethodDocker then
  begin
    if ContainerExists(Cfg.DockerName) and not FileExists(CutBackslash(WizardDirValue) + '\n8n-installer.ini') then
      Result := AskYesNo('A Docker container named "' + Cfg.DockerName + '" already exists.' + #13#10#13#10 +
        'Continuing replaces it with a new one. Its data volume is not deleted. Replace it?', False);
    if not Result then Exit;
    Need := 3000;
  end
  else
    Need := 2000;

  Have := FreeSpaceMB(WizardDirValue);
  if (Have >= 0) and (Have < Need) then
    Result := AskYesNo('There are only ' + IntToStr(Have) + ' MB free on this drive, and n8n needs about ' + IntToStr(Need) +
      ' MB while it installs.' + #13#10#13#10 + 'Continue anyway?', False);
end;

// ---------------------------------------------------------------------------
// The summary on the "Ready to Install" page
// ---------------------------------------------------------------------------

function UpdateReadyMemo(Space, NewLine, MemoUserInfoInfo, MemoDirInfo, MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: String): String;
var
  T, Shortcuts, Reach: String;
begin
  CollectConfig;
  T := 'How n8n runs:' + NewLine + Space + MethodTitle(Cfg.Method) + NewLine + NewLine;

  if Cfg.Lan then Reach := ' (other devices on your network can connect too)'
  else Reach := ' (only on this computer)';
  T := T + 'You will open n8n at:' + NewLine + Space + LocalUrl(Cfg.Port) + Reach + NewLine + NewLine;

  if Cfg.Method = MethodDocker then
  begin
    T := T + 'Docker container: ' + Cfg.DockerName + NewLine;
    if Cfg.DockerChannel = ChannelCustom then
      T := T + 'Version: ' + Cfg.DockerCustomTag + NewLine
    else if Cfg.DockerChannel = ChannelNewest3 then
      T := T + 'Version: the n8n 3 preview' + NewLine
    else
      T := T + 'Version: the newest stable n8n 2.x' + NewLine;
    T := T + 'Time zone: ' + Cfg.DockerTz + NewLine + NewLine;
  end
  else if Cfg.Method = MethodWsl then
    T := T + 'Linux distribution: ' + Cfg.WslDistro + NewLine + NewLine
  else if Cfg.Method = MethodFolder then
    T := T + 'Node.js ' + PrivateNodeLine + ' is downloaded into the folder, so you need nothing else installed.' + NewLine + NewLine;

  T := T + 'Install folder (start script, notes and uninstaller):' + NewLine + Space + CutBackslash(WizardDirValue) + NewLine + NewLine;
  if FileExists(CutBackslash(WizardDirValue) + '\n8n-installer.ini') then
  begin
    T := T + 'This folder already has an n8n install. It is updated, and your workflows and settings are kept.';
    if Cfg.Method = MethodFolder then
      T := T + ' If n8n is running from it, it is closed first.';
    T := T + NewLine + NewLine;
  end;
  T := T + 'Your workflows and settings are kept in:' + NewLine + Space + DataLocationText + NewLine + NewLine;

  Shortcuts := 'Start menu';
  if Cfg.Desktop then Shortcuts := Shortcuts + ', desktop';
  T := T + 'Shortcuts: ' + Shortcuts + NewLine;
  if Cfg.AddToPath then
    T := T + 'The n8n command is added to your PATH.' + NewLine;
  Result := T;
end;

// ---------------------------------------------------------------------------
// The installing itself
// ---------------------------------------------------------------------------

procedure WriteInstallRecord;
begin
  // A dry run never rewrites the record of a real install. A fresh folder gets one, so the uninstaller can be tried too.
  if GDryRun and GReplacing then Exit;
  ForceDirectories(AppDir);
  SaveState('method', Cfg.Method);
  SaveState('installer_version', '{#AppVersion}');
  SaveState('port', IntToStr(Cfg.Port));
  SaveState('lan', B2S(Cfg.Lan));
  SaveState('n8n_version', GN8nVersion);
  SaveState('path_added', B2S(Cfg.AddToPath and not GDryRun));
  if Cfg.Method = MethodDocker then
  begin
    SaveState('docker_name', Cfg.DockerName);
    SaveState('docker_volume', Cfg.DockerVolume);
    SaveState('docker_image', GDockerImage);
  end;
  if Cfg.Method = MethodWsl then
    SaveWslState;
end;

procedure RunInstall;
begin
  GAppDirExisted := DirExists(AppDir);
  GReplacing := FileExists(AppDir + '\n8n-installer.ini');
  if not GDryRun then ForceDirectories(AppDir);
  FileLog('Folder: ' + AppDir);
  FileLog('Method: ' + Cfg.Method + '   Port: ' + IntToStr(Cfg.Port) + '   All devices: ' + B2S(Cfg.Lan));

  if Cfg.Method = MethodDocker then InstallDocker
  else if Cfg.Method = MethodWsl then InstallWsl
  else if Cfg.Method = MethodGlobal then InstallGlobal
  else InstallFolder;

  Step('Writing the notes about this install');
  WriteReadmeFile;
  WriteInstallRecord;
  LogLine('');
  LogLine('Done.');
end;

// Take back what a failed first install left behind. A folder that held an install before is left alone.
procedure CleanUpAfterFailure;
begin
  if GDryRun or GAppDirExisted then Exit;
  if DirExists(AppDir) then
    DelTree(AppDir, True, True, True);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep <> ssInstall then Exit;
  CollectConfig;
  GBusy := True;
  try
    RunInstall;
  except
    GFailureText := GetExceptionMessage;
    GInstallFailed := True;
  end;
  GBusy := False;
  Working(False);
  if GInstallFailed then
  begin
    LogLine('');
    LogLine('FAILED: ' + GFailureText);
    CleanUpAfterFailure;
    SuppressibleMsgBox('n8n could not be installed.' + #13#10#13#10 + GFailureText + #13#10#13#10 +
      'A log of what happened is saved here:' + #13#10 + GLogFile, mbError, MB_OK, IDOK);
    Abort;
  end;
end;

procedure CancelButtonClick(CurPageID: Integer; var Cancel, Confirm: Boolean);
begin
  if GBusy then
  begin
    Cancel := False;
    SuppressibleMsgBox('n8n is being installed. Please wait until this step is finished.', mbInformation, MB_OK, IDOK);
  end;
end;

// ---------------------------------------------------------------------------
// Entry points
// ---------------------------------------------------------------------------

function InitializeSetup: Boolean;
begin
  Result := True;
end;

// The uninstaller understands the test mode too: with /DRYRUN it says which programs it would start and starts none.
function InitializeUninstall: Boolean;
begin
  GDryRun := SwitchGiven('DRYRUN');
  Result := True;
end;

// A silent install shows no pages and cannot wait for answers. Every check the pages make is made here instead,
// before anything is changed, so a problem ends Setup right away with an error code.
procedure SilentPreflight;
begin
  if not WizardSilent then Exit;
  if not ModePageNext(nil) then Abort;        // finds out what this computer has, applies the Express rules
  UpdateSuggestedDir;
  if not CheckInstallFolder then Abort;
  if not NetPageNext(nil) then Abort;
  if Cfg.Method = MethodDocker then
    if not DockerPageNext(nil) then Abort;
  if Cfg.Method = MethodWsl then
    if not WslPageNext(nil) then Abort;
  if not CheckBeforeInstall then Abort;
end;

procedure InitializeWizard;
begin
  GWizardReady := True;
  GDryRun := SwitchGiven('DRYRUN');
  GDirFromSwitch := SwitchGiven('DIR');
  OpenLogFile('install');
  FileLog('n8n Windows Community Installer {#AppVersion}');
  FileLog('Command line: ' + GetCmdTail);
  BuildPages;
  BuildLogMemo;
  GAutoDir := WizardForm.DirEdit.Text;
  ApplySwitches;
  UpdateSuggestedDir;
  SilentPreflight;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := SkipThisPage(PageID);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpSelectDir then Result := CheckInstallFolder
  else if CurPageID = wpReady then Result := CheckBeforeInstall;
  if not Result then FileLog('Not going on from page ' + IntToStr(CurPageID) + '.');
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = wpSelectDir then
  begin
    WizardForm.SelectDirLabel.Caption := 'n8n will be installed into the following folder.';
    WizardForm.DiskSpaceLabel.Visible := False;
    if ChosenMethod = MethodFolder then
      WizardForm.SelectDirBrowseLabel.Caption := 'n8n and everything it needs go in this folder, and your workflows and settings are kept inside it. Click Next to continue, or Browse to pick another folder.'
    else
      WizardForm.SelectDirBrowseLabel.Caption := 'The Start n8n shortcut, notes and uninstaller go in this folder. Click Next to continue, or Browse to pick another folder.';
  end;
end;

function GetInstanceId(Param: String): String;
begin
  // Called very early too, before there is a wizard to ask. An empty answer is allowed then.
  if GWizardReady then
    Result := InstanceIdForDir(WizardDirValue)
  else
    Result := '';
end;

function GetGroupName(Param: String): String;
begin
  Result := ExtractFileName(CutBackslash(WizardDirValue));
  if Result = '' then Result := 'n8n';
end;

// The name in Windows Settings, Apps. Method, port and folder tell several installs apart.
function GetUninstallDisplayName(Param: String): String;
begin
  Result := 'n8n (' + MethodTitle(Cfg.Method) + ', port ' + IntToStr(Cfg.Port) + ', folder ' + GetGroupName('') + ')';
end;

function WantDesktop: Boolean;
begin
  Result := Cfg.Desktop;
end;

// Docker and Linux (WSL2) keep n8n running outside the window that started it, so they get a Stop n8n shortcut.
function HasStopScript: Boolean;
begin
  Result := (Cfg.Method = MethodDocker) or (Cfg.Method = MethodWsl);
end;

function OpenAddress(Param: String): String;
begin
  Result := LocalUrl(Cfg.Port);
end;
