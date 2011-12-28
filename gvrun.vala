/** Vala-based gmrun-alike.
 *
 * TODO: Make sure the variable ownership is all defined properly so I don't
 * get memleaks.
 */
using Gtk;
using Gee;

/** Quick and dirty way to actually get my arrays INTO Gee data types. */
public void add_from_strlist(Collection<string> collection, string[] string_array) {
    foreach (var str in string_array) { collection.add(str); }
}

/** Simple API for taking a command and heuristically guessing how to open it.
 *
 * Basically a superset of what the tools it uses (xdg-open, start.exe, etc.)
 * do with what you give them.
 *
 * Resolves:
 *  - Executable names and paths (arguments processed by $SHELL)
 *  - Non-executable paths and URLs (handled by xdg-open and friends)
 *  - Shell script snippets (resorts to `$SHELL -c` as a fallback)
 */
public class ProcessRunner : Object {
    private string home_path;
    private string open_cmd;
    private string[] shell_cmd;
    private string[] term_cmd;

    private bool use_term = false;
    private Regex uri_re;

    public const string[] OPENERS = {"xdg-open", "mimeopen", "start", "open"};

    public ProcessRunner(bool? use_term) {
        // TODO: Figure out how to detect when we're on Windows.
        foreach (var cmd in OPENERS) {
            if (Environment.find_program_in_path(cmd) != null) {
                this.open_cmd = cmd;
                break;
            }
        }

        this.home_path   = Environment.get_variable("HOME") ?? Environment.get_home_dir();
        this.shell_cmd   = {Environment.get_variable("SHELL"), "-c"};
        this.term_cmd    = {"urxvt", "-e"};
        this.use_term    = use_term && !Posix.isatty(Posix.stdout.fileno());

        try {
            uri_re =  new Regex("^[a-zA-Z0-9+.\\-]+:.+$", RegexCompileFlags.CASELESS);
        } catch (RegexError e) {
            log(null, LogLevelFlags.LEVEL_ERROR, "Bad compile-time constant: ProcessRunner.uri_re");
        }

    }

    /** All common code for calling commands */
    protected bool spawn_or_log(string[] argv) {
        var _argv = argv;
        _argv += null;

        try {
            // TODO: set a GObject watch on the PID that the final argument can
            // return and use it for optional indications of completion status.
            Process.spawn_async(null, _argv, null, SpawnFlags.SEARCH_PATH, null, null);
            return true;
        } catch (SpawnError e) {
            log(null, LogLevelFlags.LEVEL_WARNING, "spawn_async() failed for %s", _argv[0]);
            return false;
        }
    }

    /** Convenience wrapper for run() which parses a single string. */
    public bool run_string(string args) {
        string[] argv;
        try {
            Shell.parse_argv(args, out argv);
        } catch (ShellError e) {
            log(null, LogLevelFlags.LEVEL_WARNING, "parse_argv() failed for: %s", args);
            return false;
        }

        return this.run(argv, args);
    }

    /** Identify and execute/open a command, file, URL, or shellscript snippet.
     *
     *  Implements flexible quoting. If args is not provided, it will be
     *  generated from argv.
     */
    public bool run (string[] argv, string? args=null) {
        string _args = "";

        if (args == null) {
            foreach (var piece in argv) {
               _args += " " + piece;
               // We don't use Shell.quote() here because it would confuse the
               // quoting guesser.
            }
        } else {
            _args = args;
        }

        // Flexible quoting for maximum versatility. (Order minimizes mistakes)
        string[] interpretations = {_args, argv[0]};
        foreach (string cmd in interpretations) {
            if (cmd[0] == '~')
                // FIXME: This segfaults
                cmd = home_path + (string) Path.DIR_SEPARATOR + cmd.substring(1);

            string _cmd; // Resolved command
            if ((_cmd = Environment.find_program_in_path(cmd)) != null) {
                // Valid command (shell execute for versatility)
                log(null, LogLevelFlags.LEVEL_DEBUG, "Found in path: %s (%s)", _cmd, _args);

                var spawn_cmd = new ArrayList<string>();
                add_from_strlist(spawn_cmd, this.shell_cmd);
                spawn_cmd.add(_args);

                return spawn_or_log((string[]) spawn_cmd.to_array());
            } else if (FileUtils.test(cmd, FileTest.EXISTS) || uri_re.match(cmd)) {
                // URL or local path (Use desktop associations system)
                log(null, LogLevelFlags.LEVEL_DEBUG, "URL or local path: %s (Opening with %s)", cmd, this.open_cmd);
                return spawn_or_log({this.open_cmd, cmd});
            } else {
                log(null, LogLevelFlags.LEVEL_DEBUG, "No match: %s", cmd);
                continue; // No match, try the alternate interpretation.
            }
        }

        // Fall back to letting the shell try to make sense of it.
        log(null, LogLevelFlags.LEVEL_DEBUG, "Attempting shell fallback for %s", _args);

        var spawn_cmd = new ArrayList<string>();
        if (this.use_term) {
            // XXX: Decide how to add this functionality to the
            // find_program_in_path branch without it being annoying.
            log(null, LogLevelFlags.LEVEL_DEBUG, "Using terminal for %s", _args);
            add_from_strlist(spawn_cmd, this.term_cmd);
        }

        add_from_strlist(spawn_cmd, shell_cmd);
        spawn_cmd.add(args);

        return spawn_or_log((string []) spawn_cmd.to_array());
    }
}


