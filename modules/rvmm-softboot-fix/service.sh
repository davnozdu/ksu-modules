#!/system/bin/sh
MODDIR=${0%/*}
export MODDIR
. "$MODDIR/common.sh"

# sys.boot_completed survives the soft restart, so wait for the NEW system_server instead.
OLD=$(cat "$FIXDIR/ss_pid" 2>/dev/null)
until P=$(pidof system_server) && [ -n "$P" ] && [ "$P" != "$OLD" ]; do sleep 2; done
until [ "$(getprop sys.boot_completed)" = 1 ] && pm path android >/dev/null 2>&1; do sleep 2; done
until ls /sdcard/Download >/dev/null 2>&1; do sleep 2; done
sleep 15
log "service: system ready (system_server $P)"

sh "$MODDIR/fix.sh"

# Morphe's own service.sh may have failed earlier for the same reason; fix.sh remounts.
# Watcher: cache the stock apk of newly flashed module versions while they are installed.
while true; do
	sleep 300
	for M in $(rv_modules); do
		PKG=$(cfg PKG_NAME "$M") VER=$(cfg PKG_VER "$M")
		needs_fix "$PKG" || continue
		[ -s "$FIXDIR/cache/$PKG-$VER.apk" ] || sh "$MODDIR/fix.sh" cache
	done
done
