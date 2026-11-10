#!/system/bin/sh
MODDIR=${0%/*}
EMPTY=$MODDIR/empty
mkdir -p "$EMPTY"
LOG=$MODDIR/last_run.log
: > "$LOG"
while read -r d; do
  [ -z "$d" ] && continue
  if [ -d "$d" ]; then
    mount --bind "$EMPTY" "$d" && echo "hidden $d" >> "$LOG" || echo "FAIL $d" >> "$LOG"
  else
    echo "missing $d" >> "$LOG"
  fi
done < "$MODDIR/targets.list"
