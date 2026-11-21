#!/usr/bin/env bash
# Start the Thread network on the Border Router.
# - If OTBR already has a network, it just makes sure it is running.
# - Else, if DATASET_FILE exists (e.g. a teammate sent you theirs), it joins
#   that network.
# - Otherwise it creates a new network (random key) on THREAD_CHANNEL.
# Saves the active dataset hex to DATASET_FILE for joining other devices.
#
# Usage: scripts/thread-form.sh          # start, join or create
#        scripts/thread-form.sh --new    # throw away the old network, create a new one
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require_otbr

current_dataset() { otctl dataset active -x 2>/dev/null | grep -E '^[0-9a-fA-F]+$' || true; }

create_network() {
	otctl dataset init new >/dev/null
	otctl dataset channel "$THREAD_CHANNEL" >/dev/null
	otctl dataset commit active >/dev/null
}

if [[ "${1:-}" == "--new" ]]; then
	warn "Creating a NEW network. Devices on the old one (e.g. the plug) must be re-added."
	read -r -p "Continue? [y/N] " answer
	[[ "$answer" == [yY] ]] || exit 1
	otctl thread stop >/dev/null || true
	otctl ifconfig down >/dev/null || true
	otctl dataset clear >/dev/null
	create_network
elif [[ -n "$(current_dataset)" ]]; then
	info "Using the existing network"
elif [[ -s "$DATASET_FILE" ]]; then
	info "Joining the network from $DATASET_FILE"
	otctl dataset set active "$(tr -d '[:space:]' <"$DATASET_FILE")" >/dev/null
else
	info "No network yet, creating one on channel $THREAD_CHANNEL"
	create_network
fi

otctl ifconfig up >/dev/null
otctl thread start >/dev/null

info "Waiting for the node to attach..."
state=""
for _ in $(seq 1 30); do
	state="$(otctl state)"
	[[ "$state" == leader || "$state" == router ]] && break
	sleep 1
done
[[ "$state" == leader || "$state" == router ]] ||
	die "node did not attach (state: $state). Check: docker compose logs otbr"

current_dataset >"$DATASET_FILE"
chmod 600 "$DATASET_FILE"

info "State: $state"
info "Network name: $(otctl networkname), channel: $(otctl channel)"
info "Dataset saved to $DATASET_FILE (secret: contains the network key)"
