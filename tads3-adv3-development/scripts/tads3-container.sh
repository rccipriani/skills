#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-help}"
shift || true
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ENGINE="${CONTAINER_ENGINE:-podman}"
IMAGE="${TADS3_DEV_IMAGE:-localhost/tads3-dev:2.0}"
PROJECT=""
MANIFEST=""
GAME_IMAGE=""
INPUT=""
RESULTS="tests/container-results"
BUILD_KIND=release
SOURCE=""
PROVENANCE=""
AUTHORIZED=0
EXPECTED=()
IMAGE_CONTEXT=""

cleanup_image_context() {
    [[ -z "$IMAGE_CONTEXT" ]] || rm -rf -- "$IMAGE_CONTEXT"
    IMAGE_CONTEXT=""
}

usage() {
    cat <<'EOF'
Usage: tads3-container.sh COMMAND [options]

Commands:
  image-build  Build the reusable image from verified FrobTADS source
  check        Check Podman and image availability, then validate the image
  build        Compile a project manifest in a disposable container
  run          Run an existing game image noninteractively or on a terminal
  validate     Compile, run a command transcript, and check semantic markers

Project options:
  --project DIR          selected host project workspace (required)
  --manifest FILE        .t3m path relative to project (required for build/validate)
  --output FILE          .t3 image relative to project (required for run/validate)
  --input FILE           command transcript relative to project
  --results-dir DIR      result directory relative to project (default tests/container-results)
  --debug|--release      compiler mode (default release)
  --expect TEXT          required output marker; repeat as needed

Image options:
  --source DIR           verified pinned FrobTADS source tree
  --provenance FILE      matching verified provenance record
  --authorize-build      confirms image/package access was explicitly authorized

Environment: CONTAINER_ENGINE, TADS3_DEV_IMAGE, TADS3_CONTAINER_SELINUX.
EOF
}
die() { printf 'ERROR[%s]: %s\n' "$1" "$2" >&2; exit "${3:-1}"; }

