#!/usr/bin/env bash
# Validate packaged zip / staging directory structure (post-build smoke test).
set -euo pipefail

source "$(dirname "$0")/common.sh"
require_profile

ROOT="${ROOT_DIR}/dist/${PROFILE}"
ZIP="$(find "$ROOT" -maxdepth 1 -name "libmpv-*-${PROFILE}.zip" -type f | head -n 1 || true)"
DIR="$(find "$ROOT" -maxdepth 1 -type d -name "libmpv-*-${PROFILE}" | head -n 1 || true)"

if [[ -n "$ZIP" ]]; then
    echo "Validating archive: $ZIP"
    if command -v unzip >/dev/null 2>&1; then
        unzip -l "$ZIP" | grep -q 'libmpv-2.dll' || { echo "missing libmpv-2.dll in zip"; exit 1; }
        unzip -l "$ZIP" | grep -q 'include/mpv/client.h' || { echo "missing client.h in zip"; exit 1; }
        unzip -l "$ZIP" | grep -q 'BUILD_INFO.json' || { echo "missing BUILD_INFO.json in zip"; exit 1; }
    fi
elif [[ -n "$DIR" ]]; then
    echo "Validating directory: $DIR"
    [[ -f "${DIR}/bin/libmpv-2.dll" ]] || { echo "missing libmpv-2.dll"; exit 1; }
    [[ -f "${DIR}/include/mpv/client.h" ]] || { echo "missing client.h"; exit 1; }
    [[ -f "${DIR}/BUILD_INFO.json" ]] || { echo "missing BUILD_INFO.json"; exit 1; }
    dll_count="$(find "${DIR}/bin" -maxdepth 1 -iname '*.dll' | wc -l | tr -d ' ')"
    if (( dll_count < 2 )); then
        echo "expected multiple runtime DLLs, found ${dll_count}" >&2
        exit 1
    fi
else
    echo "No package found under ${ROOT} for profile ${PROFILE}" >&2
    exit 1
fi

profile_in_info=""
if [[ -n "$DIR" && -f "${DIR}/BUILD_INFO.json" ]]; then
    profile_in_info="$(jq -r '.license_profile' "${DIR}/BUILD_INFO.json")"
elif [[ -n "$ZIP" ]] && command -v unzip >/dev/null 2>&1; then
    profile_in_info="$(unzip -p "$ZIP" "*/BUILD_INFO.json" | jq -r '.license_profile')"
fi

if [[ "$profile_in_info" != "$PROFILE" ]]; then
    echo "BUILD_INFO license_profile mismatch: ${profile_in_info} != ${PROFILE}" >&2
    exit 1
fi

echo "Package validation passed for profile: ${PROFILE}"
