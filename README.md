# KernelSU modules for Galaxy Tab S11 Ultra (SM-X936B)

Device context: One UI 9 / Android 17, KernelSU Next 3.4.x **without a metamodule**, root obtained by an exploit:
every boot first runs unrooted, then KernelSU soft-restarts `system_server`.
Because of that, `system/` overlays in modules are not applied and `pm uninstall --user 0` of system apps does not persist.

## Modules

### `debloat` — Samsung Debloat
Hides bloatware and telemetry systemlessly: `post-fs-data.sh` bind-mounts an empty directory over every path in
`targets.list` before PackageManager scans, so the apps do not exist for the system. `/system` is not modified.
- Edit `targets.list` (one APK folder per line, find it with `dumpsys package <pkg> | grep codePath`), reflash, reboot.
- Apps with updates in `/data` need `pm uninstall-system-updates <pkg>` first.
- Result log: `/data/adb/modules/debloat/last_run.log`.
- Restore: remove the module (or hold Volume Down during boot to disable all modules).

### `rvmm-softboot-fix` — RVMM Soft-boot Fix
Keeps j-hc root modules (YouTube Morphe / ReVanced, etc.) working with exploit root.
Problem: the preloaded app (e.g. YouTube 21.31.525) is newer than the module's stock version (21.30.216), so the module
hides the system copy with a `post-fs-data.d` hook; during the unrooted boot stage PackageManager sees the newer system
app and deletes the installed stock app, and then wipes its data.

What the module does on each boot:
1. `post-fs-data.sh` (rooted stage, before the rescan): backs up the app data to `/data/adb/rvmm-fix/data/`.
2. `service.sh`: waits for the **new** `system_server` (`sys.boot_completed` survives the soft restart), reinstalls the
   stock APK from `/data/adb/rvmm-fix/cache/`, extracts native libs, restores data, applies the KernelSU app profile,
   and calls the target module's own `mount_rv_now`.
3. Every 5 min caches the stock APK of a newly flashed module version (from its zip in `/sdcard/Download` or from the installed app).

Only acts on packages whose module created `/data/adb/post-fs-data.d/<pkg>-uninstall.sh`. The Action button runs the fix
and shows the log (`/data/adb/rvmm-fix/log.txt`). `bin/ksu_profile` comes from j-hc's revanced-magisk-module.

## Build
```sh
./build.sh            # -> dist/<id>-<version>.zip
adb push dist/*.zip /sdcard/Download/   # then install in KernelSU Next
```
