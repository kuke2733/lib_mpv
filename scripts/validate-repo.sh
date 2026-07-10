#!/usr/bin/env bash
# Offline validation of repo configs and script syntax (no MSYS2 build required).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

json_check() {
    local f="$1"
    if command -v jq >/dev/null 2>&1; then
        jq empty "$f"
    else
        python -c "import json; json.load(open('$f'))"
    fi
}

echo "Checking JSON configs..."
for f in configs/versions.json configs/profiles/gpl.json configs/profiles/lgpl.json configs/sources/*.json; do
    [[ -f "$f" ]] || continue
    json_check "$f"
    echo "  OK $f"
done

echo "Checking bash scripts..."
shopt -s nullglob
for f in scripts/*.sh; do
    bash -n "$f"
    echo "  OK $f"
done

echo "Checking source configs..."
for f in configs/sources/*.json; do
    name="$(basename "$f" .json)"
    method="$(python -c "import json; print(json.load(open('$f'))['method'])")"
    echo "  ${name}: method=${method}"
done

echo "Checking GitHub workflows..."
[[ -f .github/workflows/build-windows-x86_64.yml ]]
[[ -f .github/workflows/release.yml ]]

echo "All offline checks passed."
