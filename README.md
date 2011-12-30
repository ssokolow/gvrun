gvrun is a lightweight, desktop-independent, GTK+-based Run dialog which attempts to mimic the look and feel of [gmrun](http://sourceforge.net/projects/gmrun/) while compensating for the areas where it falls short.

# Features

 * Written in [Vala](https://live.gnome.org/Vala) for easy maintenance without the weight of a non-native language like [Python](http://www.python.org/).
 * Supports remaining resident in memory for responsiveness to global hotkeys in the face of heavy system load.
 * Requires no manual file associations. Uses `xdg-open` for non-executables.
 * Resolves `~` and `~user` in paths.
 * Runs commands in your preferred shell so script snippets just work.
 * Supports taking input on the command line to act as a backend for address bar widgets in IceWM, AwesomeWM, etc.
 * **(Pending)** Auto-completion not confused by hidden files and directories.
 * **(Pending)** Notification of non-success exit conditions via libnotify.

At present, it's in an early stage of development, so the following caveats apply:

 * Auto-completion and command history haven't been implemented yet.
 * "Run in Terminal" is incomplete.
 * I haven't set up any kind of config parsing yet, so all configuration values are currently hard-coded.
 * I haven't figured out how to test for POSIX vs. Win32 from Vala, so `%COMSPEC%` will be ignored in favor of `%SHELL%` if you get it built on Windows.

If you still want to try it, it requires GTK+ 3.x (2.x may work if the Makefile is adjusted but is untested) and libgee.

# Installation

To build on Ubuntu (probably Debian too), it only takes two commands:

    sudo apt-get install libgtk-3-dev libgee-dev valac
    make

# Usage

The default hotkey it responds to is WinKey+Space ("`<Mod4>space`" in GTK+
accelerator parlance) and is easy to see and edit at the top of `gvrun.vala`
until I can get around to implementing a config file.

# License

This program is licensed under the GNU GPL 2.0 or later with components of more
general utility kept in their own source files and licensed under an MIT
license to help enrich the Vala experience for potential future developers.
