#!/system/bin/sh
# Shared helpers for rvmm-softboot-fix
BB=/data/adb/ksu/bin/busybox
FIXDIR=/data/adb/rvmm-fix
LOG=$FIXDIR/log.txt
mkdir -p "$FIXDIR/cache" "$FIXDIR/data"

log() {
	echo "$(date '+%m-%d %H:%M:%S') $*" >>"$LOG"
	# keep log small
	if [ "$(wc -l <"$LOG")" -gt 400 ]; then
		tail -n 200 "$LOG" >"$LOG.tmp" && mv -f "$LOG.tmp" "$LOG"
	fi
}

# Lists j-hc style module dirs: have config with PKG_NAME/PKG_VER and utils.sh with mount_rv
rv_modules() {
	for M in /data/adb/modules/*/; do
		M=${M%/}
		[ -f "$M/config" ] && [ -f "$M/utils.sh" ] || continue
		grep -q '^PKG_NAME=' "$M/config" && grep -q '^PKG_VER=' "$M/config" || continue
		grep -q 'mount_rv' "$M/utils.sh" || continue
		[ -f "$M/disable" ] || [ -f "$M/remove" ] || [ -f "$M/disabled_by_action" ] && continue
		echo "$M"
	done
}

# Only handle packages whose system copy is hidden by the module's own hook
needs_fix() { [ -f "/data/adb/post-fs-data.d/$1-uninstall.sh" ]; }

cfg() { grep -m1 "^$1=" "$2/config" | cut -d= -f2-; }

installed_ver() {
	V=$(dumpsys package "$1" 2>/dev/null | grep -m1 versionName=)
	echo "${V#*=}"
}

base_path() {
	P=$(pm path "$1" 2>/dev/null | grep -m1 'base.apk')
	P=${P#package:}
	[ -n "$P" ] && echo "${P%/*}"
}
