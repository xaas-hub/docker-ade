#!/bin/bash
# Prepares the persistent layout under /data, then hands over to the command.
set -euo pipefail

mkdir -p "${HOME}" "${WORK_DIR:-/data/workspace}"

# GTK warns and occasionally refuses to start if XDG_RUNTIME_DIR is declared
# but missing. It must be private to the user.
mkdir -p "${XDG_RUNTIME_DIR:-/tmp/runtime}"
chmod 700 "${XDG_RUNTIME_DIR:-/tmp/runtime}"

# Java derives user.home from the passwd database and ignores $HOME, so an
# unknown uid would send OpenWebStart's cache and settings to "?" or /. For uid
# 0 the Dockerfile already symlinks /root to $HOME.
if ! getent passwd "$(id -u)" >/dev/null 2>&1; then
	if [ -w /etc/passwd ]; then
		echo "ade:x:$(id -u):$(id -g):Telematico:${HOME}:/bin/bash" >>/etc/passwd
	else
		echo "WARNING: uid $(id -u) is not in /etc/passwd and the file is not" >&2
		echo "writable; Java will not resolve user.home correctly." >&2
	fi
fi

# Seed the OpenWebStart configuration on first run only, so that changes made
# in the settings GUI survive and are not overwritten at every start.
OWS_CONF="${HOME}/.config/icedtea-web/deployment.properties"
if [ ! -e "${OWS_CONF}" ] && [ -f /opt/openwebstart-defaults/deployment.properties ]; then
	mkdir -p "$(dirname "${OWS_CONF}")"
	cp /opt/openwebstart-defaults/deployment.properties "${OWS_CONF}"
fi

if [ -z "${DISPLAY:-}" ]; then
	echo "WARNING: DISPLAY is not set. The GUI will not start." >&2
fi

exec "$@"
