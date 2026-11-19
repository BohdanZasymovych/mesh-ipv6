#!/usr/bin/env bash
# Show the state of the Border Router and the Thread network.
#
# Usage: scripts/status.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require_otbr

section() { printf '\n\033[1m%s\033[0m\n' "$*"; }

section "Border Router"
echo "state:   $(otctl state)"
echo "rloc16:  $(otctl rloc16)"
echo "network: $(otctl networkname), channel $(otctl channel), PAN ID $(otctl panid)"

section "IPv6 addresses on wpan0"
ip -6 -brief addr show wpan0 | tr ' ' '\n' | grep : || echo "(none)"

section "Routers in the mesh"
otctl router table

section "Children (end devices)"
otctl child table

section "Devices registered over SRP (Matter devices show up here)"
otctl srp server host
