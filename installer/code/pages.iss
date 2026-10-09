// ---------------------------------------------------------------------------
// pages.iss - the screens of the installer
//
//   Welcome -> Express or Custom -> [how n8n runs -> folder -> network ->
//   Docker or Linux settings -> shortcuts] -> summary -> installing -> finish
//
// Express skips everything in the brackets: the controls on those pages are
// filled with the usual settings instead, so there is one code path for both.
// ---------------------------------------------------------------------------

var
  PageMode, PageMethod, PageNet, PageDocker, PageWsl, PageOptions: TWizardPage;

  // Express or Custom
  RbExpress, RbCustom: TNewRadioButton;
  LblExpressInfo, LblCustomInfo, LblChecking: TNewStaticText;

  // how n8n runs
  RbDocker, RbFolder, RbGlobal, RbWsl: TNewRadioButton;
  LblDockerInfo, LblFolderInfo, LblGlobalInfo, LblWslInfo: TNewStaticText;
  BtnRecheck: TNewButton;

  // network
  EdPort: TNewEdit;
  CbLan: TNewCheckBox;
  LblPortStatus, LblLanNote: TNewStaticText;

  // Docker
  CbxDockerVersion: TNewComboBox;
  EdDockerTag, EdDockerName, EdDockerVolume, EdDockerTz: TNewEdit;

  // WSL
  CbxWslDistro: TNewComboBox;
  LblWslNote: TNewStaticText;

  // shortcuts and options
  CbDesktop, CbPath: TNewCheckBox;

  GAutoDir: String;          // the folder we suggested last; if the box still holds it, the user has not chosen
  GDirFromSwitch: Boolean;   // /DIR= was given, never suggest another folder
  GWantDistro: String;       // /WSLDISTRO= from the command line
  GWantedMethod: String;     // /METHOD= from the command line

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

function NewText(const Page: TWizardPage; const Text: String; const Indent: Integer; const Top: Integer; const Bold: Boolean): TNewStaticText;
begin
  Result := TNewStaticText.Create(Page);
  Result.Parent := Page.Surface;
  Result.AutoSize := False;
  Result.WordWrap := True;
  Result.Left := ScaleX(Indent);
  Result.Top := Top;
  Result.Width := Page.SurfaceWidth - Result.Left;
  Result.Caption := Text;
  if Bold then
    Result.Font.Style := [fsBold];
  Result.AdjustHeight;
end;

procedure SetText(const L: TNewStaticText; const Text: String);
begin
  L.Caption := Text;
  L.AdjustHeight;
end;

function NewRadio(const Page: TWizardPage; const Caption: String; const Top: Integer): TNewRadioButton;
begin
  Result := TNewRadioButton.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := 0;
  Result.Top := Top;
  Result.Width := Page.SurfaceWidth;
  Result.Caption := Caption;
end;

function NewCheck(const Page: TWizardPage; const Caption: String; const Top: Integer; const Checked: Boolean): TNewCheckBox;
begin
  Result := TNewCheckBox.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := 0;
  Result.Top := Top;
  Result.Width := Page.SurfaceWidth;
  Result.Caption := Caption;
  Result.Checked := Checked;
end;

function NewEdit(const Page: TWizardPage; const Text: String; const Left, Top, Width: Integer): TNewEdit;
begin
  Result := TNewEdit.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := ScaleX(Left);
  Result.Top := Top;
  Result.Width := ScaleX(Width);
  Result.Text := Text;
end;

function NewCombo(const Page: TWizardPage; const Left, Top, Width: Integer): TNewComboBox;
begin
  Result := TNewComboBox.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := ScaleX(Left);
  Result.Top := Top;
  Result.Width := ScaleX(Width);
  Result.Style := csDropDownList;
end;

function Below(const Control: TControl; const Gap: Integer): Integer;
begin
  Result := Control.Top + Control.Height + ScaleY(Gap);
end;

// ---------------------------------------------------------------------------
// Where we are in the wizard
// ---------------------------------------------------------------------------

function IsExpress: Boolean;
begin
  Result := RbExpress.Checked;
