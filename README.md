# n8n Windows Community Installer

A free, unofficial setup program that installs [n8n](https://n8n.io) on Windows. One window, four ways to run n8n, and a normal uninstaller.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.3.0-blue.svg)](CHANGELOG.md)

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

## Download

**[Download n8n-Installer.exe](https://github.com/kenneth-leander/n8n-windows-community-installer/raw/main/n8n-Installer.exe)** (about 2.5 MB, for 64-bit Windows 10 version 1809 or newer, or Windows 11). Open it and follow the steps. You do not need administrator rights.

The installer is not signed yet, so Windows shows **Windows protected your PC** the first time. Click **More info**, then **Run anyway**. Free code signing for open source projects is planned (see the [roadmap](#roadmap)).

To check that your download is the file in this repository, run `certutil -hashfile n8n-Installer.exe SHA256` in a terminal and compare the result with [SHA256SUMS.txt](SHA256SUMS.txt).

## What it does

Choose **Express** and the installer picks a way for you: Docker when Docker is running, otherwise Windows in a folder of its own. Choose **Custom** to pick the way, the folder, the port, whether other devices on your network may open n8n, and the Docker settings.

| Way | What it does | What you need | n8n version |
| :--- | :--- | :--- | :--- |
| **Docker** | Runs n8n in a Docker container. | Docker Desktop, running | n8n 2.x, or the n8n 3 preview if you choose it |
| **Windows, in a folder of its own** | Downloads Node.js 22 into the install folder and installs n8n next to it. | Nothing else | n8n 2.x |
| **Windows, for this user account** | Adds n8n to the Node.js that is already on the computer. | Node.js 22, or Node.js 20.19 and newer 20.x | n8n 2.x |
| **Linux inside Windows (WSL2)** | Installs n8n inside a WSL2 Linux you already have, and adds Node.js 22 there if it is missing. | WSL2 and a Linux distribution such as Ubuntu | n8n 2.x |

A way that cannot be used is greyed out, and a highlighted line under it says why and what to do about it (Docker is not running, there is no suitable Node.js, there is no Linux distribution). **Check again** asks again, for example after you started Docker Desktop.

Every install gets Start menu entries (Start n8n, Open n8n in my web browser, Stop n8n for Docker and Linux, the n8n folder, Read me, Uninstall n8n) and an entry in Windows Settings under Apps. Installing again into the same folder updates it and keeps your workflows. Several installs can live side by side, each in its own folder.

For scripts there is a silent install, for example `n8n-Installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /METHOD=folder /PORT=5678`. All switches, the exit codes and the logs are described in [installer/README.md](installer/README.md).

## n8n 3.0 Notice

As detailed in the official [n8n v3.0 Breaking Changes documentation](https://docs.n8n.io/changelog/v30-breaking-changes), n8n v3.0 (scheduled for October 2026) introduces major deployment updates:

- **Docker-based deployment required:** Self-hosted n8n v3.0 will require a Docker deployment. Installations running directly via `npm` / `npx n8n` will no longer be supported by n8n GmbH in v3.0.
- **What this installer does about it:**
  - **Docker:** supports **n8n v3.0** in addition to **n8n v2.x**.
  - **The three other ways** (Windows in a folder of its own, Windows for this user account, Linux inside Windows) stay on **n8n v2.x**.

## Where your data lives

| Way | Data |
| :--- | :--- |
| Docker | the Docker volume (default `n8n_data`) |
| Windows, in a folder of its own | `<install folder>\.n8n` |
| Windows, for this user account | `%USERPROFILE%\.n8n` |
| Linux inside Windows (WSL2) | inside the Linux distribution, in `.n8n` in your home folder (File Explorer shows it at `\\wsl$\<distribution>\home\<user>\.n8n`) |

The uninstaller asks whether to keep your data, and keeps it by default.

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

## Network and security

By default n8n answers on this computer only (`127.0.0.1`). The box **Let other devices on my network open n8n** makes it listen on all network addresses (`0.0.0.0`). The Linux (WSL2) way cannot offer that, because WSL2 sits behind Windows and Windows passes n8n on to this computer only.

- Prefer the default for personal use.
- Check the Windows Firewall rules if you let other devices connect.
- Add HTTPS, authentication, backups, and process supervision before treating an installation as production-ready.

When n8n runs natively or in a single Docker container, Code nodes (JavaScript and Python) run as child processes of the main n8n process (n8n's internal task runners). That is a complete n8n Community Edition with all features. If you run n8n for several people who may not be trusted, read n8n's [Hardening Task Runners Guide](https://docs.n8n.io/deploy/host-n8n/configure-n8n/security/harden-task-runners.md).

## If something goes wrong

- Every install and uninstall writes a log to `%LOCALAPPDATA%\n8n-installer\logs`. Open an [issue](https://github.com/kenneth-leander/n8n-windows-community-installer/issues) and attach the newest log.
- **Docker is greyed out:** start Docker Desktop, wait until it says it is running, then click **Check again**.
- **n8n starts but the browser cannot connect:** keep the n8n window open, try `http://localhost:5678` (or the port you chose), and check whether another program already uses the port: `netstat -ano | findstr :5678`.
- **Errors about locked files (`EPERM`, `EBUSY`):** close terminals and editors that use the install folder, stop n8n, and try again.

For more help, visit the [n8n Community Forum](https://community.n8n.io).

## Uninstalling

Open Windows Settings, Apps, choose the n8n entry and Uninstall. The uninstaller asks whether to keep your data (it does by default). Each install folder is its own entry, so you can remove one and keep another.

## The old batch installer

The first versions of this project were a batch file, `n8n-Installer.bat`. It was replaced by the program above and is no longer maintained. It is kept in the [legacy](legacy/) folder, together with its manual, for anyone who still uses it.

## For developers

The installer is written with [Inno Setup](https://jrsoftware.org/isinfo.php). Its source, how to build it and how it is tested are in [installer/README.md](installer/README.md). GitHub builds it only when you start it by hand: **Actions** tab, **Installer**, **Run workflow**.

## Roadmap

- **Free code signing.** Apply for free code signing for open source projects from the [SignPath Foundation](https://signpath.org/), so that Windows stops showing its warning when the installer is opened. Nothing in this project costs money.

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

- [Report Issues](https://github.com/kenneth-leander/n8n-windows-community-installer/issues)
- [Request Features](https://github.com/kenneth-leander/n8n-windows-community-installer/issues)

---

Made with ❤️ for the n8n community
