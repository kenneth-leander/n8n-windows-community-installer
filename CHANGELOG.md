# Changelog

<!-- markdownlint-disable MD024 -->

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-10-09

### Fixed

- **Native and WSL2 installs work with current n8n again.** n8n 2.36.0 (August 2026) raised its requirement to Node.js 24. The 0.2 installer accepted Node.js 20.19 and 22 and blocked 24, so a fresh native or WSL2 install ended up on n8n 2.35.7, the last release that runs on Node.js 22, and the update check in the start script could never move it forward, because npm will not install a newer n8n on Node.js 22. The manual `n8n@latest` update commands in the 0.2 README did install a newer n8n, which then exits with "Your Node.js version is currently not supported by n8n". That slipped through because `n8n --version` still works on an unsupported Node.js. Global, folder and WSL2 installs now require Node.js 24.x, and the WSL2 offer to install Node.js inside the distribution installs Node.js 24 (nvm, or NodeSource on apt and dnf distributions). Node.js 25 and 26 stay blocked, because some of n8n's native modules (`isolated-vm`, `@confluentinc/kafka-javascript`) have no prebuilt Windows binary for them and npm would try to compile them
- **Folder installs no longer pass `--allow-scripts` on the command line.** npm 11.19 and newer, including the npm that ships with Node.js 24, reject that flag in a project install with `EALLOWSCRIPTS`. The `sqlite3` allowance now lives in an `allow-scripts=sqlite3` line in a `.npmrc` file in the install folder, which npm 12 needs and older npm ignores, and the start script's update command no longer passes the flag. Global and WSL2 installs keep the flag, because npm accepts it there

### Changed

- **Every install method is pinned to n8n 2.x**, ahead of n8n 3.0, which is Docker-only and no longer ships a runnable npm package:
  - Global, folder and WSL2 installs run `npm install n8n@2`, so they stay on 2.x whatever npm's `latest` tag becomes
  - The update check in generated start scripts installs `n8n@2` and ignores a newer major version if one is ever published. Start scripts made by 0.2 keep their old behaviour until the installer is run again
  - Docker installs no longer pull the moving `latest` image, which moves to 3.0 once it is released. Docker has no floating 2.x tag, so the installer asks Docker Hub which exact 2.x release the `stable` tag points to and installs that tag. If the lookup fails it falls back to `2.42.5` and says so. The completion screen shows the installed version, and the generated `README.txt` explains how to update without jumping to 3.0
- npm 11, the line bundled with Node.js 24, is left as it is, instead of being capped at `10.x`. The installer only flags npm 12 or newer, which blocks dependency install scripts and leaves `sqlite3` without its native binary, and offers to install the newest npm 11 instead
- Node.js download hints now say to pick version 24, because Node.js 26 is expected to become the default LTS download on nodejs.org soon and this installer does not accept it yet
- `README.md`: new 0.2.1 section, Node.js and npm requirements, update instructions, troubleshooting and the n8n 3.0 notice are updated. 3.0 support is now described as arriving with the new installer, since this version installs 2.x only

## [0.2] - 2026-08-06

### Changed

- **Task Broker port is now derived from the UI port** (`N8N_RUNNERS_BROKER_PORT` = UI port + 1) for global, folder and WSL installs. n8n 2.x runs a second service on port `5679` by default, so two instances could not run at the same time. A WSL install was the worst case: WSL forwards every listener to Windows loopback, so it occupied Windows `5679` and stopped any native install from starting at all. Docker is unaffected, as its broker stays inside the container.
- Generated native start scripts now end with `pause`, so if n8n exits the error stays on screen instead of the window closing instantly.

### Added

- **WSL2 (Windows Subsystem for Linux) Guided Installation (Option 4)**:
  - Guided setup for installing n8n inside a WSL2 Linux distribution, added alongside the existing options 1-3, which are unchanged
  - Multi-distro enumeration via `wsl -l -q` with UTF-16LE decoding, and automatic filtering of system utility distros (`docker-desktop`, `rancher-desktop`)
  - Detection of the distro family and package manager (`apt-get`, `apk`, `dnf`, `pacman`, `zypper`)
  - Applies the same Node.js rule as native installs (`20.19+` or `22.x LTS`); when the distro's Node.js does not match, the installer explains what it found and offers to install Node.js 22 LTS, continue anyway, switch distro, or go back
  - Installs as `root` only when npm's prefix is a system path. If Node.js is managed inside the user's home directory (for example nvm), installation runs as that user so the Node.js tree is never left root-owned
  - npm is reported but never modified, matching the existing npm handling on Windows
  - Native Linux filesystem data storage via `N8N_USER_FOLDER=/home/<user>`, so n8n creates `/home/<user>/.n8n`
  - Generated `start_n8n_wsl.bat` launcher under `%USERPROFILE%\n8n`, with an optional update check
  - Generated `uninstall_n8n_wsl.bat`, tailored to the installation, offering "remove n8n but keep my workflows" or a full removal with an optional Desktop backup and a `DELETE` confirmation. It removes only what the installer created and never touches Node.js, the Linux distribution, or anything else
  - Sets `N8N_LISTEN_ADDRESS=0.0.0.0` inside the WSL virtual machine so the port is published on IPv4 loopback. n8n otherwise binds the IPv6 wildcard, which WSL publishes as `[::1]` only and makes `http://127.0.0.1` fail. The instance stays unreachable from the LAN, since the WSL VM is behind NAT and WSL forwards to Windows loopback only
  - Detection of existing n8n installations inside the selected distribution, with the same `DELETE` overwrite confirmation used by options 1 and 2

