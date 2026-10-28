#!/bin/bash

SCRIPT_REPO="https://gitlab.freedesktop.org/freetype/freetype.git"
SCRIPT_COMMIT="d333439633039de426f943f28a2926c7f97b5ae5"

# Notices only in files of its tree that the license files don't hold (util/run_stage.sh copies them).
LICENSE_EXTRA=( src/bdf/README src/pcf/README src/gzip/zlib.h )

ffbuild_enabled() {
    return 0
}

ffbuild_dockerbuild() {
    ./autogen.sh

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --without-harfbuzz
        --disable-shared
        --enable-static
    )

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(
            --host="$FFBUILD_TOOLCHAIN"
        )
    else
        echo "Unknown target"
        return -1
    fi

    ./configure "${myconf[@]}"
    make -j$(nproc)
    make install DESTDIR="$FFBUILD_DESTDIR"
}
