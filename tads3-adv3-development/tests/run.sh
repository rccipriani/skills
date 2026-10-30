#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SCRIPT="$ROOT/scripts/tads3-toolchain.sh"
. "$ROOT/tests/clean-container-support.sh"
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

make_mock_git() {
    local base="$1"
    mkdir -p "$base"
    cat > "$base/git" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == init ]]; then
    repo="${3}"
    mkdir -p "$repo/.git"
    cp -R -- "$MOCK_FETCH_SOURCE"/. "$repo"/
    exit 0
fi
if [[ "${1:-}" == -C ]]; then
    case "${3:-}" in
        remote) exit 0 ;;
        fetch) [[ "${MOCK_FETCH_FAIL:-0}" != 1 ]] || exit 9; exit 0 ;;
        rev-parse)
            if [[ "${MOCK_FETCH_MISMATCH:-0}" == 1 ]]; then printf '%040d\n' 0
            else printf '%s\n' 934b0e4900d9a3a1ab291aa711919f209276c421
            fi
            exit 0 ;;
        verify-commit)
            [[ "${MOCK_SIGNATURE_FAIL:-0}" != 1 ]] || exit 10
            printf '[GNUPG:] VALIDSIG 00000000000000000000000015B600E72CA59238 2021-05-09 0 4 0 1 10 00 00000000000000000000000015B600E72CA59238\n' >&2
            exit 0 ;;
        checkout) exit 0 ;;
    esac
fi
printf 'unexpected mock git invocation: %s\n' "$*" >&2
exit 11
MOCK
    chmod +x "$base/git"
}

make_mock_archive_tools() {
    local base="$1"
    mkdir -p "$base"
    cat > "$base/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[[ "${MOCK_CURL_FAIL:-0}" != 1 ]] || exit 22
output=""
while (($#)); do
    case "$1" in --output) output="$2"; shift 2 ;; *) shift ;; esac
done
[[ -n "$output" ]]
cp -- "${MOCK_ARCHIVE_FILE}" "$output"
MOCK
    cat > "$base/sha256sum" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ $# -eq 1 && "$1" == *realnc-frobtads-v2.0_GH0.tar.gz ]]; then
    if [[ "${MOCK_ARCHIVE_HASH_BAD:-0}" == 1 ]]; then printf '%064d  %s\n' 0 "$1"
    else printf 'c457860d3bf3db3c1129deddbd2c7a295602c7f59560d7e6e81df3bb77a23cd5  %s\n' "$1"
    fi
else
    exec /usr/bin/sha256sum "$@"
fi
MOCK
    cat > "$base/wc" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == -c ]]; then
    /usr/bin/wc -c >/dev/null
    if [[ "${MOCK_ARCHIVE_SIZE_BAD:-0}" == 1 ]]; then printf '10\n'; else printf '5122899\n'; fi
else
    exec /usr/bin/wc "$@"
fi
MOCK
    chmod +x "$base/curl" "$base/sha256sum" "$base/wc"
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
SOURCE_HASH="$(cd "$SOURCE" && find . -type f -not -path './.git/*' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')"
VERIFY_PROVENANCE="$TEST_TMP/verify-source-provenance.txt"
printf 'source_repository=https://github.com/realnc/frobtads\nrelease=v2.0\nverification_method=offline-test\nsource_tree_sha256=%s\n' "$SOURCE_HASH" > "$VERIFY_PROVENANCE"
expect_success 'verified source and provenance pass read-only image gate' 'source_verification=pass' /bin/bash "$SCRIPT" verify-source --source "$SOURCE" --provenance "$VERIFY_PROVENANCE"

HOST_AUTH="$TEST_TMP/host authorization"
printf 'user_approved=yes\nsource=/source\nprefix=/work/frobtads/2.0-tads3.1.3\n' > "$HOST_AUTH"
chmod 600 "$HOST_AUTH"
HOST_AUTH_BEFORE="$(stat -c '%a|%u|%g|%s|%Y' "$HOST_AUTH")|$(sha256sum "$HOST_AUTH" | awk '{print $1}')"
STAGED_AUTH="$TEST_TMP/staged authorization"
if stage_authorization_record "$HOST_AUTH" "$STAGED_AUTH" "$(id -u)" "$(id -g)" && \
        cmp -s "$HOST_AUTH" "$STAGED_AUTH" && [[ "$(stat -c %a "$STAGED_AUTH")" == 600 ]]; then
    record_pass 'mode-600 host authorization record stages exactly with private permissions'
else
    record_fail 'mode-600 host authorization record stages exactly with private permissions' 'staging, content, or mode check failed'