## [0.1.7] - 2026-08-02

### Changed

- Capped npm at `10.x`, the version bundled with Node.js 22 LTS. The update prompt now offers the highest supported npm instead of `npm@latest`
- Kept Node.js at `20.19+` or `22.x LTS`. Node.js and npm ship as one package, so allowing a newer Node.js also pulls in a newer npm
- Raised the disk space requirement from 1.2 GB to 2 GB for native installs and added a 3 GB check for Docker installs (reflecting the ~2.5 GB Docker image size)
- Quietened npm output during install and update with `--loglevel=error --no-fund --no-audit`. Deprecation warnings from n8n's dependency tree are no longer shown; errors still are
- Added `N8N_UNVERIFIED_PACKAGES_ENABLED=true` to generated start scripts to allow UI installation of community packages without deprecation warnings
- Added optional execution data pruning variables (`REM set EXECUTIONS_DATA_PRUNE=true`, `REM set EXECUTIONS_DATA_MAX_AGE=168`) commented out in generated start scripts so users can enable pruning if desired
- Added `--restart unless-stopped` flag to Docker container creation for automatic restart on reboot
- Documented `WEBHOOK_URL` and added explicit encryption key backup reminders in generated `README.txt`
- Updated environment variables documentation in `README.md` to reflect all variables configured in `start_n8n.bat`
- Added Security & Task Runner section to `README.md` and generated `README.txt` clarifying single-container/native features and external task runner isolation
- Refined `README.md` layout with a quick navigation bar, installation options comparison table, clean text formatting, step-by-step Docker update instructions, collapsible Troubleshooting & FAQ accordions, and removed outdated roadmap section
- Added n8n 3.0 notice in `README.md` detailing upcoming Docker-only requirement for 3.0 while maintaining 2.x support for native npm installs

### Fixed

- Native installs no longer produce an n8n that cannot start. npm 12 blocks dependency install scripts by default, which left `sqlite3` without its native binary and caused `SQLite package has not been found installed` on startup. The npm cap prevents this, and both install commands also pass `--allow-scripts=sqlite3` for anyone who already upgraded npm independently
- Warning markers now render as `[!]` instead of `[]`. Delayed expansion was consuming the unescaped exclamation mark in all 12 warning messages
- Fixed evaluation of `N8N_INSTALL_TYPE` in batch script so Docker installations properly prompt for custom container name, volume name, and port

## [0.1.6] - 2026-05-01

### Changed

- Updated native installation requirements for n8n 2.x to Node.js 20.19+ or 22.x LTS
- Removed Docker environment flags that conflict with n8n 2.x single-container installs
- Disabled strict settings file permission enforcement in generated native Windows start scripts

### Fixed

- Prevented unsupported Node.js current releases, such as Node.js 25, from reaching native npm installs and triggering `node-gyp` native module builds

## [0.1.5] - 2025-11-28

### Changed

- **Docker timezone auto-detection**: Removed manual timezone prompt, now automatically detects system timezone from Windows and converts to IANA format for Docker
  - Supports 18 common timezone mappings (US, Europe, Asia, Australia, NZ)
  - Falls back to UTC for unmapped timezones
  - One less prompt during Docker installation

### Fixed

- **Global installation path fix**: Start scripts now correctly saved to `%USERPROFILE%\n8n` folder instead of invalid path
- **Docker disk space check**: Skipped for Docker installations (not applicable since data stored in Docker volume)
- **Docker data path display**: Now shows "n8n data will be stored in Docker volume" instead of invalid path message

## [0.1.4] - 2025-11-28

### Added

- **Auto-update check option** for start scripts:
  - Optional prompt during installation to enable update checking
  - start_n8n.bat checks for newer n8n versions on each launch
  - Prompts user before installing updates (Y/N confirmation)
  - Supports both global (`npm update -g n8n`) and folder (`npm update n8n`) installations
  - Docker excluded (uses its own update mechanism)
- **Desktop shortcut creation**:
  - Optional prompt to create desktop shortcut for start_n8n.bat
  - Choice between current user only or all users (Public Desktop)
  - Uses PowerShell to create proper Windows .lnk shortcut

### Fixed

- Fixed encoding issue with checkmark characters in generated start scripts
  - Replaced UTF-8 `✓` with ASCII-safe `[OK]` for batch file compatibility
