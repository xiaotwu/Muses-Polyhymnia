#!/usr/bin/env bash
# Bundle exact upstream bytes before build-app.sh applies its existing signature.
# --check only reads local hashes and prints the pin; it never downloads, creates
# directories, changes permissions, or executes an existing resolver.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="2026.10.21"
SHA256="7a6fe71d7d680f1fb0ac18d4949873d77db2859e90017c0f44bd94b23be4ee40"
LICENSE_SHA256="7e12e5df4bae12cb21581ba157ced20e1986a0508dd10d0e8a4ab9a4cf94e85c"
REMOTE_URL="https://github.com/yt-dlp/yt-dlp/releases/download/$VERSION/yt-dlp_macos"
LICENSE_URL="https://raw.githubusercontent.com/yt-dlp/yt-dlp/$VERSION/LICENSE"
DEST_DIR="Sources/Muses/Resources"
DEST="$DEST_DIR/yt-dlp"
LICENSE="$DEST_DIR/yt-dlp-LICENSE"

CHECK_ONLY=0
case "${1:-}" in
    "") [[ $# -eq 0 ]] || exit 2 ;;
    --check) [[ $# -eq 1 ]] || exit 2; CHECK_ONLY=1 ;;
    *) echo "Usage: $0 [--check]" >&2; exit 2 ;;
esac

verify_sha() {
    [[ -f "$1" ]] && printf '%s  %s\n' "$2" "$1" | shasum -a 256 -c - >/dev/null 2>&1
}

BINARY_VALID=0
LICENSE_VALID=0
verify_sha "$DEST" "$SHA256" && BINARY_VALID=1
verify_sha "$LICENSE" "$LICENSE_SHA256" && LICENSE_VALID=1
printf '== yt-dlp bundling ==\npinned: %s\n' "$VERSION"
printf 'binary verified: %s\nlicense verified: %s\n' "$BINARY_VALID" "$LICENSE_VALID"
if [[ $CHECK_ONLY -eq 1 ]]; then
    exit 0
fi
if [[ $BINARY_VALID -eq 1 && $LICENSE_VALID -eq 1 ]]; then
    chmod 755 "$DEST"
    echo "Pinned resolver and license already verified; download skipped."
    exit 0
fi

# Stage on the destination filesystem, validate BOTH inputs before replacing
# either, and rename each verified file atomically. Failed/truncated downloads
# leave existing resources intact. A matching version string never bypasses SHA.
mkdir -p "$DEST_DIR"
STAGING="$(mktemp -d "$DEST_DIR/.yt-dlp-download.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
if [[ $BINARY_VALID -eq 1 ]]; then
    cp "$DEST" "$STAGING/yt-dlp"
else
    curl -fL --retry 2 "$REMOTE_URL" -o "$STAGING/yt-dlp"
fi
if [[ $LICENSE_VALID -eq 1 ]]; then
    cp "$LICENSE" "$STAGING/yt-dlp-LICENSE"
else
    curl -fsSL --retry 2 "$LICENSE_URL" -o "$STAGING/yt-dlp-LICENSE"
fi
if ! verify_sha "$STAGING/yt-dlp" "$SHA256"; then
    echo "Pinned yt-dlp SHA-256 verification failed; resources were not replaced." >&2
    exit 1
fi
if ! verify_sha "$STAGING/yt-dlp-LICENSE" "$LICENSE_SHA256"; then
    echo "Pinned yt-dlp LICENSE SHA-256 verification failed; resources were not replaced." >&2
    exit 1
fi
chmod 755 "$STAGING/yt-dlp"
chmod 644 "$STAGING/yt-dlp-LICENSE"
mv -f "$STAGING/yt-dlp-LICENSE" "$LICENSE"
mv -f "$STAGING/yt-dlp" "$DEST"
echo "Bundled verified yt-dlp $VERSION and pinned LICENSE."
