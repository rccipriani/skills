# Provisioning test results

Results recorded 2026-10-30 in the skill workspace:

- `bash -n scripts/tads3-toolchain.sh tests/run.sh tests/clean-container.sh`:
  passed with no syntax diagnostics.
- `tests/run.sh`: the current suite contains 41 provisioning scenarios plus
  the reusable-container interface suite. See the executed status below.
  Acquisition coverage includes authorization refusal, transport failure with
  no published cache entry, wrong commit rejection, signature-verification
  failure, cache reuse without network access, locally calculated tree-hash
  mismatch, incomplete-cache rejection, checksum-verified archive acquisition,
  incomplete and corrupted archive rejection, checksum mismatch rejection,
  checksum-backed cache reuse, and automatic fallback when Git signature
  verification is unavailable. Clean-container helper coverage additionally
  verifies mode-600 host authorization staging, byte-for-byte preservation,
  unchanged host metadata/content, staged-file cleanup, invalid authorization
  rejection, expected collision reporting, and unexpected collision failures.
- `tests/container-interface.sh`: added offline Podman mocks covering missing
  image diagnostics, image discovery, a project path containing spaces,
  explicit manifest mapping, offline disposable execution, keep-id mapping,
  release build and transcript capture, semantic expected-output checks,
  compiler/runtime exit propagation, containment of result paths, and cleanup.
  See the current-session note below for executed status.
- `python3 -m json.tool manifest.json`: passed.
- `shellcheck`: not run because it was not installed in the environment.
- Live upstream source fetch: not run; no source-download authorization was
  granted for the test session. Official FreeBSD repository pages were read to
  establish the archive URL, size, and independently published checksum.
- `tests/clean-container.sh`: not rerun during this editing session because
  container image/repository access and package installation were not newly
  authorized.

## Reusable image work added 2026-10-30

The reusable-image definition, host interface, and offline mock suite were
added in this workspace. `tests/run.sh` passed all 41 provisioning scenarios
and the container interface suite; Bash syntax and manifest JSON checks also
passed. A real Podman image build
and integration test were not implicitly authorized: they can access the local
image store and Ubuntu package repositories and therefore remain opt-in.

## adv3 stabilization regression, 2026-10-30

Executed after the independent *The Last Signal* evaluation, without using its
story source or modifying its artifacts:

- `bash -n scripts/tads3-toolchain.sh scripts/tads3-container.sh
  container/validate-image.sh tests/run.sh tests/clean-container.sh
  tests/container-interface.sh tests/adv3-stabilization.sh`: exit 0.
- `python3 -m json.tool manifest.json`: exit 0.
- `tests/run.sh`: exit 0; all 41 provisioning scenarios passed and the
  offline container-interface mock suite passed.
- `tests/adv3-stabilization.sh`: exit 0 using
  `localhost/tads3-dev:2.0`; release and debug compilation passed, followed by
  five offline gameplay executions. Assertions verified manifest-relative
  source/object/output paths, both `turn on generator` and
  `switch on generator` dispatching `TurnOn`, locked travel from each door
  side, synchronized programmatic unlocking, traversal in both directions,
  and ordinary-command access to an explicitly located object. All build and
  runtime status files contain 0, runtime-error scans passed, and generated
  files are owned by host uid 1000.
- `scripts/tads3-container.sh check`: exit 0; reported FrobTADS 2.0, TADS
  Compiler 3.1.3, and `image_validation=pass` for the pre-existing neutral
  fixture.

The stabilization harness uses only standard adv3 and disposable rootless
Podman containers with `--network=none`. Release and debug manifests use
separate object, symbol, and image paths. No image rebuild, source download,
host package installation, native compiler invocation, or clean-container
provisioning run was needed.

## Recorded clean-container validation

A completed run supplied on 2026-10-30 produced
`clean_container_validation=pass`. Recorded environment and results:

- Host: RHEL 9.5 x86-64.
- Runtime: Podman.
- Guest: Ubuntu 24.04.5 LTS.
- FrobTADS: 2.0.
- TADS 3 compiler and VM: 3.1.3.
- Library: standard adv3.
- Clean-container provisioning and semantic validation: PASS.
- Duplicate installation protection: PASS. The preceding `ERROR[collision]`
  was the expected diagnostic from the intentional negative test.

An earlier attempt failed because a mode-600 host authorization record was
passed directly to the unprivileged container user. The harness now stages an
exact mode-600 copy owned by that user inside the disposable container and
removes it after use. The successful run required changing the host file to
mode 644; the new offline regressions cover the mode-600 correction, but the
full container run has not yet been repeated with the corrected harness.

The supplied successful-run excerpt does not include fetch output or the
generated provenance record. Therefore its source acquisition/integrity method
is not recorded as Git-signature or FreeBSD-checksum verification. Both remain
supported and regression-tested by the harness.
