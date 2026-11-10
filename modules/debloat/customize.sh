SKIPUNZIP=0
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
# no system/ overlay: hiding is done by bind mounts in post-fs-data.sh
touch "$MODPATH/skip_mount"
ui_print "- Targets: $(grep -c '^/' "$MODPATH/targets.list") app folders will be hidden on next boot"
