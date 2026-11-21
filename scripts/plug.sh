#!/usr/bin/env bash
# Control a paired Matter plug over IPv6.
#
# Usage: scripts/plug.sh on|off|toggle|status|unpair [node-id] [endpoint]
#   unpair    remove the plug from our Matter network (do this before a reset)
#   node-id   default 1 (the number used in plug-pair.sh)
#   endpoint  default 1 (check with: chip-tool descriptor read parts-list <node> 0)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

cmd="${1:-}"
node="${2:-1}"
endpoint="${3:-1}"
log="$LOG_DIR/plug.log"

case "$cmd" in
on | off | toggle)
    require_chip_tool
    chip_tool "$log" onoff "$cmd" "$node" "$endpoint"
    info "Sent '$cmd' to node $node"
    ;;
status)
    require_chip_tool
    chip_tool "$log" onoff read on-off "$node" "$endpoint"
    if grep -qiE 'OnOff: TRUE|Data = true' "$log"; then
        echo "ON"
    elif grep -qiE 'OnOff: FALSE|Data = false' "$log"; then
        echo "OFF"
    else
        die "could not find the value in chip-tool output, see $log"
    fi
    ;;
unpair)
    # The plug deletes our credentials and its network registration, so it can
    # be paired again without stale records (see docs/border-router.md)
    require_chip_tool
    chip_tool "$log" pairing unpair "$node"
    info "Node $node removed. Pair it again with: scripts/plug-pair.sh <setup-code> $node"
    ;;
*)
    die "usage: $0 on|off|toggle|status|unpair [node-id] [endpoint]"
    ;;
esac
