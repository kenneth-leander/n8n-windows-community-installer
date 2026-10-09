================================================================
 n8n on this computer
 Installed with the n8n Windows Community Installer @@VERSION@@
================================================================

This is an UNOFFICIAL community installer. It is not made by, and has no
connection to, n8n GmbH. For help with n8n itself, use the official places:

   Documentation   https://docs.n8n.io
   Community       https://community.n8n.io
   n8n website     https://n8n.io

For problems with the installer: @@PROJECT_URL@@/issues


YOUR INSTALL
----------------------------------------------------------------
   How n8n runs   @@METHOD@@
   n8n version    @@N8N_VERSION@@
   Open n8n at    @@URL@@
   Install folder @@APP_DIR@@
   Your data      @@DATA_DIR@@
   Installed on   @@DATE@@


@@METHOD_TEXT@@

YOUR DATA - PLEASE BACK IT UP
----------------------------------------------------------------
Your workflows, saved passwords (credentials) and settings are kept in:

   @@DATA_DIR@@

The first time n8n starts it makes an encryption key and keeps it in the same
place. Without that key, saved passwords cannot be read again. So back up the
WHOLE data location, not only exported workflows, before you update or move
n8n, and keep the backup somewhere safe.


UPDATING
----------------------------------------------------------------
Run the installer again and choose the same options. Your data is kept.
This installer keeps n8n on version 2.x for Windows, folder and Linux (WSL2)
installs, because n8n 3.0 is only published for Docker.


REMOVING n8n
----------------------------------------------------------------
Open Windows Settings, then Apps, find "n8n" in the list and choose Uninstall.
You are asked whether to keep or delete your workflows and settings. Keeping
them is the default.


SECURITY
----------------------------------------------------------------
By default n8n can only be reached from this computer. If you switched on
"Let other devices on my network open n8n", anyone on your network can reach
the sign-in page, so use a strong password.

The installer saves a log of each installation in:

   %LOCALAPPDATA%\n8n-installer\logs
