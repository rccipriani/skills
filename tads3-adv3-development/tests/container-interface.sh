#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/tads3-container.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/tads3-container-tests.XXXXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
MOCK="$TMP/bin"
PROJECT="$TMP/project with spaces"
mkdir -p "$MOCK" "$PROJECT/manifests" "$PROJECT/build" "$PROJECT/tests"
printf '%s\n' '-o build/story.t3' > "$PROJECT/manifests/story.t3m"
printf '%s\n' 'look' 'quit' 'y' > "$PROJECT/tests/play.txt"

cat > "$MOCK/podman" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >> "${MOCK_PODMAN_LOG:?}"
case "${1:-}" in
    image)
        [[ "${MOCK_IMAGE_MISSING:-0}" != 1 ]]
        ;;
    run)
        [[ " $* " == *' --network=none '* ]] || exit 91
        [[ " $* " == *' --rm '* ]] || exit 92
        project=""
        args=("$@")
        for ((i=0; i<${#args[@]}; i++)); do
            if [[ "${args[i]}" == --volume ]]; then
                value="${args[i+1]}"; project="${value%%:/workspace:*}"
            fi
        done
        if [[ " $* " == *' validate-tads3-image '* ]]; then printf 'image_validation=pass\n'; exit 0; fi
        if [[ " $* " == *' t3make '* ]]; then
            [[ "${MOCK_BUILD_FAIL:-0}" != 1 ]] || { printf 'compile failed\n' >&2; exit 17; }
            mkdir -p "$project/build"
            : > "$project/build/story.t3"
            printf 'TADS Compiler 3.1.3 mock\nErrors: 0 Warnings: 0\n'
            exit 0
        fi
        [[ "${MOCK_RUNTIME_FAIL:-0}" != 1 ]] || { printf 'runtime failed\n' >&2; exit 19; }
        printf 'Workshop ready. [EVAL unlocked] [EVAL won]\n'
        ;;
    build) printf 'mock image build\n' ;;
    *) exit 90 ;;
esac
MOCK
chmod +x "$MOCK/podman"

run() { env PATH="$MOCK:/usr/bin:/bin" CONTAINER_ENGINE=podman MOCK_PODMAN_LOG="$TMP/podman.log" "$@"; }
expect_fail() {
    local wanted="$1"; shift; local out status=0
    out="$(run "$@" 2>&1)" || status=$?
    ((status != 0)) && grep -Fq "$wanted" <<<"$out" || { printf 'FAIL: expected %s, status=%s, output=%s\n' "$wanted" "$status" "$out" >&2; exit 1; }
}

expect_fail 'image localhost/tads3-dev:2.0 is missing' env MOCK_IMAGE_MISSING=1 "$SCRIPT" check
run "$SCRIPT" check | grep -Fq 'image_validation=pass'
run "$SCRIPT" build --project "$PROJECT" --manifest manifests/story.t3m --output build/story.t3
[[ -f "$PROJECT/build/story.t3" && -f "$PROJECT/tests/container-results/release-build.log" ]]
[[ "$(stat -c %u "$PROJECT/build/story.t3")" == "$(id -u)" ]]
run "$SCRIPT" validate --project "$PROJECT" --manifest manifests/story.t3m \
    --output build/story.t3 --input tests/play.txt --expect '[EVAL unlocked]' --expect '[EVAL won]'
grep -Fq '[EVAL won]' "$PROJECT/tests/container-results/release-transcript.log"
[[ -f "$PROJECT/tests/container-results/release-runtime.stderr.log" ]]
grep -Fq -- '--network=none' "$TMP/podman.log"
grep -Fq -- '--userns=keep-id' "$TMP/podman.log"
grep -Fq "$PROJECT:/workspace:ro" "$TMP/podman.log"
grep -Fq 'manifests/story.t3m' "$TMP/podman.log"
expect_fail 'compile failed' env MOCK_BUILD_FAIL=1 "$SCRIPT" build --project "$PROJECT" --manifest manifests/story.t3m
expect_fail 'runtime failed' env MOCK_RUNTIME_FAIL=1 "$SCRIPT" run --project "$PROJECT" --output build/story.t3 --input tests/play.txt
expect_fail 'expected marker not found' "$SCRIPT" run --project "$PROJECT" --output build/story.t3 --input tests/play.txt --expect '[MISSING]'
expect_fail 'must remain inside the project' "$SCRIPT" run --project "$PROJECT" --output build/story.t3 --results-dir ../outside
[[ ! -e "$TMP/outside" ]]
printf 'container_interface_tests=pass\n'
