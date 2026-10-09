// ---------------------------------------------------------------------------
// settings.iss - what the user chose, and the fixed choices of this installer
// ---------------------------------------------------------------------------

const
  MethodDocker = 'docker';
  MethodWsl    = 'wsl';
  MethodGlobal = 'global';
  MethodFolder = 'folder';

  DefaultPort = 5678;

  // Node.js 22 LTS is the line this project has tested and settled on (see CHANGELOG, v0.1.7):
  // newer Node.js lines failed to build n8n's native parts. The private Node.js that the
  // folder install downloads follows this line.
  PrivateNodeLine = '22';

  // npm installs stay on n8n 2.x. n8n 3.0 no longer publishes a runnable package to npm.
  N8nNpmSpec = 'n8n@2';

  DockerImage       = 'docker.n8n.io/n8nio/n8n';
  // Used only when Docker Hub cannot be asked which 2.x release is the newest stable one.
  // Bump it with each release of this installer.
  DockerFallbackTag = '2.42.5';

  // Docker image choices on the Docker page.
  ChannelStable2 = 0;
  ChannelNewest3 = 1;
  ChannelCustom  = 2;

type
  TConfig = record
    Method: String;
    Port: Integer;
    Lan: Boolean;                 // let other devices on the network connect
    DockerName: String;
    DockerVolume: String;
    DockerChannel: Integer;
    DockerCustomTag: String;
    DockerTz: String;
    WslDistro: String;
    AddToPath: Boolean;           // folder install: put the n8n command on the PATH
    Desktop: Boolean;             // a Start n8n shortcut on the desktop
  end;

var
  Cfg: TConfig;

// ---------------------------------------------------------------------------
// Windows time zone -> the IANA name that n8n and Docker use
// ---------------------------------------------------------------------------

function IanaTimeZone: String;
var
  Win, Table: String;
  P, E: Integer;
