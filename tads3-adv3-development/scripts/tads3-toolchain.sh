#!/usr/bin/env bash

set -euo pipefail

MODE="${1:-check}"
shift || true

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$SKILL_ROOT/assets/examples/validation-project/game.t"
T3MAKE_CMD="${T3MAKE:-}"
FROB_CMD="${FROB:-}"
SOURCE_DIR=""
INSTALL_PREFIX=""
EXECUTE=0

usage() {
    printf '%s\n' \
        'Usage: tads3-toolchain.sh check|validate|repair|install [options]' \
        '' \
        'Options for install:' \
        '  --source DIR    verified unpacked FrobTADS source directory' \
        '  --prefix DIR    new user-owned installation prefix' \
        '  --execute       perform the source build (requires explicit approval)' \
        '' \
        'Environment overrides:' \
        '  T3MAKE FROB TADS3_HOME TADS3_INCLUDE TADS3_LIB TADS3_DOC TADS3_SAMPLES'
}

while (($#)); do
    case "$1" in
        --source) SOURCE_DIR="${2:?missing value for --source}"; shift 2 ;;
        --prefix) INSTALL_PREFIX="${2:?missing value for --prefix}"; shift 2 ;;
        --execute) EXECUTE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

find_command() {
    local configured="$1" fallback="$2"
    if [[ -n "$configured" && -x "$configured" ]]; then
        printf '%s\n' "$configured"
    elif [[ -n "$configured" ]] && command -v "$configured" >/dev/null 2>&1; then
        command -v "$configured"
    elif command -v "$fallback" >/dev/null 2>&1; then
        command -v "$fallback"
    fi
}

detect_os() {
    local os_name kernel arch
    kernel="$(uname -s 2>/dev/null || printf unknown)"
    arch="$(uname -m 2>/dev/null || printf unknown)"
    os_name="$kernel"
    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_name="${PRETTY_NAME:-${NAME:-$kernel}}"
    fi
    printf 'os=%s\nkernel=%s\narchitecture=%s\n' "$os_name" "$kernel" "$arch"
}

candidate_homes() {
    local user_home="${HOME:-}"
    [[ -n "${TADS3_HOME:-}" ]] && printf '%s\n' "$TADS3_HOME"
    [[ -n "$user_home" ]] && printf '%s\n' "$user_home/.local/share/frobtads/tads3"
    printf '%s\n' /usr/local/share/frobtads/tads3 /usr/share/frobtads/tads3
    if [[ -n "$T3MAKE_CMD" ]]; then
        local bin_dir prefix
        bin_dir="$(cd "$(dirname "$T3MAKE_CMD")" && pwd)"
        prefix="$(cd "$bin_dir/.." && pwd)"
        printf '%s\n' "$prefix/share/frobtads/tads3"
    fi
}

detect_layout() {
    T3MAKE_CMD="$(find_command "$T3MAKE_CMD" t3make || true)"
    FROB_CMD="$(find_command "$FROB_CMD" frob || true)"

    TADS_INCLUDE_DIR="${TADS3_INCLUDE:-}"
    TADS_LIB_DIR="${TADS3_LIB:-}"
    TADS_DOC_DIR="${TADS3_DOC:-}"
    TADS_SAMPLES_DIR="${TADS3_SAMPLES:-}"

    local home
    while IFS= read -r home; do
        [[ -d "$home" ]] || continue
        [[ -n "$TADS_INCLUDE_DIR" ]] || [[ ! -f "$home/include/tads.h" ]] || TADS_INCLUDE_DIR="$home/include"
        [[ -n "$TADS_LIB_DIR" ]] || [[ ! -f "$home/lib/adv3/adv3.tl" ]] || TADS_LIB_DIR="$home/lib"
        [[ -n "$TADS_DOC_DIR" ]] || [[ ! -d "$home/doc" ]] || TADS_DOC_DIR="$home/doc"
        [[ -n "$TADS_SAMPLES_DIR" ]] || [[ ! -d "$home/lib/samples" ]] || TADS_SAMPLES_DIR="$home/lib/samples"
    done < <(candidate_homes | awk '!seen[$0]++')
}

