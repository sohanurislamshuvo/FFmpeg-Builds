#!/bin/bash
# Writes the corresponding source of an artifact that build.sh built with the same arguments
# into artifacts/: the FFmpeg tree at the commit that was compiled, and every dependency
# source archive the generated Dockerfile mounted, together with scripts.d and patches, which
# hold every change the build makes to those trees.
# Usage (after makeimage.sh and build.sh): util/collect_sources.sh win64 lgpl-shared 8.1 helion
set -xeo pipefail
cd "$(dirname "$0")"/..
source util/vars.sh
source "variants/${TARGET}-${VARIANT}.sh"
for addin in ${ADDINS[*]}; do
    source "addins/${addin}.sh"
done

FFMPEG_REPO="${FFMPEG_REPO:-https://github.com/FFmpeg/FFmpeg.git}"
FFMPEG_REPO="${FFMPEG_REPO_OVERRIDE:-$FFMPEG_REPO}"
GIT_BRANCH="${GIT_BRANCH:-master}"
GIT_BRANCH="${GIT_BRANCH_OVERRIDE:-$GIT_BRANCH}"

mkdir -p artifacts
WORK="$(mktemp -d)"
trap "rm -rf -- '$WORK'" EXIT

git clone --filter=blob:none --branch="$GIT_BRANCH" "$FFMPEG_REPO" "$WORK/ffmpeg"
if [[ -n "$FFMPEG_COMMIT" ]]; then
    git -C "$WORK/ffmpeg" checkout --detach "$FFMPEG_COMMIT"
fi
FFVER="$("$WORK/ffmpeg/ffbuild/version.sh" "$WORK/ffmpeg")"
git -C "$WORK/ffmpeg" archive --format=tar --prefix="ffmpeg-$FFVER/" HEAD | xz -T0 -9 > "artifacts/ffmpeg-$FFVER-source.tar.xz"

NAME="deps-source-${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}.tar"
grep -o '\.cache/downloads/[^ ,]*\.tar\.xz' Dockerfile | sort -u > "$WORK/deps.txt"
tar -cf "$WORK/$NAME" -T "$WORK/deps.txt" scripts.d patches
# A GitHub release asset must be smaller than 2 GiB.
if (( $(stat -c %s "$WORK/$NAME") > 2000000000 )); then
    split -b 1900M -d -a 2 "$WORK/$NAME" "artifacts/$NAME.part"
else
    mv "$WORK/$NAME" artifacts/
fi
