STARTING AND STOPPING n8n
----------------------------------------------------------------
n8n runs inside the Linux distribution "@@DISTRO@@" (Linux inside Windows,
also called WSL2). Windows only holds the start and stop scripts.

To start:  open "Start n8n" from the Start menu (or the desktop shortcut),
           or double-click  start-n8n.cmd  in the install folder.
           A window opens and your browser follows when n8n is ready (the
           window says "Editor is now accessible"). The first start can take
           a minute. The first time, n8n asks you to create your account.
To stop:   press Ctrl+C in that window, or use "Stop n8n" in the Start menu
           (or double-click  stop-n8n.cmd  in the install folder).
           Closing the window usually stops n8n too, but "Stop n8n" is the
           sure way, and the only one when the window is gone.

If your browser does not open by itself, go to   @@URL@@


WHAT WAS SET UP INSIDE LINUX
----------------------------------------------------------------
   Linux distribution   @@DISTRO@@
   Linux user           @@WSL_USER@@  (n8n runs as this user)
   Node.js              @@WSL_NODE@@  (npm @@WSL_NPM@@)
   n8n program          installed @@WSL_RUNAS@@
   n8n listens on       @@WSL_LISTEN@@, port @@PORT@@ (and port @@BROKER_PORT@@ for its task runner)

The port and a few optional extras are at the top of this file:

   @@APP_DIR@@\start-n8n.cmd

Open it in Notepad, change a line, save it, and start n8n again.


WHERE YOUR DATA IS
----------------------------------------------------------------
n8n keeps your workflows, saved passwords and settings on the Linux disk,
in this folder inside @@DISTRO@@:

   @@WSL_DATA@@

In Windows File Explorer you can open it at:

   @@WSL_DATA_WIN@@

The start script gives n8n your home folder (@@WSL_HOME@@) as its place, and n8n
adds the ".n8n" folder inside it by itself. Do not put ".n8n" in that setting.
Keep the data on the Linux disk: data on a Windows drive (a folder under /mnt/c)
makes the database of n8n lock up and run very slowly.

The key that unlocks your saved passwords is the file "config" in that
folder. To see it, or to copy it somewhere safe (in a Command Prompt):

   wsl -d @@DISTRO@@ --exec cat @@WSL_DATA@@/config

To save a copy of the whole folder on your desktop, before you update or
move n8n (in a Command Prompt):

   robocopy "@@WSL_DATA_WIN@@" "%USERPROFILE%\Desktop\n8n-backup" /E


WHO CAN OPEN n8n
----------------------------------------------------------------
Only this computer. A Linux distribution in WSL2 runs in a small virtual
machine behind Windows. n8n listens on all addresses of that machine, which
is what makes  http://localhost:@@PORT@@  work in Windows. (With n8n's own
default, Windows could only reach it at  http://[::1]:@@PORT@@ .) Other
devices on your network cannot reach that virtual machine.
A distribution that runs on WSL 1 shares the network of Windows instead, so
there n8n listens on 127.0.0.1 only.
The address n8n listens on is the line  set "N8N_LISTEN=..."  at the top of
start-n8n.cmd. If you switched WSL to "mirrored" networking, the virtual machine
shares the network of Windows and the Windows firewall decides who can connect.
Then it is safest to change that line to 127.0.0.1, which still works for
http://localhost on this computer.

