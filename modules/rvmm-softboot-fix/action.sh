#!/system/bin/sh
# KernelSU "Action" button: run the fix now and show status.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
export MODDIR
sh "$MODDIR/fix.sh"
echo "Cache:"; ls -la "$FIXDIR/cache"
echo; echo "Data backups:"; ls -la "$FIXDIR/data" 2>/dev/null
echo; echo "Last log lines:"; tail -n 15 "$LOG"
