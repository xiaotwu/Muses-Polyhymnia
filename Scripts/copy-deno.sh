#!/usr/bin/env bash
# Bundle the pinned standalone arm64 runtime used by yt-dlp's EJS solver.
# A GUI release must not depend on Homebrew or the user's shell PATH.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="2.9.7"
SHA256="5cd46d6268f6f78f5d88bdc7159d20bd44cdaa4b3303474839f87ec6fe7ae25c"
DEST_DIR="build/dependencies/deno-$VERSION"
ARCHIVE="$DEST_DIR/deno-aarch64-apple-darwin.zip"
mkdir -p "$DEST_DIR"
if [[ ! -f "$ARCHIVE" ]] || ! echo "$SHA256  $ARCHIVE" | shasum -a 256 -c - >/dev/null 2>&1; then
    curl -fL "https://github.com/denoland/deno/releases/download/v$VERSION/deno-aarch64-apple-darwin.zip" \
        -o "$ARCHIVE.download"
    echo "$SHA256  $ARCHIVE.download" | shasum -a 256 -c -
    mv "$ARCHIVE.download" "$ARCHIVE"
fi
# Re-extract the verified bytes rather than trusting an earlier local binary.
unzip -qo "$ARCHIVE" -d "$DEST_DIR"
chmod 755 "$DEST_DIR/deno"
"$DEST_DIR/deno" --version | head -1
LICENSE_SHA256="f62497fffecc0852960c8d3e6934b9db86d16396e9b604072e923892cae3a588"
LICENSE="$DEST_DIR/deno-LICENSE"
if [[ ! -f "$LICENSE" ]] || ! echo "$LICENSE_SHA256  $LICENSE" | shasum -a 256 -c - >/dev/null 2>&1; then
    curl -fsSL "https://raw.githubusercontent.com/denoland/deno/v$VERSION/LICENSE.md" -o "$LICENSE.download"
    echo "$LICENSE_SHA256  $LICENSE.download" | shasum -a 256 -c -
    mv "$LICENSE.download" "$LICENSE"
fi
