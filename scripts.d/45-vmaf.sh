#!/bin/bash

SCRIPT_REPO="https://github.com/Netflix/vmaf.git"
SCRIPT_COMMIT="86da14d0306a138fd3f01319860b905169746516"

# Notices only in the headers of files it compiles, and mkdirp's MIT text, which mkdirp.c's header
# only refers to: the fork carries it (licenses-extra/vmaf) and the build copies it in.
LICENSE_EXTRA=(
    libvmaf/src/svm.h
    libvmaf/src/feature/iqa/convolve.c
    libvmaf/src/feature/ciede.c
    libvmaf/src/feature/mkdirp.c
    libvmaf/src/feature/third_party/xiph/psnr_hvs.c
    mkdirp.c-LICENSE.txt
)

ffbuild_enabled() {
    return 0
}

ffbuild_dockerstage() {
    local mounts="--mount=src=${SELF},dst=/stage.sh --mount=src=licenses-extra/vmaf,dst=/licenses-extra"
    [[ -n "$SELFCACHE" ]] && mounts+=" --mount=src=${SELFCACHE},dst=/cache.tar.xz"
    to_df "RUN $mounts run_stage /stage.sh"
}

ffbuild_dockerbuild() {
    cp /licenses-extra/mkdirp.c-LICENSE.txt .

    # Kill build of unused and broken tools
    echo > libvmaf/tools/meson.build

    sed -i -E 's/([^.>:_[:alnum:]])swap\(/\1libsvm_swap(/g' libvmaf/src/svm.cpp
    sed -i -E 's/([^.>:_[:alnum:]])min\(/\1libsvm_min(/g' libvmaf/src/svm.cpp
    sed -i -E 's/([^.>:_[:alnum:]])max\(/\1libsvm_max(/g' libvmaf/src/svm.cpp

    mkdir build && cd build

    local myconf=(
        --prefix="$FFBUILD_PREFIX"
        --buildtype=release
        --default-library=static
        -Dbuilt_in_models=true
        -Denable_tests=false
        -Denable_docs=false
        -Denable_float=true
    )

    if [[ $TARGET == *32 ]]; then
        myconf+=(
            -Denable_avx512=false
            -Denable_asm=false
        )
    else
        myconf+=(
            -Denable_avx512=true
            -Denable_asm=true
        )
    fi

    if [[ $TARGET == win* || $TARGET == linux* ]]; then
        myconf+=(
            --cross-file=/cross.meson
        )
    else
        echo "Unknown target"
        return -1
    fi

    meson "${myconf[@]}" ../libvmaf || cat meson-logs/meson-log.txt
    ninja -j"$(nproc)"
    DESTDIR="$FFBUILD_DESTDIR" ninja install

    sed -i 's/Libs.private:/Libs.private: -lstdc++/; t; $ a Libs.private: -lstdc++' "$FFBUILD_DESTPREFIX"/lib/pkgconfig/libvmaf.pc
}

ffbuild_configure() {
    (( $(ffbuild_ffver) >= 501 )) || return 0
    echo --enable-libvmaf
}

ffbuild_unconfigure() {
    echo --disable-libvmaf
}