while (($#)); do
    case "$1" in
        --project) [[ $# -ge 2 ]] || die arguments 'missing value for --project' 2; PROJECT="$2"; shift 2 ;;
        --manifest) [[ $# -ge 2 ]] || die arguments 'missing value for --manifest' 2; MANIFEST="$2"; shift 2 ;;
        --output) [[ $# -ge 2 ]] || die arguments 'missing value for --output' 2; GAME_IMAGE="$2"; shift 2 ;;
        --input) [[ $# -ge 2 ]] || die arguments 'missing value for --input' 2; INPUT="$2"; shift 2 ;;
        --results-dir) [[ $# -ge 2 ]] || die arguments 'missing value for --results-dir' 2; RESULTS="$2"; shift 2 ;;
        --expect) [[ $# -ge 2 ]] || die arguments 'missing value for --expect' 2; EXPECTED+=("$2"); shift 2 ;;
        --debug) BUILD_KIND=debug; shift ;;
        --release) BUILD_KIND=release; shift ;;
        --source) [[ $# -ge 2 ]] || die arguments 'missing value for --source' 2; SOURCE="$2"; shift 2 ;;
        --provenance) [[ $# -ge 2 ]] || die arguments 'missing value for --provenance' 2; PROVENANCE="$2"; shift 2 ;;
        --authorize-build) AUTHORIZED=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die arguments "unknown option: $1" 2 ;;
    esac
done

require_engine() { command -v "$ENGINE" >/dev/null 2>&1 || die engine "$ENGINE is not installed or not on PATH"; }
require_image() {
    require_engine
    "$ENGINE" image exists "$IMAGE" >/dev/null 2>&1 || \
        die image "image $IMAGE is missing; build it with: scripts/tads3-container.sh image-build --source DIR --provenance FILE --authorize-build"
}
relative_safe() {
    [[ -n "$1" && "$1" != /* && "$1" != .. && "$1" != ../* && "$1" != */../* && "$1" != */.. ]]
}
prepare_project() {
    [[ -d "$PROJECT" ]] || die project "project directory does not exist: ${PROJECT:-<unset>}"
    PROJECT="$(cd "$PROJECT" && pwd -P)"
    relative_safe "$RESULTS" || die arguments '--results-dir must remain inside the project'
}
mount_spec() {
    local access="$1" suffix=""
    case "${TADS3_CONTAINER_SELINUX:-disable}" in
        disable) printf '%s:/workspace:%s' "$PROJECT" "$access" ;;
        private) suffix=Z; printf '%s:/workspace:%s,%s' "$PROJECT" "$access" "$suffix" ;;
        *) die selinux 'TADS3_CONTAINER_SELINUX must be disable or private' ;;
    esac
}
run_container() {
    local access="$1"; shift
    local security=(--security-opt label=disable)
    [[ "${TADS3_CONTAINER_SELINUX:-disable}" == private ]] && security=()
    "$ENGINE" run --rm --network=none --userns=keep-id \
        --user "$(id -u):$(id -g)" "${security[@]}" \
        --volume "$(mount_spec "$access")" --workdir /workspace "$IMAGE" "$@"
}
ensure_file() {
    relative_safe "$1" || die arguments "$2 must be a relative path inside the project"
    [[ -f "$PROJECT/$1" ]] || die project "$2 does not exist: $PROJECT/$1"
}
do_build() {
    prepare_project; require_image; ensure_file "$MANIFEST" manifest
    mkdir -p "$PROJECT/$RESULTS"
    local args=(t3make)
    [[ "$BUILD_KIND" == debug ]] && args+=(-d)
    args+=(-f "$MANIFEST")
    set +e
    run_container rw "${args[@]}" >"$PROJECT/$RESULTS/${BUILD_KIND}-build.log" 2>&1
    local status=$?
    set -e
    printf '%s\n' "$status" > "$PROJECT/$RESULTS/${BUILD_KIND}-build.status"
    ((status == 0)) || { sed -n '1,120p' "$PROJECT/$RESULTS/${BUILD_KIND}-build.log" >&2; return "$status"; }
    printf 'build=pass\nlog=%s\n' "$PROJECT/$RESULTS/${BUILD_KIND}-build.log"
}
do_run() {
    prepare_project; require_image; ensure_file "$GAME_IMAGE" output
    [[ -z "$INPUT" ]] || ensure_file "$INPUT" input
    mkdir -p "$PROJECT/$RESULTS"
    local transcript="$PROJECT/$RESULTS/${BUILD_KIND}-transcript.log"
    local runtime_err="$PROJECT/$RESULTS/${BUILD_KIND}-runtime.stderr.log"
    local status_file="$PROJECT/$RESULTS/${BUILD_KIND}-runtime.status"
    set +e
    if [[ -n "$INPUT" ]]; then
        run_container ro /bin/bash -c 'exec frob -i plain -p "$1" < "$2"' bash "$GAME_IMAGE" "$INPUT" >"$transcript" 2>"$runtime_err"
    else
        run_container ro frob -i plain -p "$GAME_IMAGE" >"$transcript" 2>"$runtime_err"
    fi
    local status=$?
    set -e
    printf '%s\n' "$status" > "$status_file"
    ((status == 0)) || { sed -n '1,160p' "$transcript" >&2; sed -n '1,160p' "$runtime_err" >&2; return "$status"; }
    if grep -Eiq 'runtime error|fatal error|segmentation fault|stack trace' "$transcript" "$runtime_err"; then
        sed -n '1,160p' "$transcript" >&2; sed -n '1,160p' "$runtime_err" >&2
        die runtime "runtime-error marker found; transcript: $transcript; stderr: $runtime_err"
    fi
    local marker
    for marker in "${EXPECTED[@]}"; do
        grep -Fq -- "$marker" "$transcript" || die validation "expected marker not found: $marker; transcript: $transcript"
    done
    printf 'runtime=pass\ntranscript=%s\nstderr=%s\n' "$transcript" "$runtime_err"
}
image_build() {
    require_engine
    ((AUTHORIZED == 1)) || die authorization 'image build can pull images and install packages; rerun with --authorize-build only after explicit approval'
    [[ -d "$SOURCE" && -f "$PROVENANCE" ]] || die source 'verified --source directory and --provenance file are required'
    "$ROOT/scripts/tads3-toolchain.sh" verify-source --source "$SOURCE" --provenance "$PROVENANCE" >/dev/null
    IMAGE_CONTEXT="$(mktemp -d "${TMPDIR:-/tmp}/tads3-image-context.XXXXXXXX")"
    trap cleanup_image_context EXIT
    mkdir "$IMAGE_CONTEXT/source"
    (cd "$SOURCE" && tar --exclude='./.git' --exclude='.git' -cf - .) | tar -xf - -C "$IMAGE_CONTEXT/source"
    cp -- "$PROVENANCE" "$IMAGE_CONTEXT/source-provenance.txt"
    cp -a -- "$ROOT/assets/examples/validation-project" "$IMAGE_CONTEXT/validation-project"
    cp -- "$ROOT/container/Containerfile" "$ROOT/container/validate-image.sh" "$IMAGE_CONTEXT/"
    "$ENGINE" build --pull=missing --tag "$IMAGE" --file "$IMAGE_CONTEXT/Containerfile" "$IMAGE_CONTEXT"
    cleanup_image_context
    printf 'image_build=pass\nimage=%s\n' "$IMAGE"
}

case "$MODE" in
    image-build) image_build ;;
    check)
        require_image
        security=(--security-opt label=disable)
        "$ENGINE" run --rm --network=none --userns=keep-id --user "$(id -u):$(id -g)" \
            "${security[@]}" "$IMAGE" validate-tads3-image
        ;;
    build) do_build ;;
    run) do_run ;;
    validate) do_build; do_run ;;
    help|-h|--help) usage ;;
    *) usage >&2; die arguments "unknown command: $MODE" 2 ;;
esac
