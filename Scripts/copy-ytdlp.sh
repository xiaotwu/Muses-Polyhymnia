#!/usr/bin/env bash
# Download and verify the pinned, in-place Python runtime. --check is read-only.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 -B Scripts/bundle-ytdlp.py fetch "$@"
