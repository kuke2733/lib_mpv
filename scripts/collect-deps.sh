#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config

STAGE="$(stage_dir)"
BIN_DIR="${STAGE}/bin"
MANIFEST="${STAGE}/MANIFEST.json"

if [[ ! -f "${BIN_DIR}/libmpv-2.dll" ]]; then
    echo "ERROR: ${BIN_DIR}/libmpv-2.dll not found. Run build-libmpv.sh first." >&2
    exit 1
fi

mkdir -p "$BIN_DIR"

declare -A SEEN=()
declare -a QUEUE=()

queue_push() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    local base key
    base="$(basename "$path")"
    if is_system_dll "$base"; then
        return 0
    fi
    key="${base,,}"
    if [[ -n "${SEEN[$key]:-}" ]]; then
        return 0
    fi
    SEEN[$key]=1
    QUEUE+=("$path")
}

resolve_dep() {
    local line="$1"
    if [[ "$line" =~ =\>\ (.+\.(dll|DLL)) ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

queue_push "${BIN_DIR}/libmpv-2.dll"

if [[ "$PROFILE" == "lgpl" && -n "${FFMPEG_LGPL_PREFIX:-}" && -d "${FFMPEG_LGPL_PREFIX}/bin" ]]; then
    for dll in "${FFMPEG_LGPL_PREFIX}/bin/"*.dll; do
        [[ -f "$dll" ]] || continue
        queue_push "$dll"
    done
fi

i=0
while (( i < ${#QUEUE[@]} )); do
    current="${QUEUE[$i]}"
    while IFS= read -r line; do
        dep="$(resolve_dep "$line" || true)"
        [[ -n "$dep" ]] || continue
        queue_push "$dep"
    done < <(ldd "$current" 2>/dev/null || true)
    ((i++)) || true
done

for src in "${QUEUE[@]}"; do
    base="$(basename "$src")"
    cp -fn "$src" "${BIN_DIR}/${base}" 2>/dev/null || cp -f "$src" "${BIN_DIR}/${base}"
done

{
    echo '{'
    echo '  "profile": "'"$PROFILE"'",'
    echo '  "dlls": ['
    first=1
    for src in "${QUEUE[@]}"; do
        base="$(basename "$src")"
        if (( first )); then first=0; else echo ','; fi
        printf '    {"name": "%s", "source": "%s"}' "$base" "$src"
    done
    echo
    echo '  ]'
    echo '}'
} > "$MANIFEST"

count="$(find "$BIN_DIR" -maxdepth 1 -iname '*.dll' | wc -l | tr -d ' ')"
echo "Collected ${count} DLL(s) into ${BIN_DIR}"
