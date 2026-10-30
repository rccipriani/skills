#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/tads3-toolchain.sh"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/tads3-tests.XXXXXXXX")"
PASS=0
FAIL=0

cleanup() {
    case "$TEST_TMP" in "${TMPDIR:-/tmp}"/tads3-tests.*|/tmp/tads3-tests.*) rm -rf -- "$TEST_TMP" ;; esac
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

record_pass() { PASS=$((PASS + 1)); printf 'ok %d - %s\n' "$PASS" "$1"; }
record_fail() { FAIL=$((FAIL + 1)); printf 'not ok - %s\n%s\n' "$1" "$2" >&2; }

expect_success() {
    local name="$1" expected="$2"; shift 2
    local output status=0
    output="$("$@" 2>&1)" || status=$?
    if ((status == 0)) && grep -Fq "$expected" <<<"$output"; then record_pass "$name"; else record_fail "$name" "status=$status expected=$expected output=$output"; fi
}

expect_failure() {
    local name="$1" expected="$2"; shift 2
    local output status=0
    output="$("$@" 2>&1)" || status=$?
    if ((status != 0)) && grep -Fq "$expected" <<<"$output"; then record_pass "$name"; else record_fail "$name" "status=$status expected=$expected output=$output"; fi
}

make_mock_layout() {
    local base="$1"
    mkdir -p "$base/bin" "$base/home/include" "$base/home/lib/adv3"
    : > "$base/home/include/tads.h"
    : > "$base/home/lib/adv3/adv3.tl"
    cat > "$base/bin/t3make" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
manifest=""
while (($#)); do
    case "$1" in -f) manifest="$2"; shift 2 ;; *) shift ;; esac
done
[[ "${MOCK_BUILD_FAIL:-0}" != 1 ]] || { printf 'mock compile failure\n' >&2; exit 7; }
if [[ -n "${MOCK_BUILD_SLEEP:-}" ]]; then sleep "$MOCK_BUILD_SLEEP"; fi
image="$(sed -n 's/^-o "\(.*\)"/\1/p' "$manifest")"
mkdir -p "$(dirname "$image")"
: > "$image"
printf 'TADS Compiler 3.1.3 mock\nErrors: 0 Warnings: 0\n'
MOCK
    cat > "$base/bin/frob" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == --version ]]; then printf 'FrobTADS 2.0 mock\n'; exit 0; fi
[[ "${MOCK_RUNTIME_FAIL:-0}" != 1 ]] || { printf 'mock runtime failure\n' >&2; exit 8; }
image="${*: -1}"
printf '%s\n' \
  '[VALIDATION intro]' '[VALIDATION state=unaligned]' \
  '[VALIDATION action=aligned award=5]' '[VALIDATION event=clockwork-fired]' \
  '[VALIDATION state=aligned]' '[VALIDATION conversation=aligned]' \
  '[VALIDATION duplicate-action=blocked]'
if [[ "${MOCK_BAD_TRANSCRIPT:-0}" == 1 ]]; then printf '[VALIDATION score=4]\n'; else printf '[VALIDATION score=5]\n'; fi
if [[ "$image" == *debug* ]]; then printf '[VALIDATION debug-command=accepted]\n'; else printf 'The word "debugstatus" is not necessary in this story.\n'; fi
MOCK
    chmod +x "$base/bin/t3make" "$base/bin/frob"
}

make_mock_source() {
    local base="$1"
    mkdir -p "$base/tads3"
    cat > "$base/CMakeLists.txt" <<'MOCK'
project(FrobTADS)
set(FROB_VERSION "test")
MOCK
    : > "$base/CMFrob.cmake"
    : > "$base/frob_config.h.in"
    : > "$base/tads3/tcmake.cpp"
    : > "$base/tads3/vmrun.cpp"
}