If you really want other devices on your network to open n8n, you need
an administrator window. Anyone on your network can then reach the sign-in
page of n8n, so use a strong password.

   1. Find the address of the virtual machine (a Command Prompt):
         wsl -d @@DISTRO@@ --exec hostname -I
   2. In a window started with "Run as administrator", pass the port on and
      allow it through the firewall. Use the first address from step 1
      instead of <address>:
         netsh interface portproxy add v4tov4 listenport=@@PORT@@ listenaddress=0.0.0.0 connectport=@@PORT@@ connectaddress=<address>
         netsh advfirewall firewall add rule name="n8n WSL" dir=in action=allow protocol=TCP localport=@@PORT@@
   3. In start-n8n.cmd, remove "rem" at the start of the N8N_SECURE_COOKIE
      line, so that n8n accepts a sign-in over plain http.
   4. The address from step 1 changes when WSL restarts (unless you switch
      WSL to "mirrored" networking, see Microsoft's WSL documentation).
      When other devices can no longer connect, repeat steps 1 and 2.

To undo it (in the administrator window):
         netsh interface portproxy delete v4tov4 listenport=@@PORT@@ listenaddress=0.0.0.0
         netsh advfirewall firewall delete rule name="n8n WSL"


HANDY COMMANDS (type them in a Command Prompt)
----------------------------------------------------------------
Open a Linux shell:       wsl -d @@DISTRO@@
Shut down all of WSL:     wsl --shutdown

Start n8n without the script (one line):

   wsl -d @@DISTRO@@ --exec sh -c "PATH=@@WSL_PATH@@; export PATH; export N8N_USER_FOLDER=@@WSL_HOME@@; export N8N_PORT=@@PORT@@; export N8N_RUNNERS_BROKER_PORT=@@BROKER_PORT@@; export N8N_LISTEN_ADDRESS=@@WSL_LISTEN@@; exec n8n start"

Start n8n from inside a Linux shell (open one with  wsl -d @@DISTRO@@ ):

   PATH=@@WSL_PATH@@; export PATH
   export N8N_USER_FOLDER=@@WSL_HOME@@
   export N8N_PORT=@@PORT@@
   export N8N_RUNNERS_BROKER_PORT=@@BROKER_PORT@@
   export N8N_LISTEN_ADDRESS=@@WSL_LISTEN@@
   n8n start

Keep the PATH line. The shell you open yourself may use another Node.js
than the one this installer used.

Stop n8n when its window is gone (this is what "Stop n8n" does):

   wsl -d @@DISTRO@@ --exec pkill -f @@WSL_N8N@@.start

Check that n8n is listening:

   wsl -d @@DISTRO@@ --exec sh -c "ss -tln | grep @@PORT@@"

Update n8n by hand (running the installer again does the same; both keep
n8n on version 2.x):

   wsl -d @@DISTRO@@@@WSL_SU@@ --exec sh -c "PATH=@@WSL_PATH@@; export PATH; npm install -g @@NPM_SPEC@@ --allow-scripts=sqlite3"


REMOVING n8n BY HAND
----------------------------------------------------------------
Only needed when the uninstaller in Windows Settings, Apps cannot be used.
It only takes away what this installer added: the n8n program inside
@@DISTRO@@ and the files in the install folder. Node.js, the distribution
and everything else are left alone.

   1. Stop n8n (see above).
   2. Remove the n8n program:
         wsl -d @@DISTRO@@@@WSL_SU@@ --exec sh -c "PATH=@@WSL_PATH@@; export PATH; npm uninstall -g n8n"
   3. Delete the install folder  @@APP_DIR@@  if you want it gone.

Your workflows stay in  @@WSL_DATA@@  until you delete that folder
yourself, so removing n8n can be undone by installing it again.


IF SOMETHING GOES WRONG
----------------------------------------------------------------
n8n does not start:
   - Check that port @@PORT@@ is free:   netstat -ano | findstr :@@PORT@@
   - Check that n8n runs inside Linux:
        wsl -d @@DISTRO@@ --exec sh -c "PATH=@@WSL_PATH@@; export PATH; n8n --version"

The message "n8n: not found" when starting:
   - The start script sets the PATH by itself. If you changed Node.js
     inside @@DISTRO@@ after the install, run the installer again.

The web page does not open:
   - Check that the window that runs n8n is still open.
   - Try http://127.0.0.1:@@PORT@@ as well as http://localhost:@@PORT@@
   - If only http://[::1]:@@PORT@@ works, the line  set "N8N_LISTEN=..."  was
     removed from start-n8n.cmd, or does not hold an IPv4 address any more.
     It should say 0.0.0.0 (or 127.0.0.1).
   - Restart WSL:  wsl --shutdown
   - In %USERPROFILE%\.wslconfig the line  localhostForwarding=false
     switches off what makes localhost work. Remove it.

Database or permission errors:
   - Look at who owns the data:
        wsl -d @@DISTRO@@ --exec ls -la @@WSL_HOME@@/.n8n
   - The files should belong to @@WSL_USER@@, not to root.
