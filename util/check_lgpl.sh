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
# decoders do contain "x264 - core" and "XviD", so those are not usable markers). The last one
# is Little CMS's GPL-3.0 threaded plugin (threaded_split.c, compiled on every platform).
FORBIDDEN_STRINGS=(
    'fftw-3.' '(dft-ct-' 'H.264/MPEG-4 AVC codec - Copy' 'HEVC encoder version'
    'RubberBandStretcher' 'vid.stab' 'too many threads for actual processor'
)
# Little CMS's GPL-3.0 plugins have no string of their own to look for (fast_float), so look for
# their headers: cmsPluginMagicNumber ('acpp', little-endian) followed, 8 bytes on, by a plugin
# type: transform ('zfmH'), formatters ('frmH') or parallelization ('prlH').
LCMS2_PLUGIN='\x70\x70\x63\x61.{4}(?:\x48\x6d\x66\x7a|\x48\x6d\x72\x66|\x48\x6c\x72\x70)'

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
        if perl -0777 -ne "exit(/$LCMS2_PLUGIN/s ? 0 : 1)" "$FILE"; then
            echo "$ZIP: ${FILE##*/} contains a Little CMS plugin header"
            status=1
        fi
    done
    rm -rf "$TMP"
done
exit $status
