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

public class ProcessRunner : Object {
    private string home_path;
    private string[] shell_cmd;
    private string[] term_cmd;

    private bool _useterm = false; // FIXME: Re-implement this.
    private Regex uri_re;
    private const string OPENER = "xdg-open";

    public ProcessRunner() {
        // TODO: Figure out how to detect when we're on Windows.
        this.home_path   = Environment.get_variable("HOME") ?? Environment.get_home_dir();
        this.shell_cmd   = {Environment.get_variable("SHELL"), "-c"};
        this.term_cmd    = {"urxvt", "-e"};

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

    /** Heuristically guess how to handle the given commandline.
     *
     *  TODO: Decide how best to accept (string || string[]) in Vala.
     */
    public bool run (string args) {

        string[] argv;
        try {
            Shell.parse_argv(args, out argv);
        } catch (ShellError e) {
            log(null, LogLevelFlags.LEVEL_WARNING, "parse_argv() failed for: %s", args);
            return false;
        }

        // Flexible quoting for maximum versatility. (Order minimizes mistakes)
        string[] interpretations = {args, argv[0]};
        foreach (string cmd in interpretations) {
            if (cmd[0] == '~')
                // FIXME: This segfaults
                cmd = home_path + (string) Path.DIR_SEPARATOR + cmd.substring(1);

            if (Environment.find_program_in_path(cmd) != null) {
                // Valid command (shell execute for versatility)
                log(null, LogLevelFlags.LEVEL_DEBUG, "Found in path: %s", cmd);

                var spawn_cmd = new ArrayList<string>();
                add_from_strlist(spawn_cmd, this.shell_cmd);
                spawn_cmd.add(args);

                return spawn_or_log((string[]) spawn_cmd.to_array());
            } else if (FileUtils.test(cmd, FileTest.EXISTS) || uri_re.match(cmd)) {
                // URL or local path (Use desktop associations system)
                log(null, LogLevelFlags.LEVEL_DEBUG, "URL or local path: %s", cmd);
                return spawn_or_log({OPENER, cmd});
            } else {
                log(null, LogLevelFlags.LEVEL_DEBUG, "No match: %s", cmd);
                continue; // No match, try the alternate interpretation.
            }
        }

        // Fall back to letting the shell try to make sense of it.
        log(null, LogLevelFlags.LEVEL_DEBUG, "Attempting shell fallback for %s", args);

        var spawn_cmd = new ArrayList<string>();
        if (_useterm)
            log(null, LogLevelFlags.LEVEL_DEBUG, "Using terminal for %s", args);
            add_from_strlist(spawn_cmd, this.term_cmd);

        add_from_strlist(spawn_cmd, shell_cmd);
        spawn_cmd.add(Shell.quote(args));

        return spawn_or_log((string[]) spawn_cmd.to_array());
    }
}


public class RunDialog : Dialog {
    private Entry command_entry;
    private ProcessRunner runner;

    public RunDialog() {
        runner = new ProcessRunner();

        this.title = "Run:";
        this.decorated = false;
        this.border_width = 2;
        this.set_default_size(350,50);

        // Must realize() before doing either of these.
        // http://stackoverflow.com/a/8378059/435253
        this.realize();
        this.set_keep_above(true);
        this.get_window().set_decorations(Gdk.WMDecoration.BORDER);


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
            if (runner.run(this.command_entry.text))
                this.command_entry.text = "";
        });
    }

    public static int main (string[] args) {
        Gtk.init(ref args);
        // TODO: Use Log.set_handler to omit DEBUG and INFO by default.

        var dialog = new RunDialog();
        dialog.destroy.connect(Gtk.main_quit);
        dialog.show();
        Gtk.main();
        return 0;
    }
}
