#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-check}"
shift || true

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FIXTURE="$SKILL_ROOT/assets/examples/validation-project/game.t"
TRANSCRIPT="$SKILL_ROOT/assets/examples/validation-project/smoke.txt"
T3MAKE_CMD=""
FROB_CMD=""
TADS_INCLUDE_DIR=""
TADS_LIB_DIR=""
TADS_DOC_DIR=""
TADS_SAMPLES_DIR=""
SOURCE_DIR=""
FETCH_CACHE_DIR="${FROBTADS_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME:-}/.cache}/tads3-adv3-development/frobtads}"
DOWNLOAD_AUTHORIZED=0
FETCH_METHOD="${FROBTADS_FETCH_METHOD:-auto}"
INSTALL_PREFIX=""
ALLOWED_ROOT=""
AUTHORIZATION_RECORD=""
PROVENANCE_FILE=""
EXECUTE=0
TEMP_DIR=""
FETCH_TEMP_DIR=""
WRITE_PROBE=""

cleanup() {
    if [[ -n "$FETCH_TEMP_DIR" && -d "$FETCH_TEMP_DIR" ]]; then
        case "$FETCH_TEMP_DIR" in
            */.fetch.*) rm -rf -- "$FETCH_TEMP_DIR" ;;
            *) printf 'WARNING: refusing to clean unexpected fetch path: %s\n' "$FETCH_TEMP_DIR" >&2 ;;
        esac
    fi
    FETCH_TEMP_DIR=""
    if [[ -n "$WRITE_PROBE" ]]; then
        case "$WRITE_PROBE" in
            */.tads3-write-probe.*) rm -f -- "$WRITE_PROBE" ;;
            *) printf 'WARNING: refusing to clean unexpected write probe: %s\n' "$WRITE_PROBE" >&2 ;;
        esac
    fi
    WRITE_PROBE=""
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        case "$TEMP_DIR" in
            "${TMPDIR:-/tmp}"/tads3-skill.*|/tmp/tads3-skill.*) rm -rf -- "$TEMP_DIR" ;;
            *) printf 'WARNING: refusing to clean unexpected temporary path: %s\n' "$TEMP_DIR" >&2 ;;
        esac
    fi
    TEMP_DIR=""
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

usage() {
    printf '%s\n' \
        'Usage: tads3-toolchain.sh check|validate|repair|plan|fetch|verify-source|install [options]' \
        '' \
        'Provisioning options:' \
        '  --source DIR                 verified, unpacked FrobTADS source tree' \
        '  --prefix DIR                 new user-owned, versioned installation prefix' \
        '  --allowed-root DIR           authorized existing parent for the new prefix' \
        '  --provenance FILE            source provenance record (required to execute)' \
        '  --authorization-record FILE  prior approval record (required to execute)' \
        '  --execute                    build and install after all safety gates pass' \
        '' \
        'Fetch options:' \
        '  --cache-dir DIR              verified source cache (default: user cache)' \
        '  --fetch-method METHOD        auto, git, or archive (default: auto)' \
        '  --authorize-download         record explicit authorization for network access' \
        '' \
        'Environment overrides:' \
        '  T3MAKE FROB TADS3_HOME TADS3_INCLUDE TADS3_LIB TADS3_DOC TADS3_SAMPLES'
}

die() {
    printf 'ERROR[%s]: %s\n' "$1" "$2" >&2
    return 1
}

