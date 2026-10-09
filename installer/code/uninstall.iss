// ---------------------------------------------------------------------------
// uninstall.iss - taking n8n off the computer again
//
// Removes only what the installer put there. Workflows and settings are kept
// unless the user says otherwise.
// ---------------------------------------------------------------------------

var
  GDeleteData: Boolean;

// Wraps a few lines that say what was kept, shown when the uninstaller finishes.
var
  GKeptNote: String;

procedure UninstallFolderInstall;
var
  Dir: String;
begin
  Dir := CutBackslash(ExpandConstant('{app}'));
  // Stop an n8n that is still running from this folder, or its files cannot be removed.
  StopFolderN8n(Dir);
  if LoadState('path_added', '0') = '1' then
    RemoveFromUserPath(Dir + '\bin');
  DelTree(Dir + '\node', True, True, True);
  DelTree(Dir + '\node_modules', True, True, True);
  DelTree(Dir + '\node_modules.old', True, True, True);
  DelTree(Dir + '\bin', True, True, True);
  DeleteFile(Dir + '\package.json');
  DeleteFile(Dir + '\package-lock.json');
  DeleteFile(Dir + '\.npmrc');
  // n8n keeps a cache next to its data. It is only a cache, so it goes in either case.
  DelTree(Dir + '\.cache\n8n', True, True, True);
  RemoveDir(Dir + '\.cache');
  if GDeleteData then
    DelTree(Dir + '\.n8n', True, True, True)
  else if DirExists(Dir + '\.n8n') then
    GKeptNote := Dir + '\.n8n';
end;

procedure UninstallGlobalInstall;
begin
  RunCmd('npm uninstall -g n8n', '');
  if GDeleteData then
    DelTree(GlobalDataDir, True, True, True)
  else if DirExists(GlobalDataDir) then
    GKeptNote := GlobalDataDir;
end;

procedure UninstallDockerInstall;
var
  Name, Volume, Image: String;
begin
  Name := LoadState('docker_name', '');
  Volume := LoadState('docker_volume', '');
  Image := LoadState('docker_image', '');
  if Name <> '' then RunCmd('docker rm -f ' + Name, '');
  if Image <> '' then RunCmd('docker rmi ' + Image, '');
  if Volume <> '' then
  begin
    if GDeleteData then
      RunCmd('docker volume rm ' + Volume, '')
    else
      GKeptNote := 'the Docker volume "' + Volume + '"';
  end;
end;


procedure DoUninstall;
var
  Method: String;
begin
  Method := LoadState('method', '');
  OpenLogFile('uninstall');
  FileLog('Removing the ' + Method + ' install in ' + ExpandConstant('{app}'));
  if Method = MethodDocker then UninstallDockerInstall
  else if Method = MethodWsl then UninstallWslRun(GDeleteData, GKeptNote)
  else if Method = MethodGlobal then UninstallGlobalInstall
  else UninstallFolderInstall;

  // The files the installer made on its own (the setup program only knows the ones it copied).
  DeleteFile(ExpandConstant('{app}\start-n8n.cmd'));
  DeleteFile(ExpandConstant('{app}\stop-n8n.cmd'));
  DeleteFile(ExpandConstant('{app}\n8n-env.cmd'));
  DeleteFile(ExpandConstant('{app}\README.txt'));
end;

procedure AskAboutData;
begin
  GDeleteData := False;
  if UninstallSilent then
  begin
    GDeleteData := S2B(Switch('DELETEDATA', '0'));
    Exit;
  end;
  if MsgBox('Do you want to KEEP your workflows, saved passwords and settings?' + #13#10#13#10 +
            'Yes - keep them. You can install n8n again later and carry on where you stopped.' + #13#10 +
            'No - delete them for good.', mbConfirmation, MB_YESNO or MB_DEFBUTTON1) = IDNO then
    GDeleteData := MsgBox('Are you sure? Deleting your workflows, saved passwords and settings cannot be undone.' + #13#10#13#10 +
                          'Delete them?', mbError, MB_YESNO or MB_DEFBUTTON2) = IDYES;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    AskAboutData;
    DoUninstall;
  end
  else if (CurUninstallStep = usDone) and (GKeptNote <> '') and not UninstallSilent then
    MsgBox('n8n has been removed. Your workflows and settings were kept in:' + #13#10#13#10 + GKeptNote + #13#10#13#10 +
           'Install n8n again with the same options to carry on, or delete that folder yourself when you no longer need it.',
           mbInformation, MB_OK);
end;
