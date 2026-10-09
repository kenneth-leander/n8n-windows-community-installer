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
  LblExpressInfo, LblExpressWhy, LblExpressHelp, LblCustomInfo, LblChecking: TNewStaticText;

  // how n8n runs
  RbDocker, RbFolder, RbGlobal, RbWsl: TNewRadioButton;
  LblDockerInfo, LblFolderInfo, LblGlobalInfo, LblWslInfo: TNewStaticText;
  // Why an option is greyed out: Why is the reason in one highlighted line, Help says what was found and what to do
  LblDockerWhy, LblDockerHelp, LblGlobalWhy, LblGlobalHelp, LblWslWhy, LblWslHelp: TNewStaticText;
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
  GLineHeight: Integer;      // the height of one line of text on this screen, measured once

// ---------------------------------------------------------------------------
// Building blocks
// ---------------------------------------------------------------------------

// Setup scales what is on its own forms, but not the controls that code makes: their sizes have to go through
// ScaleX and ScaleY, and a line of text is measured with the font in use. Without that, a radio button or check box
// keeps its size for 100% display scaling and cuts its caption off at 150% or 250%.
function LineHeight: Integer;
var
  L: TNewStaticText;
begin
  if GLineHeight = 0 then
  begin
    L := TNewStaticText.Create(WizardForm);
    L.Parent := WizardForm;
    L.AutoSize := False;
    L.WordWrap := False;
    L.Caption := 'Wg';
    L.AdjustHeight;
    GLineHeight := L.Height;
    L.Free;
  end;
  Result := GLineHeight;
end;

// The height of a radio button or check box: a line of text with a little room, and never less than the usual 17.
function ControlHeight: Integer;
begin
  Result := LineHeight + ScaleY(4);
  if Result < ScaleY(17) then
    Result := ScaleY(17);
end;

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
  Result.Height := ControlHeight;
  Result.Caption := Caption;
end;

function NewCheck(const Page: TWizardPage; const Caption: String; const Top: Integer; const Checked: Boolean): TNewCheckBox;
begin
  Result := TNewCheckBox.Create(Page);
  Result.Parent := Page.Surface;
  Result.Left := 0;
  Result.Top := Top;
  Result.Width := Page.SurfaceWidth;
  Result.Height := ControlHeight;
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

// The colour of the line that says why something cannot be used: a warm one that reads on light and on dark backgrounds.
function WhyColor: TColor;
begin
  if IsDarkInstallMode then
    Result := $0054B4FF
  else
    Result := $00004EB0;
end;

// The line that says why something cannot be used. It stands out (bold and coloured) and stays hidden until there is
// a reason to show.
function NewWhy(const Page: TWizardPage; const Indent: Integer): TNewStaticText;
begin
  Result := NewText(Page, '', Indent, 0, True);
  // The dark style of the wizard would paint over the colour; this control keeps its own.
  Result.StyleElements := [];
  Result.Font.Color := WhyColor;
  Result.Visible := False;
end;

// The text under it: what was found, what the program said, and what to do. Ordinary text, hidden until needed.
function NewHelp(const Page: TWizardPage; const Indent: Integer): TNewStaticText;
begin
  Result := NewText(Page, '', Indent, 0, False);
  Result.Visible := False;
end;

procedure SetReason(const Why, Help: TNewStaticText; const WhyText, HelpText: String);
begin
  SetText(Why, WhyText);
  Why.Font.Color := WhyColor;
  SetText(Help, HelpText);
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
  Cfg.Lan := CbLan.Checked and (Cfg.Method <> MethodWsl);
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
  else if (Cfg.Method = MethodWsl) and not IsSafeName(Cfg.WslDistro) then
    Result := 'The Linux distribution "' + Cfg.WslDistro + '" has a name with spaces or special characters, and wsl.exe cannot be asked to use it from here. ' +
      'Choose another distribution, or import it again under a simpler name (letters, numbers and dashes only) with  wsl --export  and  wsl --import.'
  else if (Cfg.Method = MethodWsl) and (GWantDistro <> '') and (CompareText(Cfg.WslDistro, GWantDistro) <> 0) then
    Result := 'The Linux distribution "' + GWantDistro + '" was not found in WSL.';
end;

// ---------------------------------------------------------------------------
// Text that depends on what was found on this computer
//
// Every way of running n8n that cannot be used has a reason, and the reason says what was actually found: the words of
// the program that was asked (Docker, WSL, Node.js), or that the check itself did not work. Nothing is greyed out
// without saying why. The reasons are shown in a highlighted line on the pages; a silent install gets the same
// words as its error message.
// ---------------------------------------------------------------------------