public class RunDialog : Dialog {
    private Entry command_entry;
    private ProcessRunner runner;

    private const int WIDTH = 350; // TODO: Make this configurable.

    public RunDialog(ProcessRunner runner) {
        this.runner = runner;

        this.title = "Run:";
        this.decorated = false;
        this.border_width = 2;
        this.set_default_size(WIDTH,50);

        // Must realize() before doing either of these.
        // http://stackoverflow.com/a/8378059/435253
        this.realize();
        this.set_keep_above(true);
        this.get_window().set_decorations(Gdk.WMDecoration.BORDER);

        // Only allow horizontal resizing
        // http://stackoverflow.com/a/4894417/435253
        Gdk.Geometry hints = Gdk.Geometry();
        hints.min_height = hints.max_height = -1; // Current minimum size
        hints.min_width = 0;
        hints.max_width = this.get_screen().get_width();

        set_geometry_hints(this, hints, Gdk.WindowHints.MIN_SIZE | Gdk.WindowHints.MAX_SIZE);

        create_widgets();
        connect_signals();
    }

    private void create_widgets() {
        // Create and setup widgets
        this.command_entry = new Entry();
        var command_label = new Label.with_mnemonic("  _Run program:");
        //TODO: Think of a label that reflects that xdg-open is used too.

        command_label.mnemonic_widget = this.command_entry;
        command_label.xalign = 0.0f;

        // Layout widgets
        var content = get_content_area() as Box;
        content.pack_start(command_label, false, true, 2);
        content.pack_start(this.command_entry, true, true, 0);
        content.spacing = 0;

        // Remove the action area to avoid unwanted padding
        // but keep a reference to avoid GTK warnings on stderr.
        var actions = get_action_area() as Box;
        content.remove(actions);

        show_all();
    }

    private void connect_signals() {
        this.command_entry.activate.connect (() => {
            log(null, LogLevelFlags.LEVEL_INFO, "Attempting to run: %s", this.command_entry.text);
            if (runner.run_string(this.command_entry.text))
                this.command_entry.text = "";
        });
    }


}

public class App : Object {
    static bool use_terminal;
    static bool use_gui = true;

    const OptionEntry[] valid_opts = {
        { "terminal", 't', 0, OptionArg.NONE, ref use_terminal, "Run commands in a terminal if stdout isn't a TTY", null},
        { "no-terminal", 'T', OptionFlags.REVERSE, OptionArg.NONE, ref use_terminal, "Never run commands in a terminal", null },
        { null }
    };

    public static int main(string[] argv) {
        try {
            Gtk.init_with_args(ref argv, "[command line]", valid_opts, null);
        } catch (OptionError e) {
            if (e is OptionError.FAILED) {
                // Couldn't open DISPLAY
                use_gui = false;
            } else {
                // Error parsing argv
                stderr.printf("%s\n", e.message);
                return 1;
            }
        } catch (Error e) {
            stderr.printf("Unexpected error: %s", e.message);
            return 255;
        }
        // TODO: Use Log.set_handler to omit DEBUG and INFO by default.

        var runner = new ProcessRunner(use_terminal);

        if (argv.length >= 2) {
            if (argv.length == 2) {
                log(null, LogLevelFlags.LEVEL_DEBUG, "Parsing and running string: %s", argv[0]);
                return runner.run_string(argv[1]) ? 0 : 2;
            } else {

                //XXX: Is there really no equivalent to Python's argv[1:] slice in Vala?
                bool skipped = false;
                string[] argv_trimmed = {};
                foreach (string piece in argv) {
                    if (!skipped) {
                        skipped = true;
                        continue;
                    }
                    argv_trimmed += piece;
                }

                log(null, LogLevelFlags.LEVEL_DEBUG, "Running argv: '%s'", string.joinv("' '", argv_trimmed));
                return runner.run(argv_trimmed) ? 0 : 2;
            }

            MainContext.default().iteration(true);
        } else if (use_gui) {
            log(null, LogLevelFlags.LEVEL_DEBUG, "Starting GUI");
            var dialog = new RunDialog(runner);

            dialog.destroy.connect(Gtk.main_quit);
            dialog.show();
            Gtk.main();
        } else {
            stderr.printf("Unable to initialize GTK+ and no arguments given.\n");
            return 1;
        }
        return 0;
    }
}
