#!/usr/bin/env bash
# Assemble a complete, independently signed application from a SwiftPM build.
#
# 步骤:copy-ytdlp → make-icon → swift build -c release → 装配 Contents/
# → 拷贝资源 / Info.plist → 注入版本 → codesign(ad-hoc 或 Developer ID)→ 验证。
#
# Sparkle is embedded and signed inside-out. Unconfigured previews do not update.
#
# 参数/环境:
#   --identity <id>   签名身份(默认 $MUSES_SIGN_IDENTITY 或 "-" = ad-hoc)
#   --configuration debug|release  SwiftPM and App Intents configuration (default release)
#   --bundle-id <com.muses.acceptance.*>  Isolated application without updates or account authority
#   --output <path.app>  Refuse replacement while this exact bundle is running
#   MUSES_VERSION     Override CFBundleShortVersionString (default 0.6.2)
#   MUSES_BUILD       Override CFBundleVersion (default 20261023.4)
#   MUSES_GOOGLE_OAUTH_CLIENT_ID       Muses 项目持有的 Desktop OAuth client ID
#   MUSES_GOOGLE_OAUTH_CLIENT_SECRET   Matching Desktop OAuth field when required by the issuer
#   MUSES_GOOGLE_OAUTH_REDIRECT_URI    可选；默认 http://127.0.0.1:0/（Desktop loopback 随机端口）
#   MUSES_MPV_DEPENDENCY_DIR          Prepared isolated libmpv directory (required)
#   MUSES_WEB_HOME_ENABLED             构建级 kill switch(默认 YES)
#
# 用法:
#   ./Scripts/build-app.sh                        # ad-hoc dev 构建
#   MUSES_SIGN_IDENTITY="Developer ID Application: ..." ./Scripts/build-app.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Production packaging defaults to release. Development uses this same complete
# assembly path with a separate acceptance identity and output directory.
IDENTITY="${MUSES_SIGN_IDENTITY:-}"
APP="build/Muses.app"
CONFIGURATION="release"
BUNDLE_ID="${MUSES_BUNDLE_ID:-com.muses.app}"
valid_acceptance_id() {
    [[ "$1" =~ ^com\.muses\.acceptance\.[A-Za-z0-9][A-Za-z0-9.-]*$ && ${#1} -le 120 ]]
}
while [[ $# -gt 0 ]]; do
    case "$1" in
        --identity|--output|--configuration|--bundle-id)
            [[ $# -ge 2 && -n "$2" ]] || { echo "Missing value for $1" >&2; exit 2; }
            case "$1" in
                --identity) IDENTITY="$2" ;;
                --output) APP="$2" ;;
                --configuration) CONFIGURATION="$2" ;;
                --bundle-id)
                    valid_acceptance_id "$2" || { echo "--bundle-id requires a valid com.muses.acceptance.* identifier" >&2; exit 2; }
                    BUNDLE_ID="$2"
                    ;;
            esac
            shift 2
            ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -z "$IDENTITY" ]] && IDENTITY="-"
case "$CONFIGURATION" in
    debug) XCODE_CONFIGURATION="Debug" ;;
    release) XCODE_CONFIGURATION="Release" ;;
    *) echo "--configuration must be debug or release" >&2; exit 2 ;;
esac
if [[ "$BUNDLE_ID" != "com.muses.app" ]] && ! valid_acceptance_id "$BUNDLE_ID"; then
    echo "Unsupported application bundle identifier" >&2
    exit 2
fi
if [[ "$APP" != *.app || "$APP" == ".app" ]]; then
    echo "Output must be an .app bundle path" >&2
    exit 1
fi
python3 -B - "$APP" <<'PY'
from pathlib import Path
import sys
app = Path(sys.argv[1]).resolve()
if app.suffix != '.app' or app.is_relative_to(Path('/Applications').resolve()):
    raise SystemExit('Use a newly staged .app outside /Applications; never replace an installed application')
PY

VERSION="${MUSES_VERSION:-0.6.2}"
BUILD="${MUSES_BUILD:-20261023.4}"

