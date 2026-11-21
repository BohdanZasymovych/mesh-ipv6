# shellcheck shell=bash
# Shared helpers for the scripts in this folder. Sourced, not executed.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$REPO_ROOT/.env" ]]; then
	set -a
	# shellcheck disable=SC1091
	source "$REPO_ROOT/.env"
	set +a
fi

# No defaults for RCP_DEVICE and INFRA_IF: they differ on every laptop.
# Scripts that need them call require_var.
THREAD_CHANNEL="${THREAD_CHANNEL:-25}"
DATASET_FILE="${DATASET_FILE:-./thread.dataset}"
NCS_DIR="${NCS_DIR:-$HOME/ncs/v3.4.2}"
BOARD="promicro_nrf52840/nrf52840/uf2"
LOG_DIR="$REPO_ROOT/logs"
# Relative paths in .env are relative to the repo root
[[ "$DATASET_FILE" = /* ]] || DATASET_FILE="$REPO_ROOT/${DATASET_FILE#./}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarning:\033[0m %s\n' "$*" >&2; }
die() {
	printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
	exit 1
}

# require_var NAME: stop if the variable is empty.
require_var() {
	[[ -n "${!1:-}" ]] || die "$1 is not set. Copy .env.example to .env and fill it in"
}

# Run an OpenThread CLI command inside the OTBR container.
# Prints the output without the trailing "Done" line and carriage returns.
otctl() {
	docker exec otbr ot-ctl "$@" | tr -d '\r' | sed '/^Done$/d'
}

require_otbr() {
	docker ps --format '{{.Names}}' | grep -qx otbr ||
		die "OTBR container is not running. Start it with: docker compose up -d"
}

require_chip_tool() {
	command -v chip-tool >/dev/null ||
		die "chip-tool not found. Install it: sudo snap install chip-tool (see docs/border-router.md)"
}

# chip_tool LOG ARGS...: run chip-tool with all its output in LOG.
# On failure, print the interesting lines and exit.
chip_tool() {
	local log="$1"
	shift
	mkdir -p -m 700 "$LOG_DIR"
	if ! chip-tool "$@" >"$log" 2>&1; then
		grep -E 'Error|Failure|FAIL' "$log" | tail -5 >&2 || tail -20 "$log" >&2
		die "chip-tool $1 failed, full log: $log"
	fi
}

# Directory with Matter root certificates (PAA). The snap build of chip-tool
# can only read files under ~/snap/chip-tool/.
paa_dir() {
	if [[ "$(command -v chip-tool)" == /snap/* ]]; then
		echo "$HOME/snap/chip-tool/common/paa"
	else
		echo "$HOME/.local/share/chip-tool/paa"
	fi
}
