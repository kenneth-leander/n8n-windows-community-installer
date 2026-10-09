// ---------------------------------------------------------------------------
// folder.iss - n8n in a folder of its own, with its own copy of Node.js
//
//   <folder>\node             Node.js (downloaded from nodejs.org, checked against its published hash)
//   <folder>\node_modules     n8n and everything it needs
//   <folder>\.n8n             your workflows, passwords and settings (made by n8n on first start)
//   <folder>\start-n8n.cmd    starts n8n
//
// Bringing its own Node.js is what lets this work on any computer, with or without Node.js
// installed, and whatever version of Node.js is there.
// ---------------------------------------------------------------------------

function NodeDir: String;
begin
  Result := AppDir + '\node';
end;

// The version of the Node.js in this folder, like v22.11.0, or '' when there is none.
function FolderNodeVersion: String;
var
  Lines: TArrayOfString;
  Code: Integer;
begin
  Result := '';
  if not FileExists(NodeDir + '\node.exe') then Exit;
  if CaptureTool(NodeDir + '\node.exe', '--version', Lines, Code) and (Code = 0) then
    Result := FirstNonEmpty(Lines);
end;

// Stops an n8n that is running from this folder. Its Node.js keeps the files open, and open files cannot be
// replaced or removed.
procedure StopFolderN8n(const Dir: String);
var
  Prefix: String;