const
  WhereSilent = 0;     // the text is an error message, as nobody is looking at a page
  WherePage = 1;       // the "How should n8n run?" page, which has a Check again button
  WhereExpress = 2;    // the Express page, which has none: the way to look again is the Custom install page

// Fills in what to do once the problem is fixed, as that depends on where the text is shown.
function WithRecheck(const Text: String; const Where: Integer): String;
var
  Again: String;
begin
  if Where = WherePage then Again := 'press Check again'
  else if Where = WhereExpress then Again := 'choose Custom install and press Check again'
  else Again := 'run the installer again';
  Result := ReplaceAll(Text, '#RECHECK#', Again);
end;

// What a program said, made fit for where it is shown: all of it in an error message, cut short on a page. The end of
// the text is kept when that is where the cause is named (Docker), the beginning otherwise.
function SaidText(const Said: String; const Where: Integer; const FromEnd: Boolean): String;
begin
  if Where = WhereSilent then
    Result := AsSentence(Said)
  else if FromEnd then
    Result := AsSentence(EndOf(Said, 180))
  else
    Result := AsSentence(StartOf(Said, 180));
end;

// Why Docker cannot be used. Why is the reason in a few words; Help says what Docker said and what to do about it.
// Both are '' when Docker can be used.
procedure DockerWhyParts(const Where: Integer; var Why, Help: String);
var
  Said: String;
begin
  Why := '';
  Help := '';
  if DockerReady then Exit;
  Said := '';
  if GDockerDetail <> '' then
  begin
    Said := SaidText(GDockerDetail, Where, True);
    if GDockerSaid then
      Said := 'Docker said: ' + Said;
  end;
  if GDockerState = 'windows' then
  begin
    Why := 'Docker is set to Windows containers, and n8n needs Linux containers.';
    Help := 'Switch it to Linux containers in the Docker Desktop menu, then #RECHECK#.';
  end
  else if GDockerState = 'stopped' then
  begin
    Why := 'Docker is installed, but it is not ready.';
    Help := JoinText(Said, 'Start Docker Desktop and wait until it says it is running, then #RECHECK#.');
  end
  else if GDockerState = 'error' then
  begin
    Why := 'Setup could not find out whether Docker is ready.';
    Help := JoinText(Said, 'Please #RECHECK# to try once more.');
  end
  else if GDockerDetail = 'installed' then
  begin
    Why := 'Docker Desktop is installed, but Setup cannot find its docker.exe.';
    Help := 'Windows has not told this program where to look yet. Sign out of Windows and sign in again, then start this installer again.';
  end
  else
  begin
    Why := 'Docker was not found on this computer.';
    Help := 'To use it, install Docker Desktop from docker.com and start it, then #RECHECK#.';
  end;
  Help := WithRecheck(Help, Where);
end;

// What to do instead: the folder way brings its own Node.js. A silent install is told the switch to use.
function UseFolderInstead(const Where: Integer): String;
begin
  if Where = WhereSilent then
    Result := 'Use /METHOD=folder instead: it brings its own Node.js.'
  else
    Result := 'Use "Windows, in a folder of its own" instead: it brings its own Node.js.';
end;

// Why the Node.js on this computer cannot be used, in the same two parts. Both are '' when it can be used.
procedure GlobalWhyParts(const Where: Integer; var Why, Help: String);
begin
  Why := '';
  Help := '';
  if GNodeOk then Exit;
  if GNodeVersion <> '' then
  begin
    Why := 'Your Node.js (' + GNodeVersion + ') is not one that n8n 2.x is tested with here.';
    Help := UseFolderInstead(Where);
  end
  else if GNodeDetail <> '' then
  begin
    Why := 'Setup could not check Node.js.';
    Help := JoinText(SaidText(GNodeDetail, Where, False), UseFolderInstead(Where));
  end
  else
  begin
    Why := 'Node.js was not found on this computer.';
    Help := UseFolderInstead(Where);
  end;
end;

const
  InstallADistro = 'install one first, for example with  wsl --install -d Ubuntu  in a terminal, then #RECHECK#.';