CONTENTS="$APP/Contents"

echo "== Muses .app 打包 (身份: $IDENTITY, 版本: $VERSION) =="

# Validate the native dependency before changing any packaging inputs.
MPV_DEPENDENCY_DIR="${MUSES_MPV_DEPENDENCY_DIR:-}"
if [[ -z "$MPV_DEPENDENCY_DIR" || ! -f "$MPV_DEPENDENCY_DIR/manifest.json" ]]; then
    echo "Set MUSES_MPV_DEPENDENCY_DIR after running Scripts/prepare-mpv.py --work-dir <dedicated-dir>" >&2
    exit 1
fi
python3 -B "$REPO_ROOT/Scripts/bundle-mpv.py" check --dependency-dir "$MPV_DEPENDENCY_DIR"

# Fail before downloads, generated resources or output replacement. A matching
# executable in another app, including the installed product, is irrelevant.
python3 -B "$REPO_ROOT/Scripts/check-app-not-running.py" --app "$APP"
# App Intents consumes the matching Xcode configuration's compiler metadata.
# Missing metadata must fail before changing the previous output bundle.
python3 -B - "$REPO_ROOT" "$XCODE_CONFIGURATION" <<'PY'
from pathlib import Path
import sys
root, configuration = Path(sys.argv[1]), sys.argv[2]
if not any(configuration in path.parts
           and path.parent.parent.parent.name in {'Muses.build', 'Muses-p.build'}
           for path in (root / '.build/out').rglob('*.swiftconstvalues')):
    raise SystemExit('App Intents compiler metadata is missing for ' + configuration + '. Run:\n'
                     'xcodebuild -scheme Muses -configuration ' + configuration
                     + " -destination 'platform=macOS' -derivedDataPath .build/out CODE_SIGNING_ALLOWED=NO build")
PY

# 1) 前置:yt-dlp + 图标。
./Scripts/copy-ytdlp.sh
./Scripts/copy-deno.sh
./Scripts/make-icon.sh

# 2) Build the same configuration used by App Intents metadata.
echo "[1/5] swift build -c $CONFIGURATION"
swift build -c "$CONFIGURATION"
RELEASE_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"

# 3) 装配 .app 结构。
echo "[2/5] 装配 $APP"
python3 -B "$REPO_ROOT/Scripts/check-app-not-running.py" --app "$APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$CONTENTS/Helpers" "$CONTENTS/Frameworks"

cp "$RELEASE_DIR/Muses" "$CONTENTS/MacOS/Muses"
cp "$RELEASE_DIR/MusesWebHomeHelper" "$CONTENTS/Helpers/MusesWebHomeHelper"
chmod 700 "$CONTENTS/Helpers/MusesWebHomeHelper"
cp "build/dependencies/deno-2.9.7/deno" "$CONTENTS/Helpers/deno"
cp "build/dependencies/deno-2.9.7/deno-LICENSE" "$CONTENTS/Resources/deno-LICENSE"

# 4) 拷贝资源 + Info.plist。
echo "[3/5] 拷贝 Resources / Info.plist"
RES_DIR="Sources/Muses/Resources"
for f in yt-dlp yt-dlp-LICENSE AppIcon.icns icon.png IslandMoments-Regular.ttf IslandMoments-OFL.txt; do
    [[ -f "$RES_DIR/$f" ]] && cp "$RES_DIR/$f" "$CONTENTS/Resources/"
done
cp "$RES_DIR/Info.plist" "$CONTENTS/Info.plist"
SPARKLE_SOURCE=".build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$SPARKLE_SOURCE" ]]; then
    echo "Missing pinned Sparkle artifact; run swift package resolve" >&2
    exit 1
