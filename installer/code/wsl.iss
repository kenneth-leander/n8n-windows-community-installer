// ---------------------------------------------------------------------------
// wsl.iss - n8n inside a Linux distribution in WSL2
//
// The distribution is one the user already has. Inside it this installer
//   - looks around: default user, home folder, which Linux, which Node.js
//   - adds Node.js 22 when there is none that n8n 2.x runs on (system packages as root,
//     or nvm for a Node.js that nvm keeps in the user's own home folder)
//   - runs  npm install -g n8n@2  (as root for a system-wide Node.js, as the user otherwise)
// and on the Windows side it writes start-n8n.cmd and stop-n8n.cmd.
// n8n keeps its data in  <home of the default user>/.n8n  on the Linux disk.
//
// Everything runs as   wsl.exe -d <distribution> [-u root] --exec <program> ...
// --exec starts the program directly. Without it wsl.exe hands the text to the shell
// of the Linux user, which would expand $PATH and $HOME before the command runs.
// The commands are written as   sh -c "..."   with no double quote inside and no
// backslash at the end, so Windows splits the command line exactly as meant (see WslSh).
// Nothing here asks for a password: root is reached with  -u root,  and every script
// starts with its keyboard input closed, so nothing can wait for an answer in a hidden window.
//
// Test hooks for /DRYRUN (nothing is started, the answers of Linux are made up):
//   /FAKEWSLUSER=ken|root     /FAKEWSLOS=ubuntu|alpine|fedora|...   /FAKEWSLNODE=22.11.0|none|18.19.1
//   /FAKEWSLNVM               Node.js sits in the user's own nvm folder
//   /FAKEWSLPREFIX=/home/ken/.npm-global     npm puts global packages in that folder
//   /FAKEWSLN8N=2.40.0        an n8n is already there         /FAKEWSLSTUCK  adding Node.js changes nothing
//   /FAKEWSLNET=ok|none|<text>   what Linux answers when asked to download the Node.js version list from nodejs.org
//                             (the check that runs after nvm failed): ok = it works, none = no curl and no wget,
//                             anything else = what curl said
// With /SHOWFILES the log shows the start and stop scripts and the readme that would be written.
// ---------------------------------------------------------------------------

var
  GWslDistro: String;          // the Linux distribution that is used
  GWslV1: Boolean;             // it runs on WSL 1 (WSL 2 is the normal case)
  GWslUser: String;            // its default Linux user
  GWslHome: String;            // that user's home folder, like /home/ken
  GWslOsId: String;            // ID from /etc/os-release, like ubuntu
  GWslOsLike: String;          // ID_LIKE from /etc/os-release, like "rhel fedora"
  GWslHasBash: Boolean;
  GWslNodePath: String;        // where node really is, or 'none'
  GWslNodeVer: String;         // like 22.11.0, or 'none'
  GWslNpmPath: String;         // where npm is, or 'none'
  GWslNpmVer: String;          // or 'none'
  GWslNpmPrefix: String;       // where npm puts global packages, or 'none'
  GWslN8nPath: String;         // an n8n that was there before this install, or 'none'
  GWslN8nVer: String;          // its version, or 'none'
  GWslNodeOk: Boolean;         // Node.js 22, or 20.19 and newer in the 20 line (same rule as detect.iss)
  GWslNodeBin: String;         // the folder with node in it
  GWslBinPath: String;         // folders that go first on the PATH: the one with node, and npm's own when that is another one
  GWslN8nExe: String;          // the n8n of this install, as the start script finds it, like /usr/bin/n8n
  GWslAsRoot: Boolean;         // packages are installed with root rights (a system-wide Node.js)
  GWslIsNvm: Boolean;          // the Node.js is managed by nvm
  GWslPathHint: String;        // looked at first when searching for node
  GWslNodeAdded: Boolean;      // Node.js was just added (only the dry run needs this)
  GWslAnswerText: String;      // what the last look inside printed, for error messages

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

function WslExe: String;
begin
  Result := ExpandConstant('{sys}\wsl.exe');
end;

procedure WslAddLine(var Lines: TArrayOfString; const S: String);
var
  N: Integer;
begin
  N := GetArrayLength(Lines);
  SetArrayLength(Lines, N + 1);
  Lines[N] := S;
end;

// wsl.exe writes its own messages as UTF-16, which arrive with a zero byte after every letter.
function WslNoNul(const S: String): String;
begin
  Result := ReplaceAll(S, #0, '');
end;

function WslLastLines: String;
begin
  Result := WslNoNul(LastLinesText);
end;

// Letters, digits and  / . _ -  can be put into a Linux command without any quoting.
function WslSafeChar(const C: Char): Boolean;
begin
  Result := ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) or ((C >= '0') and (C <= '9')) or
            (C = '/') or (C = '.') or (C = '_') or (C = '-');
end;

// A Linux folder that is safe to write into a command: absolute, no spaces, no special characters.
function WslSafePath(const S: String): Boolean;
var
  I: Integer;
begin
  Result := (Length(S) > 1) and (Length(S) <= 200) and (S[1] = '/') and (Pos('..', S) = 0);
  if not Result then Exit;
  for I := 1 to Length(S) do
    if not WslSafeChar(S[I]) then
    begin
      Result := False;
      Exit;
    end;
end;

// Folders separated by colons, like a PATH.
function WslSafePathList(const S: String): Boolean;
var
  Rest, Item: String;
begin
  Result := S <> '';
  Rest := S;
  while Result and (Rest <> '') do
  begin
    SplitOnce(Rest, ':', Item, Rest);
    if not WslSafePath(Item) then Result := False;
  end;
end;

function WslSafeUser(const S: String): Boolean;
var
  I: Integer;
begin
  Result := (Length(S) > 0) and (Length(S) <= 64) and (Pos('/', S) = 0);
  if not Result then Exit;
  for I := 1 to Length(S) do
    if not WslSafeChar(S[I]) then
    begin
      Result := False;
      Exit;
    end;
end;

// The folder part of a Linux path:  /usr/bin/node -> /usr/bin
function WslDirOf(const P: String): String;
var
  I: Integer;
begin
  Result := '';
  for I := Length(P) downto 1 do
    if P[I] = '/' then
    begin
      if I = 1 then Result := '/' else Result := Copy(P, 1, I - 1);
      Exit;
    end;
end;

function WslUp(const P: String; const Levels: Integer): String;
var
  I: Integer;
begin
  Result := P;
  for I := 1 to Levels do
    Result := WslDirOf(Result);
end;

function WslHasWord(const List, Word: String): Boolean;
begin
  Result := Pos(' ' + Word + ' ', ' ' + Lowercase(List) + ' ') > 0;
end;

// nvm keeps its Node.js versions in  <nvm folder>/versions/node/<version>/bin  and the folder
// is called  .nvm  (or just  nvm  when XDG folders are used).
function WslIsNvmPath(const P: String): Boolean;
begin
  Result := (Pos('/.nvm/', P) > 0) or (Pos('/nvm/', P) > 0);
end;

// WSL puts the PATH of Windows behind the Linux one, so a program found under /mnt/ belongs to Windows.
function WslIsWindowsPath(const P: String): Boolean;
begin
  Result := Copy(P, 1, 5) = '/mnt/';
