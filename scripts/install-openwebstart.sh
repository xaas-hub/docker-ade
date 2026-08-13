#!/bin/sh
# Build-time installer for the JNLP stack:
#
#   1. OpenWebStart, from the upstream .deb published by Karakun. It installs
#      into /opt/OpenWebStart and carries its own JRE, which runs OpenWebStart
#      itself and nothing else.
#   2. Azul Zulu 8 with JavaFX. Only JVMs registered in the JVM Manager can run
#      a JNLP application, and the Agenzia applications are JavaFX ones: a
#      plain OpenJDK 8 (Adoptium and friends) has no JavaFX and will not start
#      them. Zulu is unpacked into /opt/jvm and OpenWebStart is pointed there.
#
# Both artefacts can be supplied offline by dropping them into vendor/ before
# the build; the .deb is then verified against the same pinned checksum.
set -eu

OWS_URL="$1"
OWS_SHA256="$2"
ZULU_API="$3"

VENDOR=/build-vendor
JVM_DIR="${JVM_DIR:-/opt/jvm}"
DEFAULTS_DIR=/opt/openwebstart-defaults

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- OpenWebStart -----------------------------------------------------------
DEB="${tmp}/ows.deb"
local_deb=""
if [ -d "${VENDOR}" ]; then
	local_deb=$(find "${VENDOR}" -maxdepth 1 -iname 'OpenWebStart_linux*.deb' | head -n1)
fi

if [ -n "${local_deb}" ]; then
	echo "Using local OpenWebStart package: ${local_deb}"
	cp "${local_deb}" "${DEB}"
else
	echo "Downloading ${OWS_URL}"
	curl -fsSL --retry 3 -o "${DEB}" "${OWS_URL}"
fi

# sha256sum -c expects a lowercase digest; lowercase the hash only, never the
# path, because mktemp generates uppercase characters.
printf '%s  %s\n' "$(printf '%s' "${OWS_SHA256}" | tr 'A-F' 'a-f')" "${DEB}" | sha256sum -c -
dpkg -i "${DEB}"

# --- Zulu 8 with JavaFX -----------------------------------------------------
ZULU=""
if [ -d "${VENDOR}" ]; then
	ZULU=$(find "${VENDOR}" -maxdepth 1 -iname 'zulu8*fx*linux_x64.tar.gz' | head -n1)
fi

if [ -n "${ZULU}" ]; then
	echo "Using local Zulu archive: ${ZULU}"
else
	echo "Resolving Zulu 8 + JavaFX through the Azul metadata API"
	meta="${tmp}/zulu.json"
	curl -fsSL --retry 3 -H 'accept: application/json' -o "${meta}" "${ZULU_API}"

	url=$(jq -r '.[0].download_url // empty' "${meta}")
	sha=$(jq -r '.[0].sha256_hash // empty' "${meta}")
	if [ -z "${url}" ]; then
		echo "ERROR: the metadata API returned no package. Response:" >&2
		head -c 2000 "${meta}" >&2
		exit 1
	fi

	ZULU="${tmp}/$(basename "${url}")"
	echo "Downloading ${url}"
	curl -fsSL --retry 3 -o "${ZULU}" "${url}"

	# The digest travels next to the URL on the same TLS connection, so it
	# guards against a truncated or tampered CDN response, not against Azul.
	if [ -n "${sha}" ]; then
		printf '%s  %s\n' "${sha}" "${ZULU}" | sha256sum -c -
	else
		echo "WARNING: no sha256_hash in the API response, archive unverified" >&2
	fi
fi

mkdir -p "${JVM_DIR}"
tar -xzf "${ZULU}" -C "${JVM_DIR}"
chmod -R a+rX "${JVM_DIR}"

# The archive unpacks into a single versioned top-level directory, so the
# launcher sits at ${JVM_DIR}/<zulu…>/bin/java: depth 3, not 2.
jvm=$(find "${JVM_DIR}" -maxdepth 3 -name java -type f -path '*/bin/java' | head -n1)
if [ -z "${jvm}" ]; then
	echo "ERROR: no java binary found under ${JVM_DIR} after unpacking" >&2
	exit 1
fi
"${jvm}" -version

# --- OpenWebStart defaults --------------------------------------------------
# Seeded into the persistent home by the entrypoint rather than written into
# the installation directory: a deployment.properties inside the install dir
# takes precedence over the user one, which would make the settings GUI
# silently ineffective.
mkdir -p "${DEFAULTS_DIR}"
cat >"${DEFAULTS_DIR}/deployment.properties" <<EOF
# Use the Zulu 8 + JavaFX runtime shipped in the image instead of downloading
# one from the default JVM server. Delete this file to fall back to the
# stock OpenWebStart behaviour.
ows.jvm.manager.searchLocalAtStartup=true
ows.jvm.manager.excludeDefaultSearchLocation=true
ows.jvm.manager.customSearchLocation=${JVM_DIR}

# The default strategy is ASK_FOR_UPDATE_ON_LOCAL_MATCH: even when the local
# Zulu already satisfies the <j2se> request, OWS still offers whatever newer
# runtime the download server advertises — currently an Adoptium 21, which has
# no JavaFX and would not start the Agenzia applications. The local match is
# always the right answer here.
ows.jvm.manager.updateStrategy=DO_NOTHING_ON_LOCAL_MATCH
EOF

echo "OpenWebStart installed; JVM registered from ${JVM_DIR}"
