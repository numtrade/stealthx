#!/usr/bin/env bash

set -euo pipefail

APP_NAME="stealthx.app"
PRODUCT_NAME="stealthx"
CONFIGURATION="Debug"
DESTINATION="/Applications/${APP_NAME}"
OPEN_AFTER_INSTALL=1
CLEAR_QUARANTINE=1
REFRESH_ICON_CACHE=1

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

usage() {
    cat <<'EOF'
Install the newest Xcode-built stealthx.app from DerivedData.

Usage:
  install-built-app.sh [options]

Options:
  --debug                 Install the newest Debug build (default)
  --release               Install the newest Release build
  --configuration NAME    Install the newest build for NAME
  --destination PATH      Copy the app bundle to PATH
  --no-open               Do not open the app after installing it
  --keep-quarantine       Do not remove the quarantine xattr
  --no-refresh-icon-cache Do not re-register app / restart Dock and Finder
  --help                  Show this help

Examples:
  ./install-built-app.sh
  ./install-built-app.sh --release
  ./install-built-app.sh --destination "$HOME/Applications/stealthx.app"
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --debug)
            CONFIGURATION="Debug"
            shift
            ;;
        --release)
            CONFIGURATION="Release"
            shift
            ;;
        --configuration)
            CONFIGURATION="${2:-}"
            [[ -n "$CONFIGURATION" ]] || {
                echo "ERROR: --configuration requires a value." >&2
                exit 1
            }
            shift 2
            ;;
        --destination)
            DESTINATION="${2:-}"
            [[ -n "$DESTINATION" ]] || {
                echo "ERROR: --destination requires a value." >&2
                exit 1
            }
            shift 2
            ;;
        --no-open)
            OPEN_AFTER_INSTALL=0
            shift
            ;;
        --keep-quarantine)
            CLEAR_QUARANTINE=0
            shift
            ;;
        --no-refresh-icon-cache)
            REFRESH_ICON_CACHE=0
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ "$DESTINATION" != *.app ]]; then
    DESTINATION="${DESTINATION%/}/${APP_NAME}"
fi

SOURCE_APP="$(
    ls -td \
        "$HOME"/Library/Developer/Xcode/DerivedData/"${PRODUCT_NAME}"-*/Build/Products/"${CONFIGURATION}"/"${APP_NAME}" \
        2>/dev/null | head -n 1 || true
)"

if [[ -z "$SOURCE_APP" ]]; then
    echo "ERROR: No ${CONFIGURATION} build of ${APP_NAME} was found in DerivedData." >&2
    echo "Build the app in Xcode first, then rerun this script." >&2
    exit 1
fi

echo "Installing:"
echo "  Source:      ${SOURCE_APP}"
echo "  Destination: ${DESTINATION}"
echo

mkdir -p "$(dirname "$DESTINATION")"

if pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
    echo "Quitting running app..."
    pkill -x "$PRODUCT_NAME" || true
    sleep 1
fi

echo "Removing old app bundle..."
rm -rf "$DESTINATION"

echo "Copying new app bundle..."
ditto "$SOURCE_APP" "$DESTINATION"

if [[ "$CLEAR_QUARANTINE" -eq 1 ]]; then
    echo "Clearing quarantine attribute..."
    xattr -dr com.apple.quarantine "$DESTINATION" 2>/dev/null || true
fi

if [[ "$REFRESH_ICON_CACHE" -eq 1 ]]; then
    echo "Refreshing Launch Services registration..."
    if [[ -x "$LSREGISTER" ]]; then
        "$LSREGISTER" -f "$DESTINATION" || true
    fi

    echo "Restarting Dock and Finder..."
    killall Dock 2>/dev/null || true
    killall Finder 2>/dev/null || true
fi

echo
echo "Installed app signature:"
codesign -dv --verbose=4 "$DESTINATION" 2>&1 | egrep 'Identifier|Authority|TeamIdentifier' || true

echo
echo "Installed app icon metadata:"
plutil -p "$DESTINATION/Contents/Info.plist" 2>/dev/null | egrep 'CFBundleIcon|CFBundleIcons' || true

if [[ "$OPEN_AFTER_INSTALL" -eq 1 ]]; then
    echo
    echo "Opening app..."
    open "$DESTINATION"
fi

echo
echo "Done."