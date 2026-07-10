#!/usr/bin/env bash
# Fetch third-party sources declared under configs/sources/*.json
set -euo pipefail

source "$(dirname "$0")/common.sh"

COMPONENT="${1:-all}"
SOURCES_CFG_DIR="${ROOT_DIR}/configs/sources"
SOURCES_DIR="$(sources_dir)"

mkdir -p "$SOURCES_DIR"

fetch_git_source() {
    local name="$1"
    local cfg="$2"
    local repo ref commit dest
    repo="$(json_get "$cfg" '.repository')"
    ref="$(json_get "$cfg" '.ref')"
    commit="$(json_get "$cfg" '.commit // empty')"
    dest="${SOURCES_DIR}/${name}"

    if [[ -d "${dest}/.git" ]]; then
        echo "Updating existing git source: ${name}"
        git -C "$dest" fetch --depth 1 origin "refs/tags/${ref#v}" 2>/dev/null || \
            git -C "$dest" fetch --depth 1 origin "$ref" || true
        git -C "$dest" checkout -f "$ref" 2>/dev/null || git -C "$dest" checkout -f "tags/$ref"
    else
        echo "Cloning ${name} @ ${ref} ..."
        rm -rf "$dest"
        git clone --depth 1 --branch "$ref" "$repo" "$dest" 2>/dev/null || \
            git clone --depth 1 "$repo" "$dest"
        git -C "$dest" checkout -f "$ref" 2>/dev/null || git -C "$dest" checkout -f "tags/$ref"
    fi

    if [[ -n "$commit" ]]; then
        local actual
        actual="$(git -C "$dest" rev-parse HEAD)"
        if [[ "$actual" != "$commit" && "$actual" != "${commit:0:${#actual}}" ]]; then
            echo "Pinning ${name} to commit ${commit} ..."
            git -C "$dest" fetch --depth 1 origin "$commit" || git -C "$dest" fetch origin "$commit"
            git -C "$dest" checkout -f "$commit"
            actual="$(git -C "$dest" rev-parse HEAD)"
        fi
        if [[ "$actual" != "$commit" ]]; then
            echo "ERROR: ${name} commit mismatch: expected ${commit}, got ${actual}" >&2
            exit 1
        fi
    fi

    echo "Ready: ${name} @ $(git -C "$dest" rev-parse --short HEAD)"
}

fetch_tarball_source() {
    local name="$1"
    local cfg="$2"
    local version url tarball extracted dest
    version="$(json_get "$cfg" '.version')"
    url="$(json_get "$cfg" '.url')"
    tarball="${ROOT_DIR}/.cache/${name}-${version}.tar.xz"
    extracted="${ROOT_DIR}/.cache/${name}-${version}"
    dest="${SOURCES_DIR}/${name}-${version}"

    mkdir -p "${ROOT_DIR}/.cache"
    if [[ ! -f "$tarball" ]]; then
        echo "Downloading ${name} ${version} ..."
        curl -L "$url" -o "$tarball"
    fi

    if [[ ! -d "$extracted" ]]; then
        echo "Extracting ${name} ${version} ..."
        tar -xJf "$tarball" -C "${ROOT_DIR}/.cache"
    fi

    rm -rf "$dest"
    cp -a "$extracted" "$dest"
    echo "Ready: ${name} ${version} at ${dest}"
}

fetch_one() {
    local name="$1"
    local cfg="${SOURCES_CFG_DIR}/${name}.json"
    if [[ ! -f "$cfg" ]]; then
        echo "ERROR: source config not found: ${cfg}" >&2
        exit 1
    fi

    local method
    method="$(json_get "$cfg" '.method')"
    case "$method" in
        git) fetch_git_source "$name" "$cfg" ;;
        tarball) fetch_tarball_source "$name" "$cfg" ;;
        *)
            echo "ERROR: unknown fetch method '${method}' for ${name}" >&2
            exit 1
            ;;
    esac
}

if [[ "$COMPONENT" == "all" ]]; then
    shopt -s nullglob
    for cfg in "${SOURCES_CFG_DIR}"/*.json; do
        name="$(basename "$cfg" .json)"
        fetch_one "$name"
     done
else
    fetch_one "$COMPONENT"
fi
