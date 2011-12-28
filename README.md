When complete, this will look and act much the same as [gmrun](http://sourceforge.net/projects/gmrun/) but with a few adjustments for more modern desktops:

 * Written in [Vala](http://sourceforge.net/projects/gmrun/) for easy maintenance without the weight of Python.
 * Supports remaining resident in memory for responsiveness under load.
 * Runs commands in your preferred shell so script snippets just work.
 * Requires no manual file associations. Uses `xdg-open` for non-executables.
 * **(Pending)** Resolves `~` in paths.
 * **(Pending)** Auto-completion not confused by hidden files and directories.
 * **(Pending)** Supports taking input on the command line to act as a backend for address bar widgets in IceWM, AwesomeWM, etc.
 * **(Pending)** Notification of non-success exit conditions on via libnotify.

At present, it's in an early stage of development, so the following caveats apply:

 * Auto-completion and command history haven't been implemented yet.
 * Resolution of `~` has barely begun being implemented and currently segfaults.
 * "Run in Terminal" is still in the planning phase.
 * I haven't set up any kind of config parsing yet, so all configuration values
   are currently hard-coded.
 * Logging still has to be set to not show `INFO` and `DEBUG` messages by default.
 * I haven't figured out how to test for POSIX vs. Win32 from Vala, so `%COMSPEC%` ignored in favor of `%SHELL%` on Windows.

If you still want to try it, it requires GTK+ 3.x (2.x may work but is untested)
and [libgee](https://live.gnome.org/Libgee).

To build on Ubuntu (probably Debian too), it only takes two commands:

    sudo apt-get install libgtk-3-dev libgee-dev valac
    make
