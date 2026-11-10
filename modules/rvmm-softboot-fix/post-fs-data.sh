#!/system/bin/sh
# Runs on the rooted (second) boot stage, before PackageManager rescans.
# The stock app was dropped during the unrooted stage; PM is about to wipe its data,
# so back the data up now and restore it after reinstall in service.sh.
MODDIR=${0%/*}
. "$MODDIR/common.sh"

# remember the system_server of the unrooted stage (service.sh waits for a new one)
pidof system_server >"$FIXDIR/ss_pid" 2>/dev/null || : >"$FIXDIR/ss_pid"

for M in $(rv_modules); do
	PKG=$(cfg PKG_NAME "$M")
	needs_fix "$PKG" || continue
	B=$FIXDIR/data/$PKG
	if [ -d "/data/data/$PKG" ] && [ -n "$(ls -A "/data/data/$PKG" 2>/dev/null | grep -vxE 'cache|code_cache')" ]; then
		mkdir -p "$B"
		$BB tar -C /data/data -cf "$B/ce.tar.tmp" --exclude="$PKG/cache" --exclude="$PKG/code_cache" "$PKG" 2>/dev/null &&
			mv -f "$B/ce.tar.tmp" "$B/ce.tar"
		if [ -d "/data/user_de/0/$PKG" ]; then
			$BB tar -C /data/user_de/0 -cf "$B/de.tar.tmp" --exclude="$PKG/cache" --exclude="$PKG/code_cache" "$PKG" 2>/dev/null &&
				mv -f "$B/de.tar.tmp" "$B/de.tar"
		fi
		log "pfd: backed up data of $PKG ($(du -sh "$B/ce.tar" | cut -f1))"
	else
		log "pfd: no data for $PKG to back up (keeping previous backup)"
	fi
done
