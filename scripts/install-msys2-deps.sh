#!/usr/bin/env bash
# Install MSYS2 packages for the active PROFILE (gpl or lgpl).
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config

ensure_pacboy() {
    if command -v pacboy >/dev/null 2>&1; then
        return 0
    fi
    echo "pacboy not found; installing pactoys ..."
    pacman -S --needed --noconfirm pactoys
    if ! command -v pacboy >/dev/null 2>&1; then
        echo "ERROR: pacboy still unavailable after installing pactoys" >&2
        exit 1
    fi
}

COMMON_PKGS=(
    cc
    meson
    ninja
    pkgconf
    python
    git
    jq
    curl
    libass
    libplacebo
    luajit
    vulkan-headers
    lcms2
    libarchive
    libbluray
    angleproject
    shaderc
    spirv-cross
    uchardet
    mujs
)

install_msys_tools() {
    # zip/7z are MSYS packages, not available as mingw-w64-clang pacboy targets.
    pacman -S --needed --noconfirm zip p7zip
}

install_pacboy() {
    local pkg
    for pkg in "$@"; do
        echo "Installing ${pkg}..."
        pacboy -S --noconfirm "${pkg}:p"
    done
}

ensure_pacboy
install_pacboy "${COMMON_PKGS[@]}"
install_msys_tools

mapfile -t EXTRA < <(jq -r '.pacboy_extra[]' "$CONFIG")
install_pacboy "${EXTRA[@]}"

echo "MSYS2 dependencies installed for profile: ${PROFILE}"
