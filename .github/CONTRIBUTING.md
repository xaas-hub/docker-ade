# Contributing to docker-ade

Thank you for your interest in contributing!

## Repository Structure

```
├── Dockerfile                          # Image definition (Debian + OpenWebStart + Zulu 8 FX)
├── docker-compose.yml                  # Service definition, X11 mount, volumes
├── run.sh                              # Host wrapper: xhost authorisation + compose run
├── scripts/
│   ├── entrypoint.sh                   # Persistent layout under /data, passwd fixup
│   ├── install-openwebstart.sh         # Build-time: OpenWebStart .deb + Zulu 8 with JavaFX
│   ├── install-desktop-telematico.sh   # Run-time: download, checksum, unpack
│   ├── desktop-telematico              # Launcher for Desktop Telematico
│   └── jws                             # Launcher for JNLP applications (aliases: rpf, isa)
├── vendor/                             # Hand-downloaded .jnlp files, optional offline artefacts
├── .github/workflows/
│   ├── ci.yml                          # Lint, build, smoke test, push
│   ├── release.yml                     # Semantic release automation
│   ├── commitlint.yml                  # Commit message linting on PRs
│   ├── labeler.yml                     # Auto-label PRs
│   ├── auto-merge.yml                  # Auto-merge Dependabot PRs
│   └── stale.yml                       # Stale issue/PR housekeeping
└── .releaserc.json                     # Semantic release configuration
```

The image ships no software from the Agenzia delle Entrate: it is downloaded
from the official servers at run time into the persistent volume. Please do not
submit changes that would bundle it into the image.

## How to Contribute

### Reporting Issues

When reporting:

- Specify which image tag you're using
- Include Docker version (`docker version`) and whether the daemon uses
  `userns-remap`
- State your display stack (X11 or Wayland + XWayland) and the value of
  `$DISPLAY`
- For application failures, include the output of `./run.sh bash` followed by
  the manual launch (`cd $DT_HOME && ./DesktopTelematico`, or
  `jws --check` for JNLP problems)

### Proposing Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test locally (see below)
5. Submit a pull request

## Testing Locally

### Build Test Image

```bash
docker compose build     # after uncommenting the build: section
# or
docker build -t ade:local .
```

### Test the Image

```bash
# The JNLP stack must be in place: javaws plus a Java 8 with JavaFX
docker run --rm --entrypoint sh ade:local -c '
  test -x "${OWS_HOME}/javaws"
  jvm=$(find "${JVM_DIR}" -maxdepth 3 -path "*/bin/java" -type f | head -n1)
  "$jvm" -version
'

# Full run against the host X server
IMAGE=ade:local ./run.sh
```

### Lint

```bash
docker run --rm -i hadolint/hadolint < Dockerfile
shellcheck run.sh scripts/*.sh scripts/jws scripts/desktop-telematico
```

## Code Style

- Comments and any other text inside the code are in English
- Explain *why*, not *what*: the non-obvious constraints (userns-remap, Java
  reading `user.home` from passwd, the incomplete certificate chain on the
  Agenzia download servers) are the ones worth documenting
- Keep everything application-specific inside `scripts/`, so a variant based on
  a different base image can reuse them unchanged

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org). Allowed
types are the conventional ones plus `deps` (used by Dependabot):

```bash
feat: add ISA launcher alias
fix: correct javaws lookup order
docs(readme): document the vendor directory
deps: bump debian base image
chore: tidy up the compose file
```

Commit types drive the release: `feat` bumps the minor version, `fix`,
`perf`, `refactor`, `deps` and `docs(readme)` bump the patch version, and a
`BREAKING CHANGE` footer bumps the major version.

## Build Workflow

1. **On push to `main`** — lint, build, smoke test, push to Docker Hub as
   `latest`, update the Docker Hub description
2. **On pull request** — lint, build and smoke test only, no push
3. **Monthly** (1st of the month, 04:00 UTC) — rebuild, so the published tag
   tracks the current OpenWebStart and Zulu releases, both resolved at build
   time
4. **On tag `v*`** — build and push the versioned tags
5. **Manual trigger** — "Actions" tab → "Run workflow"

## Questions?

- Open a [Discussion](https://github.com/xaas-hub/docker-ade/discussions)
- Check the [Documentation](https://github.com/xaas-hub/docker-ade)

## License

By contributing, you agree your contributions will be licensed under the MIT
License.
