#!/usr/bin/env bash
# Add (commission) a Matter-over-Thread device, e.g. the IKEA GRILLPLATS plug.
# The plug must be in pairing mode: first 15 minutes after plugging it in,
# or press its ON/OFF button. The laptop needs Bluetooth.
#
# Usage: scripts/plug-pair.sh <setup-code> [node-id]
#   setup-code  "MT:..." from the QR code, or the 11-digit code without dashes
#   node-id     number you give the device in chip-tool (default 1)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

code="${1:-}"
node="${2:-1}"
[[ -n "$code" ]] || die "usage: $0 <setup-code> [node-id]"
require_chip_tool
[[ -s "$DATASET_FILE" ]] || die "$DATASET_FILE not found. Run scripts/thread-form.sh first"

# chip-tool only trusts test certificates by default. Real devices are signed
# by their vendor's root certificate (PAA), published in the Matter repo.
PAA_DIR="$(paa_dir)"
PAA_BASE="https://raw.githubusercontent.com/project-chip/connectedhomeip/master/credentials/production/paa-root-certs"
PAA_FILES=(dcld_mirror_CN_IKEA_of_Sweden_Matter_PAA_G1_vid_0x117C_1.der)
mkdir -p "$PAA_DIR"
for f in "${PAA_FILES[@]}"; do
	if [[ ! -s "$PAA_DIR/$f" ]]; then
		info "Downloading root certificate $f"
		curl -fsSL -o "$PAA_DIR/$f" "$PAA_BASE/$f"
	fi
done

# May contain the Thread dataset (network key), so LOG_DIR is private (700)
log="$LOG_DIR/pairing.log"
info "Pairing node $node (log: $log). This takes 30 s to a few minutes..."
chip_tool "$log" pairing code-thread "$node" "hex:$(cat "$DATASET_FILE")" "$code" \
	--paa-trust-store-path "$PAA_DIR"
grep -q "commissioning completed with success" "$log" ||
	die "chip-tool exited without reporting success, see $log"

addr="$(grep -oE 'Updating device address to UDP:\[[0-9a-f:]+\]' "$log" | tail -1 | grep -oE '[0-9a-f:]{6,}' || true)"
info "Success. Device address: ${addr:-unknown}"
info "Try: scripts/plug.sh toggle $node"
