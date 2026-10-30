# Toolchain provisioning

## Safety model and operations

`scripts/tads3-toolchain.sh` never runs a package manager, invokes `sudo`, or
changes global configuration. Only its separate `fetch` operation can use the
network, and only after explicit authorization.

- `check` and `plan`: bounded, read-only discovery plus a platform dependency
  plan. Explicit invalid overrides fail instead of falling back.
- `validate`: compile and run the neutral fixture entirely below a secure
  temporary directory.
- `repair`: diagnose and suggest actions without changing files.
- `fetch`: validate and reuse the pinned source cache, or download only when
  `--authorize-download` records prior explicit approval.
- `install`: inspect a supplied source tree and print a plan. Execution needs
  `--execute`, a provenance record, and a separate prior-authorization record.

The script honors `T3MAKE`, `FROB`, `TADS3_HOME`, `TADS3_INCLUDE`,
`TADS3_LIB`, `TADS3_DOC`, and `TADS3_SAMPLES`. Compiler, VM, headers, and
libraries may be in different locations. A configured path is authoritative:
if it is invalid, discovery stops with a diagnostic.

## Supported and tested configurations

- **Tested:** RHEL 9.5 x86-64, FrobTADS 2.0, TADS compiler/VM 3.1.3, bundled
  standard adv3 3.1.3.
- **Supported by planning/discovery, not clean-machine tested here:** RHEL 9
  compatibles and current Ubuntu/Debian releases on Linux architectures
  supported by upstream FrobTADS and their compiler toolchains.
- **WSL2:** use the Ubuntu/Debian flow inside WSL2. Native Windows FrobTADS
  builds are not claimed; upstream 2.0 says contemporary MinGW/MSYS builds are
  unsupported.

The checked upstream FrobTADS 2.0 release is tag `v2.0`, commit
`934b0e4900d9a3a1ab291aa711919f209276c421`, released 2021-05-09 at
`https://github.com/realnc/frobtads/releases/tag/v2.0`. GitHub identifies the
commit as signed/verified. The release page does not publish an archive
checksum, so this skill does not claim an independently published archive
checksum. The fetcher instead requires Git object identity and a valid commit
signature from upstream key ID `15B600E72CA59238` in the operator's trusted
local GnuPG keyring.

## Detection and dependency planning

Run:

```sh
scripts/tads3-toolchain.sh check
scripts/tads3-toolchain.sh plan
```

Discovery checks explicit overrides, `PATH`, `TADS3_HOME`, conventional
user/system layouts, bounded versioned prefixes under `~/.local/opt` and
`~/opt`, and locations adjacent to selected executables. It does not recurse
through the filesystem. The report records the selected compiler,
interpreter, include directory, library directory, and exact `adv3.tl`.

FrobTADS 2.0 requires CMake, Make, a C11 compiler, a C++14 compiler, ncurses
development files, and libcurl development files when TADS networking is
enabled. The plan currently reports these distribution package candidates:

- RHEL 9 family: `gcc gcc-c++ cmake make ncurses-devel libcurl-devel`
- Ubuntu/Debian: `build-essential cmake make libncurses-dev
  libcurl4-openssl-dev`

Confirm availability on the exact distribution release. The script prints
package names but never executes `dnf`, `apt`, or another package manager.

## Safe source acquisition and provenance

Network acquisition is a separate, explicitly authorized operation. It never
selects a branch, resolves `latest`, or follows a moving tag:

```sh
scripts/tads3-toolchain.sh fetch --authorize-download
```

The operation fetches only commit
`934b0e4900d9a3a1ab291aa711919f209276c421` from the official repository,
checks the fetched object ID, runs `git verify-commit --raw`, requires the
expected upstream signing key ID, recognizes FrobTADS source markers, and
calculates a deterministic unpacked-tree SHA-256. If the signing public key is
not already available under the operator's trust policy, verification fails;
the script does not silently retrieve or trust a key.

Verified content is atomically stored below
`${FROBTADS_CACHE_DIR}`, `--cache-dir`, or the user cache default. An existing
complete entry is re-recognized and re-hashed before offline reuse. Partial,
mismatched, or tampered entries are rejected, and existing entries are never
replaced. Output reports exact `source=` and `provenance=` paths.