while (($#)); do
    case "$1" in
        --source) [[ $# -ge 2 ]] || { die arguments 'missing value for --source'; exit 2; }; SOURCE_DIR="$2"; shift 2 ;;
        --prefix) [[ $# -ge 2 ]] || { die arguments 'missing value for --prefix'; exit 2; }; INSTALL_PREFIX="$2"; shift 2 ;;
        --allowed-root) [[ $# -ge 2 ]] || { die arguments 'missing value for --allowed-root'; exit 2; }; ALLOWED_ROOT="$2"; shift 2 ;;
        --provenance) [[ $# -ge 2 ]] || { die arguments 'missing value for --provenance'; exit 2; }; PROVENANCE_FILE="$2"; shift 2 ;;
        --authorization-record) [[ $# -ge 2 ]] || { die arguments 'missing value for --authorization-record'; exit 2; }; AUTHORIZATION_RECORD="$2"; shift 2 ;;
        --execute) EXECUTE=1; shift ;;
        --cache-dir) [[ $# -ge 2 ]] || { die arguments 'missing value for --cache-dir'; exit 2; }; FETCH_CACHE_DIR="$2"; shift 2 ;;
        --fetch-method) [[ $# -ge 2 ]] || { die arguments 'missing value for --fetch-method'; exit 2; }; FETCH_METHOD="$2"; shift 2 ;;
        --authorize-download) DOWNLOAD_AUTHORIZED=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

canonical_existing() {
    local path="$1"
    [[ -e "$path" ]] || return 1
    (cd "$path" 2>/dev/null && pwd -P)
}

canonical_new_path() {
    local path="$1" parent base=""
    [[ -n "$path" ]] || return 1
    while [[ "$path" != / && ! -e "$path" ]]; do
        base="/${path##*/}$base"
        path="${path%/*}"
        [[ -n "$path" ]] || path=/
    done
    parent="$(canonical_existing "$path")" || return 1
    printf '%s%s\n' "${parent%/}" "$base"
}

resolve_executable() {
    local variable="$1" configured="$2" fallback="$3" resolved
    if [[ -n "$configured" ]]; then
        if [[ "$configured" == */* ]]; then
            if [[ ! -f "$configured" || ! -x "$configured" ]]; then
                die discovery "$variable is set but is not an executable file: $configured"
                return 1
            fi
            resolved="$(cd "$(dirname "$configured")" && pwd -P)/$(basename "$configured")"
        else
            if ! resolved="$(command -v "$configured" 2>/dev/null)"; then
                die discovery "$variable is set but command is not on PATH: $configured"
                return 1
            fi
        fi
    else
        resolved="$(command -v "$fallback" 2>/dev/null || true)"
    fi
    printf '%s\n' "$resolved"
}

validate_explicit_dir() {
    local variable="$1" value="$2" marker="$3"
    [[ -n "$value" ]] || return 0
    [[ -d "$value" ]] || die discovery "$variable is set but is not a directory: $value"
    [[ -e "$value/$marker" ]] || die discovery "$variable does not contain $marker: $value"
}

detect_os() {
    local os_name kernel arch os_id=unknown os_like=unknown
    kernel="$(uname -s 2>/dev/null || printf unknown)"
    arch="$(uname -m 2>/dev/null || printf unknown)"
    os_name="$kernel"
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_name="${PRETTY_NAME:-${NAME:-$kernel}}"
        os_id="${ID:-unknown}"
        os_like="${ID_LIKE:-unknown}"
    fi
    printf 'os=%s\nos_id=%s\nos_like=%s\nkernel=%s\narchitecture=%s\n' "$os_name" "$os_id" "$os_like" "$kernel" "$arch"
    if grep -qi microsoft /proc/version 2>/dev/null; then printf 'environment=wsl2-or-wsl\n'; fi
}

candidate_homes() {
    local user_home="${HOME:-}" bin_dir prefix root candidate
    [[ -n "${TADS3_HOME:-}" ]] && printf '%s\n' "$TADS3_HOME"
    for root in \
        "${XDG_DATA_HOME:-${user_home:+$user_home/.local/share}}/frobtads/tads3" \
        "${user_home:+$user_home/.local/opt}" \
        "${user_home:+$user_home/opt}"; do
        [[ -n "$root" ]] || continue
        if [[ "$root" == */tads3 ]]; then
            printf '%s\n' "$root"
        elif [[ -d "$root" ]]; then
            for candidate in "$root"/frobtads-*/share/frobtads/tads3 "$root"/frobtads/*/share/frobtads/tads3; do
                [[ -d "$candidate" ]] && printf '%s\n' "$candidate"
            done
        fi
    done
    printf '%s\n' /usr/local/share/frobtads/tads3 /usr/share/frobtads/tads3 /opt/frobtads/share/frobtads/tads3
    for prefix in "$(dirname "${T3MAKE_CMD:-/nonexistent}")" "$(dirname "${FROB_CMD:-/nonexistent}")"; do
        [[ "$prefix" != /nonexistent ]] || continue
        bin_dir="$(cd "$prefix" 2>/dev/null && pwd -P || true)"
        [[ -n "$bin_dir" ]] && printf '%s\n' "$(dirname "$bin_dir")/share/frobtads/tads3"
    done
}

detect_layout() {
    T3MAKE_CMD="$(resolve_executable T3MAKE "${T3MAKE:-}" t3make)" || return 1
    FROB_CMD="$(resolve_executable FROB "${FROB:-}" frob)" || return 1
    validate_explicit_dir TADS3_HOME "${TADS3_HOME:-}" include/tads.h || return 1
    validate_explicit_dir TADS3_INCLUDE "${TADS3_INCLUDE:-}" tads.h || return 1
    validate_explicit_dir TADS3_LIB "${TADS3_LIB:-}" adv3/adv3.tl || return 1

    TADS_INCLUDE_DIR="${TADS3_INCLUDE:-}"
    TADS_LIB_DIR="${TADS3_LIB:-}"
    TADS_DOC_DIR="${TADS3_DOC:-}"
    TADS_SAMPLES_DIR="${TADS3_SAMPLES:-}"
    local home
    while IFS= read -r home; do
        [[ -d "$home" ]] || continue
        [[ -n "$TADS_INCLUDE_DIR" || ! -f "$home/include/tads.h" ]] || TADS_INCLUDE_DIR="$home/include"
        [[ -n "$TADS_LIB_DIR" || ! -f "$home/lib/adv3/adv3.tl" ]] || TADS_LIB_DIR="$home/lib"
        [[ -n "$TADS_DOC_DIR" || ! -d "$home/doc" ]] || TADS_DOC_DIR="$home/doc"
        [[ -n "$TADS_SAMPLES_DIR" || ! -d "$home/lib/samples" ]] || TADS_SAMPLES_DIR="$home/lib/samples"
    done < <(candidate_homes | awk 'NF && !seen[$0]++')
}

print_version() {
    local label="$1" cmd="$2"
    if [[ -n "$cmd" ]]; then
        printf 'selected_%s=%s\n' "$label" "$cmd"
        if [[ "$label" == t3make ]]; then
            printf 't3make_version=reported by validation compile banner\n'
        else
            { "$cmd" --version 2>&1 || true; } | sed -n '1,3p'
        fi
    else
        printf 'selected_%s=missing\n' "$label"
    fi
}

dependency_plan() {
    local os_data id like family=unknown packages=unknown
    os_data="$(detect_os)"
    id="$(printf '%s\n' "$os_data" | sed -n 's/^os_id=//p')"
    like="$(printf '%s\n' "$os_data" | sed -n 's/^os_like=//p')"
    case "$id $like" in
        *rhel*|*fedora*|*centos*|*rocky*|*almalinux*) family=rhel; packages='gcc gcc-c++ cmake make ncurses-devel libcurl-devel' ;;
        *ubuntu*|*debian*) family=debian; packages='build-essential cmake make libncurses-dev libcurl4-openssl-dev' ;;
    esac
    printf 'platform_family=%s\n' "$family"
    printf 'dependency_packages=%s\n' "$packages"
    printf 'dependency_action=plan only; confirm package names for this release and obtain authorization before running a package manager\n'
    printf 'source_acquisition=supply a verified source tree and provenance record; this script performs no network download\n'
}

check_environment() {
    detect_layout
    detect_os
    print_version t3make "$T3MAKE_CMD"
    print_version frob "$FROB_CMD"
    printf 'selected_tads3_include=%s\n' "${TADS_INCLUDE_DIR:-missing}"
    printf 'selected_tads3_library=%s\n' "${TADS_LIB_DIR:-missing}"
    printf 'selected_adv3=%s\n' "$([[ -n "$TADS_LIB_DIR" && -f "$TADS_LIB_DIR/adv3/adv3.tl" ]] && printf '%s' "$TADS_LIB_DIR/adv3/adv3.tl" || printf missing)"
    printf 'documentation=%s\n' "${TADS_DOC_DIR:-missing}"
    printf 'samples=%s\n' "${TADS_SAMPLES_DIR:-missing}"
    for tool in bash cmake make cc c++ sha256sum curl wget; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf 'build_tool_%s=%s\n' "$tool" "$(command -v "$tool")"
        else
            printf 'build_tool_%s=missing\n' "$tool"
        fi
    done
    dependency_plan
}

require_layout() {
    detect_layout || return 1
    [[ -n "$T3MAKE_CMD" ]] || die compiler 't3make not found; set T3MAKE or add it to PATH'
    [[ -n "$FROB_CMD" ]] || die interpreter 'frob not found; set FROB or add it to PATH'
    [[ -n "$TADS_INCLUDE_DIR" && -f "$TADS_INCLUDE_DIR/tads.h" ]] || die headers 'TADS 3 headers not found; set TADS3_INCLUDE or TADS3_HOME'
    [[ -n "$TADS_LIB_DIR" && -f "$TADS_LIB_DIR/adv3/adv3.tl" ]] || die adv3 'standard adv3 library not found; set TADS3_LIB or TADS3_HOME'
}

write_manifest() {
    local file="$1" image="$2" objdir="$3"
    {
        printf '%s\n' '-pre'
        printf '%s "%s"\n' '-FI' "$TADS_INCLUDE_DIR"
        printf '%s "%s"\n' '-FL' "$TADS_LIB_DIR"
        printf '%s "%s"\n' '-I' "$TADS_LIB_DIR/adv3"
        printf '%s "%s"\n' '-I' "$TADS_LIB_DIR/adv3/en_us"
        printf '%s\n' '-DLANGUAGE=en_us' '-DMESSAGESTYLE=neu'
        printf '%s "%s"\n' '-Fo' "$objdir" '-Fy' "$objdir" '-o' "$image"
        printf '%s\n' '-lib system' '-lib adv3/adv3'
        printf '%s "%s"\n' '-source' "$FIXTURE"
    } > "$file"
}

assert_count() {
    local stage="$1" file="$2" pattern="$3" expected="$4" actual
    actual="$(grep -Foc "$pattern" "$file" || true)"
    [[ "$actual" == "$expected" ]] || die "$stage" "expected $expected occurrence(s) of '$pattern', found $actual; transcript: $file"
}

assert_order() {
    local stage="$1" file="$2"; shift 2
    awk -v stage="$stage" -v terms="$*" '
        BEGIN { n=split(terms, wanted, "|"); at=1 }
        { line=$0; gsub(/[[:space:]]+/, " ", line); all=all " " line }
        END {
            for (i=1; i<=n; i++) {
                pos=index(substr(all, at), wanted[i]);
                if (!pos) { printf "ERROR[%s]: ordered semantic marker missing: %s\n", stage, wanted[i] > "/dev/stderr"; exit 1 }
                at += pos + length(wanted[i]) - 1
            }
        }' "$file"
}

assert_clean_build_log() {
    local stage="$1" file="$2"
    if grep -Eiv '(^|[[:space:]])Errors:[[:space:]]*0([[:space:]]+Warnings:[[:space:]]*0)?' "$file" | \
            grep -Eiq '(^|[[:space:]])(warning|error|fatal)(:|[[:space:]])'; then
        sed -n '1,80p' "$file" >&2
        die "$stage" "unexpected compiler warning or error; log: $file"
    fi
}

run_image() {
    local stage="$1" image="$2" output="$3"
    if ! "$FROB_CMD" -i plain -p "$image" < "$TRANSCRIPT" > "$output" 2>&1; then
        sed -n '1,100p' "$output" >&2
        die "$stage" "interpreter failed; transcript: $output"
    fi
    if grep -Eiq 'runtime error|fatal error|segmentation fault|stack trace' "$output"; then
        sed -n '1,100p' "$output" >&2
        die "$stage" "unexpected runtime error; transcript: $output"
    fi
}

validate_transcript() {
    local kind="$1" output="$2"
    assert_order "$kind-transcript" "$output" \
        '[VALIDATION intro]'\|'[VALIDATION state=unaligned]'\|'[VALIDATION action=aligned award=5]'\|'[VALIDATION event=clockwork-fired]'\|'[VALIDATION state=aligned]'\|'[VALIDATION conversation=aligned]'\|'[VALIDATION duplicate-action=blocked]'\|'[VALIDATION score=5]'
    assert_count "$kind-transcript" "$output" '[VALIDATION action=aligned award=5]' 1
    assert_count "$kind-transcript" "$output" '[VALIDATION event=clockwork-fired]' 1
    assert_count "$kind-transcript" "$output" '[VALIDATION score=5]' 1
    assert_count "$kind-transcript" "$output" '[VALIDATION runtime-error]' 0
}

validate_environment() {
    require_layout
    TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tads3-skill.XXXXXXXX")"
    local release_manifest debug_manifest release_image debug_image release_out debug_out
    mkdir -p "$TEMP_DIR/release obj" "$TEMP_DIR/debug obj"
    release_manifest="$TEMP_DIR/release manifest.t3m"
    debug_manifest="$TEMP_DIR/debug manifest.t3m"
    release_image="$TEMP_DIR/release image.t3"
    debug_image="$TEMP_DIR/debug image.t3"
    release_out="$TEMP_DIR/release transcript.out"
    debug_out="$TEMP_DIR/debug transcript.out"
    write_manifest "$release_manifest" "$release_image" "$TEMP_DIR/release obj"
    write_manifest "$debug_manifest" "$debug_image" "$TEMP_DIR/debug obj"

    if ! "$T3MAKE_CMD" -f "$release_manifest" >"$TEMP_DIR/release build.log" 2>&1; then
        sed -n '1,100p' "$TEMP_DIR/release build.log" >&2
        die release-build "compilation failed; log: $TEMP_DIR/release build.log"
    fi
    assert_clean_build_log release-build "$TEMP_DIR/release build.log"
    if ! "$T3MAKE_CMD" -d -f "$debug_manifest" >"$TEMP_DIR/debug build.log" 2>&1; then
        sed -n '1,100p' "$TEMP_DIR/debug build.log" >&2
        die debug-build "compilation failed; log: $TEMP_DIR/debug build.log"
    fi
    assert_clean_build_log debug-build "$TEMP_DIR/debug build.log"

    run_image release-runtime "$release_image" "$release_out"
    run_image debug-runtime "$debug_image" "$debug_out"
    validate_transcript release "$release_out"
    validate_transcript debug "$debug_out"
    assert_count debug-guard "$debug_out" '[VALIDATION debug-command=accepted]' 1
    assert_count release-guard "$release_out" '[VALIDATION debug-command=accepted]' 0
    if ! grep -Eiq 'don.t know the word|not a verb|unknown|not necessary in this story' "$release_out"; then
        sed -n '1,160p' "$release_out" >&2
        die release-guard "release build did not clearly reject debugstatus; transcript: $release_out"
    fi

    printf '%s\n' \
        'validation=pass' \
        "selected_compiler=$T3MAKE_CMD" \
        "selected_interpreter=$FROB_CMD" \
        "selected_adv3=$TADS_LIB_DIR/adv3/adv3.tl" \
        'release_build=pass' 'debug_build=pass' \
        'release_runtime=pass' 'debug_runtime=pass' \
        'semantic_assertions=pass' 'debug_guard=pass' 'warnings=none'
    grep -m1 'TADS Compiler' "$TEMP_DIR/release build.log" || true
}

repair_environment() {
    local status=0
    set +e
    check_environment
    require_layout || status=$?
    set -e
    if ((status == 0)); then
        printf '%s\n' 'repair_assessment=layout appears complete' 'next_action=run validate'
    else
        printf '%s\n' 'repair_assessment=toolchain is incomplete' \
            'next_action=review the explicit diagnostic and references/toolchain-provisioning.md' \
            'safety=no files were changed'
    fi
}

recognize_source() {
    local source="$1"
    [[ -f "$source/CMakeLists.txt" ]] || die source 'source tree has no CMakeLists.txt'
    [[ -f "$source/CMFrob.cmake" && -f "$source/frob_config.h.in" ]] || die source 'source tree lacks FrobTADS build markers (CMFrob.cmake and frob_config.h.in)'
    [[ -f "$source/tads3/tcmake.cpp" && -f "$source/tads3/vmrun.cpp" ]] || die source 'source tree lacks expected TADS 3 compiler/runtime sources'
    grep -Eq 'project[[:space:]]*\([[:space:]]*FrobTADS|set[[:space:]]*\([[:space:]]*FROB_VERSION' "$source/CMakeLists.txt" || die source 'CMake project does not identify itself as FrobTADS'
}

tree_sha256() {
    local source="$1"
    (cd "$source" && find . -type f -not -path './.git/*' -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}')
}

verify_provenance() {
    local file="$1" source="$2" expected actual
    [[ -f "$file" ]] || die provenance 'a provenance file is required for execution'
    grep -Eq '^source_(url|repository)=' "$file" || die provenance 'record must contain source_url or source_repository'
    grep -Eq '^(release|commit)=' "$file" || die provenance 'record must contain release or commit'
    grep -Eq '^verification_method=' "$file" || die provenance 'record must describe its verification method'
    if expected="$(sed -n 's/^archive_sha256=//p' "$file" | head -n1)" && [[ -n "$expected" ]]; then
        grep -Eq '^[[:xdigit:]]{64}$' <<<"$expected" || die provenance 'archive_sha256 is not a SHA-256 value'
    fi
    if expected="$(sed -n 's/^source_tree_sha256=//p' "$file" | head -n1)" && [[ -n "$expected" ]]; then
        grep -Eq '^[[:xdigit:]]{64}$' <<<"$expected" || die provenance 'source_tree_sha256 is not a SHA-256 value'
        command -v sha256sum >/dev/null 2>&1 || die provenance 'sha256sum is required to verify source_tree_sha256'
        actual="$(tree_sha256 "$source")"
        [[ "$actual" == "$expected" ]] || die provenance "source tree checksum mismatch: expected $expected, got $actual"
    else
        die provenance 'record must contain source_tree_sha256 for the exact unpacked tree'
    fi
}

fetch_source() {
    local repository='https://github.com/realnc/frobtads.git'
    local release='v2.0'
    local commit='934b0e4900d9a3a1ab291aa711919f209276c421'
    local signing_key='15B600E72CA59238'
    local archive_name='realnc-frobtads-v2.0_GH0.tar.gz'
    local archive_url='https://codeload.github.com/realnc/frobtads/tar.gz/v2.0?dummy=/realnc-frobtads-v2.0_GH0.tar.gz'
    local archive_sha256='c457860d3bf3db3c1129deddbd2c7a295602c7f59560d7e6e81df3bb77a23cd5'
    local archive_size='5122899'
    local checksum_source='https://cgit.freebsd.org/ports/tree/games/frobtads/distinfo?id=b1e257a26b880a75cad55681701caf4ff39c9c36'
    local cache entry source provenance actual fetched verify_log stage method cached_method archive_file listing

    case "$FETCH_METHOD" in auto|git|archive) ;; *) die arguments '--fetch-method must be auto, git, or archive'; return 2 ;; esac
    command -v sha256sum >/dev/null 2>&1 || die fetch 'sha256sum is required'
    [[ -n "$FETCH_CACHE_DIR" ]] || die fetch 'cache directory is empty; use --cache-dir'
    cache="$(canonical_new_path "$FETCH_CACHE_DIR")" || die fetch "cannot canonicalize cache directory: $FETCH_CACHE_DIR"
    entry="$cache/$release-$commit"
    source="$entry/source"
    provenance="$entry/source-provenance.txt"

    if [[ -e "$entry" ]]; then
        [[ -d "$source" && -f "$provenance" ]] || die cache "incomplete cache entry; refusing to replace it: $entry"
        cached_method="$(sed -n 's/^acquisition_method=//p' "$provenance" | head -n1)"
        [[ -n "$cached_method" ]] || cached_method=git-signature
        case "$cached_method" in
            git-signature)
                command -v git >/dev/null 2>&1 || die cache 'git is required to reverify the cached commit'
                fetched="$(git -C "$source" rev-parse --verify HEAD^{commit} 2>/dev/null || true)"
                [[ "$fetched" == "$commit" ]] || die cache "cached Git identity mismatch: expected $commit, got ${fetched:-missing}"
                verify_log="$(mktemp "${TMPDIR:-/tmp}/tads3-signature.XXXXXXXX")"
                if ! git -C "$source" verify-commit --raw "$commit" >"$verify_log" 2>&1 || \
                        ! grep -Eiq "VALIDSIG [[:xdigit:]]*${signing_key}([[:space:]]|$)|GOODSIG ${signing_key}([[:space:]]|$)" "$verify_log"; then
                    sed -n '1,30p' "$verify_log" >&2; rm -f -- "$verify_log"
                    die cache 'cached commit signature verification failed'; return 1
                fi
                rm -f -- "$verify_log"
                ;;
            freebsd-ports-sha256)
                archive_file="$entry/$archive_name"
                [[ -f "$archive_file" ]] || die cache 'checksum-verified cache entry is missing its verified archive'
                actual="$(sha256sum "$archive_file" | awk '{print $1}')"
                [[ "$actual" == "$archive_sha256" ]] || die cache "cached archive checksum mismatch: expected $archive_sha256, got $actual"
                [[ "$(wc -c < "$archive_file" | tr -d '[:space:]')" == "$archive_size" ]] || die cache 'cached archive size does not match FreeBSD distinfo'
                ;;
            *) die cache "unknown acquisition method in provenance: $cached_method"; return 1 ;;
        esac
        recognize_source "$source"
        grep -Fxq "commit=$commit" "$provenance" || die cache 'cached provenance has the wrong commit'
        grep -Fxq 'source_tree_sha256_origin=locally_calculated' "$provenance" || die cache 'cached provenance does not label its tree hash origin'
        verify_provenance "$provenance" "$source"
        printf 'fetch=cache-reuse\nacquisition_method=%s\nsource=%s\nprovenance=%s\nrelease=%s\ncommit=%s\n' "$cached_method" "$source" "$provenance" "$release" "$commit"
        return 0
    fi

    ((DOWNLOAD_AUTHORIZED == 1)) || die authorization 'downloading requires --authorize-download after explicit user approval'
    mkdir -p -- "$cache"
    [[ -w "$cache" && -x "$cache" ]] || die cache "cache directory is not writable: $cache"
    stage="$(mktemp -d "$cache/.fetch.XXXXXXXX")"
    FETCH_TEMP_DIR="$stage"

    method="$FETCH_METHOD"
    if [[ "$method" == auto || "$method" == git ]]; then
        if command -v git >/dev/null 2>&1 && git init -q "$stage/source" && \
                git -C "$stage/source" remote add origin "$repository" && \
                git -C "$stage/source" fetch --quiet --no-tags --depth=1 origin "$commit"; then
            fetched="$(git -C "$stage/source" rev-parse --verify FETCH_HEAD^{commit} 2>/dev/null || true)"
            [[ "$fetched" == "$commit" ]] || { rm -rf -- "$stage"; die integrity "fetched commit mismatch: expected $commit, got ${fetched:-missing}"; return 1; }
            verify_log="$stage/verify.log"
            if git -C "$stage/source" verify-commit --raw "$commit" >"$verify_log" 2>&1 && \
                    grep -Eiq "VALIDSIG [[:xdigit:]]*${signing_key}([[:space:]]|$)|GOODSIG ${signing_key}([[:space:]]|$)" "$verify_log"; then
                rm -f -- "$verify_log"
                git -C "$stage/source" checkout --quiet --detach "$commit"
                method=git-signature
            elif [[ "$FETCH_METHOD" == git ]]; then
                sed -n '1,30p' "$verify_log" >&2; rm -rf -- "$stage"
                die signature 'pinned commit signature could not be verified with the expected upstream key'; return 1
            else
                printf 'NOTICE: Git signature verification unavailable; trying the pinned FreeBSD-checksummed archive.\n' >&2
                rm -rf -- "$stage/source" "$verify_log"
                method=archive
            fi
        elif [[ "$FETCH_METHOD" == git ]]; then
            rm -rf -- "$stage"; die download "failed to fetch pinned commit $commit from $repository"; return 1
        else
            printf 'NOTICE: Git acquisition unavailable; trying the pinned FreeBSD-checksummed archive.\n' >&2
            rm -rf -- "$stage/source"
            method=archive
        fi
    fi

    if [[ "$method" == archive ]]; then
        command -v curl >/dev/null 2>&1 || { rm -rf -- "$stage"; die fetch 'curl is required for archive acquisition'; return 1; }
        command -v tar >/dev/null 2>&1 || { rm -rf -- "$stage"; die fetch 'tar is required for archive acquisition'; return 1; }
        archive_file="$stage/$archive_name"
        if ! curl --fail --location --proto '=https' --tlsv1.2 --output "$archive_file" "$archive_url"; then
            rm -rf -- "$stage"; die download "failed to download pinned archive: $archive_url"; return 1
        fi
        [[ "$(wc -c < "$archive_file" | tr -d '[:space:]')" == "$archive_size" ]] || { rm -rf -- "$stage"; die integrity 'archive is incomplete or has an unexpected size'; return 1; }
        actual="$(sha256sum "$archive_file" | awk '{print $1}')"
        [[ "$actual" == "$archive_sha256" ]] || { rm -rf -- "$stage"; die integrity "archive checksum mismatch: expected $archive_sha256, got $actual"; return 1; }
        listing="$stage/archive.list"
        tar -tzf "$archive_file" > "$listing" 2>/dev/null || { rm -rf -- "$stage"; die archive 'verified bytes are not a readable gzip tar archive'; return 1; }
        [[ -s "$listing" ]] || { rm -rf -- "$stage"; die archive 'archive contains no entries'; return 1; }
        awk '$0 != "frobtads-2.0" && $0 !~ /^frobtads-2[.]0\// { exit 1 } /(^|\/)\.\.?(\/|$)|\/\// { exit 1 }' "$listing" || { rm -rf -- "$stage"; die archive 'archive contains an unsafe or unexpected path'; return 1; }
        if tar -tvzf "$archive_file" 2>/dev/null | awk 'substr($1,1,1) !~ /^[-d]$/ { bad=1 } END { exit bad }'; then :; else
            rm -rf -- "$stage"; die archive 'archive contains links or special files'; return 1
        fi
        mkdir "$stage/extracted"
        tar -xzf "$archive_file" -C "$stage/extracted" || { rm -rf -- "$stage"; die archive 'archive extraction failed'; return 1; }
        [[ -d "$stage/extracted/frobtads-2.0" ]] || { rm -rf -- "$stage"; die archive 'expected frobtads-2.0 archive root is missing'; return 1; }
        mv -- "$stage/extracted/frobtads-2.0" "$stage/source"
        rmdir "$stage/extracted"
        rm -f -- "$listing"
        method=freebsd-ports-sha256
    fi

    recognize_source "$stage/source"
    actual="$(tree_sha256 "$stage/source")"
    [[ "$actual" =~ ^[[:xdigit:]]{64}$ ]] || { rm -rf -- "$stage"; die integrity 'could not calculate source tree SHA-256'; return 1; }
    {
        printf 'source_repository=https://github.com/realnc/frobtads\n'
        printf 'source_url=%s\nrelease=%s\ncommit=%s\n' "$([[ "$method" == git-signature ]] && printf '%s' "$repository" || printf '%s' "$archive_url")" "$release" "$commit"
        printf 'retrieved_utc=%s\nacquisition_method=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$method"
        if [[ "$method" == git-signature ]]; then
            printf 'verification_method=git object identity plus cryptographically verified upstream commit signature\n'
            printf 'commit_signature_key=%s\ncommit_verification_origin=independently_published_upstream_signature\n' "$signing_key"
            printf 'archive_sha256=\narchive_sha256_origin=not_applicable_git_fetch\n'
        else
            printf 'verification_method=exact GitHub codeload archive SHA-256 verified against official FreeBSD ports distinfo\n'
            printf 'commit_verification_origin=pinned_release_metadata; commit signature not locally verified\n'
            printf 'archive_filename=%s\narchive_size=%s\narchive_sha256=%s\n' "$archive_name" "$archive_size" "$archive_sha256"
            printf 'archive_sha256_origin=independently_published_by_freebsd_ports\narchive_sha256_source=%s\n' "$checksum_source"
        fi
        printf 'source_tree_sha256=%s\nsource_tree_sha256_origin=locally_calculated\n' "$actual"
    } > "$stage/source-provenance.txt"
    [[ ! -e "$entry" ]] || { rm -rf -- "$stage"; die cache "cache entry appeared during fetch; refusing to overwrite: $entry"; return 1; }
    mv -- "$stage" "$entry"
    FETCH_TEMP_DIR=""
    printf 'fetch=downloaded-and-verified\nacquisition_method=%s\nsource=%s\nprovenance=%s\nrelease=%s\ncommit=%s\n' "$method" "$source" "$provenance" "$release" "$commit"
}

validate_destination() {
    local prefix="$1" allowed="$2" owner mode
    [[ "$prefix" == /* && "$allowed" == /* ]] || die destination 'prefix and allowed root must be absolute paths'
    prefix="$(canonical_new_path "$prefix")" || die destination 'cannot canonicalize installation prefix'
    allowed="$(canonical_existing "$allowed")" || die destination 'allowed root must already exist'
    case "$prefix" in /|/bin|/boot|/dev|/etc|/lib|/lib64|/opt|/proc|/root|/run|/sbin|/srv|/sys|/usr|/usr/local|/var) die destination "dangerous installation prefix: $prefix" ;; esac
    case "$prefix/" in "$allowed"/*) ;; *) die destination "prefix is outside authorized root $allowed: $prefix" ;; esac
    [[ "$prefix" != "$allowed" ]] || die destination 'prefix must be a new child of the allowed root'
    [[ ! -e "$prefix" ]] || die collision "installation prefix already exists; choose a new versioned prefix: $prefix"
    owner="$(stat -c %u "$allowed" 2>/dev/null || stat -f %u "$allowed")"
    [[ "$owner" == "$(id -u)" ]] || die destination "authorized root is not owned by the current user: $allowed"
    [[ -w "$allowed" && -x "$allowed" ]] || die destination "authorized root is not writable/searchable: $allowed"
    mode="$(stat -c %A "$allowed" 2>/dev/null || true)"
    printf 'validated_prefix=%s\nvalidated_allowed_root=%s\nallowed_root_mode=%s\n' "$prefix" "$allowed" "$mode"
}

probe_destination_writable() {
    local allowed="$1"
    WRITE_PROBE="$(umask 077; mktemp "$allowed/.tads3-write-probe.XXXXXXXX")" || \
        die destination "cannot securely create a write probe under authorized root: $allowed"
    rm -f -- "$WRITE_PROBE"
    WRITE_PROBE=""
}

verify_authorization() {
    local file="$1" source="$2" prefix="$3" approved_source approved_prefix
    [[ -f "$file" ]] || die authorization 'execution requires --authorization-record created after explicit user approval'
    grep -Fxq 'user_approved=yes' "$file" || die authorization 'authorization record does not contain user_approved=yes'
    approved_source="$(sed -n 's/^source=//p' "$file" | head -n1)"
    approved_prefix="$(sed -n 's/^prefix=//p' "$file" | head -n1)"
    [[ "$approved_source" == "$source" && "$approved_prefix" == "$prefix" ]] || die authorization 'approved source/prefix do not match this request'
}

install_toolchain() {
    printf '%s\n' \
        'network_download=never performed by install; use the separate authorized fetch operation' \
        'privileged_actions=never performed by this script' \
        'source_policy=use an already acquired, verified upstream source tree'
    dependency_plan
    if [[ -z "$SOURCE_DIR" || -z "$INSTALL_PREFIX" || -z "$ALLOWED_ROOT" ]]; then
        printf '%s\n' \
            'plan=provide --source DIR --prefix DIR --allowed-root DIR' \
            'execution=not requested'
        return 0
    fi
    local source prefix allowed
    source="$(canonical_existing "$SOURCE_DIR")" || die source "source directory does not exist: $SOURCE_DIR"
    prefix="$(canonical_new_path "$INSTALL_PREFIX")" || die destination "cannot canonicalize prefix: $INSTALL_PREFIX"
    allowed="$(canonical_existing "$ALLOWED_ROOT")" || die destination "allowed root does not exist: $ALLOWED_ROOT"
    recognize_source "$source"
    validate_destination "$prefix" "$allowed"
    printf 'source=%s\nprefix=%s\nplanned_commands=cmake configure, build, install, then validate selected installed components\n' "$source" "$prefix"
    if ((EXECUTE == 0)); then
        printf 'execution=not requested; --execute also requires provenance and a prior authorization record\n'
        return 0
    fi
    verify_provenance "$PROVENANCE_FILE" "$source"
    verify_authorization "$AUTHORIZATION_RECORD" "$source" "$prefix"
    command -v cmake >/dev/null 2>&1 || die dependencies 'cmake is missing'
    probe_destination_writable "$allowed"
    TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tads3-skill.XXXXXXXX")"
    cmake -S "$source" -B "$TEMP_DIR/build" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$prefix"
    cmake --build "$TEMP_DIR/build"
    cmake --install "$TEMP_DIR/build"
    [[ -x "$prefix/bin/t3make" && -x "$prefix/bin/frob" ]] || die post-install 'installed compiler or interpreter is missing'
    [[ -f "$prefix/share/frobtads/tads3/lib/adv3/adv3.tl" ]] || die post-install 'installed adv3 library is missing'
    cp -- "$PROVENANCE_FILE" "$prefix/source-provenance.txt"
    T3MAKE="$prefix/bin/t3make" FROB="$prefix/bin/frob" TADS3_HOME="$prefix/share/frobtads/tads3" "$0" validate
    printf 'installation=complete\nprefix=%s\npath_instruction=export PATH=%s/bin:$PATH\ntads3_home_instruction=export TADS3_HOME=%s/share/frobtads/tads3\n' "$prefix" "$prefix" "$prefix"
}

case "$MODE" in
    check) check_environment ;;
    validate) validate_environment ;;
    repair) repair_environment ;;
    plan) check_environment ;;
    fetch) fetch_source ;;
    verify-source)
        [[ -n "$SOURCE_DIR" ]] || die arguments 'verify-source requires --source DIR'
        [[ -n "$PROVENANCE_FILE" ]] || die arguments 'verify-source requires --provenance FILE'
        verified_source="$(canonical_existing "$SOURCE_DIR")" || die source "source directory does not exist: $SOURCE_DIR"
        recognize_source "$verified_source"
        verify_provenance "$PROVENANCE_FILE" "$verified_source"
        printf 'source_verification=pass\nsource=%s\nprovenance=%s\n' "$verified_source" "$PROVENANCE_FILE"
        ;;
    install) install_toolchain ;;
    -h|--help|help) usage ;;
    *) printf 'Unknown mode: %s\n' "$MODE" >&2; usage >&2; exit 2 ;;
esac
