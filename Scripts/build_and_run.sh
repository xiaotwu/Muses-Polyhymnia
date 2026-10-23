#!/usr/bin/env bash
# Use the complete packaging path for every development launch and verification.
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Muses"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
case "$MODE" in
    run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify|--isolated) ;;
    *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--isolated]" >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || { echo "Only one development mode is supported" >&2; exit 2; }

BUNDLE_ID="com.muses.acceptance.development"
APP_BUNDLE="$ROOT_DIR/build/MusesDevelopment.app"
if [[ "$MODE" == "--isolated" ]]; then
    BUNDLE_ID="com.muses.acceptance.validation"
    APP_BUNDLE="$ROOT_DIR/build/MusesValidation.app"
fi
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Debuggers pass their environment to the application. Acceptance builds must
# not acquire release OAuth configuration through runtime environment overrides.
unset MUSES_GOOGLE_OAUTH_CLIENT_ID MUSES_GOOGLE_OAUTH_CLIENT_SECRET MUSES_GOOGLE_OAUTH_REDIRECT_URI

# Never reuse a previously signed bundle or apply the app's entitlements to
# nested helpers. The packager rejects an output that is still running.
"$ROOT_DIR/Scripts/build-app.sh" --configuration debug --identity - \
    --bundle-id "$BUNDLE_ID" --output "$APP_BUNDLE"

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
    --verify|verify)
        # build-app.sh already verified signatures, runtime closure receipts,
        # Deno execution and both resolver copies. Verification never launches UI.
        echo "Verified development bundle: $APP_BUNDLE"
        ;;
    --isolated)
        /usr/bin/open -n --env MUSES_IN_MEMORY_STORE=1 \
            --env "MUSES_VALIDATION_STORE=${MUSES_VALIDATION_STORE:-}" "$APP_BUNDLE"
        ;;
    run) open_app ;;
    --debug|debug) lldb -- "$APP_BINARY" ;;
    --logs|logs)
        open_app
        /usr/bin/log stream --info --style compact --predicate "processImagePath == \"$APP_BINARY\""
        ;;
    --telemetry|telemetry)
        open_app
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"com.muses.app\" && processImagePath == \"$APP_BINARY\""
        ;;
esac