end;

function ChosenMethod: String;
begin
  if RbDocker.Checked then Result := MethodDocker
  else if RbGlobal.Checked then Result := MethodGlobal
  else if RbWsl.Checked then Result := MethodWsl
  else Result := MethodFolder;
end;

procedure ChooseMethod(const Method: String);
begin
  RbDocker.Checked := Method = MethodDocker;
  RbFolder.Checked := Method = MethodFolder;
  RbGlobal.Checked := Method = MethodGlobal;
  RbWsl.Checked := Method = MethodWsl;
end;

// The folder suggested for a method: %LOCALAPPDATA%\Programs\n8n, \n8n-docker, ...
function SuggestedDir(const Method: String): String;
begin
  Result := ExpandConstant('{autopf}\') + DefaultFolderName(Method);
end;

// Keep the folder box in step with the chosen method, until the user has typed their own folder.
procedure UpdateSuggestedDir;
var
  Shown: String;
begin
  if GDirFromSwitch then Exit;
  Shown := WizardForm.DirEdit.Text;
  if (Shown = '') or (Shown = GAutoDir) then
  begin
    GAutoDir := SuggestedDir(ChosenMethod);
    WizardForm.DirEdit.Text := GAutoDir;
  end;
end;

// ---------------------------------------------------------------------------
// Settings -> Cfg
// ---------------------------------------------------------------------------

procedure CollectConfig;
begin
  Cfg.Method := ChosenMethod;
  Cfg.Port := StrToIntDef(Trim(EdPort.Text), 0);
  Cfg.Lan := CbLan.Checked;
  Cfg.DockerName := Trim(EdDockerName.Text);
  Cfg.DockerVolume := Trim(EdDockerVolume.Text);
  Cfg.DockerChannel := CbxDockerVersion.ItemIndex;
  if Trim(EdDockerTag.Text) <> '' then
    Cfg.DockerChannel := ChannelCustom;
  Cfg.DockerCustomTag := Trim(EdDockerTag.Text);
  Cfg.DockerTz := Trim(EdDockerTz.Text);
  if (CbxWslDistro.ItemIndex >= 0) and (CbxWslDistro.ItemIndex < GWslCount) then
    Cfg.WslDistro := GWslName[CbxWslDistro.ItemIndex]
  else
    Cfg.WslDistro := '';
  Cfg.AddToPath := CbPath.Checked and (Cfg.Method = MethodFolder);
  Cfg.Desktop := CbDesktop.Checked;
end;

// Returns an empty string when the settings are fine, otherwise a sentence saying what to fix.
function ProblemWithConfig: String;
begin
  Result := '';
  CollectConfig;
  if (Cfg.Port < 1024) or (Cfg.Port > 65534) then
    Result := 'Please enter a port number between 1024 and 65534. The usual choice is 5678.'
  else if (Cfg.Method = MethodDocker) and not IsSafeName(Cfg.DockerName) then
    Result := 'The container name may only use letters, numbers, dots, dashes and underscores, and must start with a letter or number.'
  else if (Cfg.Method = MethodDocker) and not IsSafeName(Cfg.DockerVolume) then
    Result := 'The data volume name may only use letters, numbers, dots, dashes and underscores, and must start with a letter or number.'
  else if (Cfg.Method = MethodDocker) and (Cfg.DockerChannel = ChannelCustom) and not IsTagSafe(Cfg.DockerCustomTag) then
    Result := 'That is not a valid Docker image tag. Leave the box empty to use the version chosen above.'
  else if (Cfg.Method = MethodDocker) and (Cfg.DockerTz = '') then
    Result := 'Please enter a time zone, for example Europe/London. UTC is fine if you are not sure.'
  else if (Cfg.Method = MethodWsl) and (Cfg.WslDistro = '') then
    Result := 'Please choose a Linux distribution.'
  else if (Cfg.Method = MethodWsl) and (GWantDistro <> '') and (CompareText(Cfg.WslDistro, GWantDistro) <> 0) then
    Result := 'The Linux distribution "' + GWantDistro + '" was not found in WSL.';
end;

// ---------------------------------------------------------------------------
// Text on the pages that depends on what was found on this computer
// ---------------------------------------------------------------------------

function DockerStatusText: String;
begin
  if GDockerState = 'ready' then
    Result := 'Docker is running on this computer.'
  else if GDockerState = 'windows' then
    Result := 'Docker is running, but it is set to Windows containers. Switch it to Linux containers in the Docker Desktop menu, then press Check again.'
  else if GDockerState = 'stopped' then
    Result := 'Docker Desktop is installed but not running. Start it, wait until it says it is running, then press Check again.'
  else
    Result := 'Docker Desktop was not found on this computer. Install it from docker.com, start it, then press Check again.';
end;

// What was found about Node.js, in words.
function GlobalNote: String;
begin
  if GNodeOk then
    Result := 'Node.js ' + GNodeVersion + ' was found on this computer.'
  else if GNodeVersion <> '' then
    Result := 'Your Node.js (' + GNodeVersion + ') is not one that n8n 2.x is tested with here. Use the folder option instead, which brings its own.'
  else
    Result := 'Node.js was not found. Use the folder option instead, which brings its own.';
end;

function WslNote: String;
begin
  if GWslCount > 0 then
    Result := IntToStr(GWslCount) + ' Linux distribution(s) found.'
  else
    Result := 'No Linux distribution is set up in WSL on this computer. Install one first, for example with the command  wsl --install -d Ubuntu  in a terminal.';
end;

function ExpressMethod: String;
begin
  if DockerReady then Result := MethodDocker else Result := MethodFolder;
end;

procedure RefreshModeText;
begin
  if not GDetected then Exit;
  LblChecking.Visible := False;
  if ExpressMethod = MethodDocker then
    SetText(LblExpressInfo, 'Docker is running on this computer, so n8n will run in Docker. The only thing you may need to do is wait a few minutes while it downloads.')
  else
    SetText(LblExpressInfo, 'n8n is installed in its own folder on Windows. You do not have to install anything else first. It takes a few minutes while it downloads.');
  LblCustomInfo.Top := Below(LblExpressInfo, 18) + ScaleY(24);
  RbCustom.Top := LblCustomInfo.Top - ScaleY(22);
end;

procedure RefreshMethodText;
begin
  if not GDetected then Exit;

  RbDocker.Enabled := DockerReady;
  SetText(LblDockerInfo, 'n8n runs in a Docker container: clean, easy to back up, and the only way that will keep working with n8n 3.0. ' +
    DockerStatusText);

  RbFolder.Enabled := True;
  SetText(LblFolderInfo, 'n8n and everything it needs are placed in one folder, so nothing else on the computer is touched. ' +
    'Nothing has to be installed first. Stays on n8n 2.x.');

  RbGlobal.Enabled := GNodeOk;
  SetText(LblGlobalInfo, 'Adds n8n to the Node.js that is already installed, so the n8n command works in every terminal. Needs Node.js 22. Stays on n8n 2.x. ' +
    GlobalNote);

  RbWsl.Enabled := GWslCount > 0;
  SetText(LblWslInfo, 'Installs n8n inside a Linux distribution you already have in WSL2, with Linux file speed. Stays on n8n 2.x. ' + WslNote);

  // Lay the descriptions out again, as their heights have changed.
  LblDockerInfo.Top := Below(RbDocker, 1);
  RbFolder.Top := Below(LblDockerInfo, 8);
  LblFolderInfo.Top := Below(RbFolder, 1);
  RbGlobal.Top := Below(LblFolderInfo, 8);
  LblGlobalInfo.Top := Below(RbGlobal, 1);
  RbWsl.Top := Below(LblGlobalInfo, 8);
  LblWslInfo.Top := Below(RbWsl, 1);

  // Move the choice off an option that cannot be used.
  if (ChosenMethod = MethodDocker) and not DockerReady then ChooseMethod(MethodFolder);
  if (ChosenMethod = MethodGlobal) and not GNodeOk then ChooseMethod(MethodFolder);
  if (ChosenMethod = MethodWsl) and (GWslCount = 0) then ChooseMethod(MethodFolder);
end;

procedure WslChanged(Sender: TObject);
var
  I: Integer;
begin
  I := CbxWslDistro.ItemIndex;
  if (I >= 0) and (I < GWslCount) and (GWslVersion[I] = '1') then
    SetText(LblWslNote, 'This distribution runs on WSL 1, which is slow and often fails with n8n. You can convert it with the command  wsl --set-version ' +
      GWslName[I] + ' 2  and then press Back and Next, or pick another one.')
  else
    SetText(LblWslNote, 'n8n is installed inside this distribution, and Node.js is added to it if it has none. ' +
      'Your workflows are kept in that distribution, in the home folder of its default user.');
end;

procedure RefreshWslList;
var
  I: Integer;
  Keep: String;
begin
  Keep := '';
  if CbxWslDistro.ItemIndex >= 0 then Keep := CbxWslDistro.Items[CbxWslDistro.ItemIndex];
  CbxWslDistro.Items.Clear;
  for I := 0 to GWslCount - 1 do
    CbxWslDistro.Items.Add(GWslName[I] + '  (WSL ' + GWslVersion[I] + ', ' + GWslState[I] + ')');
  if CbxWslDistro.Items.Count > 0 then
    CbxWslDistro.ItemIndex := 0;
  for I := 0 to GWslCount - 1 do
    if (GWantDistro <> '') and (CompareText(GWslName[I], GWantDistro) = 0) then
      CbxWslDistro.ItemIndex := I;
  WslChanged(nil);
end;

procedure RefreshPortStatus;
var
  P: Integer;
begin
  P := StrToIntDef(Trim(EdPort.Text), 0);
  if (P < 1024) or (P > 65534) then
    SetText(LblPortStatus, 'Enter a number between 1024 and 65534.')
  else if PortInUse(P) then
    SetText(LblPortStatus, 'Another program is already using port ' + IntToStr(P) + '. Choose a different number.')
  else
    SetText(LblPortStatus, 'n8n will open at ' + LocalUrl(P) + '   (port ' + IntToStr(P) + ' is free).');
end;

procedure PortChanged(Sender: TObject);
begin
  RefreshPortStatus;
end;

// Looks at the computer again and updates every text that depends on what was found.
procedure RunDetection;
begin
  WizardForm.Cursor := crHourGlass;
  try
    DetectEverything;
    RefreshModeText;
    RefreshMethodText;
    RefreshWslList;
  finally
    WizardForm.Cursor := crDefault;
  end;
end;

// Detection runs once, the first time anything needs the answers. Silent installs get there
// through the Next button of the first page, as they never show the page itself.
procedure EnsureDetected;
begin
  if GDetected then Exit;
  if not WizardSilent then
  begin
    LblChecking.Caption := 'Checking this computer, one moment...';
    WizardForm.Refresh;
  end;
  RunDetection;
  // Custom starts on the option that Express would pick, unless a method was asked for.
  if GWantedMethod = '' then
    ChooseMethod(ExpressMethod);
end;

procedure RecheckClick(Sender: TObject);
begin
  RunDetection;
end;

// ---------------------------------------------------------------------------
// Page: Express or Custom
// ---------------------------------------------------------------------------

procedure BuildModePage;
var
  Top: Integer;
begin
  PageMode := CreateCustomPage(wpWelcome, 'How do you want to install n8n?',
    'Express is right for almost everyone. You can still change things on the last screen.');
  Top := 0;
  RbExpress := NewRadio(PageMode, 'Express install (recommended)', Top);
  RbExpress.Checked := True;
  LblExpressInfo := NewText(PageMode, 'Checking this computer...', 22, Below(RbExpress, 1), False);
  RbCustom := NewRadio(PageMode, 'Custom install', Below(LblExpressInfo, 24));
  LblCustomInfo := NewText(PageMode, 'You choose how n8n runs (Docker, Windows or Linux), the folder, the port, and the other settings.', 22, Below(RbCustom, 1), False);
  LblChecking := NewText(PageMode, '', 0, Below(LblCustomInfo, 24), False);
end;

// ---------------------------------------------------------------------------
// Page: how n8n runs
// ---------------------------------------------------------------------------

procedure MethodClick(Sender: TObject);
begin
  UpdateSuggestedDir;
end;

procedure BuildMethodPage;
begin
  PageMethod := CreateCustomPage(PageMode.ID, 'How should n8n run?',
    'These are four ways of running the same n8n. If you are not sure, keep the suggestion.');

  RbDocker := NewRadio(PageMethod, 'Docker', 0);
  LblDockerInfo := NewText(PageMethod, '', 22, Below(RbDocker, 1), False);
  RbFolder := NewRadio(PageMethod, 'Windows, in a folder of its own', Below(LblDockerInfo, 8));
  RbFolder.Checked := True;
  LblFolderInfo := NewText(PageMethod, '', 22, Below(RbFolder, 1), False);
  RbGlobal := NewRadio(PageMethod, 'Windows, for this user account', Below(LblFolderInfo, 8));
  LblGlobalInfo := NewText(PageMethod, '', 22, Below(RbGlobal, 1), False);
  RbWsl := NewRadio(PageMethod, 'Linux inside Windows (WSL2)', Below(LblGlobalInfo, 8));
  LblWslInfo := NewText(PageMethod, '', 22, Below(RbWsl, 1), False);

  RbDocker.OnClick := @MethodClick;
  RbFolder.OnClick := @MethodClick;
  RbGlobal.OnClick := @MethodClick;
  RbWsl.OnClick := @MethodClick;

  BtnRecheck := TNewButton.Create(PageMethod);
  BtnRecheck.Parent := PageMethod.Surface;
  BtnRecheck.Caption := 'Check again';
  BtnRecheck.Width := ScaleX(100);
  BtnRecheck.Height := ScaleY(23);
  BtnRecheck.Left := PageMethod.SurfaceWidth - BtnRecheck.Width;
  BtnRecheck.Top := PageMethod.SurfaceHeight - BtnRecheck.Height;
  BtnRecheck.OnClick := @RecheckClick;
end;

// ---------------------------------------------------------------------------
// Page: network
// ---------------------------------------------------------------------------

procedure BuildNetPage;
var
  L: TNewStaticText;
begin
  PageNet := CreateCustomPage(wpSelectDir, 'Where should n8n answer?',
    'n8n is used in your web browser. This is the address it uses.');

  L := NewText(PageNet, 'Port number', 0, 0, True);
  EdPort := NewEdit(PageNet, IntToStr(DefaultPort), 0, Below(L, 4), 80);
  EdPort.OnChange := @PortChanged;
  LblPortStatus := NewText(PageNet, '', 0, Below(EdPort, 6), False);

  CbLan := NewCheck(PageNet, 'Let other devices on my network open n8n', Below(LblPortStatus, 28), False);
  LblLanNote := NewText(PageNet,
    'Leave this off if you are the only one who uses n8n on this computer. ' +
    'When it is on, anyone on your network can reach n8n, and Windows may ask you to allow it through the firewall.',
    22, Below(CbLan, 2), False);
end;

// ---------------------------------------------------------------------------
// Page: Docker settings
// ---------------------------------------------------------------------------

procedure BuildDockerPage;
var
  L: TNewStaticText;
  Top: Integer;
begin
  PageDocker := CreateCustomPage(PageNet.ID, 'Docker settings',
    'The usual values are filled in. Change them only if you have a reason to.');

  L := NewText(PageDocker, 'Which n8n version?', 0, 0, True);
  CbxDockerVersion := NewCombo(PageDocker, 0, Below(L, 4), 330);
  CbxDockerVersion.Items.Add('The newest stable n8n 2.x (recommended)');
  CbxDockerVersion.Items.Add('The n8n 3 preview (for trying it out, not for real work)');
  CbxDockerVersion.ItemIndex := ChannelStable2;
  Top := Below(CbxDockerVersion, 6);

  L := NewText(PageDocker, 'Or type an exact version (optional), for example 2.42.5', 0, Top, False);
  EdDockerTag := NewEdit(PageDocker, '', 0, Below(L, 4), 160);
  Top := Below(EdDockerTag, 14);

  L := NewText(PageDocker, 'Container name', 0, Top, True);
  EdDockerName := NewEdit(PageDocker, 'n8n', 0, Below(L, 4), 200);
  Top := Below(EdDockerName, 12);

  L := NewText(PageDocker, 'Data volume name (your workflows and passwords are kept here)', 0, Top, True);
  EdDockerVolume := NewEdit(PageDocker, 'n8n_data', 0, Below(L, 4), 200);
  Top := Below(EdDockerVolume, 12);

  L := NewText(PageDocker, 'Time zone (used by scheduled workflows)', 0, Top, True);
  EdDockerTz := NewEdit(PageDocker, IanaTimeZone, 0, Below(L, 4), 200);
end;

// ---------------------------------------------------------------------------
// Page: Linux (WSL2) settings
// ---------------------------------------------------------------------------

procedure BuildWslPage;
var
  L: TNewStaticText;
begin
  PageWsl := CreateCustomPage(PageDocker.ID, 'Linux (WSL2) settings',
    'Choose the Linux distribution that should run n8n.');
  L := NewText(PageWsl, 'Linux distribution', 0, 0, True);
  CbxWslDistro := NewCombo(PageWsl, 0, Below(L, 4), 330);
  CbxWslDistro.OnChange := @WslChanged;
  LblWslNote := NewText(PageWsl, '', 0, Below(CbxWslDistro, 10), False);
end;

// ---------------------------------------------------------------------------
// Page: shortcuts and options
// ---------------------------------------------------------------------------

procedure BuildOptionsPage;
begin
  PageOptions := CreateCustomPage(PageWsl.ID, 'Shortcuts and options', 'A Start menu entry is always created.');
  CbDesktop := NewCheck(PageOptions, 'Put a Start n8n shortcut on my desktop', 0, True);
  // Off unless asked for: it changes the PATH of the user account, which most people never need.
  CbPath := NewCheck(PageOptions, 'Let me type n8n in any terminal window (adds this n8n to my PATH)', Below(CbDesktop, 8), False);
end;

// ---------------------------------------------------------------------------
// Page behaviour
// ---------------------------------------------------------------------------

procedure ModePageActivate(Sender: TWizardPage);
begin
  EnsureDetected;
end;

// Why a method asked for on the command line cannot be used, or '' when it can.
function RequestedMethodProblem: String;
begin
  Result := '';
  if (GWantedMethod = '') or (ChosenMethod = GWantedMethod) then Exit;
  if GWantedMethod = MethodDocker then Result := DockerStatusText
  else if GWantedMethod = MethodGlobal then Result := GlobalNote
  else if GWantedMethod = MethodWsl then Result := WslNote;
end;

// Express on a folder that already holds an install of the same kind is an update: it keeps that install's port,
// network choice and Docker names, so the update lands on the same container, data volume and address.
procedure ApplyExistingInstall(const Dir: String);
var
  Ini, Value: String;
begin
  Ini := Dir + '\n8n-installer.ini';
  if not FileExists(Ini) then Exit;
  if GetIniString('install', 'method', '', Ini) <> ChosenMethod then Exit;
  FileLog('Updating the install in ' + Dir);
  if not SwitchGiven('PORT') then
    EdPort.Text := GetIniString('install', 'port', EdPort.Text, Ini);
  if not SwitchGiven('LAN') then
    CbLan.Checked := S2B(GetIniString('install', 'lan', '0', Ini));
  Value := GetIniString('install', 'docker_name', '', Ini);
  if (Value <> '') and not SwitchGiven('DOCKERNAME') then EdDockerName.Text := Value;
  Value := GetIniString('install', 'docker_volume', '', Ini);
  if (Value <> '') and not SwitchGiven('DOCKERVOLUME') then EdDockerVolume.Text := Value;
end;

function ModePageNext(Sender: TWizardPage): Boolean;
begin
  Result := True;
  EnsureDetected;
  // A silent install cannot show the method page, so it must stop here instead of quietly using another method.
  if WizardSilent and (RequestedMethodProblem <> '') then
  begin
    Complain('The install method "' + GWantedMethod + '" cannot be used. ' + RequestedMethodProblem);
    Result := False;
    Exit;
  end;
  if IsExpress then
  begin
    // The usual settings: Docker when it is ready, otherwise a folder of its own.
    ChooseMethod(ExpressMethod);
    UpdateSuggestedDir;
    if not SwitchGiven('PORT') then
      EdPort.Text := IntToStr(FirstFreePort(StrToIntDef(Trim(EdPort.Text), DefaultPort)));
    if not SwitchGiven('LAN') then
      CbLan.Checked := False;
    ApplyExistingInstall(CutBackslash(WizardDirValue));
  end;
end;

function MethodPageNext(Sender: TWizardPage): Boolean;
begin
  Result := True;
  UpdateSuggestedDir;
end;

procedure NetPageActivate(Sender: TWizardPage);
begin
  RefreshPortStatus;
end;

function NetPageNext(Sender: TWizardPage): Boolean;
var
  Problem: String;
begin
  Problem := ProblemWithConfig;
  Result := (Cfg.Port >= 1024) and (Cfg.Port <= 65534);
  if not Result then
  begin
    Complain(Problem);
    Exit;
  end;
  if PortInUse(Cfg.Port) or PortInUse(Cfg.Port + 1) then
    if WizardSilent then
      FileLog('Port ' + IntToStr(Cfg.Port) + ' (or the next one) is in use. Going on, as asked.')
    else
      Result := AskYesNo('Port ' + IntToStr(Cfg.Port) + ' (or the one after it, which n8n also uses) is in use by another program, ' +
        'so n8n could not start there. This is fine if that program is an earlier n8n that this install replaces.' + #13#10#13#10 +
        'Continue with this port anyway?', False);
end;

function DockerPageNext(Sender: TWizardPage): Boolean;
var
  Problem: String;
begin
  Problem := ProblemWithConfig;
  Result := Problem = '';
  if not Result then
    Complain(Problem);
end;

function WslPageNext(Sender: TWizardPage): Boolean;
var
  Problem: String;
begin
  Problem := ProblemWithConfig;
  Result := Problem = '';
  if not Result then
    Complain(Problem);
end;

procedure OptionsPageActivate(Sender: TWizardPage);
var
  M: String;
begin
  M := ChosenMethod;
  CbPath.Enabled := M = MethodFolder;
  if not CbPath.Enabled then CbPath.Checked := False;
  CbDesktop.Caption := 'Put a Start n8n shortcut on my desktop';
end;

// Called by the wizard for every page, before it is shown.
function SkipThisPage(PageID: Integer): Boolean;
begin
  Result := False;
  if IsExpress then
  begin
    Result := (PageID = PageMethod.ID) or (PageID = wpSelectDir) or (PageID = PageNet.ID) or
              (PageID = PageDocker.ID) or (PageID = PageWsl.ID) or (PageID = PageOptions.ID);
    Exit;
  end;
  if PageID = PageDocker.ID then Result := ChosenMethod <> MethodDocker
  else if PageID = PageWsl.ID then Result := ChosenMethod <> MethodWsl;
end;

procedure BuildPages;
begin
  BuildModePage;
  BuildMethodPage;
  BuildNetPage;
  BuildDockerPage;
  BuildWslPage;
  BuildOptionsPage;

  PageMode.OnActivate := @ModePageActivate;
  PageMode.OnNextButtonClick := @ModePageNext;
  PageMethod.OnNextButtonClick := @MethodPageNext;
  PageNet.OnActivate := @NetPageActivate;
  PageNet.OnNextButtonClick := @NetPageNext;
  PageDocker.OnNextButtonClick := @DockerPageNext;
  PageWsl.OnNextButtonClick := @WslPageNext;
  PageOptions.OnActivate := @OptionsPageActivate;
end;