MOCK_ROOT="$TEST_TMP/mock layout with spaces"
make_mock_layout "$MOCK_ROOT"
SYSTEM_PATH=/usr/bin:/bin
expect_failure 'missing compiler' 'ERROR[compiler]' env PATH="$SYSTEM_PATH" /bin/bash "$SCRIPT" validate
expect_failure 'missing interpreter' 'ERROR[interpreter]' env PATH="$SYSTEM_PATH" T3MAKE="$MOCK_ROOT/bin/t3make" TADS3_HOME="$MOCK_ROOT/home" /bin/bash "$SCRIPT" validate
expect_failure 'invalid explicit compiler override' 'T3MAKE is set but is not an executable file' env T3MAKE="$TEST_TMP/no-t3make" /bin/bash "$SCRIPT" check

NO_ADV3="$TEST_TMP/no-adv3"
mkdir -p "$NO_ADV3/include" "$NO_ADV3/lib"
: > "$NO_ADV3/include/tads.h"
expect_failure 'missing adv3 library' 'ERROR[discovery]: TADS3_LIB' env PATH="$MOCK_ROOT/bin:$PATH" TADS3_INCLUDE="$NO_ADV3/include" TADS3_LIB="$NO_ADV3/lib" /bin/bash "$SCRIPT" validate

SOURCE="$TEST_TMP/FrobTADS source"
make_mock_source "$SOURCE"
ALLOWED="$TEST_TMP/owned installs"
mkdir -p "$ALLOWED"
expect_failure 'invalid installation prefix' 'ERROR[destination]' /bin/bash "$SCRIPT" install --source "$SOURCE" --prefix /usr --allowed-root "$ALLOWED"

COLLISION="$ALLOWED/frobtads-2.0"
mkdir -p "$COLLISION/unrelated-app"
expect_failure 'existing installation collision' 'ERROR[collision]' /bin/bash "$SCRIPT" install --source "$SOURCE" --prefix "$COLLISION" --allowed-root "$ALLOWED"

UNRECOGNIZED="$TEST_TMP/unrecognized"
mkdir -p "$UNRECOGNIZED"
: > "$UNRECOGNIZED/CMakeLists.txt"
expect_failure 'unrecognized source tree' 'ERROR[source]' /bin/bash "$SCRIPT" install --source "$UNRECOGNIZED" --prefix "$ALLOWED/frobtads-test" --allowed-root "$ALLOWED"
expect_success 'planning mode with paths containing spaces' 'execution=not requested' /bin/bash "$SCRIPT" install --source "$SOURCE" --prefix "$ALLOWED/frobtads test" --allowed-root "$ALLOWED"
printf 'preserve me\n' > "$ALLOWED/planning sentinel"
PLAN_BEFORE="$(find "$ALLOWED" -mindepth 1 -maxdepth 1 -printf '%P|%y|%s|%T@\n' | LC_ALL=C sort)"
expect_success 'planning operation reports without writes' 'execution=not requested' /bin/bash "$SCRIPT" install --source "$SOURCE" --prefix "$ALLOWED/read-only plan" --allowed-root "$ALLOWED"
PLAN_AFTER="$(find "$ALLOWED" -mindepth 1 -maxdepth 1 -printf '%P|%y|%s|%T@\n' | LC_ALL=C sort)"
if [[ "$PLAN_BEFORE" == "$PLAN_AFTER" ]] && [[ ! -e "$ALLOWED/read-only plan" ]] && ! compgen -G "$ALLOWED/.tads3-write-probe.*" >/dev/null; then
    record_pass 'planning leaves destination unchanged'
else
    record_fail 'planning leaves destination unchanged' "before=$PLAN_BEFORE after=$PLAN_AFTER"
fi
READ_ONLY_HOME="$TEST_TMP/read-only operation state"
mkdir -p "$READ_ONLY_HOME"
printf 'unchanged\n' > "$READ_ONLY_HOME/sentinel"
READ_ONLY_BEFORE="$(find "$READ_ONLY_HOME" -printf '%P|%y|%s|%T@\n' | LC_ALL=C sort)"
for operation in check plan repair; do
    env HOME="$READ_ONLY_HOME" PATH="$MOCK_ROOT/bin:$PATH" T3MAKE="$MOCK_ROOT/bin/t3make" FROB="$MOCK_ROOT/bin/frob" TADS3_HOME="$MOCK_ROOT/home" /bin/bash "$SCRIPT" "$operation" >/dev/null
