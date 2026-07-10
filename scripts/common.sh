#!/usr/bin/env bash
# Shared helpers for lib_mpv build scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

require_profile() {
    PROFILE="${PROFILE:-}"
    if [[ -z "$PROFILE" || ( "$PROFILE" != "gpl" && "$PROFILE" != "lgpl" ) ]]; then
        echo "ERROR: PROFILE must be 'gpl' or 'lgpl' (got: '${PROFILE:-}')" >&2
        exit 1
    fi
    export PROFILE
}

load_config() {
    require_profile
    CONFIG="${ROOT_DIR}/configs/profiles/${PROFILE}.json"
    VERSIONS="${ROOT_DIR}/configs/versions.json"
    if [[ ! -f "$CONFIG" ]]; then
        echo "ERROR: missing profile config: $CONFIG" >&2
        exit 1
    fi
    if [[ ! -f "$VERSIONS" ]]; then
        echo "ERROR: missing versions config: $VERSIONS" >&2
        exit 1
    fi
    export CONFIG VERSIONS
}

json_get() {
    local file="$1"
    local query="$2"
    if command -v jq >/dev/null 2>&1; then
        jq -r "$query" "$file"
        return
    fi
    python - "$file" "$query" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
query = sys.argv[2].strip()
# Support simple jq forms: .key, .key // empty
query = query.split("//")[0].strip()
key = query.lstrip(".").strip()
value = data.get(key, "")
if value is None:
    value = ""
print(value)
PY
}

sources_dir() {
    local rel=".cache/sources"
    if [[ -f "${ROOT_DIR}/configs/versions.json" ]]; then
        rel="$(json_get "${ROOT_DIR}/configs/versions.json" '.sources_dir // ".cache/sources"')"
    fi
    echo "${ROOT_DIR}/${rel}"
}

source_config_path() {
    local name="$1"
    echo "${ROOT_DIR}/configs/sources/${name}.json"
}

mpv_source_dir() {
    echo "$(sources_dir)/mpv"
}

ffmpeg_source_dir() {
    local cfg version
    cfg="$(source_config_path ffmpeg)"
    version="$(json_get "$cfg" '.version')"
    echo "$(sources_dir)/ffmpeg-${version}"
}

mpv_version() {
    local mpv_dir tag ver
    mpv_dir="$(mpv_source_dir)"
    tag="$(json_get "$(source_config_path mpv)" '.ref')"
    if [[ -f "${mpv_dir}/common/version.h" ]]; then
        ver="$(grep -E '#define VERSION ' "${mpv_dir}/common/version.h" | sed -E 's/.*"([^"]+)".*/\1/')"
        if [[ -n "$ver" ]]; then
            echo "$ver"
            return
        fi
    fi
    echo "${tag#v}"
}

mpv_build_dir() {
    echo "$(mpv_source_dir)/build-${PROFILE}"
}

stage_dir() {
    echo "${ROOT_DIR}/dist/staging/${PROFILE}"
}

meson_feature_args() {
    local config="$1"
    local args=()
    local keys
    keys="$(jq -r '.features | keys[]' "$config")"
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        local value
        value="$(jq -r --arg k "$key" '.features[$k]' "$config")"
        args+=("-D${key}=${value}")
    done <<< "$keys"
    printf '%s\n' "${args[@]}"
}

meson_bool_args() {
    local config="$1"
    local args=()
    local keys
    keys="$(jq -r '.meson | keys[]' "$config")"
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        local value
        value="$(jq -r --arg k "$key" '.meson[$k]' "$config")"
        args+=("-D${key}=${value}")
    done <<< "$keys"
    printf '%s\n' "${args[@]}"
}

is_system_dll() {
    local name="$1"
    local lower
    lower="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
    case "$lower" in
        kernel32.dll|ntdll.dll|user32.dll|gdi32.dll|advapi32.dll|shell32.dll|ole32.dll|\
        oleaut32.dll|ws2_32.dll|msvcrt.dll|ucrtbase.dll|vcruntime*.dll|api-ms-win-*.dll|\
        combase.dll|rpcrt4.dll|sechost.dll|bcrypt.dll|crypt32.dll|imm32.dll|\
        winmm.dll|d3d11.dll|dxgi.dll|dwmapi.dll|shlwapi.dll|setupapi.dll|\
        cfgmgr32.dll|version.dll|powrprof.dll|propsys.dll|windowscodecs.dll|\
        msasn1.dll|nsi.dll|iphlpapi.dll|userenv.dll|profapi.dll|msvcp*.dll|\
        msvcp_win.dll|mswsock.dll|dbghelp.dll|win32u.dll|gdi32full.dll|\
        uxtheme.dll|d3d12.dll|dxcore.dll|mfplat.dll|mfreadwrite.dll|mf.dll|\
        evr.dll|windows.storage.dll|wldp.dll|devobj.dll|wintrust.dll|\
        cryptbase.dll|bcryptprimitives.dll|msvcp140.dll|vcruntime140.dll|\
        vcruntime140_1.dll)
            return 0
            ;;
    esac
    return 1
}

ensure_tools() {
    local missing=()
    for tool in jq meson ninja pkg-config; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done
    if ((${#missing[@]} > 0)); then
        echo "ERROR: missing tools: ${missing[*]}" >&2
        exit 1
    fi
}
