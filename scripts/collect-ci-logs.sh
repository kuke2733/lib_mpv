#!/usr/bin/env bash
# Gather diagnostic files into BUILD_LOG_DIR after a failed CI run.
set -euo pipefail

source "$(dirname "$0")/common.sh"

LOG_DIR="${BUILD_LOG_DIR:-${ROOT_DIR}/.cache/logs}"
BUNDLE="${LOG_DIR}/diagnostics"
PROFILE="${PROFILE:-unknown}"

mkdir -p "$BUNDLE"

copy_if_exists() {
    local src="$1"
    local dest_name="$2"
    if [[ -e "$src" ]]; then
        cp -a "$src" "${BUNDLE}/${dest_name}" 2>/dev/null || cp -r "$src" "${BUNDLE}/${dest_name}"
        echo "Collected: ${dest_name}"
    fi
}

# Environment snapshot
{
    echo "PROFILE=${PROFILE}"
    echo "MSYSTEM=${MSYSTEM:-}"
    echo "MSYSTEM_PREFIX=${MSYSTEM_PREFIX:-}"
    echo "FFMPEG_LGPL_PREFIX=${FFMPEG_LGPL_PREFIX:-}"
    echo "DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "--- uname -a ---"
    uname -a 2>/dev/null || true
    echo "--- pacman -Q (last 40) ---"
    pacman -Q 2>/dev/null | tail -40 || true
} > "${BUNDLE}/environment.txt"

# Staging / meson configure output
if [[ "$PROFILE" == "gpl" || "$PROFILE" == "lgpl" ]]; then
    STAGE="${ROOT_DIR}/dist/staging/${PROFILE}"
    copy_if_exists "${STAGE}/meson-configure.txt" "meson-configure-${PROFILE}.txt"
fi

# mpv meson logs
MPV_BUILD="${ROOT_DIR}/.cache/sources/mpv/build-${PROFILE}"
copy_if_exists "${MPV_BUILD}/meson-logs/meson-log.txt" "mpv-meson-log.txt"
copy_if_exists "${MPV_BUILD}/meson-logs/testlog.txt" "mpv-testlog.txt"

# ffmpeg build log fragments
copy_if_exists "${ROOT_DIR}/.cache/ffmpeg-build-lgpl/config.log" "ffmpeg-config.log"
copy_if_exists "${ROOT_DIR}/.cache/ffmpeg-build-lgpl/ffbuild/config.log" "ffmpeg-ffbuild-config.log"

# Existing step logs in LOG_DIR
if [[ -d "$LOG_DIR" ]]; then
    for f in "${LOG_DIR}"/*.log; do
        [[ -f "$f" ]] || continue
        base="$(basename "$f")"
        [[ "$base" == "diagnostics" ]] && continue
        copy_if_exists "$f" "$base"
    done
fi

# Package manifest if partial success
copy_if_exists "${ROOT_DIR}/dist/staging/${PROFILE}/MANIFEST.json" "MANIFEST.json"

echo "Diagnostics bundled under: ${BUNDLE}"
ls -la "$BUNDLE" 2>/dev/null || true

# Create a single tarball-friendly summary
{
    echo "lib_mpv CI diagnostics"
    echo "profile: ${PROFILE}"
    echo "files:"
    ls -1 "$BUNDLE" 2>/dev/null || true
} > "${LOG_DIR}/README-diagnostics.txt"
