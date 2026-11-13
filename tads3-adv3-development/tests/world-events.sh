#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROJECT="$ROOT/assets/examples/world-events-project"
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
reject_marker() {
    local file="$1" marker="$2"
    if normalize "$file" | grep -F -- "$marker" >/dev/null; then
        printf 'ERROR[assertion]: forbidden marker %s in %s\n' "$marker" "$file" >&2
        return 1
    fi
}
require_count() {
    local file="$1" marker="$2" expected="$3" actual
    actual="$(normalize "$file" | grep -Fo -- "$marker" | wc -l)"
    [[ "$actual" == "$expected" ]] || {
        printf 'ERROR[assertion]: marker %s count=%s expected=%s\n' "$marker" "$actual" "$expected" >&2
        return 1
    }
}

mkdir -p "$PROJECT/build/release/obj" "$RESULTS/scenery" "$RESULTS/events"
"$WRAPPER" build --project "$PROJECT" --manifest config/release.t3m --release \
    --results-dir tests/container-results/release-build
"$WRAPPER" run --project "$PROJECT" --output build/release/world-events.t3 \
    --input tests/input/scenery.txt --results-dir tests/container-results/scenery --release
"$WRAPPER" run --project "$PROJECT" --output build/release/world-events.t3 \
    --input tests/input/events.txt --results-dir tests/container-results/events --release

scenery="$RESULTS/scenery/release-transcript.log"
events="$RESULTS/events/release-transcript.log"
for marker in '[WORLD chandelier]' '[WORLD decoration]' '[WORLD piano]' \
    '[WORLD played]' '[WORLD portable]' '[WORLD under-chair]' \
    '[WORLD chair-moved]' '[WORLD cabinet]' '[WORLD room-part]'; do
    require_marker "$scenery" "$marker"
done
require_marker "$scenery" "You can't take that."
require_marker "$events" '[EVENT duplicate-prevented]'
require_marker "$events" '[EVENT delayed-fired]'
require_count "$events" '[EVENT delayed-fired]' 1
require_count "$events" 'generator sputters' 8
require_marker "$events" '[EVENT stage=1]'
require_marker "$events" '[EVENT stage=2]'
require_marker "$events" 'bell-state=changed'
reject_marker "$events" '[EVENT sensory-visible]'
require_marker "$events" '[EVENT canceled pulse='
require_marker "$events" 'started=no delayed=yes'
require_marker "$events" '[EVENT room-return=1]'
require_marker "$events" '[EVENT room-return=2]'
require_count "$events" '[EVENT room-return=' 2

printf '%s\n' 'world_events=pass' 'compile=pass' 'scenery_semantics=pass' \
    'vocabulary=pass' 'event_timing=pass' 'event_cancellation=pass' \
    'sensory_suppression=pass' 'duplicate_prevention=pass' 'room_entry=pass'
