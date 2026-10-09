STARTING AND STOPPING n8n
----------------------------------------------------------------
To start:  open "Start n8n" from the Start menu (or the desktop shortcut), or
           double-click  start-n8n.cmd  in the install folder.
           A window opens and your browser follows when n8n is ready.
           The first start can take a minute.
To stop:   close that window, or press Ctrl+C in it.

If your browser does not open by itself, go to   @@URL@@

CHANGING SETTINGS
----------------------------------------------------------------
The settings (port, who can connect, and a few optional extras) are in:

   @@APP_DIR@@\n8n-env.cmd

Open it in Notepad, change a line, save it, and start n8n again.
n8n uses the port you chose and also the one after it (for its task runner).
