#!/usr/bin/env bash
# Install MSYS2 packages for the active PROFILE (gpl or lgpl).
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config

mingw_pkg_prefix() {
    case "${MSYSTEM:-CLANG64}" in
        CLANG64) echo "mingw-w64-clang-x86_64" ;;
        MINGW64) echo "mingw-w64-x86_64" ;;
        UCRT64) echo "mingw-w64-ucrt-x86_64" ;;
        CLANGARM64) echo "mingw-w64-clang-aarch64" ;;
        *) echo "mingw-w64-clang-x86_64" ;;
    esac
}

sync_pacman() {
    echo "Syncing pacman databases ..."
    pacman -Sy --noconfirm
}

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
    pacman -S --needed --noconfirm zip p7zip
}

install_one_pkg() {
    local pkg="$1"
    pkg="$(strip_cr "$pkg")"
    local mingw_prefix full_name
    mingw_prefix="$(mingw_pkg_prefix)"
    full_name="${mingw_prefix}-${pkg}"

    echo "Installing ${pkg} ..."

    if pacboy -S --noconfirm "${pkg}:p"; then
        return 0
    fi

    echo "pacboy failed for ${pkg}; syncing and retrying ..."
    sync_pacman

    if pacboy -S --noconfirm "${pkg}:p"; then
        return 0
    fi

    echo "Trying direct pacman install: ${full_name}"
    if pacman -S --needed --noconfirm "${full_name}"; then
        return 0
    fi

    echo "Trying MSYS package: ${pkg}"
    pacman -S --needed --noconfirm "$pkg"
}

install_pacboy() {
    local pkg
    for pkg in "$@"; do
        install_one_pkg "$pkg"
    done
}

ensure_pacboy
sync_pacman
install_msys_tools
install_pacboy "${COMMON_PKGS[@]}"

mapfile -t EXTRA < <(jq -r '.pacboy_extra[]' "$CONFIG")
for i in "${!EXTRA[@]}"; do
    EXTRA[$i]="$(strip_cr "${EXTRA[$i]}")"
done
sync_pacman
install_pacboy "${EXTRA[@]}"

echo "MSYS2 dependencies installed for profile: ${PROFILE}"
