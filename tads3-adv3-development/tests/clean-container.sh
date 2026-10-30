#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENGINE="${CONTAINER_ENGINE:-}"
IMAGE="${TADS3_TEST_IMAGE:-docker.io/library/ubuntu:24.04}"
SOURCE_DIR="${FROBTADS_SOURCE_DIR:-}"
PROVENANCE="${FROBTADS_PROVENANCE_FILE:-}"
AUTHORIZATION="${TADS3_AUTHORIZATION_RECORD:-}"
CACHE_DIR="${FROBTADS_CACHE_DIR:-}"

if [[ -z "$ENGINE" ]]; then
    if command -v podman >/dev/null 2>&1; then ENGINE=podman
    elif command -v docker >/dev/null 2>&1; then ENGINE=docker
    else printf 'SKIP: no Podman or Docker available.\n'; exit 77
    fi
fi

if [[ "${CLEAN_CONTAINER_AUTHORIZED:-no}" != yes ]]; then
    printf '%s\n' \
        'SKIP: clean-container execution can pull an image, access package repositories, and install packages inside a disposable container.' \
        'After explicit authorization, set CLEAN_CONTAINER_AUTHORIZED=yes and TADS3_AUTHORIZATION_RECORD.' \
        'Supply FROBTADS_SOURCE_DIR and FROBTADS_PROVENANCE_FILE for offline use, or separately authorize acquisition with FROBTADS_FETCH_AUTHORIZED=yes.'
    exit 77
fi
if [[ -z "$SOURCE_DIR" || -z "$PROVENANCE" ]]; then
    if [[ "${FROBTADS_FETCH_AUTHORIZED:-no}" != yes ]]; then
        printf 'ERROR: source is absent; set FROBTADS_FETCH_AUTHORIZED=yes only after explicit download authorization.\n' >&2
        exit 2
    fi
    fetch_args=(fetch --authorize-download)
    [[ -z "$CACHE_DIR" ]] || fetch_args+=(--cache-dir "$CACHE_DIR")
    fetch_output="$("$ROOT/scripts/tads3-toolchain.sh" "${fetch_args[@]}")"
    printf '%s\n' "$fetch_output"
    SOURCE_DIR="$(sed -n 's/^source=//p' <<<"$fetch_output" | tail -n1)"
    PROVENANCE="$(sed -n 's/^provenance=//p' <<<"$fetch_output" | tail -n1)"
fi
[[ -d "$SOURCE_DIR" && -f "$PROVENANCE" && -f "$AUTHORIZATION" ]] || { printf 'ERROR: verified source directory, provenance file, or authorization audit record is missing.\n' >&2; exit 2; }

printf 'container_engine=%s\nimage=%s\n' "$ENGINE" "$IMAGE"
"$ENGINE" run --rm \
    --security-opt label=disable \
    --volume "$ROOT:/skill:ro" \
    --volume "$SOURCE_DIR:/source:ro" \
    --volume "$PROVENANCE:/provenance.txt:ro" \
    --volume "$AUTHORIZATION:/run/host-authorization.txt:ro" \
    "$IMAGE" /bin/bash -lc '
set -euo pipefail
. /skill/tests/clean-container-support.sh
staged_authorization=""
cleanup_container_test() {
    cleanup_staged_authorization "$staged_authorization"
}
trap cleanup_container_test EXIT
trap "exit 129" HUP
trap "exit 130" INT
trap "exit 143" TERM
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
staged_authorization=/work/authorization.txt
stage_authorization_record /run/host-authorization.txt "$staged_authorization" codex-test codex-test
source_path="$(cd /source && pwd -P)"
prefix=/work/frobtads/2.0-tads3.1.3
printf "%s\n" "--- installation plan ---"
runuser -u codex-test -- /skill/scripts/tads3-toolchain.sh install --source "$source_path" --prefix "$prefix" --allowed-root /work/frobtads
printf "%s\n" "--- approved provision and validation ---"
runuser -u codex-test -- /skill/scripts/tads3-toolchain.sh install --source "$source_path" --prefix "$prefix" --allowed-root /work/frobtads --provenance /provenance.txt --authorization-record "$staged_authorization" --execute
cleanup_staged_authorization "$staged_authorization"
staged_authorization=""
[[ ! -e /work/authorization.txt ]] || { printf "ERROR: staged authorization record was not cleaned up.\n" >&2; exit 1; }
if compgen -G "/tmp/tads3-skill.*" >/dev/null; then
    printf "ERROR: temporary validation/build directories remain.\n" >&2
    exit 1
fi
printf "%s\n" "--- idempotence collision ---"
set +e
runuser -u codex-test -- /skill/scripts/tads3-toolchain.sh install --source "$source_path" --prefix "$prefix" --allowed-root /work/frobtads 2>/work/repeat.err
collision_status=$?
set -e
report_expected_collision "$collision_status" /work/repeat.err
printf "clean_container_validation=pass\n"
'
