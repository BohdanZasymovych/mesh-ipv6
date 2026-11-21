#!/usr/bin/env bash
# Prepare the laptop's network settings for running a Border Router.
# Changes are temporary: run again after every reboot.
#
# Usage: scripts/host-setup.sh
set -euo pipefail
source "$(dirname "$0")/lib.sh"
require_var INFRA_IF

ip link show "$INFRA_IF" >/dev/null 2>&1 ||
	die "interface '$INFRA_IF' not found. Set INFRA_IF in .env (see: ip link)"

info "Enabling IPv6 forwarding and RA acceptance on $INFRA_IF (needs sudo)"
# Route packets between the Thread network and the normal network
sudo sysctl -q -w net.ipv6.conf.all.forwarding=1
# Only needed for NAT64 (Thread devices reaching IPv4-only servers)
sudo sysctl -q -w net.ipv4.ip_forward=1
# Keep accepting Router Advertisements on Wi-Fi even with forwarding on
sudo sysctl -q -w "net.ipv6.conf.$INFRA_IF.accept_ra=2"
# Accept routes to other /64 networks (e.g. other Thread networks) from RAs
sudo sysctl -q -w "net.ipv6.conf.$INFRA_IF.accept_ra_rt_info_max_plen=64"

if systemctl is-active --quiet ModemManager 2>/dev/null; then
	warn "ModemManager is running and may grab the RCP serial port."
	warn "Stop it with: sudo systemctl disable --now ModemManager"
fi

info "Done. Next: docker compose up -d"