done
READ_ONLY_AFTER="$(find "$READ_ONLY_HOME" -printf '%P|%y|%s|%T@\n' | LC_ALL=C sort)"
if [[ "$READ_ONLY_BEFORE" == "$READ_ONLY_AFTER" ]]; then
    record_pass 'check, plan, and repair leave filesystem state unchanged'
else
    record_fail 'check, plan, and repair leave filesystem state unchanged' "before=$READ_ONLY_BEFORE after=$READ_ONLY_AFTER"
fi
expect_failure '--execute alone is insufficient authorization' 'ERROR[provenance]' /bin/bash "$SCRIPT" install --source "$SOURCE" --prefix "$ALLOWED/frobtads-execute" --allowed-root "$ALLOWED" --execute

VALIDATE_TMP="$TEST_TMP/validation temp with spaces"
mkdir -p "$VALIDATE_TMP"
expect_success 'successful mocked toolchain validation' 'validation=pass' env TMPDIR="$VALIDATE_TMP" PATH="$MOCK_ROOT/bin:$PATH" T3MAKE="$MOCK_ROOT/bin/t3make" FROB="$MOCK_ROOT/bin/frob" TADS3_HOME="$MOCK_ROOT/home" /bin/bash "$SCRIPT" validate
if compgen -G "$VALIDATE_TMP/tads3-skill.*" >/dev/null; then record_fail 'temporary directory cleanup' 'temporary directory remained'; else record_pass 'temporary directory cleanup'; fi
expect_failure 'build failure diagnostic' 'ERROR[release-build]' env PATH="$MOCK_ROOT/bin:$PATH" T3MAKE="$MOCK_ROOT/bin/t3make" FROB="$MOCK_ROOT/bin/frob" TADS3_HOME="$MOCK_ROOT/home" MOCK_BUILD_FAIL=1 /bin/bash "$SCRIPT" validate
expect_failure 'transcript assertion diagnostic' 'ERROR[release-transcript]' env PATH="$MOCK_ROOT/bin:$PATH" T3MAKE="$MOCK_ROOT/bin/t3make" FROB="$MOCK_ROOT/bin/frob" TADS3_HOME="$MOCK_ROOT/home" MOCK_BAD_TRANSCRIPT=1 /bin/bash "$SCRIPT" validate

SIGNAL_TMP="$TEST_TMP/signal temp with spaces"
mkdir -p "$SIGNAL_TMP"
set +e
env TMPDIR="$SIGNAL_TMP" PATH="$MOCK_ROOT/bin:$PATH" T3MAKE="$MOCK_ROOT/bin/t3make" FROB="$MOCK_ROOT/bin/frob" TADS3_HOME="$MOCK_ROOT/home" MOCK_BUILD_SLEEP=2 /bin/bash "$SCRIPT" validate >"$TEST_TMP/signal.out" 2>&1 &
SIGNAL_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
    compgen -G "$SIGNAL_TMP/tads3-skill.*" >/dev/null && break
    sleep 0.1
done
kill -TERM "$SIGNAL_PID"
wait "$SIGNAL_PID"
SIGNAL_STATUS=$?
set -e
if [[ "$SIGNAL_STATUS" == 143 ]] && ! compgen -G "$SIGNAL_TMP/tads3-skill.*" >/dev/null; then
    record_pass 'SIGTERM exits 143 and cleans temporary build directory'
else
    record_fail 'SIGTERM exits 143 and cleans temporary build directory' "status=$SIGNAL_STATUS residue=$(find "$SIGNAL_TMP" -mindepth 1 -maxdepth 1 -print)"
fi

printf 'tests_passed=%d\ntests_failed=%d\n' "$PASS" "$FAIL"
((FAIL == 0))
