#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config

STAGE="$(stage_dir)"
OUT_DIR="${ROOT_DIR}/dist/${PROFILE}"
PACKAGE_ROOT="${OUT_DIR}/libmpv-$(mpv_version)-windows-x86_64-${PROFILE}"
ZIP_NAME="${OUT_DIR}/libmpv-$(mpv_version)-windows-x86_64-${PROFILE}.zip"

if [[ ! -f "${STAGE}/bin/libmpv-2.dll" ]]; then
    echo "ERROR: staging libmpv-2.dll missing" >&2
    exit 1
fi

rm -rf "$PACKAGE_ROOT"
mkdir -p "${PACKAGE_ROOT}/bin" "${PACKAGE_ROOT}/lib" "${PACKAGE_ROOT}/include" "${PACKAGE_ROOT}/LICENSE"

cp -f "${STAGE}/bin/"*.dll "${PACKAGE_ROOT}/bin/" 2>/dev/null || true
cp -f "${STAGE}/lib/"* "${PACKAGE_ROOT}/lib/" 2>/dev/null || true

if [[ -d "${STAGE}/include/mpv" ]]; then
    mkdir -p "${PACKAGE_ROOT}/include/mpv"
    cp -f "${STAGE}/include/mpv/"*.h "${PACKAGE_ROOT}/include/mpv/"
fi

# Generate MSVC import library when tools are available
if [[ -f "${PACKAGE_ROOT}/bin/libmpv-2.dll" ]]; then
    if command -v gendef >/dev/null 2>&1; then
        (
            cd "${PACKAGE_ROOT}/bin"
            gendef libmpv-2.dll >/dev/null 2>&1 || true
            if [[ -f libmpv-2.def ]]; then
                if command -v llvm-lib >/dev/null 2>&1; then
                    llvm-lib /def:libmpv-2.def /name:libmpv-2.dll /out:"${PACKAGE_ROOT}/lib/mpv.lib" /machine:x64
                elif command -v lib >/dev/null 2>&1; then
                    lib /def:libmpv-2.def /name:libmpv-2.dll /out:"${PACKAGE_ROOT}/lib/mpv.lib" /machine:x64
                fi
            fi
        )
    fi
fi

# License files
MPV_DIR="$(mpv_source_dir)"
if [[ -f "${MPV_DIR}/Copyright" ]]; then
    cp -f "${MPV_DIR}/Copyright" "${PACKAGE_ROOT}/LICENSE/mpv-LICENSE.txt"
fi

cat > "${PACKAGE_ROOT}/LICENSE/THIRD-PARTY-NOTICES.txt" <<EOF
lib_mpv Windows x86_64 ${PROFILE} build

This package bundles libmpv and runtime dependencies built for profile: ${PROFILE}

$(if [[ "$PROFILE" == "gpl" ]]; then
    echo "License: GPLv2 or later (mpv and several bundled components)."
    echo "Suitable for open-source projects that comply with GPL."
else
    echo "License: LGPLv2.1 or later (mpv with -Dgpl=false, LGPL ffmpeg from source)."
    echo "Suitable for proprietary applications that comply with LGPL linking requirements."
fi)

See individual upstream projects for full license texts.
EOF

if [[ "$PROFILE" == "lgpl" ]]; then
    cat >> "${PACKAGE_ROOT}/LICENSE/THIRD-PARTY-NOTICES.txt" <<EOF

FFmpeg was built from source with --disable-gpl --disable-nonfree.
EOF
else
    cat >> "${PACKAGE_ROOT}/LICENSE/THIRD-PARTY-NOTICES.txt" <<EOF

FFmpeg is provided via MSYS2 packages (GPL configuration).
EOF
fi

# BUILD_INFO.json
MPV_COMMIT="$(git -C "${MPV_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
MPV_TAG="$(json_get "$(source_config_path mpv)" '.ref')"
FFMPEG_SOURCE="$(json_get "$CONFIG" '.ffmpeg_source')"

ENABLED_FEATURES="$(jq -c '[.features | to_entries[] | select(.value == "enabled") | .key]' "$CONFIG")"
DISABLED_GPL="$(jq -c '.disabled_gpl_features // []' "$CONFIG")"

cat > "${PACKAGE_ROOT}/BUILD_INFO.json" <<EOF
{
  "license_profile": "${PROFILE}",
  "mpv_version": "$(mpv_version)",
  "mpv_tag": "${MPV_TAG}",
  "mpv_commit": "${MPV_COMMIT}",
  "platform": "windows-x86_64",
  "msys_env": "$(json_get "$VERSIONS" '.msys_env')",
  "ffmpeg_source": "${FFMPEG_SOURCE}",
  "enabled_features": ${ENABLED_FEATURES},
  "disabled_gpl_features": ${DISABLED_GPL},
  "build_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

if [[ -f "${STAGE}/MANIFEST.json" ]]; then
    cp -f "${STAGE}/MANIFEST.json" "${PACKAGE_ROOT}/MANIFEST.json"
fi

cat > "${PACKAGE_ROOT}/README.txt" <<EOF
libmpv SDK — Windows x86_64 — ${PROFILE^^} profile
===================================================

Version: $(mpv_version)
Profile: ${PROFILE}

Layout:
  bin/     libmpv-2.dll and runtime dependencies
  include/ mpv client headers (client.h is ISC-licensed)
  lib/     libmpv.dll.a (MinGW) and mpv.lib (MSVC import lib, if generated)

MinGW link example:
  gcc app.c -Iinclude -Llib -lmpv.dll

MSVC link example:
  cl app.c /Iinclude mpv.lib

$(if [[ "$PROFILE" == "lgpl" ]]; then
    echo "LGPL profile: for use in proprietary software subject to LGPL compliance."
else
    echo "GPL profile: entire combined work must comply with GPLv2+ if you distribute it."
fi)
EOF

mkdir -p "$OUT_DIR"
rm -f "$ZIP_NAME"
if command -v zip >/dev/null 2>&1; then
    (cd "$OUT_DIR" && zip -r "$(basename "$ZIP_NAME")" "$(basename "$PACKAGE_ROOT")")
elif command -v 7z >/dev/null 2>&1; then
    7z a -tzip "$ZIP_NAME" "$PACKAGE_ROOT"
else
    echo "WARNING: zip/7z not found; leaving unpacked tree at ${PACKAGE_ROOT}" >&2
fi

echo "Package ready: ${PACKAGE_ROOT}"
[[ -f "$ZIP_NAME" ]] && echo "Archive: ${ZIP_NAME}"
