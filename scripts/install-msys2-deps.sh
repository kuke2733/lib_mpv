#!/usr/bin/env bash
# Install MSYS2 packages for the active PROFILE (gpl or lgpl).
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config

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
    zip
    mujs
)

install_pacboy() {
    local pkg
    for pkg in "$@"; do
        echo "Installing ${pkg}..."
        pacboy -S --noconfirm "${pkg}:p"
    done
}

install_pacboy "${COMMON_PKGS[@]}"

mapfile -t EXTRA < <(jq -r '.pacboy_extra[]' "$CONFIG")
install_pacboy "${EXTRA[@]}"

echo "MSYS2 dependencies installed for profile: ${PROFILE}"
