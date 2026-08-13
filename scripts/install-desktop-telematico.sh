#!/bin/sh
# Downloads Desktop Telematico, verifies the published SHA-256 and unpacks it
# into ${DT_HOME}, which lives on the persistent volume. It is installed at run
# time rather than baked into the image for two reasons: the application
# auto-updates itself and therefore needs a writable install directory, and the
# image can be published without redistributing the Agenzia software.
#
# Runs automatically on first launch; re-run by hand to reinstall:
#
#   docker compose run --rm ade install-desktop-telematico --force
#
# Acquisition order:
#   1. a local copy dropped in vendor/ (fully offline, most reproducible)
#   2. plain HTTPS download
#   3. HTTPS download with peer verification disabled
#
# Step 3 is safe here and is not a workaround for laziness: the download
# servers serve an incomplete certificate chain (leaf without intermediate),
# which curl cannot resolve on its own. Authenticity is established by the
# SHA-256 in DT_SHA256, published by the Agenzia on a page served over a valid
# TLS connection. The checksum is verified unconditionally on every path,
# including the local file.
set -eu

URL="${DT_URL:?DT_URL is not set}"
SHA256="${DT_SHA256:?DT_SHA256 is not set}"
DEST="${DT_HOME:?DT_HOME is not set}"
VENDOR="${VENDOR_DIR:-/vendor}"

if [ -x "${DEST}/DesktopTelematico" ] && [ "${1:-}" != "--force" ]; then
	echo "Desktop Telematico already installed in ${DEST}; use --force to reinstall."
	exit 0
fi

# sha256sum -c expects a lowercase digest; lowercase the hash only, never the
# path, because mktemp generates uppercase characters.
SHA_LC=$(printf '%s' "${SHA256}" | tr 'A-F' 'a-f')

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ZIP="${tmp}/dt.zip"

local_copy=""
if [ -d "${VENDOR}" ]; then
	local_copy=$(find "${VENDOR}" -maxdepth 1 -iname 'DesktopTelematico-linux64*.zip' | head -n1)
fi

if [ -n "${local_copy}" ]; then
	echo "Using local copy: ${local_copy}"
	cp "${local_copy}" "${ZIP}"
else
	echo "Downloading ${URL}"
	if ! curl -fL --progress-bar --retry 3 -o "${ZIP}" "${URL}"; then
		echo "TLS verification failed. Retrying without peer verification;"
		echo "integrity is still enforced by the SHA-256 check below."
		curl -fL --progress-bar --retry 3 --insecure -o "${ZIP}" "${URL}"
	fi
fi

echo "${SHA_LC}  ${ZIP}" | sha256sum -c -

mkdir -p "${tmp}/x"
unzip -q "${ZIP}" -d "${tmp}/x"

# Locate the launcher instead of assuming a single top-level directory: when the
# archive unpacks its files at the root, `find -type d` returns nothing and the
# copy below would silently take the whole filesystem as its source.
launcher=$(find "${tmp}/x" -maxdepth 3 -name 'DesktopTelematico' -type f | head -n1)
if [ -z "${launcher}" ]; then
	echo "ERROR: DesktopTelematico launcher not found in the archive. Contents:" >&2
	find "${tmp}/x" -maxdepth 2 >&2
	exit 1
fi

src=$(dirname "${launcher}")
mkdir -p "${DEST}"
cp -a "${src}/." "${DEST}/"

# The archive is packed without executable bits: both the launcher and the
# bundled JVM need them (see the ubuntu-it wiki on Desktop Telematico).
chmod +x "${DEST}/DesktopTelematico"
[ -d "${DEST}/jre/bin" ] && find "${DEST}/jre/bin" -type f -exec chmod +x {} \;
chmod -R a+rX "${DEST}"

echo "Desktop Telematico unpacked into ${DEST}"
