#!/bin/sh
# Builds installable KernelSU module zips into dist/
set -e
cd "$(dirname "$0")"
mkdir -p dist
for M in modules/*/; do
	M=${M%/}; ID=$(grep '^id=' "$M/module.prop" | cut -d= -f2); VER=$(grep '^version=' "$M/module.prop" | cut -d= -f2)
	for f in "$M"/*.sh; do sh -n "$f"; done
	OUT="dist/$ID-$VER.zip"; rm -f "$OUT"
	(cd "$M" && zip -qr -X "../../$OUT" . -x '.*')
	echo "built $OUT"
done
