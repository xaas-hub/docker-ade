# AGENTS.md

Instructions for AI agents working on this repository. Everything a human
contributor needs is in [CONTRIBUTING](.github/CONTRIBUTING.md): read it, this
file does not repeat it.

## Hard rules

- **No Agenzia delle Entrate software in the image.** Desktop Telematico is
  downloaded at run time into the persistent volume, the JNLP applications are
  dropped into `vendor/` by hand. Bundling either at build time makes the image
  no longer redistributable.
- **Never read `data/`.** It holds tax credentials, workspaces and signed
  declarations. The smoke test in `ci.yml` does not need it.
- **Never read `.env`.** Only `.env.dist` is tracked.
- **Do not edit `CHANGELOG.md`.** semantic-release writes it from the commit
  log.
- **Do not weaken the SHA-256 check** in
  `scripts/install-desktop-telematico.sh`: it is unconditional, and it is the
  only thing that makes the `--insecure` fallback safe. `DT_URL` and
  `DT_SHA256` are always bumped together.
- **Do not widen the X11 authorisation**: `run.sh` uses
  `xhost +SI:localuser:$(id -un)`, never `xhost +local:` or `xhost +`.
- `linux/amd64` only: the Agenzia publishes its Linux software for x86-64 only,
  and Zulu 8 with JavaFX has no aarch64 build.

## Commands

Everything runs in Docker. If you cannot run it, say which commands have to be
run and what output to look for.

```bash
IMAGE=ade:local docker compose build
docker run --rm --entrypoint sh ade:local -c '
  set -eu
  test -x "${OWS_HOME}/javaws"
  jvm=$(find "${JVM_DIR}" -maxdepth 3 -path "*/bin/java" -type f | head -n1)
  "$jvm" -version
'
```

The GUI needs the host X server (`IMAGE=ade:local ./run.sh`): an agent usually
cannot check it, and has to say so.

Lint as described in the header of `.megalinter.yml`, which mirrors `ci.yml`.

## Conventions

- Code, comments and commit messages in English. Comments explain why, not
  what.
- Conventional Commits, plus the `deps` type: the type decides the release
  (see CONTRIBUTING). Body lines up to 150 characters.
- Shell scripts must pass shellcheck and are indented with tabs, like the
  existing ones.
- Everything application-specific lives in `scripts/`, so a variant based on a
  different base image can reuse them unchanged.
- A new launcher without an extension must be added to the `shellcheck` line in
  `ci.yml` and to `BASH_SHELLCHECK_FILE_NAMES_REGEX` in `.megalinter.yml`,
  otherwise neither checks it.
- A new JNLP alias is just a symlink to `jws` in the `Dockerfile`: `jws` keeps
  no list of known applications.
- `README.md` is in Italian, with the `<details>` blocks in English: keep it
  that way.

## Private notes

`agents/` is gitignored. If your checkout has it, it holds the maintainer's
notes: read what is relevant to the task, never reference it from versioned
files.