fi
/usr/bin/ditto "$SPARKLE_SOURCE" "$CONTENTS/Frameworks/Sparkle.framework"
python3 "$REPO_ROOT/Scripts/bundle-mpv.py" install --app "$APP" --dependency-dir "$MPV_DEPENDENCY_DIR"
"$REPO_ROOT/Scripts/build-app-intents.sh" "$XCODE_CONFIGURATION" "$CONTENTS/Resources"
# Bundle.module must resolve inside the installed app, not a source checkout.
RESOURCE_BUNDLE="$RELEASE_DIR/Muses-Polyhymnia_Muses.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    RESOURCE_BUNDLE="$RELEASE_DIR/Muses_Muses.bundle"
fi
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
    echo "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2
    exit 1
fi
/usr/bin/ditto "$RESOURCE_BUNDLE" "$CONTENTS/Resources/Muses_Muses.bundle"
# SwiftPM and Xcode's SwiftPM integration generate different accessor names.
# Both aliases resolve to one copy of the current build's resources.
ln -s Muses_Muses.bundle "$CONTENTS/Resources/Muses-Polyhymnia_Muses.bundle"
# Refresh both complete runtimes even if SwiftPM reused older copied resources.
python3 -B "$REPO_ROOT/Scripts/bundle-ytdlp.py" install --app "$APP"

# Shipping bundles contain only app resources. Catch accidental fixture and
# acceptance-data copies before signing makes the bundle immutable.
if find "$CONTENTS" \( -iname '*fixture*' -o -iname '*acceptance*' -o -iname '*testdata*' \
    -o -iname '*.sqlite' -o -iname '*.sqlite-shm' -o -iname '*.sqlite-wal' \
    -o -iname '*.db' -o -iname '*.log' -o -iname '*.xcresult' \) -print -quit | grep -q .; then
    echo "Release bundle contains test or user data" >&2
    exit 1
fi

# 5) 注入版本号。
echo "[4/5] 注入版本 $VERSION ($BUILD)"
PLIST="/usr/libexec/PlistBuddy"
"$PLIST" -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
"$PLIST" -c "Set :CFBundleVersion $BUILD" "$CONTENTS/Info.plist"
"$PLIST" -c "Set :MusesGoogleOAuthClientID ${MUSES_GOOGLE_OAUTH_CLIENT_ID:-}" "$CONTENTS/Info.plist"
"$PLIST" -c "Set :MusesGoogleOAuthClientSecret ${MUSES_GOOGLE_OAUTH_CLIENT_SECRET:-}" "$CONTENTS/Info.plist"
"$PLIST" -c "Set :MusesGoogleOAuthRedirectURI ${MUSES_GOOGLE_OAUTH_REDIRECT_URI:-http://127.0.0.1:0/}" "$CONTENTS/Info.plist"
"$PLIST" -c "Set :MusesWebHomeEnabled ${MUSES_WEB_HOME_ENABLED:-YES}" "$CONTENTS/Info.plist"

if valid_acceptance_id "$BUNDLE_ID"; then
    # Developer environments may carry release credentials and feed settings.
    # Acceptance applications never inherit an update feed or OAuth authority.
    MUSES_BUNDLE_ID="$BUNDLE_ID" MUSES_AUTOMATIC_UPDATES_REQUIRED=NO \
        MUSES_UPDATE_PUBLIC_KEY= MUSES_UPDATE_FEED_URL= MUSES_UPDATE_ACCEPTANCE_LOOPBACK=NO \
        MUSES_SIGN_IDENTITY="$IDENTITY" MUSES_BUNDLE_PATH="$APP" \
        python3 "$REPO_ROOT/Scripts/configure-updates.py"
else
    if [[ "${MUSES_AUTOMATIC_UPDATES_REQUIRED:-NO}" == YES && -z "${MUSES_UPDATE_PUBLIC_KEY:-}" ]]; then
        # Read an already provisioned public key; builds never create private keys.
        MUSES_UPDATE_PUBLIC_KEY="$(.build/artifacts/sparkle/Sparkle/bin/generate_keys \
            --account "${MUSES_UPDATE_KEY_ACCOUNT:-muses-polyhymnia}" -p)"
        export MUSES_UPDATE_PUBLIC_KEY
    fi
    MUSES_BUNDLE_ID="$BUNDLE_ID" MUSES_SIGN_IDENTITY="$IDENTITY" MUSES_BUNDLE_PATH="$APP" python3 "$REPO_ROOT/Scripts/configure-updates.py"
