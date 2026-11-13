# Containerized TADS 3 development

This is the reusable project-development mode. It is separate from native
provisioning and from `tests/clean-container.sh`, which deliberately proves a
from-scratch installation in a disposable guest.

## Build the image

First use `scripts/tads3-toolchain.sh fetch` (with separately authorized
network access) or an existing verified cache. Then explicitly authorize the
base-image/package operation:

```sh
scripts/tads3-container.sh image-build \
  --source "/path/to/verified/cache/source" \
  --provenance "/path/to/verified/cache/source-provenance.txt" \
  --authorize-build
scripts/tads3-container.sh check
```

The host revalidates the exact source tree against its provenance before
creating a temporary build context. The `Containerfile` performs no upstream
source fetch. The authorized build uses `--pull=missing`, so it may obtain the
Ubuntu base only when absent; package repository access during the two image
stages is covered by the same explicit authorization. The final Ubuntu 24.04 image contains FrobTADS 2.0, the TADS
3.1.3 compiler/VM and standard adv3, runtime libraries, provenance, and the
neutral validation fixture—not Codex, credentials, source-control metadata, or
the host cache. A build-stage compiler toolchain is not copied into the final
stage. Image construction compiles and runs the neutral fixture.

The suggested tag is `localhost/tads3-dev:2.0`; override it with
`TADS3_DEV_IMAGE`. `CONTAINER_ENGINE` defaults to `podman`.

## Build and run projects

Paths following `--manifest`, `--output`, `--input`, and `--results-dir` are
relative to the selected project. Absolute paths and `..` escapes are refused.
The manifest can have any name and controls its own sources and output:

```sh
scripts/tads3-container.sh build --project "/work/My Game" \
  --manifest config/release.t3m --release
scripts/tads3-container.sh build --project "/work/My Game" \
  --manifest config/debug.t3m --debug
scripts/tads3-container.sh validate --project "/work/My Game" \
  --manifest config/release.t3m --output build/my-game.t3 \
  --input tests/winning-path.txt \
  --expect '[GAME gate=unlocked]' --expect '[GAME won]'
```

Builds mount only the selected project read/write because `t3make` writes
images and object files according to the manifest. Gameplay runs remount that
same project read-only; the host wrapper writes the gameplay transcript,
standard error, and numeric status into `tests/container-results/` (or the selected in-project
directory). Stable `--expect` markers provide semantic checks. Nonzero
compiler/interpreter statuses propagate unchanged, and common runtime-error
markers fail validation. Use distinct manifests or outputs for release and
debug builds.

Every normal operation uses `--rm`, `--network=none`, `--userns=keep-id`, and
the host UID/GID. There is no privileged mode, Podman socket, home-directory,
credential, or Codex mount. Generated files consequently remain host-owned.

## SELinux behavior

The default is `TADS3_CONTAINER_SELINUX=disable`: label separation is disabled
for this one unprivileged container, avoiding changes to the existing project
labels. Set `TADS3_CONTAINER_SELINUX=private` only when the user has explicitly
approved relabeling the selected dedicated workspace; it adds `:Z`. Podman can
recursively change labels on that directory, so never use `private` casually
on a home directory, shared checkout, or arbitrary user directory. The wrapper
never silently applies `:Z`.

## Mode comparison

- **Native mode** uses `t3make`, `frob`, headers, and adv3 installed on the
  host; `scripts/tads3-toolchain.sh check|validate` selects and verifies them.
- **Clean-container validation** uses `tests/clean-container.sh` to provision
  from scratch in one disposable Ubuntu container. It remains an independent,
  opt-in test of the provisioning procedure.
- **Reusable container development** builds `localhost/tads3-dev:2.0` once,
  then uses disposable offline containers against one explicitly selected host
  project for everyday compilation and transcript tests.
