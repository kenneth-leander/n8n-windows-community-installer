# n8n Windows Community Installer

An unofficial, community-created installation wizard for [n8n](https://n8n.io) on Windows systems.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.2.1-blue.svg)](https://github.com/web3Leander/n8n-windows-community-installer)

> **IMPORTANT DISCLAIMER**
>
> **This is an UNOFFICIAL community-made installer and is NOT affiliated with, endorsed by, or connected to n8n.io or n8n GmbH in any way.**
>
> For official n8n support, please visit:
> - [n8n Official Website](https://n8n.io)
> - [n8n GitHub Repository](https://github.com/n8n-io/n8n)
> - [n8n Community Forum](https://community.n8n.io)
> - [n8n Documentation](https://docs.n8n.io)
>
> For issues with this installer, please open an issue in this repository.

## What's New in 0.2.1 - Stays on n8n 2.x

**n8n 3.0 is due in October 2026, and this release keeps every install on n8n 2.x.**

n8n 3.0 is Docker-only and no longer supports npm installs. This release makes sure an installation made with this installer cannot move to 3.0 on its own.

- **Every install method stays on n8n 2.x.** npm installs ask for the newest 2.x release, the update check in the generated start scripts never offers a 3.x version, and Docker installs pull an exact 2.x image tag instead of `latest`
- **Docker installs show the exact version** they installed, and the generated `README.txt` explains how to update without jumping to n8n 3.0
- **n8n 3.0 is not supported yet.** It will arrive with the new installer. See the [n8n 3.0 Notice](#n8n-30-notice)

The Node.js and npm requirements are the same as in 0.2.

## What's New in 0.2 - WSL2 Support Has Landed

**WSL2 (Linux) installation is finally here as Option 4.**

This one took far longer than it should have, and I'm sorry it wasn't shipped sooner. It was promised for a while and kept slipping. Rather than push out something that half worked, it was held back until it could handle the messy reality of real WSL setups - multiple distributions, different package managers, root versus non-root users, and Node.js installed through nvm instead of the system. Thank you for your patience.

What you get:

- **Native Linux SQLite performance** - no NTFS file-locking latency, no Windows `MAX_PATH` limits, and no native module build quirks
- **Pick your distribution** - Ubuntu, Debian, Alpine, Fedora, Arch, openSUSE and others are detected automatically, with Docker's internal distros filtered out
- **It asks before it changes anything** - if the Node.js inside your distro isn't supported, the installer explains exactly what it found and lets you choose. It never silently reconfigures your Linux environment
- **It won't break an nvm setup** - if Node.js lives in your home folder, the install runs as your user rather than root, so you're never left with root-owned files in your Node.js tree
- **Works at `http://localhost` straight away**, and stays off your LAN by default

Existing Options 1, 2 and 3 are completely unchanged. If you don't have WSL installed, the installer behaves exactly as it did in 0.1.7.

## Quick Navigation

[What's New](#whats-new-in-021---stays-on-n8n-2x) •
[Overview](#overview) •
[Features](#features) •
[System Requirements](#system-requirements) •
[Quick Start](#quick-start) •
[Installation Options](#installation-options) •
[n8n 3.0 Notice](#n8n-30-notice) •
[Security & Task Runners](#security--task-runners) •
[Troubleshooting](#troubleshooting) •
[FAQ](#frequently-asked-questions) •
[Uninstalling](#uninstalling-a-wsl2-installation) •
[Roadmap](#roadmap)

## Overview

This installer is a guided Windows batch wizard for setting up [n8n](https://n8n.io) without having to assemble every command by hand. It supports native Windows npm installs, isolated WSL2 Linux installs, and Docker-based installs, then writes a local `README.txt` with the exact settings chosen during setup.

It is designed for local development, personal automation, and small Windows-hosted n8n setups. For hardened production deployments, use this as a starting point and review n8n's official production guidance.

## Features

- **Four installation methods**
  - Global npm install with the `n8n` command available system-wide on Windows
  - Folder-specific npm install for isolated or test instances on Windows
  - Docker install using the official `docker.n8n.io/n8nio/n8n` image
  - WSL2 (Linux) install inside your chosen Linux distribution for maximum SQLite performance

- **Guided WSL2 distribution selection**
  - Detects installed WSL distributions (Ubuntu, Debian, Alpine, Fedora, Arch, openSUSE, etc.)
  - Auto-probes package managers, Linux users, and existing n8n installations inside WSL
  - Offers Node.js 22 LTS provisioning inside WSL, and never installs it for you without asking
  - Enforces native Linux filesystem storage (`/home/<user>/.n8n`) to eliminate NTFS file-locking latency

- **n8n 2.x compatibility checks**
  - Native installs require Node.js `20.19+` or `22.x LTS`
  - npm is capped at `10.x`, the version bundled with Node.js 22 LTS
  - Newer release lines are blocked before `npm install`
  - Every install method stays on n8n 2.x: npm installs ask for the newest 2.x release and Docker installs use an exact 2.x image tag
  - Docker installs avoid forcing external task-runner flags and let n8n use its default runner behavior

- **Guided setup and safety checks**
  - Checks Node.js, npm, Docker, and WSL subsystem availability, plus default port `5678`
  - Detects existing global, folder, Docker, or WSL installations before overwriting
  - Checks available disk space for native, Docker, and WSL installs
  - Prompts for folder paths, Docker container/volume names, WSL distros, host, port, update checks, and shortcuts

- **Windows-friendly launch configuration**
  - Creates `start_n8n.bat` for native Windows and `start_n8n_wsl.bat` for WSL2
  - Sets `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false` for native Windows launches
  - Optionally creates a desktop shortcut for the current user or all users
  - Optionally checks for n8n updates whenever the generated start script runs

- **Generated documentation**
  - Writes a `README.txt` with the selected install type, paths, ports, Docker/WSL details, and useful commands
  - Documents data folder behavior and backup reminders
  - Includes troubleshooting notes for the installed instance

## System Requirements

### Required for the installer

- **Operating system:** Windows 10 or Windows 11, 64-bit
- **PowerShell:** 5.1 or later, included with Windows
- **Internet connection:** Required to download npm packages or Docker images
- **Node.js and npm:** The current wizard checks for both before installation choices are shown

### Native npm requirements

- **Node.js:** `20.19+` or `22.x LTS` from [nodejs.org](https://nodejs.org/), with `22.x LTS` recommended
- **npm:** `10.x`, as bundled with Node.js 22 LTS
- **Disk space:** At least 2 GB free on the target drive
- **Administrator rights:** Optional, but recommended for global installs and all-users shortcuts

Avoid Node.js 24 and newer for native npm installs. Node.js and npm ship as one package, and newer Node.js lines bundle newer npm. npm 12 blocks dependency install scripts by default, which leaves `sqlite3` without its native binary and stops n8n from opening its database. Node.js 22 LTS with npm 10 is the pairing this installer targets.

On Node.js 22, npm installs n8n 2.35.7, the newest release that supports Node.js 22. n8n 2.36 and newer declare Node.js 24 or later as their minimum.

### Docker requirements

- **Docker Desktop:** Installed and running from [docker.com](https://www.docker.com/products/docker-desktop)
- **Disk space:** At least 3 GB free on the system drive for the Docker image (~2.5 GB) and volume data

If Docker is available, the installer can offer Docker even when the detected Node.js version is not supported for native installs.

### WSL2 requirements

- **WSL Subsystem:** Windows Subsystem for Linux enabled on Windows 10/11
- **Linux Distribution:** At least one installed Linux distribution (e.g., Ubuntu, Debian, Alpine, Fedora, Arch, openSUSE)
- **Disk space:** At least 2 GB free on the system drive

If WSL is enabled, the installer will automatically detect your Linux distributions and offer WSL installation even if Node.js is not installed on the Windows host.

## Quick Start

1. Download `n8n-Installer.bat`.
2. Install Node.js `22.x LTS` for native Windows npm installs, or start Docker Desktop / enable WSL2.
3. Right-click `n8n-Installer.bat` and choose **Run as Administrator** when using global installs or all-users shortcuts.
4. Follow the prompts and confirm the final summary.
5. Start n8n with the generated `start_n8n.bat`, `start_n8n_wsl.bat`, Docker Desktop, or the Docker/WSL command shown in the generated `README.txt`.

## Installation Options

| Feature | Global npm | Folder-Specific npm | Docker Container | WSL2 (Linux) |
| :--- | :--- | :--- | :--- | :--- |
| **Best For** | System-wide CLI availability on Windows | Isolated instances & side-by-side testing | Containerized, clean runtime | Native Linux speed & SQLite performance |
| **Command** | `n8n start` | `start_n8n.bat` (or `npx n8n start`) | `docker start <container-name>` | `start_n8n_wsl.bat` |
| **Isolation** | Shared system Node environment | Local folder `node_modules` | Isolated Docker volume & image | Isolated Linux distribution (`~/.n8n`) |
| **Updates** | `npm install -g n8n@2` | `npm install n8n@2` | Re-run the installer, or pull a newer 2.x image & recreate the container | Update check built into `start_n8n_wsl.bat` |

### Global Installation

Installs the newest n8n 2.x with `npm install -g n8n@2`.

- Best when you want the `n8n` command available from any terminal
- Creates the launcher and generated README under `%USERPROFILE%\n8n`
- Can detect and confirm before replacing an existing global n8n package
- Supports optional start-time update checks with `npm install -g n8n@2`

### Folder-Specific Installation

Installs the newest n8n 2.x with `npm install n8n@2` inside a folder you choose.

- Best for isolated installs, testing, and multiple side-by-side instances
- Keeps the package, launcher, generated README, and data base path together
- Adds the folder's `node_modules\.bin` path to the current user's PATH
- Supports optional start-time update checks with `npm install n8n@2`

### Docker Installation

Creates a Docker volume, pulls the official n8n image, and starts one container.

- Best when you want a containerized n8n runtime
- Installs an exact n8n 2.x image tag, the one Docker Hub's `stable` tag points to (for example `2.42.5`), instead of the moving `latest` tag, so the container never jumps to n8n 3.0 on its own
- Lets you choose the container name and Docker volume name
- Auto-detects the Windows timezone and maps common zones to IANA names
- Maps your chosen Windows port to container port `5678`
- Uses Docker Desktop or Docker CLI commands for start, stop, logs, and updates

The installer runs a single n8n container. It does not enable external task runners or start a separate `n8nio/runners` container.

### WSL2 (Linux) Installation

Installs n8n inside your chosen WSL Linux distribution (Ubuntu, Debian, Alpine, Fedora, Arch, openSUSE).

- Best when you want **maximum SQLite performance** and zero Windows npm path/locking quirks
- Auto-probes the Linux default user and package manager family (`apt`, `apk`, `dnf`, `pacman`, `zypper`)
- Applies the same Node.js rule as native installs (`20.19+` or `22.x LTS`), and if the distro's Node.js does not match it explains the situation and lets you choose
- Installs as `root` only when npm's prefix is a system path; if Node.js is managed inside your home folder (for example nvm) it installs as your own user so your Node.js tree is never left root-owned
- Keeps all n8n data on native Linux storage in the distro's home folder (`<home>/.n8n`, usually `/home/<user>/.n8n`), via `N8N_USER_FOLDER=<home>`
- Creates `start_n8n_wsl.bat` under `%USERPROFILE%\n8n-wsl`
- Listens inside the WSL virtual machine and is reachable from Windows at `http://localhost:<port>`. It is **not** exposed to your local network; the generated `README.txt` documents the `netsh interface portproxy` recipe if you deliberately want that.

## How It Works

1. **System verification** checks Node.js, npm, Docker status, WSL distributions, and default port `5678`.
2. **Installation setup** collects the install type, target folder, Docker names or WSL distribution, network settings, update preference, and shortcut preference.
3. **Installation** runs npm, Docker or WSL commands and verifies that n8n was installed or the container started.
4. **Completion** creates generated documentation and a configured launcher: `start_n8n.bat` for native installs, `start_n8n_wsl.bat` for WSL2.

## Network Configuration

### Native network settings

For global and folder installs, the wizard asks for both host and port.

- `127.0.0.1` keeps n8n available only on the local computer and is the default.
- `0.0.0.0` listens on all network interfaces and can expose n8n to your LAN.
- A specific local IP such as `192.168.1.100` limits listening to that interface.
- Port `5678` is the default, with common alternatives such as `3000`, `5000`, or `8080`.

### Docker network settings

For Docker installs, the wizard asks for the Windows host port only. The container always listens on port `5678` internally, and Docker maps your chosen host port to it.

### WSL2 network settings

For WSL2 installs, the wizard asks for the port only. n8n binds `0.0.0.0` inside the WSL virtual machine, which WSL forwards to Windows loopback, so `http://localhost:<port>` works from your Windows browser while staying unreachable from other machines.

The IPv4 bind is deliberate. n8n defaults to the IPv6 wildcard, which WSL then publishes as `[::1]` only, and that makes `http://127.0.0.1:<port>` fail while `http://[::1]:<port>` works. The generated launcher sets `N8N_LISTEN_ADDRESS=0.0.0.0` to avoid this.

Exposing a WSL2 instance to your LAN needs a `netsh interface portproxy` rule as well as a firewall rule, because WSL2 sits behind NAT. The generated `README.txt` documents the exact commands if you decide you want that.

### Security Notes

- Prefer `127.0.0.1` for personal/local use.
- Use `0.0.0.0` only when you intentionally need LAN access.
- Check Windows Firewall rules when exposing n8n beyond localhost.
- Add HTTPS, authentication, backups, and process supervision before treating an installation as production-ready.

## n8n 3.0 Notice

As detailed in the official [n8n v3.0 Breaking Changes documentation](https://docs.n8n.io/changelog/v30-breaking-changes), n8n v3.0 (scheduled for October 2026) introduces major deployment updates:

- **Docker-based deployment required:** Self-hosted n8n v3.0 will require a Docker deployment. Native installations running directly via `npm` / `npx n8n` will no longer be supported by n8n GmbH in v3.0.
- **What this version does:** Version 0.2.1 installs **n8n v2.x only**, with every install method. It does not install 3.0 and its update checks never offer it, so the release of 3.0 cannot break an installation made with it.
- **Installer Support Strategy:**
  - **Docker installations:** **n8n v3.0** support comes with the new installer described in the [Roadmap](#roadmap), in addition to **n8n v2.x**.
  - **Native installations (Global, Folder npm and WSL2):** Will remain available and dedicated to **n8n v2.x** releases.
- **Installed with 0.2 and have update checks on?** The start scripts that 0.2 generated do not have the 2.x guard. Decline any update prompt that offers a 3.x version, or run this installer again to regenerate the start script.

## Security & Task Runners

When installing n8n natively or via a single Docker container, Code nodes (JavaScript & Python) run using **Internal Task Runners** as child processes of the main n8n process.

> **Is single-container / native n8n a limited version?**
>
> **No.** A single-container or native install includes **100% of all n8n Community Edition features**, nodes, and capabilities.

### Task Runner Modes & Isolation

- **Single Container / Native (Default):** Code nodes execute in child processes sharing the host or container environment. This is secure and standard for local development, personal automation, and single-user or trusted-team setups.
- **External Mode (Sidecar Container):** If you deploy n8n in a multi-tenant production environment where untrusted users can create workflows with arbitrary Code nodes, n8n recommends running task runners in **External Mode** via a separate `n8nio/runners` sidecar container. Refer to n8n's official [Hardening Task Runners Guide](https://docs.n8n.io/deploy/host-n8n/configure-n8n/security/harden-task-runners.md) for details.

## What Gets Installed

### Native installed files

- n8n installed through npm
- A configured `start_n8n.bat` launcher
- A generated `README.txt` with the exact paths and settings chosen
- A data folder created by n8n on first launch
- Optional desktop shortcut

The generated start script sets:

```batch
N8N_USER_FOLDER=<your configured data base path>
N8N_PORT=<your selected port>
N8N_PROTOCOL=http
N8N_HOST=<your selected host>
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
N8N_UNVERIFIED_PACKAGES_ENABLED=true
REM set EXECUTIONS_DATA_PRUNE=true
REM set EXECUTIONS_DATA_MAX_AGE=168
REM set WEBHOOK_URL=https://n8n.example.com/
```

n8n stores workflows, credentials, settings, the local database, and the encryption key in its user folder. The generated `README.txt` shows the exact path for the installation you created.

### Docker installed files

- One Docker container running `docker.n8n.io/n8nio/n8n` at an exact 2.x tag
- One Docker volume mounted to `/home/node/.n8n`
- Port mapping from your selected Windows port to container port `5678`
- A generated `README.txt` in the installer folder with container and volume details

### WSL2 installed files

- n8n installed inside your chosen WSL Linux distribution
- A configured `start_n8n_wsl.bat` launcher stored under `%USERPROFILE%\n8n-wsl`, a folder of its own so it can never collide with a global install
- A Linux native data folder located at `/home/<user>/.n8n` inside your WSL distro
- A generated `README.txt` under `%USERPROFILE%\n8n-wsl` with WSL distribution and user details
- Optional desktop shortcut pointing to `start_n8n_wsl.bat`

## Backup Your Encryption Key

> **CRITICAL DATA NOTICE**
>
> On first startup, n8n generates an encryption key to protect credentials and sensitive data. **Back up the full n8n data folder (`.n8n`) or Docker volume**, not only exported workflow JSON files.
>
> Back up before:
>
> - Upgrading n8n
> - Moving an installation
> - Reinstalling Windows or changing computers
> - Deleting a folder, global package, container, or Docker volume
>
> **Without the original encryption key, encrypted credentials cannot be recovered!**

## Usage

### Starting n8n

For global or folder installs, run:

```batch
start_n8n.bat
```

Use the generated shortcut if you created one, or run the script from a terminal to keep logs visible.

For Docker installs, run:

```bash
docker start n8n
```

Replace `n8n` with your custom container name if you chose one during setup.

For WSL2 installs, run:

```batch
start_n8n_wsl.bat
```

It is created in `%USERPROFILE%\n8n-wsl`, along with a desktop shortcut if you asked for one. Keep the window open while n8n runs.

You are not tied to that script. The same thing from Windows in one line:

```batch
wsl -d <distro> --exec sh -c "export PATH=<node-bin>:/usr/local/bin:/usr/bin:/bin:$PATH; export N8N_USER_FOLDER=<home>; export N8N_PORT=<port>; export N8N_LISTEN_ADDRESS=0.0.0.0; n8n start"
```

Or from inside a WSL shell (`wsl -d <distro>`):

```bash
export PATH=<node-bin>:/usr/local/bin:/usr/bin:/bin:$PATH
export N8N_USER_FOLDER=$HOME
export N8N_PORT=<port>
export N8N_LISTEN_ADDRESS=0.0.0.0
n8n start
```

> **Keep the `PATH` line.** Your interactive shell may select a different Node.js than the installer used - especially with nvm - and n8n will then either not be found or run from the wrong version. The exact `<node-bin>` for your machine is written into the generated `README.txt` in `%USERPROFILE%\n8n-wsl`.
>
> `N8N_LISTEN_ADDRESS=0.0.0.0` is what makes `http://localhost:<port>` reachable from Windows. Without it n8n binds the IPv6 wildcard and only `http://[::1]:<port>` works.

### Stopping n8n

- Native installs: press `Ctrl+C` in the terminal running n8n.
- Docker installs: use Docker Desktop or run `docker stop <container-name>`.
- WSL2 installs: press `Ctrl+C` in the window running n8n.

If that window was closed without stopping n8n first, stop it from Windows with:

```batch
wsl -d <distro> --exec pkill -f "n8n start"
```

To shut the whole subsystem down, run `wsl --shutdown`. That stops every distribution, including Docker Desktop's, so use it deliberately.

### Viewing Logs

- Native installs: read the terminal window running `start_n8n.bat`.
- Docker installs: run `docker logs -f <container-name>`.
- WSL2 installs: read the terminal window running n8n.

To confirm a WSL2 instance is up and listening:

```batch
wsl -d <distro> --exec sh -c "ss -tulpn | grep <port>"
```

### Updating n8n

Native start scripts can optionally check for updates each time they run. You can also update manually:

```bash
npm install -g n8n@2
```

For folder installs, run this in the installation folder:

```bash
npm install n8n@2
```

The `@2` means "the newest 2.x version", so npm keeps n8n on version 2 and never moves you to n8n 3.0 by accident.

For Docker installs, the simplest way is to run `n8n-Installer.bat` again. Choose the same container name, answer `1` to replace the existing container, and enter the same volume name. It looks up the newest stable 2.x release for you.

To do it by hand, pull a newer 2.x image and restart the container with your existing volume. Replace `<2.x.y>` with a 2.x version such as `2.42.5`; the available tags are listed on [Docker Hub](https://hub.docker.com/r/n8nio/n8n/tags):

```bash
docker pull docker.n8n.io/n8nio/n8n:<2.x.y>
docker stop n8n
docker rm n8n
docker run -d --name n8n --restart unless-stopped -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n:<2.x.y>
```

> **Do not use the `latest` or `stable` tags for now.** They move to n8n 3.0 when it is released, and this version of the installer does not support 3.0.

> **How data is preserved:** `docker rm n8n` only removes the temporary container process. Your workflows, credentials, database, and encryption keys are stored inside the named Docker volume (`n8n_data`) and automatically re-attached when the new container starts.
>
> *(Replace `n8n` and `n8n_data` with your custom container and volume names if you customized them during setup.)*

For WSL2 installs, `start_n8n_wsl.bat` can optionally check for updates each time it runs. To update manually, match the command to how n8n was installed:

```batch
wsl -d <distro> -u root --exec sh -c "export PATH=<node-bin>:/usr/local/bin:/usr/bin:/bin:$PATH; npm install -g n8n@2 --allow-scripts=sqlite3"
```

If the installer reported that Node.js is managed by your user (for example through nvm), drop `-u root` so the files stay owned by you:

```batch
wsl -d <distro> --exec sh -c "export PATH=<node-bin>:/usr/local/bin:/usr/bin:/bin:$PATH; npm install -g n8n@2 --allow-scripts=sqlite3"
```

> **The `PATH` matters here too.** Without it, `npm` can resolve to a different Node.js version and install n8n into a prefix the launcher never reads, so nothing appears to change. The generated `README.txt` in `%USERPROFILE%\n8n-wsl` contains the exact command for your setup.

## Troubleshooting

<details>
<summary><b>Unsupported Node.js version</b></summary>


Native npm installs require Node.js `20.19+` or `22.x LTS`. If you see a warning about Node.js 24 or a newer release line, install Node.js 22 LTS and rerun the installer.

Check your version with:

```bash
node --version
```

</details>

<details>
<summary><b>`isolated-vm`, `node-gyp`, Python, or build tools errors</b></summary>


These usually happen when npm cannot use a prebuilt native package for your Node version and tries to compile locally. Use Node.js 22 LTS for native installs. Installing Python or Visual Studio build tools is usually the wrong fix for this installer path.

</details>

<details>
<summary><b>npm peer dependency warnings</b></summary>


n8n has a large dependency tree, so npm may print peer dependency or deprecation warnings. Warnings are not always fatal. The installer fails only if npm exits with an error and n8n is not found afterward.

</details>

<details>
<summary><b>n8n starts but the browser cannot connect</b></summary>


- Confirm the terminal or Docker container is still running.
- Try `http://localhost:5678` or the custom port you selected.
- Check whether the port is already in use: `netstat -ano | findstr :5678`.
- Review Windows Firewall rules if you selected `0.0.0.0` or a LAN IP.

</details>

<details>
<summary><b>Windows settings file permission errors</b></summary>


Use the generated `start_n8n.bat`. It disables strict Linux-style settings file permission enforcement for native Windows installs with `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false`.

</details>

<details>
<summary><b>Docker container does not start</b></summary>


Check container status and logs:

```bash
docker ps -a
docker logs -f <container-name>
```

If the container name already exists, remove it only after confirming your data is in the Docker volume you expect:

```bash
docker rm -f <container-name>
```

</details>

<details>
<summary><b>Cleanup warnings on Windows</b></summary>


If npm reports `EPERM`, `EBUSY`, or locked `node_modules` folders, close terminals and editors using that install folder, stop any running n8n process, and try again. For folder installs, starting with an empty folder is often the cleanest recovery.

</details>

For more help, visit the [n8n Community Forum](https://community.n8n.io).

## Frequently Asked Questions

<details>
<summary><b>Can I run multiple n8n instances?</b></summary>


Yes. Use folder-specific installs with different folders and ports, or Docker installs with different container names, volumes, and host ports.

</details>

<details>
<summary><b>Does this work with Docker?</b></summary>


Yes. Docker Desktop must be installed and running. The installer creates one n8n container and one Docker volume, then documents the names in the generated `README.txt`.

</details>

<details>
<summary><b>Is my data safe?</b></summary>


The installer stores data locally in your n8n user folder or Docker volume and does not send workflows or credentials anywhere. Your responsibility is backing up the full data folder or Docker volume so the encryption key is preserved.

</details>

<details>
<summary><b>How do I uninstall n8n?</b></summary>


For global installs:

```bash
npm uninstall -g n8n
```

Then remove the generated `%USERPROFILE%\n8n` folder and your n8n data folder if you no longer need the data.

For folder installs, delete the installation folder after backing up any data you want to keep. If the installer added `node_modules\.bin` to PATH, remove that entry from the user environment variables.

For Docker installs, remove the container and, only if you no longer need the data, the Docker volume:

```bash
docker rm -f <container-name>
docker volume rm <volume-name>
```

</details>

<details>
<summary><b>Can I move my installation to another computer?</b></summary>


Yes, but preserve the encryption key.

- Native installs: back up the full n8n data folder and restore it before first launch on the new machine.
- Folder installs: also copy or recreate the installation folder and update paths in `start_n8n.bat` if needed.
- Docker installs: back up and restore the Docker volume, then recreate the container with the same volume.

</details>

<details>
<summary><b>Can I use this in production?</b></summary>


This installer can help bootstrap a Windows installation, but production use needs additional hardening: HTTPS, authentication, backups, monitoring, process supervision, and the official n8n production guidance.

</details>

## Additional Resources

- **Official Website:** [https://n8n.io](https://n8n.io)
- **Documentation:** [https://docs.n8n.io](https://docs.n8n.io)
- **Community Forum:** [https://community.n8n.io](https://community.n8n.io)
- **GitHub Repository:** [https://github.com/n8n-io/n8n](https://github.com/n8n-io/n8n)
- **Workflow Templates:** [https://n8n.io/workflows](https://n8n.io/workflows)
- **YouTube Channel:** [https://www.youtube.com/@n8n-io](https://www.youtube.com/@n8n-io)

## Uninstalling a WSL2 Installation

The installer creates `uninstall_n8n_wsl.bat` in `%USERPROFILE%\n8n-wsl`, next to the launcher. Double-click it and choose an option.

| Option | What happens |
| :--- | :--- |
| **Remove n8n, keep my workflows** | The n8n program is removed from your distribution. Your workflows, credentials and encryption key stay where they are, so reinstalling later picks up exactly where you left off. |
| **Remove n8n and delete my workflows** | The above, plus your data folder. You are offered a backup to your Desktop first, and then have to type `DELETE` to confirm. |

It also cleans up the generated `start_n8n_wsl.bat`, `README.txt` and the desktop shortcut.

> It removes only what the installer created. **Node.js, your Linux distribution, Docker and everything else are left untouched.**

Prefer to do it by hand? The exact commands for your installation, already filled in with your distribution, paths and user, are in `README.txt` under **HOW TO UNINSTALL**.

## Roadmap

### A proper `.msi` installer

The next major goal is to ship this as a signed Windows `.msi` package instead of a batch file.

A batch script is easy to read and audit, which is why it was the starting point, but it has real limitations: Windows SmartScreen and antivirus tools are rightly suspicious of `.bat` files downloaded from the internet, there is no clean uninstall path, and the script has to be run from the right place with the right permissions.

An `.msi` would bring:

- **A safer, more trustworthy experience** - a signed package that Windows and antivirus software recognise instead of flagging
- **Proper install and uninstall** - registered in *Apps & features*, with a clean removal that leaves your `.n8n` data alone unless you ask otherwise
- **A real UI** - a standard Windows setup wizard rather than a console window
- **Reliable upgrades** - in-place version upgrades without re-running a script

No date is being promised this time. It will be announced when it is genuinely ready.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Created by [web3Leander](https://github.com/web3Leander)

## Credits

- **n8n** is developed and maintained by [n8n GmbH](https://n8n.io)
- This installer is a community contribution to make n8n more accessible on Windows

## Links

- [Report Issues](https://github.com/web3Leander/n8n-windows-community-installer/issues)
- [Request Features](https://github.com/web3Leander/n8n-windows-community-installer/issues)

---

Made with ❤️ for the n8n community
