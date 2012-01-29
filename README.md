gvrun is a lightweight, desktop-independent, GTK+-based Run dialog which attempts to mimic the look and feel of [gmrun](http://sourceforge.net/projects/gmrun/) while compensating for the areas where it falls short.

# Features

 * Just Works™ wherever feasible.
   * Resolves `~` and `~user` in paths.
   * Respects your desktop's settings for opening files and URLs by using `xdg-open`.
   * Executes shell script snippets in your preferred shell via `$SHELL`.
 * Can be used as a backend by other GUIs such as the IceWM and AwesomeWM address bar widgets. Just pass the command as an argument.
 * Stays resident and does its own global hotkey-binding for better responsiveness than gmrun when the system is heavily loaded.
 * Lightweight and fast. Written in [Vala](https://live.gnome.org/Vala) for easy maintenance without the weight of a non-native language like [Python](http://www.python.org/).
 * Minimal dependencies. Requires only GTK+, [Libgee](https://live.gnome.org/Libgee), and Xlib for keybinding.
 * Clean, well-commented source. Useful as a reference example for how to accomplish quite a few common tasks with the Glib API.
 * **(Pending)** Auto-completion not confused by hidden files and directories.
 * **(Pending)** Notification of non-success exit conditions via libnotify.

**Note:** At present, it's in an early stage of development, so the following caveats apply:

 * Auto-completion and command history haven't been implemented yet.
 * "Run in Terminal" is incomplete.
 * I haven't set up any kind of config parsing yet, so all configuration values are currently hard-coded.
 * I haven't figured out how to test for POSIX vs. Win32 from Vala so, if you get it building on Windows, it'll ignore `%COMSPEC%` in favor of `%SHELL%`.

If you still want to try it, it requires GTK+ 3.x (2.x may work if the Makefile is adjusted but is untested) and libgee.

# Installation

To build on Ubuntu (probably Debian too), it only takes three commands:

    sudo cp supplemental/xdg-* /usr/bin/
    sudo apt-get install libgtk-3-dev libgee-dev valac
    make

(As of this writing, there are bugs and shortcomings in the released version of `xdg-open` and `xdg-terminal` has not been released. I have filed bug reports and submitted patches but they have not made it into any distros yet. Hence the installation of the included copies of `xdg-open` and `xdg-terminal` as part of the setup process for gvrun.)

# Usage

The default hotkey is WinKey+Space ("`<Mod4>space`" in GTK+ accelerator parlance) and is easy to see and edit at the top of `gvrun.vala` until I can get around to implementing a config file.

To replicate the functionality of the `URL_*` and `EXT:` keys from `~/.gmrunrc`, set custom associations in your desktop's control panel. (This has the side-benefit of working in all applications, not just gvrun)

See the [FAQ/PAQ](https://github.com/ssokolow/gvrun/wiki/Potentially-Asked-Questions) page for instructions if your desktop lacks a GUI for this.

# License

This program is licensed under the GNU GPL 2.0 or later with components of more general utility kept in their own source files and licensed under an MIT license to help enrich the Vala experience for potential future developers.
