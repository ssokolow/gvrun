When complete, this will look and act much the same as [gmrun](http://sourceforge.net/projects/gmrun/) but with a few adjustments for more modern desktops:

 * Written in [Vala](http://sourceforge.net/projects/gmrun/) for easy maintenance without the weight of Python.
 * Supports remaining resident in memory for responsiveness under load.
 * Runs commands in your preferred shell so script snippets just work.
 * Requires no manual file associations. Uses `xdg-open` for non-executables.
 * Supports taking input on the command line to act as a backend for address bar widgets in IceWM, AwesomeWM, etc.
 * **(Pending)** Resolves `~` in paths.
 * **(Pending)** Auto-completion not confused by hidden files and directories.
 * **(Pending)** Notification of non-success exit conditions on via libnotify.

At present, it's in an early stage of development, so the following caveats apply:

 * Auto-completion and command history haven't been implemented yet.
 * Resolution of `~` has barely begun being implemented and currently segfaults.
 * "Run in Terminal" is incomplete.
 * I haven't set up any kind of config parsing yet, so all configuration values
   are currently hard-coded.
 * I haven't figured out how to test for POSIX vs. Win32 from Vala, so `%COMSPEC%` ignored in favor of `%SHELL%` on Windows.

If you still want to try it, it requires GTK+ 3.x (2.x may work if the Makefile is adjusted but is untested) and libgee.

To build on Ubuntu (probably Debian too), it only takes two commands:

    sudo apt-get install libgtk-3-dev libgee-dev valac
    make

The default hotkey it responds to is WinKey+Space ("`<Mod4>space`" in GTK+
accelerator parlance) and is easy to see and edit at the top of `gvrun.vala`
until I can get around to implementing a config file.