print_version() {
    local label="$1" cmd="$2"
    if [[ -n "$cmd" ]]; then
        printf '%s=%s\n' "$label" "$cmd"
        if [[ "$label" == t3make ]]; then
            printf '%s\n' 't3make_version_query=not exposed by this command-line build; validate records its compile banner'
        else
            { "$cmd" --version 2>&1 || true; } | sed -n '1,3p'
        fi
    else
        printf '%s=missing\n' "$label"
    fi
}

check_environment() {
    detect_layout
    detect_os
    print_version t3make "$T3MAKE_CMD"
    print_version frob "$FROB_CMD"
    printf 'tads3_include=%s\n' "${TADS_INCLUDE_DIR:-missing}"
    printf 'tads3_library=%s\n' "${TADS_LIB_DIR:-missing}"
    printf 'adv3=%s\n' "$([[ -n "${TADS_LIB_DIR:-}" && -f "$TADS_LIB_DIR/adv3/adv3.tl" ]] && printf present || printf missing)"
    printf 'documentation=%s\n' "${TADS_DOC_DIR:-missing}"
    printf 'samples=%s\n' "${TADS_SAMPLES_DIR:-missing}"
    for tool in bash cmake make cc c++; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf 'build_tool_%s=%s\n' "$tool" "$(command -v "$tool")"
        else
            printf 'build_tool_%s=missing\n' "$tool"
        fi
    done
}

require_layout() {
    detect_layout
    [[ -n "$T3MAKE_CMD" ]] || { printf 'ERROR: t3make not found. Set T3MAKE or PATH.\n' >&2; return 1; }
    [[ -n "$FROB_CMD" ]] || { printf 'ERROR: FrobTADS interpreter not found. Set FROB or PATH.\n' >&2; return 1; }
    [[ -n "$TADS_INCLUDE_DIR" && -f "$TADS_INCLUDE_DIR/tads.h" ]] || { printf 'ERROR: TADS 3 headers not found. Set TADS3_INCLUDE or TADS3_HOME.\n' >&2; return 1; }
    [[ -n "$TADS_LIB_DIR" && -f "$TADS_LIB_DIR/adv3/adv3.tl" ]] || { printf 'ERROR: standard adv3 library not found. Set TADS3_LIB or TADS3_HOME.\n' >&2; return 1; }
}

write_manifest() {
    local file="$1" image="$2" objdir="$3"
    {
        printf '%s\n' '-pre'
        printf '%s %s\n' '-FI' "$TADS_INCLUDE_DIR"
        printf '%s %s\n' '-FL' "$TADS_LIB_DIR"
        printf '%s %s\n' '-I' "$TADS_LIB_DIR/adv3"
        printf '%s %s\n' '-I' "$TADS_LIB_DIR/adv3/en_us"
        printf '%s\n' '-DLANGUAGE=en_us' '-DMESSAGESTYLE=neu'
        printf '%s %s\n' '-Fo' "$objdir" '-Fy' "$objdir" '-o' "$image"
        printf '%s\n' '-lib system' '-lib adv3/adv3'
        printf '%s %s\n' '-source' "$FIXTURE"
    } > "$file"
}

