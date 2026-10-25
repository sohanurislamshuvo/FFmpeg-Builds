#!/bin/bash
# Fails when an LGPL artifact was configured with, or contains, GPL-only code.
# Usage: util/check_lgpl.sh artifacts/ffmpeg-*.zip
set -eo pipefail

# --enable-gpl/--enable-nonfree, every library FFmpeg's configure lists as GPL, and the two
# libraries FFmpeg accepts without --enable-gpl although this build links GPL code through them.
FORBIDDEN_FLAGS=(
    --enable-gpl --enable-nonfree --enable-chromaprint --enable-libzvbi
    --enable-avisynth --enable-frei0r --enable-libcdio --enable-libdavs2 --enable-libdvdnav
    --enable-libdvdread --enable-librubberband --enable-libvidstab --enable-libx264
    --enable-libx265 --enable-libxavs --enable-libxavs2 --enable-libxvid --enable-libsmbclient
)
# Strings only GPL libraries put in a binary: FFTW's version and planner names, the x264 and
# x265 banners, Rubber Band and vid.stab. None occurs in a clean LGPL build (FFmpeg's own
# decoders do contain "x264 - core" and "XviD", so those are not usable markers).
FORBIDDEN_STRINGS=(
    'fftw-3.' '(dft-ct-' 'H.264/MPEG-4 AVC codec - Copy' 'HEVC encoder version'
    'RubberBandStretcher' 'vid.stab'
)

status=0
for ZIP in "$@"; do
    TMP="$(mktemp -d)"
    unzip -q "$ZIP" '*/bin/*' -d "$TMP"
    CONF="$(cat "$TMP"/*/bin/* | grep -a -o -m1 -- '--prefix=/ffbuild/prefix[^[:cntrl:]]*' | head -n1 || true)"
    if [[ -z "$CONF" ]]; then
        echo "$ZIP: no configuration string found"
        status=1
    fi
    for FLAG in $(tr ' ' '\n' <<<"$CONF" | grep -x -F -f <(printf '%s\n' "${FORBIDDEN_FLAGS[@]}") || true); do
        echo "$ZIP: configured with $FLAG"
        status=1
    done
    for FILE in "$TMP"/*/bin/*; do
        for S in "${FORBIDDEN_STRINGS[@]}"; do
            if grep -a -q -F -- "$S" "$FILE"; then
                echo "$ZIP: ${FILE##*/} contains '$S'"
                status=1
            fi
        done
    done
    rm -rf "$TMP"
done
exit $status