For a manually acquired tree (the preserved offline workflow):

1. Verify the tag/commit using trusted GitHub release metadata and, for a Git
   checkout, `git verify-commit 934b0e4...` when the signing key trust policy
   is established.
2. If using an archive, record its SHA-256 immediately. Because upstream does
   not publish one, label it as a locally calculated reproducibility hash, not
   an independently published checksum.
3. Compute a deterministic unpacked-tree hash:

   ```sh
   (cd /path/to/frobtads && find . -type f -not -path './.git/*' -print0 |
     LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum)
   ```

4. Copy `assets/examples/source-provenance.example` and record the repository,
   release, commit, verification method, retrieval date, and tree hash.

The installer recognizes FrobTADS-specific CMake and TADS 3 source markers;
a generic directory containing only `CMakeLists.txt` is rejected.

## Plan, authorization, installation, and validation

Use a dedicated existing user-owned root and a new versioned child prefix:

```sh
mkdir -p "$HOME/.local/opt/frobtads"
scripts/tads3-toolchain.sh install \
  --source "/path/to/frobtads source" \
  --prefix "$HOME/.local/opt/frobtads/2.0-tads3.1.3" \
  --allowed-root "$HOME/.local/opt/frobtads"
```

Review that plan. Only after the user explicitly approves those exact
canonical source and prefix paths, create a private authorization record:

```text
user_approved=yes
source=/canonical/path/to/frobtads source
prefix=/canonical/home/.local/opt/frobtads/2.0-tads3.1.3
```

Then execution uses all gates:

```sh
scripts/tads3-toolchain.sh install \
  --source "/path/to/frobtads source" \
  --prefix "$HOME/.local/opt/frobtads/2.0-tads3.1.3" \
  --allowed-root "$HOME/.local/opt/frobtads" \
  --provenance /path/to/source-provenance.txt \
  --authorization-record /path/to/authorization.txt \
  --execute
```

`--execute` alone is insufficient. The allowed root must already exist, be
owned and writable by the current user, and contain the canonical prefix. The
prefix must not exist at all, which prevents overwriting working toolchains or
unrelated applications. Broad system prefixes are rejected. Installation uses
a temporary out-of-tree CMake build, copies the provenance record, then runs
the complete fixture validation against the installed compiler, VM, and adv3.

On success the script prints `PATH` and `TADS3_HOME` instructions. Re-running
with the same prefix reports a collision; `check`/`validate` remain idempotent.

## Validation contract

Validation requires both release and debug compilation with no detected
warnings, executes both images, and checks ordered semantic markers for initial
state, custom action, state change, state-dependent NPC response, one daemon
event, duplicate-action rejection, and a score of exactly five. It also checks
that the debug verb is accepted exactly once in debug and rejected by release.
Failures name the stage (`compiler`, `adv3`, `release-build`,
`debug-runtime`, `release-transcript`, and so on) and show bounded diagnostics.

## Regression and clean-container testing

```sh
tests/run.sh
scripts/tads3-toolchain.sh validate
tests/clean-container.sh
```

`tests/run.sh` is offline, unprivileged, and uses mocks. On 2026-10-30 it
passed all 26 scenarios, including refused unauthorized download, failed
download cleanup, commit and signature mismatch rejection, verified cache
reuse without network authorization, incomplete-cache rejection, and
tampered-cache checksum rejection.
The exact executed/not-executed test record is in
[test-results.md](test-results.md).

The clean-container harness is opt-in. It uses an existing verified source and
provenance when supplied. If they are absent it can call `fetch` automatically,
but only when `FROBTADS_FETCH_AUTHORIZED=yes` separately records explicit
download approval. `CLEAN_CONTAINER_AUTHORIZED=yes` remains required for image
access and in-container package installation. Dependencies and compilation
remain inside the disposable container; only the verified source cache is
created on the host. The harness does not run as part of ordinary regression
tests or claim success merely because Podman or Docker exists.

Known limitations: the script does not establish GPG trust, resolve
distribution repository availability, prove ABI compatibility without
compiling, or support native Windows provisioning. A complete
clean-image provisioning run was not performed for this release of the skill.
