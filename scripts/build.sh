#!/usr/bin/env bash
# Build a firmware image with the nRF Connect SDK (NCS).
# Run it from a shell where `west` works: the NCS v3.4.2 toolchain environment
# (nRF Connect for VS Code terminal, or nrfutil sdk-manager).
#
# Usage: scripts/build.sh ot-node|ot-rcp [-- extra CMake args]
#   e.g. scripts/build.sh ot-node -- -DEXTRA_CONF_FILE=extra_conf/l2_logging.conf
set -euo pipefail
source "$(dirname "$0")/lib.sh"

app="${1:-}"
[[ "$app" == ot-node || "$app" == ot-rcp ]] || die "usage: $0 ot-node|ot-rcp [-- extra CMake args]"
shift
command -v west >/dev/null || die "west not found. Open the NCS v3.4.2 toolchain environment first (see README)"
[[ -d "$NCS_DIR" ]] || die "NCS not found at $NCS_DIR. Set NCS_DIR in .env"

# west only works inside the NCS workspace. Sources and build output stay in this repo.
cd "$NCS_DIR"
west build -p always -b "$BOARD" -d "$REPO_ROOT/build/$app" "$REPO_ROOT/$app" "$@"
info "Built. Flash with: scripts/flash.sh $app"
