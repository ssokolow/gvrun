
gvrun: gvrun.vala process_runner.vala keybinding-manager.vala
	valac --pkg gtk+-3.0 --pkg gdk-x11-3.0 --pkg gee-1.0 --pkg posix --pkg x11 -X -O1 gvrun.vala process_runner.vala keybinding-manager.vala