fi
HOST_AUTH_AFTER="$(stat -c '%a|%u|%g|%s|%Y' "$HOST_AUTH")|$(sha256sum "$HOST_AUTH" | awk '{print $1}')"
if [[ "$HOST_AUTH_BEFORE" == "$HOST_AUTH_AFTER" ]]; then record_pass 'authorization staging leaves host record unchanged'; else record_fail 'authorization staging leaves host record unchanged' "before=$HOST_AUTH_BEFORE after=$HOST_AUTH_AFTER"; fi
cleanup_staged_authorization "$STAGED_AUTH"
if [[ ! -e "$STAGED_AUTH" ]]; then record_pass 'staged authorization record is cleaned up'; else record_fail 'staged authorization record is cleaned up' 'staged file remains'; fi

COLLISION_DIAG="$TEST_TMP/collision diagnostic"
printf 'ERROR[collision]: installation prefix already exists\n' > "$COLLISION_DIAG"
expect_success 'expected collision is reported as a passing negative test' 'PASS: duplicate installation correctly rejected' report_expected_collision 1 "$COLLISION_DIAG"
expect_failure 'unexpected collision-test success fails the harness check' 'duplicate installation unexpectedly succeeded' report_expected_collision 0 "$COLLISION_DIAG"
OTHER_DIAG="$TEST_TMP/other diagnostic"
printf 'ERROR[source]: unrelated failure marker\n' > "$OTHER_DIAG"
expect_failure 'unexpected collision-test failure preserves diagnostic and fails' 'ERROR[source]: unrelated failure marker' report_expected_collision 1 "$OTHER_DIAG"

SOURCE_HASH="$(cd "$SOURCE" && find . -type f -not -path './.git/*' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')"
INVALID_PROVENANCE="$TEST_TMP/invalid authorization provenance"
printf 'source_repository=https://github.com/realnc/frobtads\nrelease=v2.0\ncommit=934b0e4900d9a3a1ab291aa711919f209276c421\nverification_method=offline test fixture\nsource_tree_sha256=%s\nsource_tree_sha256_origin=locally_calculated\n' "$SOURCE_HASH" > "$INVALID_PROVENANCE"
INVALID_ALLOWED="$TEST_TMP/invalid authorization installs"
mkdir -p "$INVALID_ALLOWED"
INVALID_PREFIX="$INVALID_ALLOWED/frobtads-test"
INVALID_AUTH="$TEST_TMP/invalid authorization"
printf 'user_approved=no\nsource=%s\nprefix=%s\n' "$SOURCE" "$INVALID_PREFIX" > "$INVALID_AUTH"
expect_failure 'invalid authorization record is rejected' 'ERROR[authorization]' /bin/bash "$SCRIPT" install --source "$SOURCE" --prefix "$INVALID_PREFIX" --allowed-root "$INVALID_ALLOWED" --provenance "$INVALID_PROVENANCE" --authorization-record "$INVALID_AUTH" --execute

MOCK_GIT="$TEST_TMP/mock git"
make_mock_git "$MOCK_GIT"
FETCH_CACHE="$TEST_TMP/fetch cache"
expect_failure 'fetch requires explicit download authorization' 'ERROR[authorization]' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" /bin/bash "$SCRIPT" fetch --cache-dir "$FETCH_CACHE"
expect_failure 'download failure leaves no cache entry' 'ERROR[download]' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" MOCK_FETCH_FAIL=1 /bin/bash "$SCRIPT" fetch --fetch-method git --cache-dir "$FETCH_CACHE" --authorize-download
if [[ ! -e "$FETCH_CACHE/v2.0-934b0e4900d9a3a1ab291aa711919f209276c421" ]]; then record_pass 'failed download is not cached'; else record_fail 'failed download is not cached' 'cache entry exists'; fi
expect_failure 'fetched commit identity mismatch is rejected' 'ERROR[integrity]' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" MOCK_FETCH_MISMATCH=1 /bin/bash "$SCRIPT" fetch --cache-dir "$FETCH_CACHE" --authorize-download
expect_failure 'unverifiable commit signature is rejected' 'ERROR[signature]' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" MOCK_SIGNATURE_FAIL=1 /bin/bash "$SCRIPT" fetch --fetch-method git --cache-dir "$FETCH_CACHE" --authorize-download
expect_success 'pinned signed commit is fetched and cached' 'fetch=downloaded-and-verified' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" /bin/bash "$SCRIPT" fetch --cache-dir "$FETCH_CACHE" --authorize-download
expect_success 'verified cache is reused without network authorization' 'fetch=cache-reuse' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" MOCK_FETCH_FAIL=1 /bin/bash "$SCRIPT" fetch --cache-dir "$FETCH_CACHE"
printf 'tamper\n' >> "$FETCH_CACHE/v2.0-934b0e4900d9a3a1ab291aa711919f209276c421/source/CMakeLists.txt"
expect_failure 'cached tree checksum mismatch is rejected' 'source tree checksum mismatch' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" /bin/bash "$SCRIPT" fetch --cache-dir "$FETCH_CACHE"
INCOMPLETE_CACHE="$TEST_TMP/incomplete cache"
mkdir -p "$INCOMPLETE_CACHE/v2.0-934b0e4900d9a3a1ab291aa711919f209276c421/source"
expect_failure 'incomplete cache entry is rejected without replacement' 'ERROR[cache]: incomplete cache entry' env PATH="$MOCK_GIT:$SYSTEM_PATH" MOCK_FETCH_SOURCE="$SOURCE" /bin/bash "$SCRIPT" fetch --cache-dir "$INCOMPLETE_CACHE" --authorize-download