validate_environment() {
    require_layout
    local tmp_dir release_manifest debug_manifest release_image debug_image transcript release_out debug_out
    tmp_dir="$(mktemp -d)"
    trap "rm -rf '$tmp_dir'" EXIT
    mkdir -p "$tmp_dir/release-obj" "$tmp_dir/debug-obj"
    release_manifest="$tmp_dir/release.t3m"
    debug_manifest="$tmp_dir/debug.t3m"
    release_image="$tmp_dir/release.t3"
    debug_image="$tmp_dir/debug.t3"
    transcript="$SKILL_ROOT/assets/examples/validation-project/smoke.txt"
    release_out="$tmp_dir/release.out"
    debug_out="$tmp_dir/debug.out"

    write_manifest "$release_manifest" "$release_image" "$tmp_dir/release-obj"
    write_manifest "$debug_manifest" "$debug_image" "$tmp_dir/debug-obj"

    "$T3MAKE_CMD" -f "$release_manifest" >"$tmp_dir/release-build.log" 2>&1 || {
        printf 'ERROR: release compilation failed.\n' >&2
        sed -n '1,40p' "$tmp_dir/release-build.log" >&2
        return 1
    }
    "$T3MAKE_CMD" -d -f "$debug_manifest" >"$tmp_dir/debug-build.log" 2>&1 || {
        printf 'ERROR: debug compilation failed.\n' >&2
        sed -n '1,40p' "$tmp_dir/debug-build.log" >&2
        return 1
    }

    "$FROB_CMD" -i plain -p "$release_image" < "$transcript" > "$release_out"
    "$FROB_CMD" -i plain -p "$debug_image" < "$transcript" > "$debug_out"

    grep -Fq 'Standard adv3 validation fixture.' "$debug_out"
    grep -Fq 'You align the demonstration device.' "$debug_out"
    grep -Fq 'The caretaker says the reading is now correct.' "$debug_out"
    grep -Fq 'A quiet mechanism clicks once.' "$debug_out"
    grep -Fq '5 points' "$debug_out"
    grep -Fq 'DEBUG STATUS:' "$debug_out"
    if grep -Fq 'DEBUG STATUS:' "$release_out"; then
        printf 'ERROR: debug-only command is present in the release image.\n' >&2
        return 1
    fi

    printf 'validation=pass\nrelease_build=pass\ndebug_build=pass\ntranscript_smoke=pass\ndebug_guard=pass\n'
    grep -m1 'TADS Compiler' "$tmp_dir/release-build.log" || true
}

repair_environment() {
    set +e
    check_environment
    local status=0
    require_layout || status=$?
    set -e
    if ((status == 0)); then
        printf '%s\n' \
            'repair_assessment=layout appears complete' \
            'next_action=run validate; inspect project-specific paths if its build still fails'
    else
        printf '%s\n' \
            'repair_assessment=toolchain is incomplete' \
            'next_action=set explicit T3MAKE/FROB/TADS3_* paths or review references/toolchain-provisioning.md' \
            'safety=no files were changed'
    fi
}

install_toolchain() {
    printf '%s\n' \
        'Install mode never downloads sources or installs system packages.' \
        'Review references/toolchain-provisioning.md and obtain a verified upstream source tree.'
    if [[ -z "$SOURCE_DIR" || -z "$INSTALL_PREFIX" ]]; then
        printf '%s\n' \
            'plan=provide --source DIR and --prefix DIR' \
            'execution=not requested'
        return 0
    fi
    [[ -f "$SOURCE_DIR/CMakeLists.txt" ]] || { printf 'ERROR: source directory has no CMakeLists.txt.\n' >&2; return 1; }
    case "$INSTALL_PREFIX" in
        /|/usr|/usr/local|/opt) printf 'ERROR: choose a new, user-owned, versioned prefix.\n' >&2; return 1 ;;
    esac
    if [[ -e "$INSTALL_PREFIX/bin/t3make" || -e "$INSTALL_PREFIX/bin/frob" ]]; then
        printf 'ERROR: refusing to overwrite an existing toolchain in %s.\n' "$INSTALL_PREFIX" >&2
        return 1
    fi
    printf 'source=%s\nprefix=%s\n' "$SOURCE_DIR" "$INSTALL_PREFIX"
    printf 'planned_commands=cmake configure, build, install into the new prefix\n'
    if ((EXECUTE == 0)); then
        printf 'execution=not requested; rerun with --execute only after explicit authorization\n'
        return 0
    fi
    command -v cmake >/dev/null 2>&1 || { printf 'ERROR: cmake is missing.\n' >&2; return 1; }
    local build_dir
    build_dir="$(mktemp -d)"
    trap "rm -rf '$build_dir'" EXIT
    cmake -S "$SOURCE_DIR" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX"
    cmake --build "$build_dir"
    cmake --install "$build_dir"
    printf 'installation=complete\nprefix=%s\n' "$INSTALL_PREFIX"
}

case "$MODE" in
    check) check_environment ;;
    validate) validate_environment ;;
    repair) repair_environment ;;
    install) install_toolchain ;;
    -h|--help|help) usage ;;
    *) printf 'Unknown mode: %s\n' "$MODE" >&2; usage >&2; exit 2 ;;
esac
