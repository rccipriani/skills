#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROJECT="$ROOT/assets/examples/stabilization-project"
WRAPPER="$ROOT/scripts/tads3-container.sh"
RESULTS="$PROJECT/tests/container-results"

normalize() { tr '\n' ' ' < "$1" | tr -s '[:space:]' ' '; }
require_marker() {
    local file="$1" marker="$2"
    normalize "$file" | grep -F -- "$marker" >/dev/null || {
        printf 'ERROR[assertion]: missing marker %s in %s\n' "$marker" "$file" >&2
        return 1
    }
}
require_order() {
    local file="$1"; shift
    normalize "$file" | awk -v terms="$*" '
        BEGIN { n=split(terms, wanted, "|"); at=1 }
        {
            for (i=1; i<=n; ++i) {
                pos=index(substr($0, at), wanted[i]);
                if (!pos) {
                    printf "ERROR[assertion]: ordered marker missing: %s\n", wanted[i] > "/dev/stderr";
                    exit 1;
                }
                at += pos + length(wanted[i]) - 1;
            }
        }'
}

mkdir -p \
    "$PROJECT/build/release/obj" "$PROJECT/build/debug/obj" \
    "$RESULTS/release-turn" "$RESULTS/release-switch" \
    "$RESULTS/release-door" "$RESULTS/debug-door" "$RESULTS/debug-locked-sides"

"$WRAPPER" build --project "$PROJECT" --manifest config/release.t3m --release \
    --results-dir tests/container-results/release-build
"$WRAPPER" build --project "$PROJECT" --manifest config/debug.t3m --debug \
    --results-dir tests/container-results/debug-build

"$WRAPPER" run --project "$PROJECT" \
    --output build/release/stabilization.t3 --input tests/input/turn-on.txt \
    --results-dir tests/container-results/release-turn --release
"$WRAPPER" run --project "$PROJECT" \
    --output build/release/stabilization.t3 --input tests/input/switch-on.txt \
    --results-dir tests/container-results/release-switch --release
"$WRAPPER" run --project "$PROJECT" \
    --output build/release/stabilization.t3 --input tests/input/door-and-location.txt \
    --results-dir tests/container-results/release-door --release
"$WRAPPER" run --project "$PROJECT" \
    --output build/debug/stabilization-debug.t3 --input tests/input/door-and-location.txt \
    --results-dir tests/container-results/debug-door --debug
"$WRAPPER" run --project "$PROJECT" \
    --output build/debug/stabilization-debug.t3 --input tests/input/locked-both-sides-debug.txt \
    --results-dir tests/container-results/debug-locked-sides --debug

turn="$RESULTS/release-turn/release-transcript.log"
switch="$RESULTS/release-switch/release-transcript.log"
release_door="$RESULTS/release-door/release-transcript.log"
debug_door="$RESULTS/debug-door/debug-transcript.log"
debug_locked="$RESULTS/debug-locked-sides/debug-transcript.log"

require_marker "$turn" '[REGRESSION action=TurnOn reached]'
require_marker "$turn" 'generator=on]'
require_marker "$switch" '[REGRESSION action=TurnOn reached]'
require_marker "$switch" 'generator=on]'
require_marker "$release_door" '[REGRESSION generator-location=workshop state=off]'
require_order "$release_door" \
    '[REGRESSION status location=workshop outer=locked inner=locked generator=off]|[REGRESSION puzzle=unlocked-both]|[REGRESSION status location=workshop outer=unlocked inner=unlocked generator=off]|[REGRESSION room=archive]|[REGRESSION status location=archive outer=unlocked inner=unlocked generator=off]|[REGRESSION room=workshop]'
require_marker "$debug_door" '[REGRESSION puzzle=unlocked-both]'
require_marker "$debug_door" '[REGRESSION status location=archive outer=unlocked inner=unlocked generator=off]'
require_order "$debug_locked" \
    '[REGRESSION status location=workshop outer=locked inner=locked generator=off]|[REGRESSION debug-position=archive]|[REGRESSION status location=archive outer=locked inner=locked generator=off]'

if grep -Eiq 'runtime error|fatal error|segmentation fault|stack trace' \
        "$RESULTS"/*/*.log; then
    printf 'ERROR[runtime]: unexpected runtime-error marker\n' >&2
    exit 1
fi

host_uid="$(id -u)"
while IFS= read -r artifact; do
    [[ "$(stat -c %u "$artifact")" == "$host_uid" ]] || {
        printf 'ERROR[ownership]: %s is not owned by uid %s\n' "$artifact" "$host_uid" >&2
        exit 1
    }
done < <(find "$PROJECT/build" "$RESULTS" -type f -print)

printf '%s\n' \
    'adv3_stabilization=pass' \
    'release_build=pass' 'debug_build=pass' \
    'turn_on_dispatch=pass' 'switch_on_dispatch=pass' \
    'paired_lockable_doors=pass' 'explicit_location=pass' \
    'semantic_assertions=pass' 'offline_runtime=pass' 'host_ownership=pass'
