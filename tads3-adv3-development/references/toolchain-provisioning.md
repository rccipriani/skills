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
checksum. FreeBSD's official ports repository independently publishes a
SHA-256 for the exact v2.0 GitHub codeload distfile, providing a second
verification method when the upstream signing key is unavailable.

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

Three method selections are supported:

- `--fetch-method git` fetches only commit
  `934b0e4900d9a3a1ab291aa711919f209276c421`, checks the fetched object ID,
  runs `git verify-commit --raw`, and requires upstream signing key ID
  `15B600E72CA59238`. The script never retrieves or silently trusts a key.
- `--fetch-method archive` downloads only the exact URL
  `https://codeload.github.com/realnc/frobtads/tar.gz/v2.0?dummy=/realnc-frobtads-v2.0_GH0.tar.gz`.
  It requires size `5122899` and SHA-256
  `c457860d3bf3db3c1129deddbd2c7a295602c7f59560d7e6e81df3bb77a23cd5`.
- The default, `--fetch-method auto`, tries Git-signature verification first.
  If Git transport or signature verification is unavailable, it tries the
  checksum-verified archive. A wrong fetched Git object is an integrity error
  and is not silently converted into a fallback.

The checksum comes from FreeBSD ports
[`games/frobtads/distinfo`](https://cgit.freebsd.org/ports/tree/games/frobtads/distinfo?id=b1e257a26b880a75cad55681701caf4ff39c9c36),
which names `realnc-frobtads-v2.0_GH0.tar.gz`. The corresponding official port
sets `DISTVERSIONPREFIX=v`, `DISTVERSION=2.0`, `USE_GITHUB=yes`, and
`GH_ACCOUNT=realnc` in its
[`Makefile`](https://cgit.freebsd.org/ports/tree/games/frobtads/Makefile?id=b1e257a26b880a75cad55681701caf4ff39c9c36).
FreeBSD's official
[`bsd.sites.mk`](https://cgit.freebsd.org/ports/tree/Mk/bsd.sites.mk)
constructs GitHub downloads as
`https://codeload.github.com/account/project/tar.gz/tag?dummy=/` followed by
the ports distfile name. This establishes that the published checksum applies
to the exact URL above; it is not transferred to GitHub's `/archive/`, API
tarball, or release-asset endpoints.

After authentication, the archive path is listed before extraction. Entries
outside the single `frobtads-2.0` root, traversal paths, links, and special
files are rejected. Extraction occurs only in the cache staging directory,
then FrobTADS-specific source markers and a deterministic tree hash are
checked before atomic publication.

Verified content is atomically stored below
`${FROBTADS_CACHE_DIR}`, `--cache-dir`, or the user cache default. An existing
complete entry is authenticated according to its recorded method,
re-recognized, and re-hashed before offline reuse. Archive-backed cache entries
retain the verified distfile so its independently published checksum and size
can be rechecked. Partial, mismatched, or tampered entries are rejected, and
existing entries are never replaced. Output reports the acquisition method and
exact `source=` and `provenance=` paths.

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
passed all 41 provisioning scenarios plus the container interface suite,
including refused unauthorized download, failed and
incomplete archive downloads, commit/signature/checksum mismatch rejection,
corrupted archive rejection, automatic signature-to-checksum fallback,
verified cache reuse without network authorization, incomplete-cache
rejection, and tampered-cache checksum rejection.
The exact executed/not-executed test record is in
[test-results.md](test-results.md).

The clean-container harness is opt-in. It uses an existing verified source and
provenance when supplied. If they are absent it can call `fetch` automatically,
but only when `FROBTADS_FETCH_AUTHORIZED=yes` separately records explicit
download approval. `CLEAN_CONTAINER_AUTHORIZED=yes` remains required for image
access and in-container package installation. Dependencies and compilation
remain inside the disposable container; only the verified source cache is
created on the host. `FROBTADS_FETCH_METHOD=git|archive|auto` can select either
verified acquisition method for the harness. The harness does not run as part
of ordinary regression tests or claim success merely because Podman or Docker
exists.

Host authorization records may remain mode 600. The harness bind-mounts the
record read-only, disables SELinux label separation for the disposable
container instead of relabeling host files, and has container root create a
byte-identical mode-600 copy owned by `codex-test` under `/work`. The installer
receives only that staged copy. It is removed immediately after the authorized
installation and again by an exit trap on failure. The host record is never
written, chmodded, chowned, or relabeled by the harness.

On 2026-10-30, clean-container provisioning and validation passed using Podman
on RHEL 9.5 x86-64 with an Ubuntu 24.04.5 LTS guest, FrobTADS 2.0, TADS 3
compiler/VM 3.1.3, and standard adv3. The intentional second installation was
correctly rejected with `ERROR[collision]`, confirming overwrite protection.
The harness now renders that expected result as
`PASS: duplicate installation correctly rejected`; any other failure retains
its original diagnostic and fails the harness. See
[test-results.md](test-results.md) for the distinction between that completed
run and checks rerun in the current workspace.

Known limitations: the script does not establish GPG trust, resolve
distribution repository availability, prove ABI compatibility without
compiling, or support native Windows provisioning. The supplied successful
clean-container log excerpt did not identify which verified source-acquisition
method was used.

## Reusable development image

The clean-container harness above is deliberately not the everyday container
interface. For a reusable Ubuntu 24.04 image and disposable offline project
builds, read [container-development.md](container-development.md). The image
builder calls `verify-source`, a read-only operation that recognizes the pinned
FrobTADS tree and checks its deterministic tree hash against the provenance
record before constructing the temporary context. Native installation, clean
from-scratch validation, and reusable-image development remain independent.
