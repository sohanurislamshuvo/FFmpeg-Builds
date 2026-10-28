#!/bin/bash

SCRIPT_REPO="https://github.com/mm2/Little-CMS.git"
SCRIPT_COMMIT="35cef8775e0ab46f0dda0b46aae1e69d27524432"

ffbuild_enabled() {
    (( $(ffbuild_ffver) >= 501 )) || return -1
    return 0
}

ffbuild_dockerbuild() {
    mkdir build && cd build

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        -Ddefault_library=static
        -Dutils=false
    )

    # The fast_float and threaded plugins are GPL-3.0, and lcms2.pc puts them on FFmpeg's link line:
    # an LGPL build must not have them at all.
    if [[ $VARIANT == lgpl* ]]; then
        myconf+=( -Dfastfloat=false -Dthreaded=false )
    else
        myconf+=( -Dfastfloat=true -Dthreaded=true )
    fi

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(
            --cross-file=/cross.meson
        )
    else
        echo "Unknown target"
        return -1
    fi

    export CFLAGS="$CFLAGS -fpermissive"

    meson setup "${myconf[@]}" ..
    ninja -j$(nproc)
    DESTDIR="$FFBUILD_DESTDIR" ninja install
}

ffbuild_configure() {
    echo --enable-lcms2
}

ffbuild_unconfigure() {
    (( $(ffbuild_ffver) >= 501 )) || return 0
    echo --disable-lcms2
}
