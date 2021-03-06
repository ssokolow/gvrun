/** Simple API for taking a command and heuristically guessing how to open it.
 *
 * Basically a superset of what the tools it uses (xdg-open, start.exe, etc.)
 * do with what you give them.
 *
 * Resolves:
 *  - Executable names and paths (arguments processed by $SHELL)
 *  - Non-executable paths and URLs (handled by xdg-open and friends)
 *  - Shell script snippets (resorts to `$SHELL -c` as a fallback)
 *
 * @author Stephan Sokolow <http://www.ssokolow.com/ContactMe>
 * @license MIT
 *
 * Copyright (c) 2011 Stephan Sokolow
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */


/** Resolve a path beginning with "~" */
public static string expand_tilde(string path) {
    // Just pass paths through if they don't start with ~
    if (!path.has_prefix("~")) { return path; }

    // Split the ~user portion from the path
    // (Use / for the path if not present)
    string parts[2];
    if (!(Path.DIR_SEPARATOR_S in path)) {
        parts = { path.substring(1), Path.DIR_SEPARATOR_S };
    } else {
        string trimmed = path.substring(1);
        parts = trimmed.split(Path.DIR_SEPARATOR_S, 2);
    }
    warn_if_fail(parts.length == 2);

    // Handle both "~" and "~user" forms
    string home_path;
    if (parts[0] == "") {
        home_path = Environment.get_variable("HOME") ?? Environment.get_home_dir();
    } else {
        unowned Posix.Passwd _pw = Posix.getpwnam(parts[0]);
        home_path = (_pw == null) ? null : _pw.pw_dir;
    }

    // Fail safely if we couldn't look up a homedir
    if (home_path == null) {
        warning("Could not get homedir for user: %s", parts[0].length > 0 ? parts[0] : "<current user>");
        return path;
    } else {
        return home_path + Path.DIR_SEPARATOR_S + parts[1];
    }
}

// XXX: Is there REALLY no generic way to turn an array into a Gee data type?
public string[] strlist_concat(string[] strlist, string[] string_array) {
    string[] result = strlist;
    foreach (var str in string_array) { result += str; }
    return result;
}

/** Simple class wrapping xdg-open and similar functionality. */
public class ProcessRunner : Object {
    private string open_cmd;
    private string[] shell_cmd;
    private string[] term_cmd;

    private bool use_term = false;
    private Regex uri_re;

    public const string[] OPENERS = {"xdg-open", "open", "start", "mimeopen"};

    public ProcessRunner(bool? use_term) {
        // Choose the best method available for accessing file associations.
        foreach (var cmd in OPENERS) {
            if (Environment.find_program_in_path(cmd) != null) {
                this.open_cmd = cmd;
                break;
            }
        }

        this.shell_cmd   = {Environment.get_variable("SHELL"), "-c"}; // TODO: On Windows, use COMSPEC.
        this.term_cmd    = {"urxvt", "-e"}; // TODO: On Windows, leave this blank.
        this.use_term    = use_term && !Posix.isatty(Posix.stdout.fileno());

        // There's no way to make Vala understand that it can know at compile
        // time whether this will or won't throw a RegexError, so just silence
        // the warning responsibly.
        try {
            uri_re =  new Regex("^[a-zA-Z0-9+.\\-]+:.+$", RegexCompileFlags.CASELESS);
        } catch (RegexError e) {
            error("Bad compile-time constant: ProcessRunner.uri_re");
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
            warning("spawn_async() failed for %s", _argv[0]);
            return false;
        }
    }

    /** Convenience wrapper for run() which parses a single string. */
    public bool run_string(string args) {
        string[] argv;
        try {
            Shell.parse_argv(args, out argv);
        } catch (ShellError e) {
            warning("parse_argv() failed for: %s", args);
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

        // Generate args from argv if not provided
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
            cmd = expand_tilde(cmd);

            string _cmd; // Resolved command
            if ((_cmd = Environment.find_program_in_path(cmd)) != null) {
                // Valid command (shell execute for versatility)
                message("Executing with shell: %s (%s)", _cmd, _args);

                string[] spawn_cmd = this.shell_cmd;
                spawn_cmd += _args;

                return spawn_or_log((string[]) spawn_cmd);
            } else if (FileUtils.test(cmd, FileTest.EXISTS) || uri_re.match(cmd)) {
                // URL or local path (Use desktop associations system)
                message("URL or local path: %s (Opening with %s)", cmd, this.open_cmd);
                return spawn_or_log({this.open_cmd, cmd});
            } else {
                debug("No match: '%s'", cmd);
                continue; // No match, try the alternate interpretation.
            }
        }

        // Fall back to letting the shell try to make sense of it.
        message("Attempting shell fallback for %s", _args);

        string[] spawn_cmd = {};
        if (this.use_term) {
            // TODO: Decide how to add this functionality to the
            // find_program_in_path branch without it being annoying.
            debug("Using terminal for %s", _args);
            spawn_cmd = this.term_cmd;
        }

        spawn_cmd = strlist_concat(spawn_cmd, shell_cmd);
        spawn_cmd += args;

        return spawn_or_log((string []) spawn_cmd);
    }
}