begin
  Result := 'UTC';
  if not RegQueryStringValue(HKLM, 'SYSTEM\CurrentControlSet\Control\TimeZoneInformation', 'TimeZoneKeyName', Win) then
    Exit;
  Win := Trim(Win);
  Table :=
    '|Pacific Standard Time=America/Los_Angeles|Mountain Standard Time=America/Denver|Central Standard Time=America/Chicago' +
    '|Eastern Standard Time=America/New_York|Atlantic Standard Time=America/Halifax|GMT Standard Time=Europe/London' +
    '|W. Europe Standard Time=Europe/Amsterdam|Central Europe Standard Time=Europe/Budapest|Central European Standard Time=Europe/Warsaw' +
    '|Romance Standard Time=Europe/Paris|FLE Standard Time=Europe/Kiev|Russian Standard Time=Europe/Moscow' +
    '|India Standard Time=Asia/Kolkata|China Standard Time=Asia/Shanghai|Tokyo Standard Time=Asia/Tokyo' +
    '|Singapore Standard Time=Asia/Singapore|AUS Eastern Standard Time=Australia/Sydney|New Zealand Standard Time=Pacific/Auckland' +
    '|Alaskan Standard Time=America/Anchorage|Hawaiian Standard Time=Pacific/Honolulu|US Mountain Standard Time=America/Phoenix' +
    '|US Eastern Standard Time=America/Indianapolis|Canada Central Standard Time=America/Regina|Newfoundland Standard Time=America/St_Johns' +
    '|Central Standard Time (Mexico)=America/Mexico_City|Mountain Standard Time (Mexico)=America/Mazatlan|Pacific Standard Time (Mexico)=America/Tijuana' +
    '|SA Pacific Standard Time=America/Bogota|SA Western Standard Time=America/La_Paz|SA Eastern Standard Time=America/Cayenne' +
    '|E. South America Standard Time=America/Sao_Paulo|Argentina Standard Time=America/Argentina/Buenos_Aires|Pacific SA Standard Time=America/Santiago' +
    '|Venezuela Standard Time=America/Caracas|Central America Standard Time=America/Guatemala|Greenwich Standard Time=Atlantic/Reykjavik' +
    '|Azores Standard Time=Atlantic/Azores|Cape Verde Standard Time=Atlantic/Cape_Verde|Morocco Standard Time=Africa/Casablanca' +
    '|W. Central Africa Standard Time=Africa/Lagos|South Africa Standard Time=Africa/Johannesburg|Egypt Standard Time=Africa/Cairo' +
    '|E. Africa Standard Time=Africa/Nairobi|Namibia Standard Time=Africa/Windhoek|GTB Standard Time=Europe/Bucharest' +
    '|E. Europe Standard Time=Europe/Chisinau|Belarus Standard Time=Europe/Minsk|Turkey Standard Time=Europe/Istanbul' +
    '|Kaliningrad Standard Time=Europe/Kaliningrad|Israel Standard Time=Asia/Jerusalem|Middle East Standard Time=Asia/Beirut' +
    '|Jordan Standard Time=Asia/Amman|Arab Standard Time=Asia/Riyadh|Arabic Standard Time=Asia/Baghdad|Arabian Standard Time=Asia/Dubai' +
    '|Iran Standard Time=Asia/Tehran|Azerbaijan Standard Time=Asia/Baku|Georgian Standard Time=Asia/Tbilisi|Caucasus Standard Time=Asia/Yerevan' +
    '|Afghanistan Standard Time=Asia/Kabul|West Asia Standard Time=Asia/Tashkent|Pakistan Standard Time=Asia/Karachi' +
    '|Sri Lanka Standard Time=Asia/Colombo|Nepal Standard Time=Asia/Kathmandu|Central Asia Standard Time=Asia/Almaty' +
    '|Bangladesh Standard Time=Asia/Dhaka|Myanmar Standard Time=Asia/Yangon|SE Asia Standard Time=Asia/Bangkok' +
    '|Taipei Standard Time=Asia/Taipei|Korea Standard Time=Asia/Seoul|W. Australia Standard Time=Australia/Perth' +
    '|AUS Central Standard Time=Australia/Darwin|Cen. Australia Standard Time=Australia/Adelaide|E. Australia Standard Time=Australia/Brisbane' +
    '|Tasmania Standard Time=Australia/Hobart|West Pacific Standard Time=Pacific/Port_Moresby|Fiji Standard Time=Pacific/Fiji' +
    '|Samoa Standard Time=Pacific/Apia|Tonga Standard Time=Pacific/Tongatapu|Ulaanbaatar Standard Time=Asia/Ulaanbaatar' +
    '|N. Central Asia Standard Time=Asia/Novosibirsk|North Asia Standard Time=Asia/Krasnoyarsk|North Asia East Standard Time=Asia/Irkutsk' +
    '|Yakutsk Standard Time=Asia/Yakutsk|Vladivostok Standard Time=Asia/Vladivostok|Ekaterinburg Standard Time=Asia/Yekaterinburg' +
    '|Magadan Standard Time=Asia/Magadan|UTC=Etc/UTC|';
  P := Pos('|' + Win + '=', Table);
  if P = 0 then Exit;
  Table := Copy(Table, P + Length(Win) + 2, Length(Table));
  E := Pos('|', Table);
  if E > 1 then
    Result := Copy(Table, 1, E - 1);
end;

// ---------------------------------------------------------------------------
// Where things go
// ---------------------------------------------------------------------------

// The address n8n answers on, as typed in a browser on this computer.
function LocalUrl(const Port: Integer): String;
begin
  Result := 'http://localhost:' + IntToStr(Port);
end;

function MethodTitle(const Method: String): String;
begin
  if Method = MethodDocker then Result := 'Docker'
  else if Method = MethodWsl then Result := 'WSL2 (Linux inside Windows)'
  else if Method = MethodGlobal then Result := 'Windows, for this user account'
  else Result := 'Windows, in its own folder';
end;

// The default install folder name for each method, so two methods never share a folder by accident.
function DefaultFolderName(const Method: String): String;
begin
  if Method = MethodDocker then Result := 'n8n-docker'
  else if Method = MethodWsl then Result := 'n8n-wsl'
  else if Method = MethodGlobal then Result := 'n8n-global'
  else Result := 'n8n';
end;

// ---------------------------------------------------------------------------
// Data folder of a global install
// ---------------------------------------------------------------------------

// Where n8n keeps its data for a global install. The old .bat installer pointed n8n at
// %USERPROFILE%\.n8n, which made n8n use %USERPROFILE%\.n8n\.n8n. Anyone who installed with
// it keeps their workflows by keeping that setting.
function GlobalUserFolder: String;
begin
  if DirExists(GetEnv('USERPROFILE') + '\.n8n\.n8n') then
    Result := '%USERPROFILE%\.n8n'
  else
    Result := '%USERPROFILE%';
end;

function GlobalDataDir: String;
begin
  if DirExists(GetEnv('USERPROFILE') + '\.n8n\.n8n') then
    Result := GetEnv('USERPROFILE') + '\.n8n\.n8n'
  else
    Result := GetEnv('USERPROFILE') + '\.n8n';
end;
