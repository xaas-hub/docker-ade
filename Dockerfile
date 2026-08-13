# syntax=docker/dockerfile:1

# Runtime for the desktop applications published by the Agenzia delle Entrate.
#
# The image deliberately contains NO software from the Agenzia: only the
# generic stack those applications need (GTK, fonts, OpenWebStart, a Java 8
# runtime with JavaFX) plus the launchers in scripts/. Desktop Telematico is
# downloaded into the persistent volume on first run, which keeps the image
# redistributable and lets a new release be adopted without a rebuild.
#
# Everything application-specific lives in scripts/, so a variant based on
# jlesage/baseimage-gui (browser access through noVNC) can reuse them
# unchanged: only the base image, the CMD and the X11 mount would differ.

FROM debian:bookworm-slim

# OpenWebStart, upstream release from github.com/karakun/OpenWebStart.
ARG OWS_URL=https://github.com/karakun/OpenWebStart/releases/download/v1.14.0/OpenWebStart_linux_1_14_0.deb
ARG OWS_SHA256=7e600b779111de2ef18b7b93badada887ba6fb227bc6503e656a284fd9c4563d

# Azul metadata API query resolving the latest Zulu 8 build that bundles
# JavaFX. The API answers over TLS with the download URL and its SHA-256, so
# the archive is verified without pinning a version that would rot here.
ARG ZULU_API="https://api.azul.com/metadata/v1/zulu/packages/?java_version=8&os=linux&arch=x64&archive_type=tar.gz&java_package_type=jdk&javafx_bundled=true&release_status=ga&availability_types=CA&latest=true&include_fields=sha256_hash&page_size=1"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=it_IT.UTF-8 \
    LC_ALL=it_IT.UTF-8 \
    HOME=/data/home \
    DT_HOME=/data/desktop-telematico \
    WORK_DIR=/data/workspace \
    VENDOR_DIR=/vendor \
    JVM_DIR=/opt/jvm \
    OWS_HOME=/opt/OpenWebStart

# Desktop Telematico 1.4.0 of 04/06/2026, Linux 64-bit. URL and checksum are
# published on https://telematici.agenziaentrate.gov.it/Main/Desktop.jsp and
# are consumed at RUN time, so they can be overridden from .env when the
# Agenzia releases a new version — no rebuild needed. Bump both together.
ENV DT_URL=https://swdownload1.agenziaentrate.gov.it/repos/DesktopTelematico-linux64_140.zip \
    DT_SHA256=C0305F87A603E3D89780896948A5F0B87BBABBCA42306BF5FEC5904C2475595E

# --- System dependencies ----------------------------------------------------
# Desktop Telematico ships its own JVM 1.8 but links against the system GTK/SWT
# stack; the JNLP applications need a working font and X client setup.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        unzip \
        locales \
        procps \
        libgtk2.0-0 \
        libgtk-3-0 \
        libwebkit2gtk-4.0-37 \
        libxtst6 \
        libxrender1 \
        libxi6 \
        libxss1 \
        libnss3 \
        libasound2 \
        libcanberra-gtk-module \
        libcanberra-gtk3-module \
        fontconfig \
        fonts-dejavu-core \
        fonts-liberation2 \
    && sed -i 's/^# *\(it_IT.UTF-8\)/\1/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

# --- JNLP stack -------------------------------------------------------------
# vendor/ is copied at build time as well, so that an air-gapped build can
# supply the OpenWebStart .deb and the Zulu archive from local files.
COPY vendor/ /build-vendor/
COPY --chmod=0755 scripts/install-openwebstart.sh /tmp/
RUN /tmp/install-openwebstart.sh "${OWS_URL}" "${OWS_SHA256}" "${ZULU_API}" \
    && rm -rf /tmp/install-openwebstart.sh /build-vendor

COPY scripts/install-desktop-telematico.sh /opt/bin/install-desktop-telematico
COPY scripts/desktop-telematico /opt/bin/desktop-telematico
COPY scripts/jws /opt/bin/jws
COPY scripts/entrypoint.sh /opt/bin/entrypoint.sh
# rpf and isa are aliases of the same launcher, which dispatches on argv[0].
RUN chmod +x /opt/bin/* \
    && ln -s jws /opt/bin/rpf \
    && ln -s jws /opt/bin/isa

# --- Runtime layout ---------------------------------------------------------
# The container runs as root by default. With a daemon configured for
# userns-remap, container uid 0 maps to the host user, which is what keeps the
# bind-mounted ./data writable from the host and lets the X11 socket accept the
# connection. Without userns-remap, set DOCKER_USER in .env to your own
# uid:gid: the entrypoint registers that uid in /etc/passwd, because Java
# derives user.home from the passwd database and ignores $HOME.
RUN mkdir -p /data /vendor "${JVM_DIR}" \
    && rm -rf /root && ln -s "${HOME}" /root

ENV PATH="/opt/bin:${PATH}"
WORKDIR /data/workspace

ENTRYPOINT ["/opt/bin/entrypoint.sh"]
CMD ["desktop-telematico"]
