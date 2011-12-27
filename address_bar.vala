using Gtk;

class RunDialog : Dialog {
    private Entry command_entry;

    public RunDialog() {
        this.title = "Run:";
        this.decorated = false;
        this.border_width = 2;

        this.set_keep_above(true);

        create_widgets();
        connect_signals();
    }

    private void create_widgets() {
        // Create and setup widgets
        this.command_entry = new Entry();
        var command_label = new Label.with_mnemonic("_Run program:");

        command_label.mnemonic_widget = this.command_entry;
        command_label.xalign = 0.11f;

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
            var args =
            stdout.printf("ACTIVATE: %s\n", this.command_entry.text);
        });
    }

    public static int main (string[] args) {
        Gtk.init(ref args);

        var dialog = new RunDialog();
        dialog.destroy.connect(Gtk.main_quit);
        dialog.show();
        Gtk.main();
        return 0;
    }
}
