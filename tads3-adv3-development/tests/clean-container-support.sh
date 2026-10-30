#!/usr/bin/env bash

# Shared by the clean-container harness and its offline regression tests.

stage_authorization_record() {
    local source="$1" destination="$2" owner="$3" group="$4"
    [[ -f "$source" ]] || { printf 'ERROR: authorization record is missing: %s\n' "$source" >&2; return 1; }
    [[ ! -e "$destination" ]] || { printf 'ERROR: refusing to overwrite staged authorization record: %s\n' "$destination" >&2; return 1; }
    install -o "$owner" -g "$group" -m 600 -- "$source" "$destination" || return 1
    if ! cmp -s -- "$source" "$destination"; then
        rm -f -- "$destination"
        printf 'ERROR: staged authorization record differs from the host record.\n' >&2
        return 1
    fi
}

cleanup_staged_authorization() {
    local staged="$1"
    [[ -n "$staged" ]] || return 0
    rm -f -- "$staged"
}

report_expected_collision() {
    local status="$1" diagnostic="$2"
    if ((status == 0)); then
        printf 'ERROR: duplicate installation unexpectedly succeeded.\n' >&2
        return 1
    fi
    if grep -Fq 'ERROR[collision]' "$diagnostic"; then
        printf 'PASS: duplicate installation correctly rejected\n'
        return 0
    fi
    printf 'ERROR: duplicate installation failed for an unexpected reason; original diagnostic follows:\n' >&2
    sed -n '1,120p' "$diagnostic" >&2
    return 1
}
