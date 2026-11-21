#!/usr/bin/env bash
# Check that this laptop has everything the Border Router setup needs.
# Prints what is missing and how to fix it. Changes nothing.
#
# Usage: scripts/doctor.sh
set -uo pipefail # no -e: keep going after a failed check
source "$(dirname "$0")/lib.sh"

fails=0
section() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
fixhint() { if [[ -n "${1:-}" ]]; then printf '        fix: %s\n' "$1"; fi; }
bad() {
	printf '  \033[31mFAIL\033[0m  %s\n' "$1"
	fixhint "${2:-}"
	fails=$((fails + 1))
}
meh() {
	printf '  \033[33mwarn\033[0m  %s\n' "$1"
	fixhint "${2:-}"
}
in_group() { id -nG | tr ' ' '\n' | grep -qx "$1"; }

section "System"
if [[ "$(uname -s)" == Linux ]]; then
	ok "$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}")"
else
	bad "OTBR needs Linux (host networking, USB serial, Bluetooth). macOS/Windows/WSL are not supported"
fi

section "Docker"
if ! command -v docker >/dev/null; then
	bad "docker not installed" "Ubuntu/Pop!_OS: sudo apt install docker.io docker-compose-v2 (or Docker CE from docs.docker.com)"
else
	if docker info >/dev/null 2>&1; then
		ok "docker daemon reachable"
	elif ! in_group docker; then
		bad "no access to the docker daemon" "sudo usermod -aG docker \$USER, then log out and back in"
	else
		bad "docker daemon not running" "sudo systemctl enable --now docker"
	fi
	if docker compose version >/dev/null 2>&1; then
		ok "docker compose v2"
	else
		bad "'docker compose' (v2) missing; the old 'docker-compose' is not enough" "sudo apt install docker-compose-v2"
	fi
	image="$(sed -n 's/^[[:space:]]*image:[[:space:]]*//p' "$REPO_ROOT/compose.yaml" | head -1)"
	if docker image inspect "$image" >/dev/null 2>&1; then
		ok "OTBR image pulled"
	else
		meh "OTBR image not pulled yet (docker compose up will pull it)" "docker compose pull"
	fi
fi

section "Settings (.env)"
if [[ ! -f "$REPO_ROOT/.env" ]]; then
	bad ".env missing" "cp .env.example .env, then fill in RCP_DEVICE and INFRA_IF"
fi
if [[ -z "${RCP_DEVICE:-}" ]]; then
	bad "RCP_DEVICE not set" "ls -l /dev/serial/by-id/ and put the Thread_Co-Processor path into .env"
elif [[ ! -e "$RCP_DEVICE" ]]; then
	bad "RCP_DEVICE $RCP_DEVICE not found" "plug in the RCP board; check ls -l /dev/serial/by-id/"
else
	ok "RCP_DEVICE exists"
	[[ "$RCP_DEVICE" == *Co-Processor* ]] ||
		meh "RCP_DEVICE does not look like the RCP board (expected *Thread_Co-Processor*)" "flash it with ot-rcp: scripts/build.sh ot-rcp && scripts/flash.sh ot-rcp"
fi
if [[ -z "${INFRA_IF:-}" ]]; then
	bad "INFRA_IF not set" "ip -br link, put the Wi-Fi/Ethernet interface name into .env"
elif ! ip link show "$INFRA_IF" >/dev/null 2>&1; then
	bad "interface $INFRA_IF not found" "ip -br link, fix INFRA_IF in .env"
else
	ok "INFRA_IF $INFRA_IF exists"
fi

section "Serial ports"
if systemctl is-active --quiet ModemManager 2>/dev/null; then
	bad "ModemManager is running and grabs /dev/ttyACM* ports" "sudo systemctl disable --now ModemManager"
else
	ok "ModemManager not running"
fi
serial_group=dialout
getent group dialout >/dev/null || serial_group=uucp # Arch
if in_group "$serial_group"; then
	ok "in group $serial_group (picocom to ot-node boards)"
else
	meh "not in group $serial_group, picocom to ot-node boards will fail" "sudo usermod -aG $serial_group \$USER, then log out and back in"
fi

section "Matter (chip-tool, Bluetooth, mDNS)"
if ! command -v chip-tool >/dev/null; then
	bad "chip-tool not installed" "sudo snap install chip-tool (Pop!_OS: sudo apt install snapd first)"
elif [[ "$(command -v chip-tool)" == /snap/* ]]; then
	ok "chip-tool (snap)"
	while read -r plug; do
		bad "chip-tool snap interface $plug not connected" "sudo snap connect $plug"
	done < <(snap connections chip-tool 2>/dev/null | awk 'NR > 1 && $3 == "-" { print $2 }')
else
	ok "chip-tool ($(command -v chip-tool))"
fi
if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
	ok "avahi-daemon running"
else
	bad "avahi-daemon not running (chip-tool finds devices over mDNS)" "sudo apt install avahi-daemon && sudo systemctl enable --now avahi-daemon"
fi
if ! command -v bluetoothctl >/dev/null; then
	bad "bluetoothctl missing" "sudo apt install bluez"
elif timeout 5 bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
	ok "Bluetooth on"
else
	bad "no Bluetooth adapter, or it is off (needed once, for pairing the plug)" "rfkill unblock bluetooth && bluetoothctl power on"
fi
command -v curl >/dev/null && ok "curl" || bad "curl missing" "sudo apt install curl"

section "Firmware build (only needed to build ot-node / ot-rcp)"
if command -v west >/dev/null; then ok "west"; else meh "west not in PATH" "open the NCS v3.4.2 toolchain environment (see README)"; fi
if [[ -d "$NCS_DIR" ]]; then ok "NCS at $NCS_DIR"; else meh "NCS not found at $NCS_DIR" "install NCS v3.4.2 or set NCS_DIR in .env"; fi

section "Current session"
if [[ "$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)" == 1 ]]; then
	ok "IPv6 forwarding on"
else
	meh "IPv6 forwarding off" "scripts/host-setup.sh (again after every reboot)"
fi
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx otbr; then
	ok "OTBR container running"
else
	meh "OTBR container not running" "docker compose up -d"
fi

echo
if ((fails > 0)); then
	printf '\033[1;31m%d problem(s) found.\033[0m\n' "$fails"
	exit 1
fi
printf '\033[1;32mAll required checks passed.\033[0m\n'
