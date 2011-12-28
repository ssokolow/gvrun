
gvrun: gvrun.vala
	valac --pkg gtk+-3.0 --pkg gdk-x11-3.0 --pkg gee-1.0 --pkg posix --pkg x11 -X -ggdb3 gvrun.vala keybinding-manager.vala
