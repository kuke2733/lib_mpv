#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config
ensure_tools

"${ROOT_DIR}/scripts/fetch-sources.sh" ffmpeg

export FFMPEG_LGPL_PREFIX="${FFMPEG_LGPL_PREFIX:-${ROOT_DIR}/.cache/ffmpeg-lgpl-prefix}"
SRC_DIR="$(ffmpeg_source_dir)"
BUILD_DIR="${ROOT_DIR}/.cache/ffmpeg-build-lgpl"

if [[ -f "${FFMPEG_LGPL_PREFIX}/lib/pkgconfig/libavcodec.pc" ]]; then
    echo "LGPL ffmpeg already installed at ${FFMPEG_LGPL_PREFIX}"
    export FFMPEG_LGPL_PREFIX
    exit 0
fi

mkdir -p "$FFMPEG_LGPL_PREFIX"

CONFIGURE_FLAGS=()
while IFS= read -r flag; do
    flag="$(strip_cr "$flag")"
    [[ -z "$flag" ]] && continue
    CONFIGURE_FLAGS+=("$flag")
done < <(jq -r '.ffmpeg.configure_flags[]' "$CONFIG")

while IFS= read -r lib; do
    lib="$(strip_cr "$lib")"
    [[ -z "$lib" ]] && continue
    CONFIGURE_FLAGS+=("--disable-${lib}")
done < <(jq -r '.ffmpeg.disable_libs[]' "$CONFIG")

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

export CC="${CC:-clang}"
export CXX="${CXX:-clang++}"
export AR="${AR:-llvm-ar}"
export NM="${NM:-llvm-nm}"
export RANLIB="${RANLIB:-llvm-ranlib}"

echo "::group::Configure ffmpeg (LGPL)"
"${SRC_DIR}/configure" \
    --prefix="$FFMPEG_LGPL_PREFIX" \
    --arch=x86_64 \
    --target-os=mingw32 \
    --cc=clang \
    --cxx=clang++ \
    --pkg-config=pkg-config \
    --extra-cflags="-O2" \
    "${CONFIGURE_FLAGS[@]}"
echo "::endgroup::"

echo "::group::Build ffmpeg (LGPL)"
make -j"$(nproc 2>/dev/null || echo 4)"
make install
echo "::endgroup::"

export FFMPEG_LGPL_PREFIX
echo "LGPL ffmpeg installed to ${FFMPEG_LGPL_PREFIX}"