fi
"$REPO_ROOT/Scripts/sync-app-icon.sh" "$APP"

# 6) Sign every nested executable before signing the app.
echo "[5/5] codesign (inside-out, hardened runtime)"
ENTITLEMENTS="$RES_DIR/Muses.entitlements"
TIMESTAMP_ARGS=(--timestamp=none)
if [[ "$IDENTITY" != "-" ]]; then
    TIMESTAMP_ARGS=(--timestamp)
fi
# Sign Python, every extension/dylib and the entry point in both resolver copies.
python3 -B "$REPO_ROOT/Scripts/bundle-ytdlp.py" sign --app "$APP" --identity "$IDENTITY"
# Deno alone needs JIT; the application and other helpers retain their own
# entitlements. Sign and execute it under hardened runtime before shipping.
codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" \
    --entitlements "$RES_DIR/Deno.entitlements" \
    --sign "$IDENTITY" "$CONTENTS/Helpers/deno"
python3 "$REPO_ROOT/Scripts/bundle-mpv.py" sign --app "$APP" --identity "$IDENTITY"
# Sign Sparkle's helpers and XPC services before the enclosing framework.
SPARKLE="$CONTENTS/Frameworks/Sparkle.framework/Versions/B"
for component in "$SPARKLE/XPCServices/Downloader.xpc" "$SPARKLE/XPCServices/Installer.xpc" \
                 "$SPARKLE/Autoupdate" "$SPARKLE/Updater.app"; do
    codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" --sign "$IDENTITY" "$component"
done
codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" --sign "$IDENTITY" \
    "$CONTENTS/Frameworks/Sparkle.framework"

# Helper 必须先用与主 app 相同的身份签名；主进程会在每次启动前校验固定路径、
# 严格签名和 TeamIdentifier，绝不从 PATH 加载同名程序。
codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" \
    --sign "$IDENTITY" "$CONTENTS/Helpers/MusesWebHomeHelper"
# Nested code is already signed. A deep re-sign would overwrite Deno's narrow
# JIT entitlement with the application's different entitlement set.
codesign --force --options runtime "${TIMESTAMP_ARGS[@]}" \
    --entitlements "$ENTITLEMENTS" \
    --sign "$IDENTITY" "$APP"

# 7) 验证。
python3 -B "$REPO_ROOT/Scripts/bundle-ytdlp.py" verify --app "$APP"
python3 "$REPO_ROOT/Scripts/bundle-mpv.py" verify --app "$APP"
codesign --verify --deep --strict "$CONTENTS/Frameworks/Sparkle.framework"
otool -L "$CONTENTS/MacOS/Muses" | grep -q '@rpath/Sparkle.framework/'
codesign --verify --deep --strict "$APP" && echo "      ✓ codesign 验证通过"
codesign --verify --strict "$CONTENTS/Helpers/deno"
PATH=/usr/bin:/bin:/usr/sbin:/sbin \
    DENO_DIR="$REPO_ROOT/build/dependencies/deno-cache" DENO_NO_UPDATE_CHECK=1 \
    "$CONTENTS/Helpers/deno" eval 'if (1 + 1 !== 2) Deno.exit(1)'
codesign --verify --strict "$CONTENTS/Helpers/MusesWebHomeHelper" \
    && echo "      ✓ Web Home helper 签名验证通过"
for YTDLP_BINARY in \
    "$CONTENTS/Resources/yt-dlp" \
    "$CONTENTS/Resources/Muses_Muses.bundle/Contents/Resources/Resources/yt-dlp"; do
    "$YTDLP_BINARY" --version >/dev/null
done
echo "      ✓ 两份 yt-dlp 在 hardened runtime 下启动通过"
if [[ "$IDENTITY" != "-" ]]; then
    codesign -dvvv "$APP" 2>&1 | grep -E "Authority|TeamIdentifier" || true
fi

echo ""
echo "完成: $APP"
echo "启动: open $APP"
