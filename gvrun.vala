/** Vala-based gmrun-alike.
 *
 * TODO: Decide how to license this file. (Probably GPL)
 *
 * TODO: Make sure the variable ownership is all defined properly so I don't
 * get noticeable memleaks when I'm logged in for weeks at a time.
 */
using Gtk;

// TODO: Load hotkey from a config file
const string HOTKEY = "<Mod4>space";

// XXX: Is there REALLY no generic way to turn an array into a Gee data type?
public string[] strlist_concat(string[] strlist, string[] string_array) {
    string[] result = strlist;
    foreach (var str in string_array) { result += str; }
    return result;
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

        // FIXME: This causes a warning on hide()
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
        hide(); // We want to show all child widgets but wait to show the window.
    }

    private void connect_signals() {
        this.command_entry.activate.connect (() => {
            log(null, LogLevelFlags.LEVEL_INFO, "Attempting to run: %s", this.command_entry.text);
            if (runner.run_string(this.command_entry.text)) {
                this.command_entry.text = "";
                this.hide();
            }
        });
    }


}

public class App : Object {
    // Command-line switches
    public static bool use_terminal;
    public static bool use_gui = true;
    public static bool verbose = false;
    public static bool debug = false;

    // Modifiers which will be bound against but which we want to ignore.
    // Basically, all combinations of CapsLock and NumLock we need to bind to
    // get the behaviour we intuitively expect.
    // TODO: This can't be the proper way to do this. What do I have to mask off?
    const uint[] ignored_mods = {0, X.KeyMask.Mod2Mask, X.KeyMask.LockMask, X.KeyMask.Mod2Mask | X.KeyMask.LockMask};

    // TODO: Support a "service one request, then exit" mode.
    public const OptionEntry[] valid_opts = {
        { "verbose", 'v', 0, OptionArg.NONE, ref verbose, "Make the logging output more verbose", null},
        { "debug", 0, 0, OptionArg.NONE, ref debug, "Turn on debugging messages (make things very verbose)", null},
        { "terminal", 't', 0, OptionArg.NONE, ref use_terminal, "Run commands in a terminal if stdout isn't a TTY", null},
        { "no-terminal", 'T', OptionFlags.REVERSE, OptionArg.NONE, ref use_terminal, "Never run commands in a terminal", null },
        { null }
    };

    RunDialog dialog;

    public App(ProcessRunner runner) {

        this.dialog = new RunDialog(runner);
        dialog.delete_event.connect(() => {
            // Hijack Gtk.Dialog's default ESC behaviour and hide() instead.
            // Probably not the right way to do this, but it seems to work.
            this.dialog.hide();
            return true;
        });
    }

    public void show() {
        this.dialog.show();
    }
}

public static int main(string[] argv) {
    try {
        Gtk.init_with_args(ref argv, "[command line]", App.valid_opts, null);
    } catch (OptionError e) {
        if (e is OptionError.FAILED) {
            // Couldn't open DISPLAY
            App.use_gui = false;
        } else {
            // Error parsing argv
            log(null, LogLevelFlags.LEVEL_ERROR, e.message);
        }
    } catch (Error e) {
        log(null, LogLevelFlags.LEVEL_ERROR, "Unexpected error: %s", e.message);
    }

    // Hide DEBUG and INFO messages
    // http://stackoverflow.com/a/7519108
    Log.set_handler(null, LogLevelFlags.LEVEL_MASK, () => {});
    Log.set_handler(null,
       LogLevelFlags.LEVEL_WARNING |
       LogLevelFlags.LEVEL_ERROR |
       LogLevelFlags.LEVEL_CRITICAL, Log.default_handler);

    if (App.debug)
         Log.set_handler(null, LogLevelFlags.LEVEL_INFO | LogLevelFlags.LEVEL_DEBUG, Log.default_handler);
    else if (App.verbose)
         Log.set_handler(null, LogLevelFlags.LEVEL_INFO, Log.default_handler);

    var runner = new ProcessRunner(App.use_terminal);

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
    } else if (App.use_gui) {
        log(null, LogLevelFlags.LEVEL_DEBUG, "Starting GUI");
        App app = new App(runner);

        // TODO: I'll need an equivalent to this if I want to support Windows.
        // Have to do this here because inside a class segfaults it.
        KeybindingManager manager = new KeybindingManager();
        manager.bind(HOTKEY, app.show);
        // http://mail.gnome.org/archives/vala-list/2009-December/msg00076.html

        Gtk.main();
    } else {
        log(null, LogLevelFlags.LEVEL_ERROR, "Unable to initialize GTK+ and no arguments given.");
    }
    return 0;
}