end;

// The text after  Key=  on the first output line that starts with it (Default when there is none).
function WslValue(const Lines: TArrayOfString; const Key, Default: String): String;
var
  I: Integer;
  L: String;
begin
  Result := Default;
  for I := 0 to GetArrayLength(Lines) - 1 do
  begin
    L := Trim(WslNoNul(Lines[I]));
    if Copy(L, 1, Length(Key) + 1) = Key + '=' then
    begin
      Result := Trim(Copy(L, Length(Key) + 2, Length(L)));
      if Result = '' then Result := Default;
      Exit;
    end;
  end;
end;

// The first dotted number in S:  v22.11.0 -> 22.11.0,  n8n/2.42.5 linux-x64 -> 2.42.5.  '' when there is none.
function WslNumber(const S: String): String;
var
  I, Start, Dots: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] >= '0') and (S[I] <= '9') then
    begin
      Start := I;
      Dots := 0;
      while (I <= Length(S)) and (((S[I] >= '0') and (S[I] <= '9')) or (S[I] = '.')) do
      begin
        if S[I] = '.' then Inc(Dots);
        Inc(I);
      end;
      if Dots >= 1 then
      begin
        Result := Copy(S, Start, I - Start);
        Exit;
      end;
    end
    else
      Inc(I);
  end;
end;

// The same rule as detect.iss: Node.js 22, or 20.19 and newer in the 20 line.
function WslNodeVersionOk(const Ver: String): Boolean;
var
  Major, Minor, Rest: String;
begin
  SplitOnce(Ver, '.', Major, Rest);
  SplitOnce(Rest, '.', Minor, Rest);
  Result := (StrToIntDef(Major, 0) = 22) or ((StrToIntDef(Major, 0) = 20) and (StrToIntDef(Minor, 0) >= 19));
end;