ARCHIVE_ROOT="$TEST_TMP/archive root"
mkdir -p "$ARCHIVE_ROOT/frobtads-2.0"
cp -R -- "$SOURCE"/. "$ARCHIVE_ROOT/frobtads-2.0"/
ARCHIVE_FILE="$TEST_TMP/frobtads-v2.0.tar.gz"
tar -czf "$ARCHIVE_FILE" -C "$ARCHIVE_ROOT" frobtads-2.0
CORRUPT_ARCHIVE="$TEST_TMP/corrupt.tar.gz"
printf 'not a tar archive\n' > "$CORRUPT_ARCHIVE"
MOCK_ARCHIVE_TOOLS="$TEST_TMP/mock archive tools"
make_mock_archive_tools "$MOCK_ARCHIVE_TOOLS"
ARCHIVE_PATH="$MOCK_ARCHIVE_TOOLS:$SYSTEM_PATH"
expect_failure 'archive download failure is rejected' 'ERROR[download]' env PATH="$ARCHIVE_PATH" MOCK_ARCHIVE_FILE="$ARCHIVE_FILE" MOCK_CURL_FAIL=1 /bin/bash "$SCRIPT" fetch --fetch-method archive --cache-dir "$TEST_TMP/archive download failure" --authorize-download
expect_failure 'incomplete archive download is rejected' 'ERROR[integrity]: archive is incomplete' env PATH="$ARCHIVE_PATH" MOCK_ARCHIVE_FILE="$ARCHIVE_FILE" MOCK_ARCHIVE_SIZE_BAD=1 /bin/bash "$SCRIPT" fetch --fetch-method archive --cache-dir "$TEST_TMP/archive incomplete" --authorize-download
expect_failure 'archive checksum mismatch is rejected' 'ERROR[integrity]: archive checksum mismatch' env PATH="$ARCHIVE_PATH" MOCK_ARCHIVE_FILE="$ARCHIVE_FILE" MOCK_ARCHIVE_HASH_BAD=1 /bin/bash "$SCRIPT" fetch --fetch-method archive --cache-dir "$TEST_TMP/archive checksum mismatch" --authorize-download
expect_failure 'corrupted checksum-matching archive is rejected' 'ERROR[archive]' env PATH="$ARCHIVE_PATH" MOCK_ARCHIVE_FILE="$CORRUPT_ARCHIVE" /bin/bash "$SCRIPT" fetch --fetch-method archive --cache-dir "$TEST_TMP/archive corrupt" --authorize-download
ARCHIVE_CACHE="$TEST_TMP/archive success cache"
expect_success 'FreeBSD-checksummed archive is acquired' 'acquisition_method=freebsd-ports-sha256' env PATH="$ARCHIVE_PATH" MOCK_ARCHIVE_FILE="$ARCHIVE_FILE" /bin/bash "$SCRIPT" fetch --fetch-method archive --cache-dir "$ARCHIVE_CACHE" --authorize-download
expect_success 'checksum-verified archive cache is reused offline' 'fetch=cache-reuse' env PATH="$ARCHIVE_PATH" MOCK_ARCHIVE_FILE="$ARCHIVE_FILE" MOCK_CURL_FAIL=1 /bin/bash "$SCRIPT" fetch --cache-dir "$ARCHIVE_CACHE"
AUTO_CACHE="$TEST_TMP/automatic fallback cache"
expect_success 'missing Git signing key falls back to verified archive' 'acquisition_method=freebsd-ports-sha256' env PATH="$MOCK_GIT:$ARCHIVE_PATH" MOCK_FETCH_SOURCE="$SOURCE" MOCK_SIGNATURE_FAIL=1 MOCK_ARCHIVE_FILE="$ARCHIVE_FILE" /bin/bash "$SCRIPT" fetch --cache-dir "$AUTO_CACHE" --authorize-download
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
"$ROOT/tests/container-interface.sh"
