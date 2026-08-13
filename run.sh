#!/usr/bin/env bash
# Convenience wrapper: authorises the container user on the host X server, runs
# the requested command in the container, then revokes the authorisation.
#
#   ./run.sh                 # Desktop Telematico
#   ./run.sh isa 2024        # a JNLP application from vendor/
#   ./run.sh jws --list      # what is available in vendor/
#   ./run.sh bash            # a shell, to look around
set -euo pipefail

cd "$(dirname "$0")"

if [ ! -f .env ]; then
	printf 'DISPLAY=%s\n' "${DISPLAY:-:0}" >.env
	echo "Created .env with DISPLAY=${DISPLAY:-:0}."
fi

# SI:localuser matches on the peer credentials of the unix socket, so the
# authorisation names the host user the container process maps to.
xhost "+SI:localuser:$(id -un)" >/dev/null
trap 'xhost -SI:localuser:$(id -un) >/dev/null 2>&1 || true' EXIT

exec docker compose run --rm ade "$@"