// True when the wizard knows this distribution runs on WSL 1.
function WslDistroIsV1(const Name: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to GWslCount - 1 do
    if (CompareText(GWslName[I], Name) = 0) and (GWslVersion[I] = '1') then
      Result := True;
end;

// ---------------------------------------------------------------------------
// Running commands inside the distribution
// ---------------------------------------------------------------------------

// The parameters for wsl.exe:   -d <distribution> [-u root] --exec <shell> -c "<script>"
function WslSh(const Distro: String; const AsRoot: Boolean; const Shell, Script: String): String;
begin
  if not IsSafeName(Distro) then
    Fail('Internal error: the name of the Linux distribution cannot be used in a command.');
  if (Pos('"', Script) > 0) or (Copy(Script, Length(Script), 1) = '\') then
    Fail('Internal error: a Linux command cannot be quoted safely.');
  Result := '-d ' + Distro;
  if AsRoot then Result := Result + ' -u root';
  Result := Result + ' --exec ' + Shell + ' -c "' + Script + '"';
end;

// Every script starts like this: no keyboard input (so nothing can wait for an answer in a
// hidden window), and a folder that always exists (wsl.exe starts in a Windows folder otherwise).
function WslScriptStart: String;
begin
  Result := 'exec </dev/null; cd /; ';
end;

// The PATH that n8n is installed and started with. The folders of the Node.js come first,
// and the PATH that WSL itself provides stays at the end.
function WslRunPath(const BinPath: String): String;
begin
  if BinPath = '/usr/local/bin' then
    Result := '/usr/local/bin:/usr/bin:/bin:$PATH'
  else
    Result := BinPath + ':/usr/local/bin:/usr/bin:/bin:$PATH';
end;

// Two plain steps: a plain assignment is never split at spaces, and the PATH of Windows has some
// ("Program Files").
function WslPathLine(const BinPath: String): String;
begin
  Result := 'PATH=' + WslRunPath(BinPath) + '; export PATH; ';
end;

function WslNpmScript(const BinPath, NpmArguments: String): String;
begin
  Result := WslScriptStart + WslPathLine(BinPath) + 'npm ' + NpmArguments;
end;

// ---------------------------------------------------------------------------
// Where the data is, in words
// ---------------------------------------------------------------------------

// The data folder as Windows File Explorer shows it:  \\wsl$\Ubuntu\home\ken\.n8n
function WslWinDataPath(const Distro, Home: String): String;
begin
  Result := '\\wsl$\' + Distro + ReplaceAll(Home, '/', '\') + '\.n8n';
end;

function WslDataText(const Distro, Home: String): String;
begin
  Result := WslWinDataPath(Distro, Home) + '   (inside ' + Distro + ': ' + Home + '/.n8n)';
end;

// Used on the summary page and in the readme. Before the install has looked inside Linux the
// home folder is not known yet, so the words are general.
function WslDataDisplay: String;
begin
  if GWslHome <> '' then
    Result := WslDataText(Cfg.WslDistro, GWslHome)
  else
    Result := 'the .n8n folder in the home folder of the default Linux user of ' + Cfg.WslDistro;
end;

// ---------------------------------------------------------------------------
// Looking inside the distribution (the "probe")
//
// The script prints  KEY=value  lines, all plain ASCII, and sentinel values ('none') so
// that every key has a value. It runs as the DEFAULT user, because that user's PATH is the
// one the start script will use.
// ---------------------------------------------------------------------------

function WslProbeScript(const PathHint: String): String;
begin
  Result := WslScriptStart +
    'PATH=' + PathHint + ':$PATH; export PATH; ' +
    'echo WSLUSER=$(id -un); ' +
    'H=$HOME; case $H in /*) ;; *) H=$(getent passwd $(id -un) 2>/dev/null | cut -d: -f6);; esac; echo WSLHOME=$H; ' +
    'if [ -r /etc/os-release ]; then . /etc/os-release; fi; ' +
    'echo OSID=${ID:-none}; ' +
    'echo OSLIKE=${ID_LIKE:-none}; ' +
    'BH=$(command -v bash 2>/dev/null); echo HASBASH=${BH:-none}; ' +
    'NP=$(command -v node 2>/dev/null); NP=${NP:-none}; ' +
    'case $NP in none) echo NODEPATH=none;; *) RP=$(readlink -f $NP); echo NODEPATH=$RP; PATH=$(dirname $RP):$PATH; export PATH;; esac; ' +
    'echo NODEVER=$(node -v 2>/dev/null || echo none); ' +
    'NM=$(command -v npm 2>/dev/null); echo NPMPATH=${NM:-none}; ' +
    'echo NPMVER=$(npm -v 2>/dev/null || echo none); ' +
    'echo NPMPREFIX=$(npm config get prefix 2>/dev/null || echo none); ' +
    'NB=$(command -v n8n 2>/dev/null); echo N8NPATH=${NB:-none}; ' +
    'echo N8NVER=$(n8n --version 2>/dev/null || echo none)';
end;

// Made-up answers for the dry run, in the same KEY=value form.
procedure WslFakeAnswer(var Lines: TArrayOfString);
var
  User, Home, Node, NodePath, Prefix: String;
begin
  SetArrayLength(Lines, 0);
  User := Switch('FAKEWSLUSER', 'ken');
  if User = 'root' then Home := '/root' else Home := '/home/' + User;
  Node := Switch('FAKEWSLNODE', '22.11.0');
  if GWslNodeAdded and not SwitchGiven('FAKEWSLSTUCK') then Node := '22.20.0';
  if Node = 'none' then
  begin
    NodePath := 'none';
    Prefix := 'none';
  end
  else if SwitchGiven('FAKEWSLNVM') then
  begin
    NodePath := Home + '/.nvm/versions/node/v' + Node + '/bin/node';
    Prefix := Home + '/.nvm/versions/node/v' + Node;
  end
  else
  begin
    NodePath := '/usr/bin/node';
    Prefix := '/usr';
  end;
  if SwitchGiven('FAKEWSLPREFIX') and (Node <> 'none') then Prefix := Switch('FAKEWSLPREFIX', '/usr');
  WslAddLine(Lines, 'WSLUSER=' + User);
  WslAddLine(Lines, 'WSLHOME=' + Home);
  WslAddLine(Lines, 'OSID=' + Switch('FAKEWSLOS', 'ubuntu'));
  WslAddLine(Lines, 'OSLIKE=none');
  WslAddLine(Lines, 'HASBASH=/usr/bin/bash');
  WslAddLine(Lines, 'NODEPATH=' + NodePath);
  if Node = 'none' then
  begin
    WslAddLine(Lines, 'NODEVER=none');
    WslAddLine(Lines, 'NPMPATH=none');
    WslAddLine(Lines, 'NPMVER=none');
  end
  else
  begin
    WslAddLine(Lines, 'NODEVER=v' + Node);
    WslAddLine(Lines, 'NPMPATH=' + WslDirOf(NodePath) + '/npm');
    WslAddLine(Lines, 'NPMVER=10.9.2');
  end;
  WslAddLine(Lines, 'NPMPREFIX=' + Prefix);
  if Switch('FAKEWSLN8N', 'none') = 'none' then
  begin
    WslAddLine(Lines, 'N8NPATH=none');
    WslAddLine(Lines, 'N8NVER=none');
  end
  else
  begin
    WslAddLine(Lines, 'N8NPATH=/usr/bin/n8n');
    WslAddLine(Lines, 'N8NVER=' + Switch('FAKEWSLN8N', 'none'));
  end;
end;

// Who runs npm, and where Node.js lives. These are the rules of the old batch installer:
//   - a Node.js (or npm prefix) in a user's home folder, or managed by nvm, is installed into as that user;
//     a root-owned tree must never appear in it
//   - everything else is a system-wide Node.js, and is installed into as root
//   - when the default user is root, root it is
procedure WslWorkOutRoles;
var
  Extra: String;
begin
  GWslAsRoot := True;
  if Copy(GWslNpmPrefix, 1, 6) = '/home/' then GWslAsRoot := False;
  if WslIsNvmPath(GWslNpmPrefix) then GWslAsRoot := False;
  GWslIsNvm := WslIsNvmPath(GWslNodePath);
  if GWslUser = 'root' then GWslAsRoot := True;
  if GWslNodePath = 'none' then
    GWslNodeBin := '/usr/local/bin'
  else
    GWslNodeBin := WslDirOf(GWslNodePath);
  GWslNodeOk := (GWslNodeVer <> 'none') and WslNodeVersionOk(GWslNodeVer);

  // npm puts the n8n command in  <prefix>/bin.  That is the folder of node nearly always, but not when
  // npm is set to use a folder of its own (like ~/.npm-global), and then that folder must be on the PATH too.
  GWslBinPath := GWslNodeBin;
  if WslSafePath(GWslNpmPrefix) then
  begin
    Extra := GWslNpmPrefix + '/bin';
    if (Extra <> GWslNodeBin) and (Extra <> '/usr/local/bin') and (Extra <> '/usr/bin') and (Extra <> '/bin') then
      GWslBinPath := GWslNodeBin + ':' + Extra;
  end;
end;

// Keeps what the probe printed. False when the distribution did not answer at all.
function WslReadAnswer(const Lines: TArrayOfString): Boolean;
begin
  GWslUser := WslValue(Lines, 'WSLUSER', '');
  GWslHome := WslValue(Lines, 'WSLHOME', '');
  if (Length(GWslHome) > 1) and (GWslHome[Length(GWslHome)] = '/') then
    Delete(GWslHome, Length(GWslHome), 1);
  GWslOsId := Lowercase(WslValue(Lines, 'OSID', 'none'));
  GWslOsLike := Lowercase(WslValue(Lines, 'OSLIKE', 'none'));
  GWslHasBash := WslValue(Lines, 'HASBASH', 'none') <> 'none';
  GWslNodePath := WslValue(Lines, 'NODEPATH', 'none');
  GWslNodeVer := WslNumber(WslValue(Lines, 'NODEVER', 'none'));
  if GWslNodeVer = '' then GWslNodeVer := 'none';
  GWslNpmPath := WslValue(Lines, 'NPMPATH', 'none');
  GWslNpmVer := WslNumber(WslValue(Lines, 'NPMVER', 'none'));
  if GWslNpmVer = '' then GWslNpmVer := 'none';
  GWslNpmPrefix := WslValue(Lines, 'NPMPREFIX', 'none');
  GWslN8nPath := WslValue(Lines, 'N8NPATH', 'none');
  GWslN8nVer := WslNumber(WslValue(Lines, 'N8NVER', 'none'));
  if GWslN8nVer = '' then GWslN8nVer := 'none';
  // Programs found on a Windows drive (the Windows PATH is behind the Linux one) are not part of Linux.
  if WslIsWindowsPath(GWslNodePath) then
  begin
    GWslNodePath := 'none';
    GWslNodeVer := 'none';
  end;
  if WslIsWindowsPath(GWslNpmPath) then
  begin
    GWslNpmPath := 'none';
    GWslNpmVer := 'none';
    GWslNpmPrefix := 'none';
  end;
  if WslIsWindowsPath(GWslN8nPath) then
  begin
    GWslN8nPath := 'none';
    GWslN8nVer := 'none';
  end;
  WslWorkOutRoles;
  Result := GWslUser <> '';
end;

// Asks the distribution about itself. False when it did not answer.
function WslAsk(const PathHint: String): Boolean;
var
  Lines: TArrayOfString;
  Code, I: Integer;
  Params: String;
begin
  Params := WslSh(GWslDistro, False, 'sh', WslProbeScript(PathHint));
  GWslAnswerText := '';
  if GDryRun then
  begin
    FileLog('(dry run) would ask: ' + WslExe + ' ' + Params);
    WslFakeAnswer(Lines);
  end
  else
  begin
    FileLog('> ' + WslExe + ' ' + Params);
    SetArrayLength(Lines, 0);
    if not CaptureTool(WslExe, Params, Lines, Code) then
      FileLog('  wsl.exe could not be started');
    for I := 0 to GetArrayLength(Lines) - 1 do
    begin
      FileLog('  ' + WslNoNul(Lines[I]));
      if (I < 4) and (Trim(WslNoNul(Lines[I])) <> '') then
        GWslAnswerText := GWslAnswerText + Trim(WslNoNul(Lines[I])) + #13#10;
    end;
  end;
  Result := WslReadAnswer(Lines);
end;

// A sentence about what is wrong with the answers, or '' when they are fine to use.
function WslProblemWithAnswer: String;
begin
  Result := '';
  if GWslHome = '' then
  begin
    Result := GWslDistro + ' did not say where the home folder of ' + GWslUser + ' is. Open it once with  wsl -d ' + GWslDistro +
      '  and check that  echo $HOME  prints a folder, then run this installer again.';
    Exit;
  end;
  if not WslSafeUser(GWslUser) then
    Result := 'the Linux user name "' + GWslUser + '"'
  else if not WslSafePath(GWslHome) then
    Result := 'the home folder "' + GWslHome + '"'
  else if (GWslNodePath <> 'none') and not WslSafePath(GWslNodePath) then
    Result := 'the Node.js folder "' + GWslNodePath + '"';
  if Result <> '' then
    Result := GWslDistro + ' uses ' + Result + ', which has spaces or special characters. This installer can only use names made of ' +
      'letters, numbers and the characters  . _ -  Use another Linux distribution or another Linux user, then run this installer again.';
end;

// ---------------------------------------------------------------------------
// Node.js
// ---------------------------------------------------------------------------

// How this Linux installs packages: DEB (Debian, Ubuntu), RPM (Fedora, Red Hat), PAC (Arch),
// ZYP (openSUSE), APK (Alpine), or '' when unknown.
function WslPackageFamily: String;
begin
  Result := '';
  if (GWslOsId = 'ubuntu') or (GWslOsId = 'debian') or WslHasWord(GWslOsLike, 'debian') or WslHasWord(GWslOsLike, 'ubuntu') then
    Result := 'DEB'
  else if (GWslOsId = 'fedora') or (GWslOsId = 'rhel') or WslHasWord(GWslOsLike, 'fedora') or WslHasWord(GWslOsLike, 'rhel') then
    Result := 'RPM'
  else if GWslOsId = 'alpine' then
    Result := 'APK'
  else if GWslOsId = 'arch' then
    Result := 'PAC'
  else if (GWslOsId = 'opensuse-leap') or (GWslOsId = 'opensuse-tumbleweed') then
    Result := 'ZYP';
end;

// How Node.js 22 can be added: 'pkg' (system packages, as root), 'nvm' (as the user), or '' with
// the reason in Why. Only ways that give the 22 line are offered; this installer never adds a newer Node.js.
function WslNodeRoute(var Why: String): String;
var
  Family: String;
begin
  Result := '';
  Why := '';
  if GWslAsRoot then
  begin
    Family := WslPackageFamily;
    if (Family = 'DEB') or (Family = 'RPM') or (Family = 'PAC') or (Family = 'ZYP') then
      Result := 'pkg'
    else if Family = 'APK' then
      Why := 'Alpine Linux may give a newer Node.js than the Node.js ' + PrivateNodeLine + ' that n8n 2.x is tested with, so this installer does not add it for you.'
    else
      Why := GWslDistro + ' calls itself "' + GWslOsId + '", and this installer does not know how to add Node.js to it.';
  end
  else if GWslIsNvm and GWslHasBash then
    Result := 'nvm'
  else if GWslIsNvm then
    Why := 'The Node.js here is managed by nvm, which needs bash, and bash was not found in ' + GWslDistro + '.'
  else
    Why := 'The Node.js here lives in the home folder of ' + GWslUser + ', but nvm (the Node.js version manager) was not found there, so this installer will not touch it.';
end;

function WslNodeProblemText: String;
begin
  if GWslNodeVer = 'none' then
    Result := 'Node.js is not installed inside ' + GWslDistro + '.'
  else
    Result := GWslDistro + ' has Node.js ' + GWslNodeVer + ', which n8n 2.x does not run on.';
  Result := Result + ' n8n 2.x needs Node.js ' + PrivateNodeLine + ', or Node.js 20.19 or newer in the 20 line.';
end;

// The commands that add Node.js 22 from the system packages (run as root). Empty for an unknown family.
// The NodeSource setup script is saved to a file first, so a failed download stops the install here
// (in a pipe,  curl | bash  would carry on with the Node.js of the distribution, which is too old).
// Arch and openSUSE have a package for the 22 line itself; nodejs-lts-jod is Arch's name for it.
function WslPackageScript(const Family: String): String;
begin
  Result := WslScriptStart;
  if Family = 'DEB' then
    Result := Result + 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq && apt-get install -y -qq curl ca-certificates python3 make g++ && ' +
      'curl -fsSL https://deb.nodesource.com/setup_' + PrivateNodeLine + '.x -o /tmp/n8n-nodesource.sh && bash /tmp/n8n-nodesource.sh && apt-get install -y -qq nodejs'
  else if Family = 'RPM' then
    Result := Result + 'curl -fsSL https://rpm.nodesource.com/setup_' + PrivateNodeLine + '.x -o /tmp/n8n-nodesource.sh && bash /tmp/n8n-nodesource.sh && ' +
      'dnf install -y -q nodejs gcc-c++ make python3'
  else if Family = 'PAC' then
    Result := Result + 'pacman -Sy --noconfirm nodejs-lts-jod npm python make gcc curl ca-certificates'
  else if Family = 'ZYP' then
    Result := Result + 'zypper --non-interactive install nodejs' + PrivateNodeLine + ' npm' + PrivateNodeLine + ' python3 make gcc-c++ curl ca-certificates'
  else
    Result := '';
end;

// nvm is a shell function that needs bash (under dash it quietly fails to find versions). It keeps its
// versions in <nvm folder>/versions/node/<version>/bin/node, so the nvm folder is five levels above node.
// The default alias of nvm is left alone: the start script puts the right folder on the PATH itself.
function WslNvmHead: String;
begin
  Result := WslScriptStart + 'NR=' + WslUp(GWslNodePath, 5) + '; if [ ! -s $NR/nvm.sh ]; then NR=$HOME/.nvm; fi; ';
end;

procedure WslAddNodeWithPackages(const Family: String);
var
  Code: Integer;
begin
  Working(True);
  GQuiet := True;
  Code := RunTool(WslExe, WslSh(GWslDistro, True, 'sh', WslPackageScript(Family)), '');
  GQuiet := False;
  Working(False);
  if Code <> 0 then
    Fail('Linux could not install Node.js ' + PrivateNodeLine + ' inside ' + GWslDistro + ' (exit code ' + IntToStr(Code) + ').' + #13#10#13#10 + WslLastLines);
  GWslPathHint := '/usr/bin';
end;

// nvm looks Node.js versions up in a list that it downloads from nodejs.org, and it tells curl to say nothing when that
// download fails, so all it then says is  Version '22' not found  (exit code 3), as if there were no such version.
// This asks the same question again with the messages switched on. It prints NETTOOL (curl, wget or none), NETCODE
// (0 = the list can be downloaded) and NETSAID (what the tool said when it could not).
function WslNodejsOrgScript: String;
begin
  Result := 'set -f; ' + WslScriptStart +
    'if command -v curl >/dev/null 2>&1; then T=curl; R=$(curl -fsS -L --max-time 20 -o /dev/null https://nodejs.org/dist/index.tab 2>&1); C=$?; ' +
    'elif command -v wget >/dev/null 2>&1; then T=wget; R=$(wget -nv -T 20 -t 1 -O /dev/null https://nodejs.org/dist/index.tab 2>&1); C=$?; ' +
    'else T=none; R=; C=127; fi; ' +
    'echo NETTOOL=$T; echo NETCODE=$C; echo NETSAID=$R';
end;

// Sentences about why nvm could not find the version, or '' when that cannot be told. Run after nvm has failed.
function WslNvmWhy: String;
var
  Lines: TArrayOfString;
  Code, I: Integer;
  Params, Tool, Said, Fake, TryIt: String;
begin
  Result := '';
  Params := WslSh(GWslDistro, False, 'sh', WslNodejsOrgScript);
  SetArrayLength(Lines, 0);
  if GDryRun then
  begin
    FileLog('(dry run) would ask: ' + WslExe + ' ' + Params);
    Fake := Switch('FAKEWSLNET', 'ok');
    if Fake = 'ok' then
    begin
      WslAddLine(Lines, 'NETTOOL=curl');
      WslAddLine(Lines, 'NETCODE=0');
    end
    else if Fake = 'none' then
    begin
      WslAddLine(Lines, 'NETTOOL=none');
      WslAddLine(Lines, 'NETCODE=127');
    end
    else
    begin
      WslAddLine(Lines, 'NETTOOL=curl');
      WslAddLine(Lines, 'NETCODE=6');
      WslAddLine(Lines, 'NETSAID=' + Fake);
    end;
  end
  else
  begin
    FileLog('> ' + WslExe + ' ' + Params);
    if not CaptureTool(WslExe, Params, Lines, Code) then
      FileLog('  wsl.exe could not be started');
    for I := 0 to GetArrayLength(Lines) - 1 do
      FileLog('  ' + WslNoNul(Lines[I]));
  end;

  Tool := WslValue(Lines, 'NETTOOL', '');
  Code := StrToIntDef(WslValue(Lines, 'NETCODE', ''), -1);
  Said := EndOf(WslValue(Lines, 'NETSAID', ''), 300);
  if (Tool = 'curl') and (Copy(Said, 1, 6) = 'curl: ') then Delete(Said, 1, 6);
  if (Tool = 'wget') and (Copy(Said, 1, 6) = 'wget: ') then Delete(Said, 1, 6);
  if Tool = 'wget' then
    TryIt := 'wget --spider https://nodejs.org'
  else
    TryIt := 'curl -I https://nodejs.org';
  TryIt := 'Open ' + GWslDistro + ' (type  wsl -d ' + GWslDistro + '  in a terminal) and try  ' + TryIt + '  there. ' +
    'When that works, run this installer again.';

  if Tool = 'none' then
    Result := GWslDistro + ' has neither curl nor wget, and nvm needs one of them to download Node.js. ' +
      'Install one inside ' + GWslDistro + ' (for example with  sudo apt install curl ), then run this installer again.'
  else if (Tool <> '') and (Code = 0) then
    Result := GWslDistro + ' can download from nodejs.org, so the problem is something else. The lines above are what nvm said. ' +
      'To see more, open ' + GWslDistro + ' (type  wsl -d ' + GWslDistro + '  in a terminal), run  nvm install ' + PrivateNodeLine + '  there, and run this installer again.'
  else if (Tool <> '') and (Code > 0) then
  begin
    Result := GWslDistro + ' could not download the list of Node.js versions from nodejs.org, which nvm (the Node.js version manager) ' +
      'needs to find Node.js ' + PrivateNodeLine + '. ';
    if Said <> '' then
      Result := Result + Tool + ' said: ' + AsSentence(Said) + ' '
    else
      Result := Result + Tool + ' ended with code ' + IntToStr(Code) + ' and said nothing. ';
    Result := Result + TryIt;
  end;
end;

// The text for the case that the nvm program itself was not where the Node.js of the user says it is.
function WslNvmMissingText: String;
var
  Where: String;
begin
  Where := WslUp(GWslNodePath, 5);
  if Where <> GWslHome + '/.nvm' then
    Where := Where + ' or in ' + GWslHome + '/.nvm';
  Result := 'The Node.js of ' + GWslUser + ' is managed by nvm, but the program of nvm (nvm.sh) was not found in ' + Where + '. ' +
    'Install Node.js ' + PrivateNodeLine + ' yourself (see nodejs.org), then run this installer again.';
end;

procedure WslAddNodeWithNvm;
var
  Code: Integer;
  Lines: TArrayOfString;
  Params, Bin, Head: String;
begin
  Working(True);
  GQuiet := True;
  Code := RunTool(WslExe, WslSh(GWslDistro, False, 'bash',
    WslNvmHead + 'if [ -s $NR/nvm.sh ]; then . $NR/nvm.sh; nvm install ' + PrivateNodeLine + '; else echo NVM_SCRIPT_NOT_FOUND; exit 1; fi'), '');
  GQuiet := False;
  Working(False);
  if Code <> 0 then
  begin
    Head := 'nvm could not install Node.js ' + PrivateNodeLine + ' for ' + GWslUser + ' inside ' + GWslDistro + ' (exit code ' + IntToStr(Code) + ').' + #13#10#13#10;
    if Pos('NVM_SCRIPT_NOT_FOUND', WslLastLines) > 0 then
      Fail(Head + WslNvmMissingText)
    else
      Fail(Head + WslLastLines + #13#10 + WslNvmWhy);
  end;

  // nvm only changes the PATH of interactive shells, so ask it where the new version went.
  Params := WslSh(GWslDistro, False, 'bash',
    WslNvmHead + '. $NR/nvm.sh >/dev/null 2>&1; NW=$(nvm which ' + PrivateNodeLine + ' 2>/dev/null); ' +
    'case $NW in /*) echo NVMBIN=$(dirname $NW);; *) echo NVMBIN=none;; esac');
  if GDryRun then
  begin
    FileLog('(dry run) would ask: ' + WslExe + ' ' + Params);
    Bin := GWslHome + '/.nvm/versions/node/v22.20.0/bin';
  end
  else
  begin
    FileLog('> ' + WslExe + ' ' + Params);
    Bin := 'none';
    if CaptureTool(WslExe, Params, Lines, Code) then
      Bin := WslValue(Lines, 'NVMBIN', 'none');
  end;
  if not WslSafePath(Bin) then
    Fail('nvm installed Node.js ' + PrivateNodeLine + ', but its folder could not be found.' + #13#10#13#10 +
      'Open ' + GWslDistro + ' (type  wsl -d ' + GWslDistro + '  in a terminal), check that  nvm which ' + PrivateNodeLine + '  works, then run this installer again.');
  GWslPathHint := Bin;
end;

// Makes sure the distribution has a Node.js that n8n 2.x runs on, and npm.
procedure WslEnsureNode;
var
  Route, Why, Family: String;
begin
  if GWslNodeVer = 'none' then
    LogLine('Node.js: not found inside ' + GWslDistro)
  else
    LogLine('Node.js ' + GWslNodeVer + '  (npm ' + GWslNpmVer + ')  at ' + GWslNodePath);

  if GWslNodeOk then
  begin
    if GWslNpmVer = 'none' then
      Fail('Node.js ' + GWslNodeVer + ' is installed inside ' + GWslDistro + ', but npm, which installs n8n, was not found next to it.' + #13#10#13#10 +
        'Install npm inside ' + GWslDistro + ', then run this installer again.');
    Exit;
  end;

  Route := WslNodeRoute(Why);
  if Route = '' then
    Fail(WslNodeProblemText + #13#10#13#10 + Why + #13#10#13#10 +
      'Install Node.js ' + PrivateNodeLine + ' inside ' + GWslDistro + ' yourself (see nodejs.org), then run this installer again. ' +
      'You can also choose another Linux distribution, or another way to run n8n.');

  Family := WslPackageFamily;
  Step('Adding Node.js ' + PrivateNodeLine + ' to ' + GWslDistro + '. This takes a few minutes and uses the internet.');
  LogLine(WslNodeProblemText);
  if Route = 'nvm' then
  begin
    LogLine('Node.js ' + PrivateNodeLine + ' is added with nvm for ' + GWslUser + '. Your other Node.js versions are kept.');
    WslAddNodeWithNvm;
  end
  else
  begin
    LogLine('Node.js ' + PrivateNodeLine + ' is added system-wide, as root, from the ' + Family + ' packages.');
    WslAddNodeWithPackages(Family);
  end;
  GWslNodeAdded := True;

  Step('Looking inside ' + GWslDistro + ' again');
  if not WslAsk(GWslPathHint) then
    Fail('Could not run commands inside ' + GWslDistro + ' after adding Node.js. Try  wsl -d ' + GWslDistro + '  in a terminal, then run this installer again.');
  if GWslNodeVer = 'none' then
    LogLine('Node.js: still not found')
  else
    LogLine('Node.js ' + GWslNodeVer + '  (npm ' + GWslNpmVer + ')  at ' + GWslNodePath);
  if not GWslNodeOk then
  begin
    if GWslNodeVer = 'none' then
      Fail('Node.js ' + PrivateNodeLine + ' was added, but ' + GWslDistro + ' still cannot find a Node.js.' + #13#10#13#10 +
        'Open ' + GWslDistro + ' (type  wsl -d ' + GWslDistro + '  in a terminal), check that  node -v  works, then run this installer again.')
    else
      Fail('Node.js ' + PrivateNodeLine + ' was added, but ' + GWslDistro + ' still uses Node.js ' + GWslNodeVer + ', which n8n 2.x does not run on.' + #13#10#13#10 +
        'Another Node.js is probably found before the new one. Remove the other one, or make Node.js ' + PrivateNodeLine +
        ' the one that is used, then run this installer again.');
  end;
  if GWslNpmVer = 'none' then
    Fail('Node.js ' + GWslNodeVer + ' is installed inside ' + GWslDistro + ', but npm, which installs n8n, was not found next to it.' + #13#10#13#10 +
      'Install npm inside ' + GWslDistro + ', then run this installer again.');
end;

// ---------------------------------------------------------------------------
// n8n itself
// ---------------------------------------------------------------------------

procedure WslInstallN8n;
var
  Code: Integer;
begin
  Step('Installing n8n inside ' + GWslDistro + '. This takes a few minutes and uses the internet.');
  if GWslAsRoot then
    LogLine('n8n is installed with root rights, for the whole of ' + GWslDistro + '. It runs as ' + GWslUser + '.')
  else
    LogLine('n8n is installed for ' + GWslUser + ' only (the Node.js here belongs to that user). It runs as ' + GWslUser + '.');
  Working(True);
  GQuiet := True;
  // --allow-scripts lets npm run the one install script that gives n8n its database; npm 12 blocks it otherwise.
  Code := RunTool(WslExe, WslSh(GWslDistro, GWslAsRoot, 'sh',
    WslNpmScript(GWslBinPath, 'install -g ' + N8nNpmSpec + ' --allow-scripts=sqlite3 --no-fund --no-audit --loglevel=http')), '');
  GQuiet := False;
  Working(False);
  if Code <> 0 then
    Fail('npm could not install n8n inside ' + GWslDistro + ' (exit code ' + IntToStr(Code) + ').' + #13#10#13#10 + WslLastLines);
end;

// Runs  n8n --version  the way the start script will. True when it works; then Version is the version
// and GWslN8nExe the file the start script runs (and the stop script looks for).
function WslCheckN8n(var Version: String): Boolean;
var
  Lines: TArrayOfString;
  Code: Integer;
  Params, Found: String;
begin
  Result := False;
  Version := '';
  GWslN8nExe := '';
  Params := WslSh(GWslDistro, False, 'sh', WslScriptStart + WslPathLine(GWslBinPath) +
    'NB=$(command -v n8n 2>/dev/null); echo N8NPATH=${NB:-none}; echo N8NVER=$(n8n --version 2>/dev/null || echo none)');
  if GDryRun then
  begin
    FileLog('(dry run) would ask: ' + WslExe + ' ' + Params);
    GWslN8nExe := GWslNodeBin + '/n8n';
    Version := DockerFallbackTag;
    Result := True;
    Exit;
  end;
  FileLog('> ' + WslExe + ' ' + Params);
  if not CaptureTool(WslExe, Params, Lines, Code) then Exit;
  Found := WslValue(Lines, 'N8NPATH', 'none');
  Version := WslNumber(WslValue(Lines, 'N8NVER', ''));
  if (Version = '') or not WslSafePath(Found) or WslIsWindowsPath(Found) then
  begin
    Version := '';
    Exit;
  end;
  GWslN8nExe := Found;
  Result := True;
end;

// For the check before the install starts: the n8n that is already inside the chosen distribution,
// like  2.40.0 (/usr/bin/n8n),  or '' when there is none (or Linux does not answer).
function WslExistingN8nText: String;
begin
  Result := '';
  GWslDistro := Cfg.WslDistro;
  if not IsSafeName(GWslDistro) then Exit;
  if not GDryRun and not FileExists(WslExe) then Exit;
  if not WslAsk('/usr/local/bin') then Exit;
  if GWslN8nPath <> 'none' then
  begin
    if GWslN8nVer = 'none' then
      Result := GWslN8nPath
    else
      Result := GWslN8nVer + ' (' + GWslN8nPath + ')';
  end;
end;

// ---------------------------------------------------------------------------
// The start and stop scripts, and the values the readme needs
// ---------------------------------------------------------------------------

// Called by SetCommonVars when the method is Linux (WSL2), so the readme and the scripts get these values too.
procedure SetWslVars;
begin
  SetVar('WSL_USER', GWslUser);
  SetVar('WSL_HOME', GWslHome);
  SetVar('WSL_DATA', GWslHome + '/.n8n');
  SetVar('WSL_DATA_WIN', WslWinDataPath(Cfg.WslDistro, GWslHome));
  SetVar('WSL_NODE', GWslNodeVer);
  SetVar('WSL_NPM', GWslNpmVer);
  SetVar('WSL_PATH', WslRunPath(GWslBinPath));
  if GWslN8nExe <> '' then
    SetVar('WSL_N8N', GWslN8nExe)
  else
    SetVar('WSL_N8N', GWslNodeBin + '/n8n');
  SetVar('NPM_SPEC', N8nNpmSpec);
  if GWslAsRoot then
  begin
    SetVar('WSL_SU', ' -u root');
    SetVar('WSL_RUNAS', 'with root rights, for the whole distribution');
  end
  else
  begin
    SetVar('WSL_SU', '');
    SetVar('WSL_RUNAS', 'for the Linux user ' + GWslUser + ' only');
  end;
  // WSL2 passes the port on to Windows only when n8n listens on an IPv4 address of the virtual machine (0.0.0.0),
  // and that machine sits behind Windows. WSL1 shares the network of Windows, where 0.0.0.0 would be open to the
  // whole network, so there n8n listens on this computer only (unless other devices were asked for).
  if GWslV1 then
    SetVar('WSL_LISTEN', ListenAddress)
  else
    SetVar('WSL_LISTEN', '0.0.0.0');
  // Other devices open n8n over plain http, so the login cookie cannot be marked secure.
  if Cfg.Lan then
    SetVar('WSL_COOKIE', 'export N8N_SECURE_COOKIE=false;')
  else
    SetVar('WSL_COOKIE', '');
end;

procedure WriteWslLaunchers;
begin
  Step('Creating the Start n8n and Stop n8n shortcuts');
  SetCommonVars;      // for the Linux method this also calls SetWslVars
  WriteFromTemplate('start-wsl.cmd', AppDir + '\start-n8n.cmd');
  WriteFromTemplate('stop-wsl.cmd', AppDir + '\stop-n8n.cmd');
end;

// A few lines for the "Ready to Install" summary: what is going to happen inside Linux.
// (The wizard has not looked inside yet, so these are the things that may happen.)
function WslReadyNote(const Space, NewLine: String): String;
begin
  Result := 'Inside ' + Cfg.WslDistro + ' this installer will:' + NewLine +
    Space + '- add Node.js ' + PrivateNodeLine + ' if there is no Node.js that n8n 2.x runs on (with nvm when your Node.js comes from nvm, otherwise system-wide with root rights; this uses the internet)' + NewLine +
    Space + '- install the newest n8n 2.x. An n8n that is already there is replaced; your workflows and settings are kept' + NewLine;
  if WslDistroIsV1(Cfg.WslDistro) then
    Result := Result + Space + '- Note: ' + Cfg.WslDistro + ' runs on WSL 1, which is slow and often fails with n8n' + NewLine;
end;

// ---------------------------------------------------------------------------
// The install
// ---------------------------------------------------------------------------

// Which distribution, and is it fit to use? Fails with a sentence about what to do.
procedure WslChooseDistro;
var
  I: Integer;
  Names: String;
begin
  if not GDryRun and not FileExists(WslExe) then
    Fail('Windows Subsystem for Linux (WSL) was not found on this computer, so n8n cannot be installed inside Linux. Choose another way to run n8n.');

  GWslDistro := Cfg.WslDistro;
  // A silent install names its distribution with /WSLDISTRO=. A name that is not in the list must not
  // quietly turn into another distribution.
  if WizardSilent and (GWantDistro <> '') and (CompareText(GWantDistro, GWslDistro) <> 0) then
  begin
    Names := '';
    for I := 0 to GWslCount - 1 do
    begin
      if Names <> '' then Names := Names + ', ';
      Names := Names + GWslName[I];
    end;
    Fail('The Linux distribution "' + GWantDistro + '" (from /WSLDISTRO=) was not found.' + #13#10#13#10 +
      'These are available: ' + Names + '. Use one of those names.');
  end;
  if GWslDistro = '' then
    Fail('No Linux distribution was chosen. Choose one in the installer, or give its name with /WSLDISTRO=name, then run the installer again.');
  if not IsSafeName(GWslDistro) then
    Fail('The Linux distribution "' + GWslDistro + '" has a name with spaces or special characters, and wsl.exe cannot be asked to use it from here.' + #13#10#13#10 +
      'Choose another distribution, or import it again under a simpler name (letters, numbers and dashes only) with  wsl --export  and  wsl --import,  ' +
      'then run this installer again.');

  GWslV1 := WslDistroIsV1(GWslDistro);
  if GWslV1 then
    LogLine('Note: ' + GWslDistro + ' runs on WSL 1, which is slow and often fails with n8n. If n8n does not start, convert it with the command  wsl --set-version ' +
      GWslDistro + ' 2');
end;

procedure InstallWsl;
var
  Version, Problem, Earlier: String;
begin
  GWslNodeAdded := False;
  GWslPathHint := '/usr/local/bin';

  Step('Checking the Linux distribution');
  WslChooseDistro;
  LogLine('Linux distribution: ' + GWslDistro);
  // The record of this folder can name only one distribution, and the uninstaller removes n8n from that one.
  Earlier := LoadState('wsl_distro', '');
  if (Earlier <> '') and (CompareText(Earlier, GWslDistro) <> 0) then
    LogLine('Note: this folder was set up for ' + Earlier + ' before. The n8n inside ' + Earlier +
      ' stays there. The uninstaller of this folder only removes the n8n inside ' + GWslDistro + '.');

  Step('Looking inside ' + GWslDistro + ' (this takes a few seconds, longer if it is stopped)');
  if not WslAsk(GWslPathHint) then
  begin
    Problem := '';
    if GWslAnswerText <> '' then
      Problem := 'wsl.exe said:' + #13#10 + GWslAnswerText + #13#10;
    Fail('Could not run commands inside ' + GWslDistro + '.' + #13#10#13#10 + Problem +
      'Open a terminal, type  wsl -d ' + GWslDistro + '  to start it once, check that it works, then run this installer again.');
  end;
  Problem := WslProblemWithAnswer;
  if Problem <> '' then
    Fail(Problem);
  LogLine('Linux user: ' + GWslUser + '   Home folder: ' + GWslHome + '   System: ' + GWslOsId);
  if WslIsWindowsPath(GWslHome) then
    LogLine('Warning: the home folder is on a Windows drive. n8n keeps its database there, and SQLite locks up and is very slow on a Windows drive.');

  WslEnsureNode;

  if GWslN8nPath <> 'none' then
    LogLine('n8n ' + GWslN8nVer + ' is already installed inside ' + GWslDistro + ' (' + GWslN8nPath + '). ' +
      'It is replaced by the newest n8n 2.x. Your workflows and settings are kept.');

  WslInstallN8n;

  Step('Checking that n8n works inside ' + GWslDistro);
  if not WslCheckN8n(Version) then
    Fail('npm finished, but the n8n command was not found inside ' + GWslDistro + '.' + #13#10#13#10 +
      'The log of this install has the details. Try  wsl -d ' + GWslDistro + '  and look for n8n there.');
  GN8nVersion := Version;
  LogLine('n8n ' + Version + ' is installed inside ' + GWslDistro + '  (' + GWslN8nExe + ').');

  WriteWslLaunchers;
end;

// What the uninstaller needs to find this install again.
procedure SaveWslState;
begin
  SaveState('wsl_distro', GWslDistro);
  SaveState('wsl_user', GWslUser);
  SaveState('wsl_home', GWslHome);
  SaveState('wsl_data', GWslHome + '/.n8n');
  SaveState('wsl_binpath', GWslBinPath);
  SaveState('wsl_n8n', GWslN8nExe);
  SaveState('wsl_root', B2S(GWslAsRoot));
  SaveState('wsl_node', GWslNodeVer);
end;

// ---------------------------------------------------------------------------
// Taking it away again. Runs inside the uninstaller: no wizard, no setup-only files.
// ---------------------------------------------------------------------------

// Can the distribution still be reached? (The user may have removed it from WSL meanwhile.)
function WslReachable(const Distro: String): Boolean;
var
  Lines: TArrayOfString;
  Code: Integer;
begin
  Result := GDryRun;
  if GDryRun then Exit;
  if CaptureTool(WslExe, WslSh(Distro, False, 'sh', 'echo N8NWSL=ok'), Lines, Code) then
    Result := WslValue(Lines, 'N8NWSL', '') = 'ok';
end;

function WslFolderExists(const Distro, Folder: String): Boolean;
var
  Lines: TArrayOfString;
  Code: Integer;
begin
  Result := GDryRun;
  if GDryRun then Exit;
  if CaptureTool(WslExe, WslSh(Distro, False, 'sh', 'if [ -d ' + Folder + ' ]; then echo N8NDIR=yes; else echo N8NDIR=no; fi'), Lines, Code) then
    Result := WslValue(Lines, 'N8NDIR', '') = 'yes'
  else
    Result := False;
end;

// Copies the data folder to a new folder on the Desktop. Returns that folder, or '' when it did not work.
function WslBackupData(const Distro, Home: String): String;
var
  Target: String;
  Code: Integer;
begin
  Result := '';
  Target := ExpandConstant('{userdesktop}') + '\n8n-backup-' + Distro + '-' + GetDateTimeString('yyyymmdd-hhnnss', '-', ':');
  // robocopy says 0 to 7 when the copy worked, 8 and up when something was not copied.
  Code := RunTool(ExpandConstant('{sys}\robocopy.exe'), Q(WslWinDataPath(Distro, Home)) + ' ' + Q(Target) + ' /E /R:1 /W:1 /NFL /NDL /NP', '');
  if (Code >= 0) and (Code < 8) and (DirExists(Target) or GDryRun) then
    Result := Target;
end;

// Removes n8n from the distribution. DeleteData: the user chose to delete the workflows and settings too
// (an interactive uninstall offers a copy on the Desktop first, and nothing is deleted if that copy fails).
// KeptNote says where the data stays.
procedure UninstallWslRun(const DeleteData: Boolean; var KeptNote: String);
var
  Distro, Home, N8nExe, Data, Backup, First, Rest: String;
  AsRoot, HaveData, DoDelete, WantBackup: Boolean;
  Code, Answer: Integer;
begin
  Distro := LoadState('wsl_distro', '');
  Home := LoadState('wsl_home', '');
  GWslBinPath := LoadState('wsl_binpath', '/usr/local/bin');
  N8nExe := LoadState('wsl_n8n', '');
  AsRoot := S2B(LoadState('wsl_root', '1'));
  if not IsSafeName(Distro) then
  begin
    LogLine('No Linux distribution is recorded for this install, so nothing was removed from Linux.');
    Exit;
  end;
  if not WslSafePathList(GWslBinPath) then GWslBinPath := '/usr/local/bin';
  if not WslSafePath(N8nExe) then
  begin
    SplitOnce(GWslBinPath, ':', First, Rest);
    N8nExe := First + '/n8n';
  end;
  if not GDryRun and not FileExists(WslExe) then
  begin
    LogLine('WSL is not available on this computer, so nothing was removed from ' + Distro + '.');
    Exit;
  end;
  if not WslReachable(Distro) then
  begin
    LogLine('The Linux distribution ' + Distro + ' could not be reached (it may have been removed from WSL). Nothing was removed from it.');
    Exit;
  end;

  // Matched on the full path of n8n, so another n8n in the same distribution is left running. The dot
  // stands for the space in "n8n start"; exec replaces the shell by pkill, so it cannot find itself.
  LogLine('Stopping n8n inside ' + Distro + ' (exit code 1 only means it was not running)...');
  RunTool(WslExe, WslSh(Distro, False, 'sh', 'exec pkill -f ' + N8nExe + '.start'), '');

  Data := Home + '/.n8n';
  HaveData := WslSafePath(Home) and WslFolderExists(Distro, Data);
  DoDelete := DeleteData and HaveData;

  // The copy is made after n8n has closed its database, so it is complete. The data folder is the standard one
  // of the Linux user, so another n8n that the user runs by hand in this distribution shares it: Cancel is the way out.
  WantBackup := False;
  if DoDelete and not UninstallSilent then
  begin
    Answer := SuppressibleMsgBox('Your workflows and settings are in ' + Data + ' inside ' + Distro + '. That is the standard n8n folder of the Linux user, ' +
      'so any other n8n that you run as that user inside ' + Distro + ' uses the same folder.' + #13#10#13#10 +
      'Do you want a copy of them on your Desktop before they are deleted?' + #13#10#13#10 +
      'Yes - save a copy first (recommended).' + #13#10 + 'No - delete them without a copy.' + #13#10 + 'Cancel - do not delete them.',
      mbConfirmation, MB_YESNOCANCEL or MB_DEFBUTTON1, IDYES);
    if Answer = IDCANCEL then
    begin
      DoDelete := False;
      LogLine('Deleting was cancelled, so your workflows and settings were kept.');
    end;
    WantBackup := Answer = IDYES;
  end;
  if HaveData and not GDryRun then Sleep(3000);
  if WantBackup then
  begin
    LogLine('Saving a copy of your workflows and settings on the Desktop first...');
    Backup := WslBackupData(Distro, Home);
    if Backup = '' then
    begin
      DoDelete := False;
      LogLine('The copy could not be made, so your workflows and settings were NOT deleted.');
    end
    else
      LogLine('A copy is saved in ' + Backup);
  end;

  LogLine('Removing the n8n program from ' + Distro + '...');
  Code := RunTool(WslExe, WslSh(Distro, AsRoot, 'sh', WslNpmScript(GWslBinPath, 'uninstall -g n8n --no-fund --no-audit --loglevel=error')), '');
  if Code <> 0 then
    LogLine('npm could not remove n8n (exit code ' + IntToStr(Code) + '). It can be removed later with:  npm uninstall -g n8n');

  if DoDelete then
  begin
    LogLine('Deleting ' + Data + ' inside ' + Distro + '...');
    RunTool(WslExe, '-d ' + Distro + ' --exec rm -rf ' + Data, '');
  end;
  if HaveData and (not DoDelete or (not GDryRun and WslFolderExists(Distro, Data))) then
    KeptNote := WslDataText(Distro, Home);
  LogLine('Node.js and the distribution ' + Distro + ' were not touched.');
end;