// Why there is no Linux distribution to use in WSL, in the same two parts. Both are '' when there is one.
procedure WslWhyParts(const Where: Integer; var Why, Help: String);
begin
  Why := '';
  Help := '';
  if GWslCount > 0 then Exit;
  if not GWslHasExe then
  begin
    Why := 'WSL is not installed on this computer.';
    Help := 'To use it, open a terminal as administrator, run  wsl --install -d Ubuntu , restart Windows, then start this installer again.';
  end
  else if GWslProblem <> '' then
  begin
    Why := 'WSL did not list a Linux distribution.';
    // The beginning of what WSL said is the part that says what is the matter.
    Help := JoinText(SaidText(GWslProblem, Where, False), 'To use this way, ' + InstallADistro);
  end
  else
  begin
    Why := 'WSL did not list a Linux distribution.';
    Help := 'To use this way, ' + InstallADistro;
  end;
  Help := WithRecheck(Help, Where);
end;

function DockerWhy(const Where: Integer): String;
var
  Why, Help: String;
begin
  DockerWhyParts(Where, Why, Help);
  Result := JoinText(Why, Help);
end;

function GlobalWhy(const Where: Integer): String;
var
  Why, Help: String;
begin
  GlobalWhyParts(Where, Why, Help);
  Result := JoinText(Why, Help);
end;

function WslWhy(const Where: Integer): String;
var
  Why, Help: String;
begin
  WslWhyParts(Where, Why, Help);
  Result := JoinText(Why, Help);
end;

// What the install code says when Docker is not ready, just before it starts.
function DockerStatusText: String;
begin
  if DockerReady then
    Result := 'Docker is running on this computer.'
  else
    Result := DockerWhy(WhereSilent);
end;

function DockerInfo: String;
begin
  Result := 'n8n runs in a Docker container: clean, easy to back up, and the only way to keep working with n8n 3.0.';
  if DockerReady then
    Result := Result + ' Docker ' + GDockerVersion + ' is running on this computer.';
end;

function GlobalInfo: String;
begin
  Result := 'Adds n8n to the Node.js that is already installed, so the n8n command works in every terminal. Needs Node.js 22. Stays on n8n 2.x.';
  if GNodeOk then
    Result := Result + ' Node.js ' + GNodeVersion + ' was found.';
end;

function WslInfo: String;
var
  I: Integer;
  Names: String;
begin
  Result := 'Installs n8n inside a Linux distribution you already have in WSL2, with Linux file speed. Stays on n8n 2.x.';
  if GWslCount > 0 then
  begin
    Names := '';
    for I := 0 to GWslCount - 1 do
      if I < 3 then
        Names := Names + ', ' + GWslName[I];
    Delete(Names, 1, 2);
    if GWslCount > 3 then
      Names := Names + ' and more';
    Result := Result + ' Found: ' + Names + '.';
  end;
end;

function ExpressMethod: String;
begin
  if DockerReady then Result := MethodDocker else Result := MethodFolder;
end;

// Express quietly uses the folder way when Docker is not ready. Someone who has Docker would wonder why, so that is
// said. When Docker is simply not installed there is nothing to explain, and Why is ''.
procedure ExpressWhyParts(var Why, Help: String);
begin
  Why := '';
  Help := '';
  if DockerReady then Exit;
  if (GDockerState = 'missing') and (GDockerDetail = '') then Exit;
  DockerWhyParts(WhereExpress, Why, Help);
  Why := Why + ' So Express does not use it.';
end;

// Puts one way of running n8n on the page at Top: its radio button, its description (unless ShowInfo is False) and, only
// when the way cannot be used, the highlighted reason with the help under it (Why is nil for a way that can always be
// used). Returns where the next one starts.
function PlaceOption(const Radio: TNewRadioButton; const Info, Why, Help: TNewStaticText; const ShowInfo: Boolean; const Top: Integer): Integer;
begin
  Radio.Top := Top;
  Result := Below(Radio, 1);
  Info.Visible := ShowInfo;
  if ShowInfo then
  begin
    Info.Top := Result;
    Result := Below(Info, 0);
  end;
  if Why <> nil then
  begin
    Why.Visible := Why.Caption <> '';
    Help.Visible := Why.Visible and (Help.Caption <> '');
    if Why.Visible then
    begin
      Why.Top := Result + ScaleY(3);
      Result := Below(Why, 0);
      if Help.Visible then
      begin
        Help.Top := Result;
        Result := Below(Help, 0);
      end;
    end;
  end;
  Result := Result + ScaleY(9);
end;

// Lays the four ways out from the top and returns where the last one ends. Hide says which descriptions to leave out, for
// a page that would otherwise not fit. It only ever leaves out those of ways that cannot be used, as their reasons
// say more: 0 none, 1 the Node.js way's, 2 that one and the Linux way's, 3 all three, with Docker's.
function LayoutMethodPage(const Hide: Integer): Integer;
begin
  Result := PlaceOption(RbDocker, LblDockerInfo, LblDockerWhy, LblDockerHelp, DockerReady or (Hide < 3), 0);
  Result := PlaceOption(RbFolder, LblFolderInfo, nil, nil, True, Result);
  Result := PlaceOption(RbGlobal, LblGlobalInfo, LblGlobalWhy, LblGlobalHelp, GNodeOk or (Hide < 1), Result);
  Result := PlaceOption(RbWsl, LblWslInfo, LblWslWhy, LblWslHelp, (GWslCount > 0) or (Hide < 2), Result);
