#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/common.sh"
load_config

STAGE="$(stage_dir)"
BUILD_DIR="$(mpv_build_dir)"
errors=0

fail() {
    echo "VERIFY FAIL: $*" >&2
    errors=$((errors + 1))
}

echo "::group::Verify license profile: ${PROFILE}"

# Meson configure must reflect gpl setting
expected_gpl="$(json_get "$CONFIG" '.meson.gpl')"
if [[ -f "${STAGE}/meson-configure.txt" ]]; then
    if [[ "$expected_gpl" == "true" ]]; then
        grep -q "gpl.*true" "${STAGE}/meson-configure.txt" || fail "expected gpl=true in meson configure"
    else
        grep -q "gpl.*false" "${STAGE}/meson-configure.txt" || fail "expected gpl=false in meson configure"
    fi
fi

# Required features for GPL
while IFS= read -r feat; do
    feat="$(strip_cr "$feat")"
    [[ -z "$feat" ]] && continue
    val="$(jq -r --arg f "$feat" '.features[$f] // empty' "$CONFIG")"
    val="$(strip_cr "$val")"
    if [[ "$val" != "enabled" ]]; then
        fail "required feature not enabled: $feat (got: ${val:-missing})"
    fi
done < <(jq -r '.required_features[]? // empty' "$CONFIG")

# Disabled GPL features must stay disabled for LGPL
if [[ "$PROFILE" == "lgpl" ]]; then
    while IFS= read -r feat; do
        feat="$(strip_cr "$feat")"
        [[ -z "$feat" ]] && continue
        val="$(jq -r --arg f "$feat" '.features[$f] // empty' "$CONFIG")"
        val="$(strip_cr "$val")"
        if [[ "$val" != "disabled" ]]; then
            fail "GPL feature should be disabled for LGPL: $feat"
        fi
    done < <(jq -r '.disabled_gpl_features[]? // empty' "$CONFIG")
fi

# Forbidden strings in bundled DLLs (LGPL must not link GPL codecs)
if [[ -d "${STAGE}/bin" ]]; then
    while IFS= read -r needle; do
        needle="$(strip_cr "$needle")"
        [[ -z "$needle" ]] && continue
        if find "${STAGE}/bin" -maxdepth 1 -name '*.dll' -print0 | xargs -0 strings 2>/dev/null | grep -qi "$needle"; then
            if [[ "$PROFILE" == "lgpl" ]]; then
                fail "forbidden string '$needle' found in DLLs for LGPL profile"
            fi
        fi
    done < <(jq -r '.forbidden_strings[]? // empty' "$CONFIG")
fi

# libmpv must exist
[[ -f "${STAGE}/bin/libmpv-2.dll" ]] || fail "libmpv-2.dll missing"

# Headers
[[ -f "${STAGE}/include/mpv/client.h" ]] || fail "include/mpv/client.h missing"

echo "::endgroup::"

if (( errors > 0 )); then
    echo "License verification failed with ${errors} error(s)" >&2
    exit 1
fi

echo "License verification passed for profile: ${PROFILE}"
