#!/system/bin/sh
MODDIR=${MODDIR:-${0%/*}}
. "$MODDIR/common.sh"

# Find stock apk for PKG/VER: cached copy, a module zip in Download, or the installed app.
ensure_cache() {
	PKG=$1 VER=$2 C=$FIXDIR/cache/$1-$2.apk
	[ -s "$C" ] && return 0
	for Z in /sdcard/Download/*.zip; do
		[ -f "$Z" ] || continue
		$BB unzip -p "$Z" config 2>/dev/null | grep -qx "PKG_NAME=$PKG" || continue
		$BB unzip -p "$Z" config 2>/dev/null | grep -qx "PKG_VER=$VER" || continue
		if $BB unzip -p "$Z" stock/base.apk >"$C.tmp" 2>/dev/null && [ -s "$C.tmp" ]; then
			mv -f "$C.tmp" "$C"; log "cached $PKG $VER from $Z"; break
		fi
		rm -f "$C.tmp"
	done
	if [ ! -s "$C" ] && [ "$(installed_ver "$PKG")" = "$VER" ] && BP=$(base_path "$PKG"); then
		# read the real stock apk underneath the patched bind mount
		$BB unshare -m sh -c "umount -l '$BP/base.apk' 2>/dev/null; cat '$BP/base.apk'" >"$C.tmp" 2>/dev/null
		if [ -s "$C.tmp" ] && ! $BB cmp -s "$C.tmp" "/data/adb/rvhc/$3.apk"; then
			mv -f "$C.tmp" "$C"; log "cached $PKG $VER from installed app"
		fi
		rm -f "$C.tmp"
	fi
	if [ -s "$C" ]; then
		chcon u:object_r:apk_data_file:s0 "$C"
		# drop caches of other versions
		for O in "$FIXDIR/cache/$PKG"-*.apk; do [ "$O" != "$C" ] && rm -f "$O"; done
		return 0
	fi
	return 1
}

install_stock() {
	PKG=$1 C=$2
	SZ=$(stat -c %s "$C")
	SES=$(pm install-create --user 0 -i com.android.vending -r -S "$SZ" 2>&1) || { log "install-create failed: $SES"; return 1; }
	SES=${SES#*[} SES=${SES%]*}
	OP=$(pm install-write -S "$SZ" "$SES" base.apk "$C" 2>&1) || { log "install-write failed: $OP"; pm install-abandon "$SES"; return 1; }
	OP=$(pm install-commit "$SES" 2>&1) || { log "install-commit failed: $OP"; return 1; }
	BP=$(base_path "$PKG") || { log "no basepath after install"; return 1; }
	L=$BP/lib/arm64
	mkdir -p "$L" && rm -f "$L"/*
	$BB unzip -o -j "$C" 'lib/arm64-v8a/*' -d "$L" >/dev/null 2>&1 || log "lib extract failed"
	chown -R 1000:1000 "$BP/lib"; chmod -R 755 "$BP/lib"; chcon -R u:object_r:apk_data_file:s0 "$BP/lib"
	log "installed stock $PKG $(installed_ver "$PKG")"
	(cmd package compile -m speed-profile -f "$PKG" >/dev/null 2>&1 &)
	return 0
}

restore_data() {
	PKG=$1 B=$FIXDIR/data/$1
	[ -f "$B/ce.tar" ] || return 0
	UID_=$(stat -c %u "/data/data/$PKG" 2>/dev/null)
	[ -n "$UID_" ] || { log "restore: no data dir for $PKG"; return 1; }
	am force-stop "$PKG"
	$BB tar -C /data/data -xf "$B/ce.tar" 2>/dev/null
	chown -R "$UID_:$UID_" "/data/data/$PKG"
	chown "$UID_:$((UID_ + 10000))" "/data/data/$PKG/cache" "/data/data/$PKG/code_cache" 2>/dev/null
	restorecon -RF "/data/data/$PKG"
	if [ -f "$B/de.tar" ] && [ -d "/data/user_de/0/$PKG" ]; then
		$BB tar -C /data/user_de/0 -xf "$B/de.tar" 2>/dev/null
		chown -R "$UID_:$UID_" "/data/user_de/0/$PKG"
		chown "$UID_:$((UID_ + 10000))" "/data/user_de/0/$PKG/cache" "/data/user_de/0/$PKG/code_cache" 2>/dev/null
		restorecon -RF "/data/user_de/0/$PKG"
	fi
	log "restored data of $PKG (uid $UID_)"
}

is_mounted() { su -M -c "grep -F '$1' /proc/mounts" 2>/dev/null | grep -q base.apk; }

fix_module() {
	M=$1 ID=${1##*/}
	PKG=$(cfg PKG_NAME "$M") VER=$(cfg PKG_VER "$M")
	needs_fix "$PKG" || return 0
	ensure_cache "$PKG" "$VER" "$ID"
	CUR=$(installed_ver "$PKG")
	if [ "$CUR" != "$VER" ]; then
		log "$ID: installed='$CUR' module='$VER' -> reinstalling stock"
		[ -s "$FIXDIR/cache/$PKG-$VER.apk" ] || { log "$ID: no stock apk cached for $VER; put the module zip into Download"; return 1; }
		install_stock "$PKG" "$FIXDIR/cache/$PKG-$VER.apk" || return 1
		restore_data "$PKG"
		UID_=$(stat -c %u "/data/data/$PKG" 2>/dev/null)
		[ -n "$UID_" ] && "$MODDIR/bin/ksu_profile" "$UID_" "$PKG" >/dev/null 2>&1
	fi
	if ! is_mounted "$PKG"; then
		(MODDIR=$M; export MODDIR; . "$M/utils.sh"; mount_rv_now) && log "$ID: mounted patched apk" || log "$ID: mount failed (see module description)"
	fi
}

MODE=$1
for M in $(rv_modules); do
	if [ "$MODE" = cache ]; then
		ensure_cache "$(cfg PKG_NAME "$M")" "$(cfg PKG_VER "$M")" "${M##*/}"
	else
		fix_module "$M"
	fi
done