end;

procedure RefreshModeText;
var
  Why, Help: String;
  Top: Integer;
begin
  if not GDetected then Exit;
  LblChecking.Visible := False;
  if ExpressMethod = MethodDocker then
    SetText(LblExpressInfo, 'Docker is running on this computer, so n8n will run in Docker. The only thing you may need to do is wait a few minutes while it downloads.')
  else
    SetText(LblExpressInfo, 'n8n is installed in its own folder on Windows. You do not have to install anything else first. It takes a few minutes while it downloads.');
  ExpressWhyParts(Why, Help);
  SetReason(LblExpressWhy, LblExpressHelp, Why, Help);

  LblExpressInfo.Top := Below(RbExpress, 1);
  Top := Below(LblExpressInfo, 0);
  LblExpressWhy.Visible := Why <> '';
  LblExpressHelp.Visible := (Why <> '') and (Help <> '');
  if LblExpressWhy.Visible then
  begin
    LblExpressWhy.Top := Below(LblExpressInfo, 4);
    Top := Below(LblExpressWhy, 0);
    if LblExpressHelp.Visible then
    begin
      LblExpressHelp.Top := Below(LblExpressWhy, 0);
      Top := Below(LblExpressHelp, 0);
    end;
  end;
  RbCustom.Top := Top + ScaleY(16);
  LblCustomInfo.Top := Below(RbCustom, 1);
end;

procedure RefreshMethodText;
var
  Why, Help: String;
  Hide: Integer;
begin
  if not GDetected then Exit;

  RbDocker.Enabled := DockerReady;
  RbFolder.Enabled := True;
  RbGlobal.Enabled := GNodeOk;
  RbWsl.Enabled := GWslCount > 0;

  SetText(LblDockerInfo, DockerInfo);
  DockerWhyParts(WherePage, Why, Help);
  SetReason(LblDockerWhy, LblDockerHelp, Why, Help);
  SetText(LblFolderInfo, 'n8n and everything it needs are placed in one folder, so nothing else on the computer is touched. ' +
    'Nothing has to be installed first. Stays on n8n 2.x.');
  SetText(LblGlobalInfo, GlobalInfo);
  GlobalWhyParts(WherePage, Why, Help);
  SetReason(LblGlobalWhy, LblGlobalHelp, Why, Help);
  SetText(LblWslInfo, WslInfo);
  WslWhyParts(WherePage, Why, Help);
  SetReason(LblWslWhy, LblWslHelp, Why, Help);

  // Lay the page out again, as the heights of the texts have changed. If it does not fit, leave out descriptions.
  Hide := 0;
  while (LayoutMethodPage(Hide) - ScaleY(9) > PageMethod.SurfaceHeight) and (Hide < 3) do
    Hide := Hide + 1;

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
  else if GPortProblem <> '' then
    SetText(LblPortStatus, 'n8n will open at ' + LocalUrl(P) + '   (Setup could not check whether port ' + IntToStr(P) + ' is free: ' + WithoutStop(GPortProblem) + ').')
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
  // Asking Docker can take a while when it is starting up, so the button says that something is going on.
  BtnRecheck.Caption := 'Checking...';
  BtnRecheck.Enabled := False;
  WizardForm.Refresh;
  RunDetection;
  BtnRecheck.Caption := 'Check again';
  BtnRecheck.Enabled := True;
end;

// ---------------------------------------------------------------------------
// Page: Express or Custom
// ---------------------------------------------------------------------------

