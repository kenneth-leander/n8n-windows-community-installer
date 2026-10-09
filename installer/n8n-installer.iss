; ---------------------------------------------------------------------------
; n8n Windows Community Installer
;
; One installer for every way of running n8n on Windows: Docker, WSL2 (Linux),
; a folder of its own, or the whole user account. Unofficial community project,
; not affiliated with n8n GmbH.
;
; Build:  ISCC.exe installer\n8n-installer.iss [/DAppVersion=0.3.0]
; See installer\README.md for the full build and test notes.
; ---------------------------------------------------------------------------

#ifndef AppVersion
  #define AppVersion "0.3.0-dev"
#endif
; Numeric form for the file properties (digits and dots only).
#ifndef AppVersionNumeric
  #define AppVersionNumeric "0.3.0.0"
#endif

#define AppName       "n8n"
#define AppPublisher  "kenneth-leander (unofficial community project)"
#define AppUrl        "https://github.com/kenneth-leander/n8n-windows-community-installer"

[Setup]
; The AppId ends in a short code worked out from the install folder, so every
; folder gets its own entry in Apps & features and can be removed on its own.
AppId={{3E8EFF73-81C1-46E7-B2C0-1D0164C986A5}-{code:GetInstanceId}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
VersionInfoVersion={#AppVersionNumeric}
VersionInfoDescription=n8n Windows Community Installer
VersionInfoCompany={#AppPublisher}
VersionInfoProductName=n8n Windows Community Installer
VersionInfoProductVersion={#AppVersionNumeric}
VersionInfoTextVersion={#AppVersion}
VersionInfoProductTextVersion={#AppVersion}

; Per-user install: no administrator prompt. The one step that needs one
; (installing Node.js for everybody) asks for it on its own.
PrivilegesRequired=lowest
DefaultDirName={autopf}\n8n
UsePreviousAppDir=no
UsePreviousLanguage=no
UsePreviousTasks=no
DisableProgramGroupPage=yes
DisableWelcomePage=no
DisableDirPage=no
DirExistsWarning=no
AppendDefaultDirName=no
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
SetupMutex=n8nCommunityInstallerSetup
CloseApplications=no
RestartApplications=no
ChangesEnvironment=yes

; Looks
WizardStyle=modern dynamic
WizardSizePercent=125,115
WizardImageFile=assets\wizard-side.bmp
WizardSmallImageFile=assets\wizard-small.bmp
SetupIconFile=assets\n8n.ico
UninstallDisplayIcon={app}\n8n.ico
UninstallDisplayName={code:GetUninstallDisplayName}

; Output
OutputDir=dist
OutputBaseFilename=n8n-Installer
Compression=lzma2
SolidCompression=yes
SetupLogging=yes
; Unpacking Node.js (a .7z with one big file) needs much less memory this way.
ArchiveExtraction=enhanced/nopassword

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Welcome to the n8n installer
FinishedHeadingLabel=n8n is installed
FinishedLabelNoIcons=n8n is installed on this computer.
FinishedLabel=n8n is installed on this computer.%n%nWhenever you want to use it, open "Start n8n" from your Start menu or desktop. Your workflows and settings stay on this computer.
ConfirmUninstall=Remove this n8n from your computer? You are asked next whether to keep your workflows and settings.
WelcomeLabel2=This installs n8n, the workflow automation tool, on this computer.%n%nIt is an unofficial community installer. It is not made by n8n GmbH and has no connection to them.%n%nIt takes a few minutes, and you do not need to be an administrator.

[Files]
; Shipped with the install, used by the Start n8n shortcut
Source: "assets\n8n.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "scripts\wait-n8n.ps1"; DestDir: "{app}\support"; Flags: ignoreversion

; Used by the installer itself while it runs (unpacked on demand into the setup's temporary folder)
Source: "scripts\*.ps1"; Flags: dontcopy
Source: "templates\*"; Flags: dontcopy

[Icons]
Name: "{autoprograms}\{code:GetGroupName}\Start n8n"; Filename: "{app}\start-n8n.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\n8n.ico"; Comment: "Starts n8n and opens it in your web browser"
Name: "{autoprograms}\{code:GetGroupName}\Open n8n in my web browser"; Filename: "{code:OpenAddress}"; IconFilename: "{app}\n8n.ico"
Name: "{autoprograms}\{code:GetGroupName}\Stop n8n"; Filename: "{app}\stop-n8n.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\n8n.ico"; Check: IsDockerInstall
Name: "{autoprograms}\{code:GetGroupName}\The n8n folder"; Filename: "{app}"
Name: "{autoprograms}\{code:GetGroupName}\Read me"; Filename: "{app}\README.txt"
Name: "{autoprograms}\{code:GetGroupName}\Uninstall n8n"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Start n8n"; Filename: "{app}\start-n8n.cmd"; WorkingDir: "{app}"; IconFilename: "{app}\n8n.ico"; Comment: "Starts n8n and opens it in your web browser"; Check: WantDesktop

[UninstallDelete]
; The note this install keeps about itself is written by the install code, so Setup does not know about it.
Type: files; Name: "{app}\n8n-installer.ini"

[Run]
Filename: "{app}\start-n8n.cmd"; Description: "Start n8n and open it in my web browser"; WorkingDir: "{app}"; Flags: postinstall nowait skipifsilent shellexec

[Code]
#include "code\util.iss"
#include "code\run.iss"
#include "code\settings.iss"
#include "code\detect.iss"
#include "code\pages.iss"
#include "code\install.iss"
#include "code\folder.iss"
#include "code\global.iss"
#include "code\docker.iss"
#include "code\wsl.iss"
#include "code\uninstall.iss"
#include "code\events.iss"
