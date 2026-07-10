#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config
ensure_tools

"${ROOT_DIR}/scripts/fetch-sources.sh" mpv

MPV_DIR="$(mpv_source_dir)"
BUILD_DIR="$(mpv_build_dir)"
STAGE="$(stage_dir)"

if [[ "$PROFILE" == "lgpl" ]]; then
    "${ROOT_DIR}/scripts/build-ffmpeg-lgpl.sh"
    export PKG_CONFIG_PATH="${FFMPEG_LGPL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export PATH="${FFMPEG_LGPL_PREFIX}/bin:${PATH}"
fi

mkdir -p "$STAGE/bin" "$STAGE/lib" "$STAGE/include"

cd "$MPV_DIR"

mapfile -t MESON_BOOL < <(meson_bool_args "$CONFIG")
mapfile -t MESON_FEATURES < <(meson_feature_args "$CONFIG")

MESON_ARGS=(
    "${MESON_BOOL[@]}"
    "${MESON_FEATURES[@]}"
    -Dsubrandr=disabled
    -Dmanpage-build=disabled
    -Dhtml-build=disabled
    -Dpdf-build=disabled
    --prefix="${MSYSTEM_PREFIX:-/clang64}"
    --wrap-mode=nodownload
)

if [[ "$PROFILE" == "lgpl" ]]; then
    # Prefer LGPL ffmpeg from our prefix over any system GPL ffmpeg pkg-config.
    export PKG_CONFIG_PATH="${FFMPEG_LGPL_PREFIX}/lib/pkgconfig"
fi

echo "::group::Meson setup (PROFILE=${PROFILE})"
meson setup "$BUILD_DIR" "${MESON_ARGS[@]}"
echo "::endgroup::"

echo "::group::Compile libmpv"
meson compile -C "$BUILD_DIR" libmpv-2.dll
echo "::endgroup::"

LIBMPV_DLL="$(find "$BUILD_DIR" -name 'libmpv-2.dll' -type f | head -n 1)"
if [[ -z "$LIBMPV_DLL" ]]; then
    echo "ERROR: libmpv-2.dll not found under $BUILD_DIR" >&2
    exit 1
fi

cp -f "$LIBMPV_DLL" "$STAGE/bin/"

IMPORT_LIB="$(find "$BUILD_DIR" \( -name 'libmpv.dll.a' -o -name 'mpv.lib' \) -type f | head -n 1 || true)"
if [[ -n "$IMPORT_LIB" ]]; then
    cp -f "$IMPORT_LIB" "$STAGE/lib/"
fi

if [[ -d "${MPV_DIR}/include/mpv" ]]; then
    mkdir -p "$STAGE/include/mpv"
    cp -f "${MPV_DIR}/include/mpv/"*.h "$STAGE/include/mpv/"
fi

# Capture enabled features from meson configure for BUILD_INFO.json
meson configure "$BUILD_DIR" > "${STAGE}/meson-configure.txt" 2>&1 || true

echo "Build complete: ${STAGE}/bin/libmpv-2.dll"