begin
  Prefix := ReplaceAll(Dir + '\node\', '''', '''''');
  RunTool(PowerShellExe, '-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ' +
    Q('Get-Process -Name node -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith(''' + Prefix +
      ''', [StringComparison]::OrdinalIgnoreCase) } | Stop-Process -Force'), '');
end;

procedure InstallPrivateNode;
var
  Have, Base, Line, Sha, FileName, Archive, Unpacked: String;
  Lines: TArrayOfString;
  I: Integer;
begin
  Have := FolderNodeVersion;
  if (Have <> '') and (Copy(Have, 1, Length(PrivateNodeLine) + 2) = 'v' + PrivateNodeLine + '.') then
  begin
    LogLine('Node.js ' + Have + ' is already in this folder.');
    Exit;
  end;

  Step('Downloading Node.js ' + PrivateNodeLine + ' (the engine n8n runs on)');
  Base := 'https://nodejs.org/dist/latest-v' + PrivateNodeLine + '.x/';
  Download(Base + 'SHASUMS256.txt', 'node-shasums.txt', '');
  if GDryRun then Exit;

  // The list has one line per file: the SHA-256 hash, two spaces, then the file name.
  FileName := '';
  Sha := '';
  if LoadStringsFromFile(ExpandConstant('{tmp}\node-shasums.txt'), Lines) then
    for I := 0 to GetArrayLength(Lines) - 1 do
    begin
      Line := Trim(Lines[I]);
      if (Length(Line) > 70) and (Copy(Line, Length(Line) - 10, 11) = '-win-x64.7z') and (Copy(Line, 67, 6) = 'node-v') then
      begin
        Sha := Copy(Line, 1, 64);
        FileName := Trim(Copy(Line, 65, Length(Line)));
        Break;
      end;
    end;
  if (FileName = '') or (Length(Sha) <> 64) then
    Fail('Could not find the Windows download of Node.js ' + PrivateNodeLine + ' on nodejs.org.');

  LogLine('Node.js file: ' + FileName);
  Archive := Download(Base + FileName, FileName, Sha);

  Step('Unpacking Node.js');
  if DirExists(NodeDir) then
    DelTree(NodeDir, True, True, True);
  ExtractArchive(Archive, AppDir, '', True, @OnUnpack);
  Unpacked := AppDir + '\' + Copy(FileName, 1, Length(FileName) - 3);
  if not RenameFile(Unpacked, NodeDir) then
    Fail('Could not move Node.js into place (' + Unpacked + ').');
  Have := FolderNodeVersion;
  if Have = '' then
    Fail('Node.js was unpacked but does not start. A virus scanner may have blocked it.');
  LogLine('Node.js ' + Have + ' is ready.');
end;

// Reads the version number out of an installed package's package.json.
function PackageVersion(const PackageJson: String): String;
var
  Raw: AnsiString;
  Text, Rest: String;
  P: Integer;
begin
  Result := '';
  if not LoadStringFromFile(PackageJson, Raw) then Exit;
  Text := Raw;
  P := Pos('"version"', Text);
  if P = 0 then Exit;
  Rest := Copy(Text, P + 9, 80);
  P := Pos('"', Rest);
  if P = 0 then Exit;
  Rest := Copy(Rest, P + 1, 80);
  P := Pos('"', Rest);
  if P = 0 then Exit;
  Result := Copy(Rest, 1, P - 1);
end;

procedure InstallFolderPackages;
var
  Code: Integer;
  OldModules: String;
  HadModules, SetAside: Boolean;
begin
  Step('Installing n8n. This takes a few minutes and uses the internet.');
  PutOnPath(NodeDir);

  if not FileExists(AppDir + '\package.json') then
    SaveAsciiFile(AppDir + '\package.json',
      '{' + #13#10 +
      '  "name": "n8n-local-install",' + #13#10 +
      '  "version": "1.0.0",' + #13#10 +
      '  "private": true,' + #13#10 +
      '  "description": "n8n, installed by the n8n Windows Community Installer"' + #13#10 +
      '}' + #13#10);

  // Newer npm versions block the install script that gives n8n its database. This allows only that one.
  SaveAsciiFile(AppDir + '\.npmrc',
    'allow-scripts=sqlite3' + #13#10 +
    'fund=false' + #13#10 +
    'audit=false' + #13#10 +
    'update-notifier=false' + #13#10);

  // A folder from the old .bat installer has n8n built for whatever Node.js that computer had. Start clean,
  // but keep the old copy until the new one is in, so a failed update does not leave n8n broken.
  OldModules := AppDir + '\node_modules.old';
  HadModules := DirExists(AppDir + '\node_modules');
  SetAside := HadModules and not GHadPrivateNode;
  if SetAside then
  begin
    if DirExists(OldModules) then DelTree(OldModules, True, True, True);
    if not RenameFile(AppDir + '\node_modules', OldModules) then
      Fail('The existing n8n files in this folder are in use. Close n8n (and any window using this folder), then try again.');
  end;

  Working(True);
  GQuiet := True;
  Code := RunCmd(Q(NodeDir + '\npm.cmd') + ' install ' + N8nNpmSpec + ' --no-fund --no-audit --loglevel=http', AppDir);
  GQuiet := False;
  Working(False);

  if (Code <> 0) or (not GDryRun and not FileExists(AppDir + '\node_modules\n8n\bin\n8n')) then
  begin
    if SetAside then
    begin
      if DirExists(AppDir + '\node_modules') then DelTree(AppDir + '\node_modules', True, True, True);
      RenameFile(OldModules, AppDir + '\node_modules');
    end;
    Fail('npm could not install n8n (exit code ' + IntToStr(Code) + ').' + #13#10#13#10 + LastLinesText);
  end;

  if SetAside then
  begin
    Step('Removing the previous n8n files');
    Working(True);
    DelTree(OldModules, True, True, True);
    Working(False);
  end;

  GN8nVersion := PackageVersion(AppDir + '\node_modules\n8n\package.json');
  LogLine('n8n ' + GN8nVersion + ' is installed.');
end;

procedure WriteFolderLaunchers;
begin
  Step('Creating the Start n8n shortcut and settings');
  SetCommonVars;
  SetVar('USER_FOLDER', '%N8N_HOME%');
  SetVar('PATH_LINE', 'set "PATH=%N8N_HOME%\node;%PATH%"');
  SetVar('RUN_LINE', 'call "%N8N_HOME%\node\node.exe" "%N8N_HOME%\node_modules\n8n\bin\n8n" start');
  SetVar('SHIM_RUN_LINE', 'set "PATH=%N8N_HOME%\node;%PATH%"' + #13#10 + '"%N8N_HOME%\node\node.exe" "%N8N_HOME%\node_modules\n8n\bin\n8n" %*');
  WriteFromTemplate('env-npm.cmd', AppDir + '\n8n-env.cmd');
  WriteFromTemplate('start-npm.cmd', AppDir + '\start-n8n.cmd');
  if Cfg.AddToPath then
  begin
    WriteFromTemplate('n8n-shim.cmd', AppDir + '\bin\n8n.cmd');
    if not GDryRun then
      AddToUserPath(AppDir + '\bin');
  end;
end;

procedure InstallFolder;
begin
  GHadPrivateNode := FileExists(NodeDir + '\node.exe');
  if GHadPrivateNode then
    StopFolderN8n(AppDir);
  InstallPrivateNode;
  InstallFolderPackages;
  WriteFolderLaunchers;
end;