- Fixed missing closing parenthesis in auto-update version display

### Changed

- Version display in auto-update now uses square brackets `[v1.x.x]` for reliable escaping

## [0.1.3] - 2025-11-28

### Added

- **Pre-installation checks** for better user experience:
  - Port 5678 availability check during prerequisites
  - Disk space check on target drive after path selection (requires 1.2GB+)
  - Existing folder installation detection with overwrite confirmation
  - Existing Docker container detection with option to remove or rename
- Warning reminder during network configuration if port 5678 is in use

### Fixed

- **Critical**: Fixed Docker configuration prompts appearing during folder installations
  - Batch script labels inside `if` blocks were breaking conditional flow
  - Restructured Docker configuration section with proper `goto` skip logic
- Disk space check now correctly checks the target drive (not just C:)

### Changed

- Disk space check moved from prerequisites to after installation path selection
- Folder installation now requires typing "DELETE" to confirm overwrite of existing n8n installation

## [0.1.2] - 2025-11-17

### Added

- **Docker installation support** - Run n8n in Docker containers
  - Docker Desktop detection in prerequisites check
  - Docker as installation option #3 (alongside Global and Folder)
  - Docker configuration prompts: container name (default: n8n), volume name (default: n8n_data), timezone (default: UTC), port (default: 5678)
  - Automatic Docker volume creation for persistent data storage
  - Automatic Docker image pull: `docker.n8n.io/n8nio/n8n`
  - Container startup with proper environment variables and port mapping
  - Complete Docker documentation in generated README.txt
- Simplified network configuration for Docker installations (port-only, localhost assumed)

### Changed

- Prerequisites check now includes Docker status (optional)
- Installation flow supports three installation types: Global, Folder, Docker
- Network configuration adapts based on installation type
- Generated README.txt includes Docker-specific commands and management instructions
- Documentation updated with Docker installation option and usage
- FAQ updated to reflect Docker support availability

### Fixed

- Fixed ERRORLEVEL checking in prerequisites to use delayed expansion (`!ERRORLEVEL!` instead of `%ERRORLEVEL%`)
- Fixed duplicate port prompts in Docker installation flow

### Technical Details

- Docker image: `docker.n8n.io/n8nio/n8n` (official n8n image)
- Environment variables: `GENERIC_TIMEZONE`, `TZ`, `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS`, `N8N_RUNNERS_ENABLED`
- Port mapping: User-specified host port to container port 5678
- Data persistence: Docker volume mounted to `/home/node/.n8n` in container
- Container verification after startup with 5-second initialization wait

## [0.1.1] - 2025-11-16

### Added

- Informative message showing where n8n will create the `.n8n` data folder
- Clear documentation in README.txt about n8n's automatic `.n8n` folder creation

### Changed

- **BREAKING**: Removed "Quick Install" mode - all installations now use the streamlined installer
- Simplified installation flow from 5 steps to 4 steps
- Data directory is now automatically set based on installation location (no separate prompt)
- For folder installs: data stored in same folder as installation
- For global installs: data stored in `%USERPROFILE%\.n8n`
- Reduced installer size from 888 lines to 739 lines
- Updated README.md to reflect simplified installation process

### Fixed

- **CRITICAL**: Fixed nested `.n8n\.n8n` folder
- Installer now correctly accounts for n8n's behavior of automatically appending `.n8n` to paths
- Users no longer need to manually specify `.n8n` in data paths
- Updated all prompts and documentation to clarify automatic folder creation

## [0.1.0] - 2025-11-16

### Initial Release

#### Added

- Interactive installation wizard with step-by-step guidance
- Two installation modes: Quick Install and Custom Install
- Global npm installation support
- Folder-specific (portable) installation support
- Custom data directory selection
- Network configuration (custom host/IP and port)
- Automatic Node.js and npm prerequisite checking
- Installation verification with proper error handling
- Automatic PATH configuration for folder installations
- Start script generation with configured settings
- Comprehensive README.txt generation in installation folder
- Credits and disclaimer throughout installer and documentation
- Support for Windows 10 and Windows 11

#### Features

- **Quick Install Mode**
  - Fast, one-click installation with sensible defaults
  - Global npm installation
  - Configurable network settings

- **Custom Install Mode**
  - Full control over installation location
  - Choice between global and folder installations
  - Custom data directory
  - Configurable network host and port
  - Automatic PATH setup

#### Documentation

- Complete README.md for GitHub repository
- Installation guide and troubleshooting tips
- FAQ section with common questions
- Security considerations for network configurations
- Links to official n8n resources

#### Known Limitations

- Windows only (PowerShell required)
- No Docker installation support (planned for future release)
- No automatic update checking (planned for future release)
- Manual uninstallation process

---

## [Unreleased]

### Planned Features

- Automatic update manager
- Backup and restore tools
- Uninstaller script
- Process manager integration (PM2/NSSM)

---

**Note:** This is an unofficial community installer and is not affiliated with n8n.io or n8n GmbH.
