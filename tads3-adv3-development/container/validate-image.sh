#!/usr/bin/env bash
set -euo pipefail

work="$(mktemp -d /tmp/tads3-image-validation.XXXXXXXX)"
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT

home="${TADS3_HOME:?TADS3_HOME is not set}"
cat > "$work/validation.t3m" <<EOF
-pre
-FI "$home/include"
-FL "$home/lib"
-I "$home/lib/adv3"
-I "$home/lib/adv3/en_us"
-DLANGUAGE=en_us
-DMESSAGESTYLE=neu
-Fo "$work/obj"
-Fy "$work/obj"
-o "$work/validation.t3"
-lib system
-lib adv3/adv3
-source /opt/validation-project/game.t
EOF
mkdir -p "$work/obj"
t3make -f "$work/validation.t3m" > "$work/build.log" 2>&1
frob -i plain -p "$work/validation.t3" \
    < /opt/validation-project/smoke.txt > "$work/transcript.log" 2>&1
tr '\n' ' ' < "$work/transcript.log" > "$work/transcript.normalized.log"
grep -Fq '[VALIDATION score=5]' "$work/transcript.normalized.log"
grep -Fq '[VALIDATION conversation=aligned]' "$work/transcript.normalized.log"
! grep -Eiq 'runtime error|fatal error|segmentation fault|stack trace' "$work/transcript.log"
frob --version > "$work/frob-version.log" 2>&1
grep -F 'FrobTADS 2.0' "$work/frob-version.log"
grep -m1 'TADS Compiler 3.1.3' "$work/build.log"
printf 'image_validation=pass\n'
