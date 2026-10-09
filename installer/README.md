# The n8n Windows Community Installer (the `.exe`)

This folder holds the source of the Windows installer. It is built with [Inno Setup](https://jrsoftware.org/isinfo.php)
by GitHub Actions (see `.github/workflows/installer.yml`) and replaces the old `n8n-Installer.bat`.

One window, four ways of running n8n (the same four the `.bat` had):

| Way | What it does | Stays on |
|---|---|---|
| **Docker** | Runs n8n in a Docker container. The only way that keeps working with n8n 3.0. | n8n 2.x, or the 3 preview |
| **Windows, in a folder of its own** | Downloads Node.js 22 into the install folder and installs n8n next to it. Needs nothing else on the computer. | n8n 2.x |
| **Windows, for this user account** | Adds n8n to the Node.js that is already installed (`npm install -g`). | n8n 2.x |
| **Linux inside Windows (WSL2)** | Installs n8n inside a WSL2 distribution you already have. | n8n 2.x |

*Express* picks Docker when Docker is running and the folder install otherwise. *Custom* lets you choose
the way, folder, port, whether other devices on the network may connect, and the Docker settings.

## What gets installed

Everything goes into one install folder (default `%LOCALAPPDATA%\Programs\n8n`, `n8n-docker`, `n8n-global`
or `n8n-wsl`, depending on the way). No administrator rights are needed.

```
start-n8n.cmd      starts n8n and opens it in the browser (the Start menu shortcut runs this)
stop-n8n.cmd       Docker and WSL2 only
n8n-env.cmd        the settings of this install (port, who can connect); edit it with Notepad
n8n-installer.ini  what the uninstaller needs to know about this install
README.txt         notes for the person who installed
unins000.exe       the uninstaller (also listed in Windows Settings, Apps)
```

Every install folder is its own install: the entry in *Apps & features* is derived from the folder, so
you can have several side by side (for example two ports) and remove each one on its own.
Installing again into the same folder updates it and keeps the data.

By default n8n listens on `127.0.0.1` only. "Let other devices on my network open n8n" switches it to
`0.0.0.0`.

Where the data (workflows, saved passwords, the encryption key) lives:

| Way | Data |
|---|---|
| Docker | the Docker volume (default `n8n_data`) |
| Folder | `<install folder>\.n8n` |
| User account | `%USERPROFILE%\.n8n` (or `%USERPROFILE%\.n8n\.n8n` when an install made by the old `.bat` is found) |
| WSL2 | inside the Linux distribution |

The uninstaller asks whether to keep the data and keeps it by default.

## Linux inside Windows (WSL2)

The installer does not set up WSL or a Linux distribution. It uses one you already have (`wsl --install -d Ubuntu`
in a terminal sets one up). Inside it, it:

* looks around: the default Linux user, its home folder, which Linux it is, and which Node.js is there
* adds Node.js 22 when there is no Node.js that n8n 2.x runs on (Node.js 22, or 20.19 and newer in the 20 line):
  from the system packages as root (Debian and Ubuntu, Fedora and Red Hat, Arch, openSUSE), or with nvm when the
  Node.js belongs to a user and is managed by nvm. On any other Linux (Alpine, for example) it stops and says what
  to install by hand
* installs the newest n8n 2.x with `npm install -g`: as root when Node.js is installed for the whole system, as the
  user when Node.js lives in the user's home folder
* writes `start-n8n.cmd` and `stop-n8n.cmd` in the install folder, because n8n keeps running inside Linux when the
  window that started it is gone

n8n keeps its data on the Linux disk, in `.n8n` in the home folder of the default user (File Explorer shows it at
`\\wsl$\<distribution>\home\<user>\.n8n`). Windows passes n8n on to this computer only, so "other devices on my
network" is not offered for this way. Uninstalling removes the n8n program from the distribution, keeps the data
unless you ask for it to be deleted (then you are offered a copy on the desktop first), and does not touch Node.js
or the distribution.

## Silent install

```
n8n-Installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /METHOD=folder /PORT=5678
```

`/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /DIR= /LOG=` are Inno Setup's own switches
([documentation](https://jrsoftware.org/ishelp/index.php?topic=setupcmdline)). Ours:

| Switch | Meaning |
|---|---|
| `/METHOD=docker\|folder\|global\|wsl` | the way to install. Without it a silent install does what Express does. |
| `/PORT=5678` | the port n8n answers on (it also uses the next one) |
| `/LAN=1` | let other devices on the network connect |
| `/DESKTOP=1` | put a Start n8n shortcut on the desktop (off for silent installs) |
| `/ADDPATH=1` | folder install only: let `n8n` be typed in any terminal |
| `/DOCKERNAME=` `/DOCKERVOLUME=` `/DOCKERTAG=` `/DOCKERVERSION=3` `/TZ=` | Docker settings |
| `/WSLDISTRO=Ubuntu` | the WSL2 distribution |

A silent install checks everything first and ends with a non-zero exit code (and a line in the log) when
something is wrong, instead of waiting for someone to answer: `1` means something about the settings or the
computer has to change first (a question that would need a yes, like replacing a Docker container or using a
folder that holds other files, counts as a no), `3` means the install started and failed. The uninstaller takes
`/DELETEDATA=1` to delete the data as well.

Logs are written to `%LOCALAPPDATA%\n8n-installer\logs`.

## Building

You need Inno Setup 6.7 or newer. Then:

```
ISCC.exe installer\n8n-installer.iss
```

The installer is written to `installer\dist\n8n-Installer.exe`. GitHub Actions does the same with a pinned,
checksum-verified copy of the compiler, and uploads the result as an artifact.

```
n8n-installer.iss   the main script: settings, files, shortcuts
code\               the wizard and the install logic, one file per part (Inno Setup Pascal Script)
scripts\            PowerShell helpers that ship inside the installer
templates\          the launchers and the notes that are written into the install folder
assets\             icon and wizard pictures
tests\              Test-Install.ps1, the end to end test that CI runs
```

## Testing

* **GitHub Actions** builds the installer and then, on real Windows computers, runs `tests\Test-Install.ps1`
  for the folder way and for the user-account way: install, start n8n, wait until it answers, stop it,
  install again over it (the data must stay), uninstall (keep the data), install, uninstall and delete the data.
  It also runs the PowerShell helpers on Windows PowerShell 5.1 and asks Docker Hub for the n8n versions.
  The test installs on drive D: and keeps npm's download cache there: the system drive (C:) of GitHub's Windows
  computers is so slow for the thousands of small files npm writes that n8n needs more than 20 minutes to install
  on it (with or without this installer), against about 6 minutes on D:. While the installer runs, the test says
  every minute which programs it started and what the installer's log says, and it stops an installer that takes
  longer than 25 minutes, so a stuck run still ends with logs.
* **Docker and WSL2 cannot run on GitHub's computers.** There, `tests\Test-DryRun.ps1` runs the installer and the
  uninstaller in test mode for every way and checks which commands they would start (the Docker command line,
  the names, the ports, what is removed again). To test them for real, use a computer that has them:
  `powershell -File installer\tests\Test-Install.ps1 -Installer .\n8n-Installer.exe -Method docker -Dir C:\n8n-test-docker`
  (or `-Method wsl -WslDistro Ubuntu`), and click through the wizard once.
* **Test mode.** `/DRYRUN` walks through an install without changing anything (the install folder only gets the
  uninstaller and a note about the install, so the uninstaller can be tried). With it, `/FAKEDOCKER=ready|windows|stopped|missing`,
  `/FAKENODE=22.11.0` and `/FAKEWSL="Ubuntu|2|Running;Debian|1|Stopped"` pretend to have found those things,
  `/DRYRUN=fail` makes every program the installer would start fail, `/SLOW=3` makes every step take 3 seconds, and
  `/SHOWFILES` prints the start script and the notes it would write, with every setting filled in. For the WSL2 way
  they also pretend what Linux answers: `/FAKEWSLUSER=ken` (or `root`), `/FAKEWSLOS=ubuntu` (`fedora`, `alpine`, ...),
  `/FAKEWSLNODE=22.11.0` (`none`, `18.19.1`), `/FAKEWSLNVM` (Node.js sits in the nvm folder of the user),
  `/FAKEWSLPREFIX=/home/ken/.npm-global`, `/FAKEWSLN8N=2.40.0` (an n8n is there already) and `/FAKEWSLSTUCK`
  (adding Node.js changes nothing).
  These are only honoured together with `/DRYRUN`. The uninstaller takes `/DRYRUN` as well: it then says which
  programs it would start (like `docker rm`) and starts none.

## Signing

The `.exe` is not signed yet, so Windows SmartScreen shows a warning the first time ("Windows protected your
PC": More info, Run anyway). The plan is to apply for free code signing for open source projects from the
[SignPath Foundation](https://signpath.org/). Nothing here costs money.
