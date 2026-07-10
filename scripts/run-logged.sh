#!/usr/bin/env bash
# Run a command and tee output to a log file; preserve the command exit code.
set -euo pipefail

if (($# < 2)); then
    echo "Usage: run-logged.sh <logfile> <command...>" >&2
    exit 2
fi

LOG_FILE="$1"
shift

mkdir -p "$(dirname "$LOG_FILE")"
"$@" 2>&1 | tee "$LOG_FILE"
exit "${PIPESTATUS[0]}"
