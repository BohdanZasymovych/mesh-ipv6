#!/usr/bin/env bash
# Copy a built firmware image to a board in UF2 bootloader mode.
# Finds the NICENANO drive wherever the distro mounts it
# (/media/$USER on Ubuntu and Pop!_OS, /run/media/$USER on Fedora and Arch).
#
# Usage: scripts/flash.sh ot-node|ot-rcp
set -euo pipefail
source "$(dirname "$0")/lib.sh"

app="${1:-}"
[[ "$app" == ot-node || "$app" == ot-rcp ]] || die "usage: $0 ot-node|ot-rcp"

uf2=""
# build/<app>/<app>/... with sysbuild (the NCS default), build/<app>/... without
for f in "$REPO_ROOT/build/$app/$app/zephyr/zephyr.uf2" "$REPO_ROOT/build/$app/zephyr/zephyr.uf2"; do
	if [[ -f "$f" ]]; then
		uf2="$f"
		break
	fi
done
[[ -n "$uf2" ]] || die "no firmware found. Build it first: scripts/build.sh $app"

find_drive() {
	findmnt -rn -S LABEL=NICENANO -o TARGET 2>/dev/null | head -1
}

drive="$(find_drive)"
if [[ -z "$drive" ]]; then
	info "Double-tap RST to GND on the board. Waiting for the NICENANO drive..."
	for _ in $(seq 1 30); do
		sleep 1
		drive="$(find_drive)"
		[[ -n "$drive" ]] && break
	done
fi
[[ -n "$drive" ]] ||
	die "NICENANO drive not found. If it shows up but is not mounted: udisksctl mount -b /dev/disk/by-label/NICENANO"

info "Copying $(basename "$uf2") to $drive"
cp "$uf2" "$drive/"
sync 2>/dev/null || true # the drive may already be gone
info "Done. The board reboots into the new firmware."
