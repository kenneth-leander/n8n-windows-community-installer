# n8n Windows Community Installer

**Install n8n on Windows 10 or Windows 11 in a few clicks.** A free, open-source setup program for running n8n, the workflow automation tool, on your own PC. No command line, no administrator rights, and a normal uninstaller.

[![Download](https://img.shields.io/badge/Download-n8n--Installer.exe-2ea44f?style=for-the-badge&logo=windows)](https://github.com/kenneth-leander/n8n-windows-community-installer/raw/main/n8n-Installer.exe)

> **Windows Defender warning (October 2026):** Defender currently flags `n8n-Installer.exe` as "Trojan:Win32/Ulthar.A!ml". This is a false alarm from Defender's automatic guesswork (the "!ml" part), not a virus: the file is built from the source in this repository by GitHub Actions and has not changed since 9 October 2026. We are looking into it and reporting it to Microsoft, and will remove this note once it is fixed. To check that your download is genuine, see [Want to make sure the download is genuine?](#install-n8n-on-windows-in-4-steps) below.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.3.0-blue.svg)](CHANGELOG.md)
![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows)

> This is an **unofficial** community project. It is not made by, endorsed by or connected to n8n GmbH. For n8n itself, see [n8n.io](https://n8n.io), the [n8n docs](https://docs.n8n.io) and the [n8n community forum](https://community.n8n.io). For problems with this installer, [open an issue here](https://github.com/kenneth-leander/n8n-windows-community-installer/issues).

**Contents:** [Install in 4 steps](#install-n8n-on-windows-in-4-steps) · [Which way should I pick?](#which-way-should-i-pick) · [Update n8n](#update-n8n) · [Back up your data](#back-up-your-data-and-encryption-key) · [Problems](#if-something-goes-wrong) · [FAQ](#frequently-asked-questions) · [Uninstall](#uninstall-n8n)

---

## What is this?

[n8n](https://n8n.io) is a workflow automation tool, a free alternative to Zapier and Make that you can host yourself. It connects apps, APIs and AI models into automations you build by dragging boxes around in your web browser.

Setting n8n up on Windows by hand means installing Node.js or Docker, typing commands and writing start scripts. This installer does all of that for you, and you end up with:

- n8n running on your own computer, opened in your browser at `http://localhost:5678`
- **Start n8n**, **Open n8n in my web browser** and **Uninstall n8n** in the Start menu
- an entry in Windows Settings under Apps, like any other program
- your workflows and saved passwords kept when you update or reinstall

## Install n8n on Windows in 4 steps

1. **[Download n8n-Installer.exe](https://github.com/kenneth-leander/n8n-windows-community-installer/raw/main/n8n-Installer.exe)** (about 2.5 MB).
2. **Open it.** Windows may show a blue box saying **Windows protected your PC**, because the installer is not signed yet. Click **More info**, then **Run anyway**.
3. **Choose Express** and click through. Express picks the best way for your computer: Docker if Docker Desktop is running, otherwise a self-contained install that needs nothing else.
4. **Click Start n8n** in the Start menu. n8n opens in your browser when it is ready. Create your owner account and build your first workflow.

That's it. You need 64-bit Windows 10 (version 1809 or newer) or Windows 11, and an internet connection during the install.

<details>
<summary>Want to make sure the download is genuine?</summary>

Open a terminal in your Downloads folder and run:

```
certutil -hashfile n8n-Installer.exe SHA256
```

The long number it prints must match the one in [SHA256SUMS.txt](SHA256SUMS.txt).

</details>

## Which way should I pick?

Choose **Custom** instead of Express to pick one of four ways to run n8n, and to set the folder, the port and the Docker settings.

| Way | Best for | What you need first | n8n version |
| :--- | :--- | :--- | :--- |
| **Docker** | Most people who already use Docker. The only way that will run n8n 3.0. | [Docker Desktop](https://www.docker.com/products/docker-desktop/), running | newest n8n 2.x, or the n8n 3 preview |
| **Windows, in a folder of its own** | Beginners. Simplest, nothing else to install. | Nothing | n8n 2.x |
| **Windows, for this user account** | People who already have Node.js and want the `n8n` command everywhere. | Node.js 22 (or 20.19 and newer 20.x) | n8n 2.x |
| **Linux inside Windows (WSL2)** | People who already use WSL2 and Ubuntu. | WSL2 with a Linux such as Ubuntu | n8n 2.x |

**Not sure?** Pick **Docker** if you have Docker Desktop, otherwise **Windows, in a folder of its own**.

If a way is greyed out, a highlighted line under it says why and what to do (for example "Docker is not running"). Fix it and click **Check again**.

You can have several n8n installs side by side, each in its own folder and on its own port.

### About n8n 3.0

n8n 3.0 (October 2026) runs only with Docker; n8n no longer supports installing it with Node.js and npm ([n8n's announcement](https://docs.n8n.io/changelog/v30-breaking-changes)). So:

- the **Docker** way can install n8n 2.x or n8n 3,
- the other three ways stay on **n8n 2.x**, which keeps working.

## Update n8n

Run the newest `n8n-Installer.exe` again and install into the **same folder** with the same way. It updates n8n and keeps your workflows, credentials and settings.

## Back up your data and encryption key

> [!IMPORTANT]
> The first time n8n starts, it creates an **encryption key** that protects your saved passwords and API keys. **Back up the whole n8n data folder (or Docker volume)**, not just exported workflows. Without the original key, saved credentials cannot be recovered.

Back up before you update n8n, move it, reinstall Windows or delete anything. This is where your data lives:

| Way | Your data |
| :--- | :--- |
| Docker | the Docker volume (default name `n8n_data`) |
| Windows, in a folder of its own | the `.n8n` folder inside the install folder |
| Windows, for this user account | `%USERPROFILE%\.n8n` |
| Linux inside Windows (WSL2) | `.n8n` in your Linux home folder (in File Explorer: `\\wsl$\<Linux name>\home\<user>\.n8n`) |

## Use n8n from other devices, and security

By default only your own computer can open n8n. In **Custom**, the box **Let other devices on my network open n8n** lets your phone or other PCs on the same network reach it (not available for the WSL2 way, because of how WSL2 works).

- For personal use, keep the default.
- If you let other devices in, check your Windows Firewall rules.
- Before using n8n for a business or for other people, add HTTPS, logins, backups and a way to restart it automatically. For shared setups, read n8n's [guide to hardening task runners](https://docs.n8n.io/deploy/host-n8n/configure-n8n/security/harden-task-runners.md).

This installs the full **n8n Community Edition**, the free self-hosted version, with all its features, including Code nodes in JavaScript and Python.

## If something goes wrong

| Problem | What to do |
| :--- | :--- |
| **Windows protected your PC** | Click **More info**, then **Run anyway**. The installer is not signed yet (see the [roadmap](#roadmap)). |
| **Docker is greyed out** | Start Docker Desktop, wait until it says it is running, then click **Check again**. |
| **n8n starts but the browser can't connect** | Keep the n8n window open and try `http://localhost:5678` (or the port you chose). Another program may use the port: run `netstat -ano \| findstr :5678` to check. |
| **Errors about locked files (`EPERM`, `EBUSY`)** | Close terminals and editors that use the install folder, stop n8n, and try again. |
| **Something else** | Every install writes a log to `%LOCALAPPDATA%\n8n-installer\logs`. [Open an issue](https://github.com/kenneth-leander/n8n-windows-community-installer/issues) and attach the newest log. |

For questions about using n8n itself, the [n8n community forum](https://community.n8n.io) is the best place.

## Frequently asked questions

**How do I install n8n on Windows?**
Download [n8n-Installer.exe](https://github.com/kenneth-leander/n8n-windows-community-installer/raw/main/n8n-Installer.exe), open it and choose Express. See [Install in 4 steps](#install-n8n-on-windows-in-4-steps).

**Is n8n free to run on my own PC?**
Yes. The n8n Community Edition is free to self-host, and this installer is free and open source (MIT license).

**Do I need Docker to run n8n on Windows?**
No. The "Windows, in a folder of its own" way needs nothing else. Docker is only needed for n8n 3.0.

**Do I need to know the command line, Node.js or npm?**
No. The installer downloads and sets up everything it needs.

**Do I need administrator rights?**
No. Everything installs for your own Windows user.

**Does it work on Windows 11?**
Yes, on Windows 11 and on 64-bit Windows 10 version 1809 or newer.

**Can I run n8n locally without the cloud?**
Yes. n8n runs on your own computer, and your workflows and data stay there.

**Will I lose my workflows when I update or uninstall?**
No. Updating keeps your data, and the uninstaller asks whether to keep it (it keeps it unless you say otherwise).

**Can I install n8n on several PCs automatically?**
Yes, there is a silent install, for example
`n8n-Installer.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /METHOD=folder /PORT=5678`.
All options, exit codes and logs are in [installer/README.md](installer/README.md).

## Uninstall n8n

Open Windows **Settings**, **Apps**, choose the n8n entry and click **Uninstall** (or use **Uninstall n8n** in the Start menu). It asks whether to keep your data, and keeps it by default. Each install folder has its own entry, so you can remove one and keep another.

## The old batch installer

Earlier versions of this project were a batch file, `n8n-Installer.bat`. It is replaced by the program above and no longer maintained, but it is kept with its manual in the [legacy](legacy/) folder.

## For developers

The installer is built with [Inno Setup](https://jrsoftware.org/isinfo.php). The source, how to build it and how it is tested are in [installer/README.md](installer/README.md). Contributions are welcome: open an issue first for bigger changes, then a pull request.

## Roadmap

- **Free code signing** through the [SignPath Foundation](https://signpath.org/), so Windows stops warning when you open the installer. Nothing in this project costs money.

## License, author and credits

- MIT License, see [LICENSE](LICENSE).
- Created by [Kenneth Leander Meyer](https://github.com/kenneth-leander).
- **n8n** is developed by [n8n GmbH](https://n8n.io). This installer is a community contribution to make n8n easier to use on Windows.

---

Made with ❤️ for the n8n community. If it helped you, a ⭐ on this repository helps other people find it.
