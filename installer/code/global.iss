// ---------------------------------------------------------------------------
// global.iss - n8n added to the Node.js that is already on this computer
//
// Same as typing  npm install -g n8n@2  yourself. The launcher and notes live
// in the install folder; the n8n program lives in npm's global folder.
// ---------------------------------------------------------------------------

function NpmGlobalRoot: String;
var
  Lines: TArrayOfString;
  Code: Integer;
begin
  Result := '';
  if CaptureCmd('npm root -g', Lines, Code) and (Code = 0) then
    Result := CutBackslash(FirstNonEmpty(Lines));
end;

procedure InstallGlobal;
var
  Code: Integer;
  Root, AppData, RunLine, PathLine: String;
begin
  if not GNodeOk then
    Fail('Node.js 22 (or 20.19 or newer) is needed for this way, and it cannot be used here. ' + GlobalWhy(WhereSilent));

  Step('Installing n8n for this user account. This takes a few minutes and uses the internet.');
  Working(True);
  GQuiet := True;
  // --allow-scripts lets npm run the one install script that gives n8n its database; npm 12 blocks it otherwise.
  Code := RunCmd('npm install -g ' + N8nNpmSpec + ' --allow-scripts=sqlite3 --no-fund --no-audit --loglevel=http', '');
  GQuiet := False;
  Working(False);
  if Code <> 0 then
    Fail('npm could not install n8n (exit code ' + IntToStr(Code) + '). If n8n is running right now, close it and try again.'
      + #13#10#13#10 + LastLinesText);

  Root := NpmGlobalRoot;
  if GDryRun and (Root = '') then
    Root := ExpandConstant('{userappdata}\npm\node_modules');
  if (Root = '') or (not GDryRun and not FileExists(Root + '\n8n\bin\n8n')) then
    Fail('npm finished, but n8n was not found where npm installs global packages.');
  GN8nVersion := PackageVersion(Root + '\n8n\package.json');
  LogLine('n8n ' + GN8nVersion + ' is installed in ' + Root);

  Step('Creating the Start n8n shortcut and settings');
  SetCommonVars;
  SetVar('USER_FOLDER', GlobalUserFolder);

  // Run n8n straight from npm's global folder, with the Node.js that is on the PATH.
  AppData := CutBackslash(ExpandConstant('{userappdata}'));
  if Copy(Lowercase(Root), 1, Length(AppData)) = Lowercase(AppData) then
  begin
    RunLine := 'call node "%APPDATA%' + Copy(Root, Length(AppData) + 1, Length(Root)) + '\n8n\bin\n8n" start';
    PathLine := '';
  end
  else
  begin
    RunLine := 'call n8n start';
    PathLine := '';
  end;
  SetVar('PATH_LINE', PathLine);
  SetVar('RUN_LINE', RunLine);
  WriteFromTemplate('env-npm.cmd', AppDir + '\n8n-env.cmd');
  WriteFromTemplate('start-npm.cmd', AppDir + '\start-n8n.cmd');
end;
