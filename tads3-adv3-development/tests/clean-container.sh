#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENGINE="${CONTAINER_ENGINE:-}"
IMAGE="${TADS3_TEST_IMAGE:-docker.io/library/ubuntu:24.04}"
SOURCE_DIR="${FROBTADS_SOURCE_DIR:-}"
PROVENANCE="${FROBTADS_PROVENANCE_FILE:-}"
AUTHORIZATION="${TADS3_AUTHORIZATION_RECORD:-}"

if [[ -z "$ENGINE" ]]; then
    if command -v podman >/dev/null 2>&1; then ENGINE=podman
    elif command -v docker >/dev/null 2>&1; then ENGINE=docker
    else printf 'SKIP: no Podman or Docker available.\n'; exit 77
    fi
fi

if [[ "${CLEAN_CONTAINER_AUTHORIZED:-no}" != yes ]]; then
    printf '%s\n' \
        'SKIP: clean-container execution can pull an image, access package repositories, and install packages inside a disposable container.' \
        'After explicit authorization, set CLEAN_CONTAINER_AUTHORIZED=yes, FROBTADS_SOURCE_DIR, FROBTADS_PROVENANCE_FILE, and TADS3_AUTHORIZATION_RECORD.'
    exit 77
fi
[[ -d "$SOURCE_DIR" && -f "$PROVENANCE" && -f "$AUTHORIZATION" ]] || { printf 'ERROR: verified source directory, provenance file, or authorization audit record is missing.\n' >&2; exit 2; }

printf 'container_engine=%s\nimage=%s\n' "$ENGINE" "$IMAGE"
"$ENGINE" run --rm \
    --volume "$ROOT:/skill:ro" \
    --volume "$SOURCE_DIR:/source:ro" \
    --volume "$PROVENANCE:/provenance.txt:ro" \
    --volume "$AUTHORIZATION:/authorization.txt:ro" \
    "$IMAGE" /bin/bash -lc '
set -euo pipefail
printf "%s\n" "--- initial clean-environment detection ---"
initial="$(/skill/scripts/tads3-toolchain.sh check)"
printf "%s\n" "$initial"
grep -F "selected_t3make=missing" <<<"$initial"
grep -F "selected_frob=missing" <<<"$initial"
grep -F "selected_adv3=missing" <<<"$initial"
printf "%s\n" "--- dependency plan ---"
/skill/scripts/tads3-toolchain.sh plan
if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends build-essential cmake make libncurses-dev libcurl4-openssl-dev ca-certificates passwd util-linux
else
    printf "ERROR: this harness currently implements Debian-family container provisioning only.\n" >&2
    exit 2
fi
useradd --create-home --shell /bin/bash codex-test
install -d -o codex-test -g codex-test /work/frobtads
source_path="$(cd /source && pwd -P)"
prefix=/work/frobtads/2.0-tads3.1.3
printf "%s\n" "--- installation plan ---"
runuser -u codex-test -- /skill/scripts/tads3-toolchain.sh install --source "$source_path" --prefix "$prefix" --allowed-root /work/frobtads
printf "%s\n" "--- approved provision and validation ---"
runuser -u codex-test -- /skill/scripts/tads3-toolchain.sh install --source "$source_path" --prefix "$prefix" --allowed-root /work/frobtads --provenance /provenance.txt --authorization-record /authorization.txt --execute
if compgen -G "/tmp/tads3-skill.*" >/dev/null; then
    printf "ERROR: temporary validation/build directories remain.\n" >&2
    exit 1
fi
printf "%s\n" "--- idempotence collision ---"
if runuser -u codex-test -- /skill/scripts/tads3-toolchain.sh install --source "$source_path" --prefix "$prefix" --allowed-root /work/frobtads 2>/work/repeat.err; then
    printf "ERROR: repeated provisioning unexpectedly succeeded.\n" >&2
    exit 1
fi
grep -F "ERROR[collision]" /work/repeat.err
printf "clean_container_validation=pass\n"
'