procedure BuildModePage;
begin
  PageMode := CreateCustomPage(wpWelcome, 'How do you want to install n8n?',
    'Express is right for almost everyone. You see a summary before anything is installed.');
  RbExpress := NewRadio(PageMode, 'Express install (recommended)', 0);
  RbExpress.Checked := True;
  LblExpressInfo := NewText(PageMode, 'Checking this computer...', 22, Below(RbExpress, 1), False);
  LblExpressWhy := NewWhy(PageMode, 22);
  LblExpressHelp := NewHelp(PageMode, 22);
  RbCustom := NewRadio(PageMode, 'Custom install', Below(LblExpressInfo, 16));
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

  // Everything is placed by RefreshMethodText once the computer has been looked at, as the texts decide the heights.
  RbDocker := NewRadio(PageMethod, 'Docker', 0);
  LblDockerInfo := NewText(PageMethod, '', 22, 0, False);
  LblDockerWhy := NewWhy(PageMethod, 22);
  LblDockerHelp := NewHelp(PageMethod, 22);
  RbFolder := NewRadio(PageMethod, 'Windows, in a folder of its own', 0);
  RbFolder.Checked := True;
  LblFolderInfo := NewText(PageMethod, '', 22, 0, False);
  RbGlobal := NewRadio(PageMethod, 'Windows, for this user account', 0);
  LblGlobalInfo := NewText(PageMethod, '', 22, 0, False);
  LblGlobalWhy := NewWhy(PageMethod, 22);
  LblGlobalHelp := NewHelp(PageMethod, 22);
  RbWsl := NewRadio(PageMethod, 'Linux inside Windows (WSL2)', 0);
  LblWslInfo := NewText(PageMethod, '', 22, 0, False);
  LblWslWhy := NewWhy(PageMethod, 22);
  LblWslHelp := NewHelp(PageMethod, 22);

  RbDocker.OnClick := @MethodClick;
  RbFolder.OnClick := @MethodClick;
  RbGlobal.OnClick := @MethodClick;
  RbWsl.OnClick := @MethodClick;

  // Top right, on the line of the first option, where it never gets in the way of the texts below.
  BtnRecheck := TNewButton.Create(PageMethod);
  BtnRecheck.Parent := PageMethod.Surface;
  BtnRecheck.Caption := 'Check again';
  BtnRecheck.Width := ScaleX(100);
  BtnRecheck.Height := ScaleY(23);
  if BtnRecheck.Height < ControlHeight then
    BtnRecheck.Height := ControlHeight;
  BtnRecheck.Left := PageMethod.SurfaceWidth - BtnRecheck.Width;
  BtnRecheck.Top := 0;
  BtnRecheck.OnClick := @RecheckClick;
  RbDocker.Width := BtnRecheck.Left - ScaleX(8);
  RbDocker.Height := BtnRecheck.Height;
end;

// ---------------------------------------------------------------------------
// Page: network
// ---------------------------------------------------------------------------

const
  LanNoteText = 'Leave this off if you are the only one who uses n8n on this computer. ' +
    'When it is on, anyone on your network can reach n8n, and Windows may ask you to allow it through the firewall.';
  LanNoteWsl = 'Not available for Linux inside Windows (WSL2): Windows passes n8n on to this computer only, ' +
    'so other devices cannot reach it.';

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
  LblLanNote := NewText(PageNet, LanNoteText, 22, Below(CbLan, 2), False);
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
  if GWantedMethod = MethodDocker then Result := DockerWhy(WhereSilent)
  else if GWantedMethod = MethodGlobal then Result := GlobalWhy(WhereSilent)
  else if GWantedMethod = MethodWsl then Result := WslWhy(WhereSilent);
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
  if ChosenMethod = MethodWsl then
  begin
    // Windows passes a WSL2 program on to this computer only, so there is nothing for the box to switch.
    CbLan.Checked := False;
    CbLan.Enabled := False;
    SetText(LblLanNote, LanNoteWsl);
  end
  else
  begin
    CbLan.Enabled := True;
    SetText(LblLanNote, LanNoteText);
  end;
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
  if WizardSilent and CbLan.Checked and (Cfg.Method = MethodWsl) then
    FileLog('/LAN is ignored for Linux inside Windows (WSL2): Windows passes n8n on to this computer only.');
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
  I: Integer;
begin
  Problem := ProblemWithConfig;
  Result := Problem = '';
  if not Result then
  begin
    Complain(Problem);
    Exit;
  end;
  // WSL 1 shares the network of Windows and has trouble with the database file locking of n8n.
  I := CbxWslDistro.ItemIndex;
  if (I >= 0) and (I < GWslCount) and (GWslVersion[I] = '1') then
  begin
    if WizardSilent then
      FileLog(Cfg.WslDistro + ' runs on WSL 1, which is slow and often fails with n8n. Going on, as asked.')
    else
      Result := AskYesNo(Cfg.WslDistro + ' runs on WSL 1, which is slow and often fails with n8n (WSL 1 has trouble with the file locking of its database).' + #13#10#13#10 +
        'WSL 2 is much better. You can convert it with the command  wsl --set-version ' + Cfg.WslDistro + ' 2' + #13#10#13#10 +
        'Continue with WSL 1 anyway?', False);
  end;
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
