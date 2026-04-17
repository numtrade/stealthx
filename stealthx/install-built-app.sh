#!/usr/bin/env bash

set -euo pipefail

APP_NAME="stealthx.app"
PRODUCT_NAME="stealthx"
CONFIGURATION="Debug"
DESTINATION="/Applications/${APP_NAME}"
OPEN_AFTER_INSTALL=1
CLEAR_QUARANTINE=1

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
  --help                  Show this help
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
            [[ -n "$CONFIGURATION" ]] || { echo "ERROR: --configuration requires a value." >&2; exit 1; }
            shift 2
            ;;
        --destination)
            DESTINATION="${2:-}"
            [[ -n "$DESTINATION" ]] || { echo "ERROR: --destination requires a value." >&2; exit 1; }
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

SOURCE_APP="$(ls -td "$HOME"/Library/Developer/Xcode/DerivedData/"${PRODUCT_NAME}"-*/Build/Products/"${CONFIGURATION}"/"${APP_NAME}" 2>/dev/null | head -n 1 || true)"

if [[ -z "$SOURCE_APP" ]]; then
    echo "ERROR: No ${CONFIGURATION} build of ${APP_NAME} was found in DerivedData." >&2
    echo "Build the app in Xcode first, then rerun this script." >&2
    exit 1
fi

echo "Installing:"
echo "  Source: ${SOURCE_APP}"
echo "  Destination: ${DESTINATION}"

mkdir -p "$(dirname "$DESTINATION")"

if pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
    echo "Quitting running app..."
    pkill -x "$PRODUCT_NAME" || true
    sleep 1
fi

rm -rf "$DESTINATION"
ditto "$SOURCE_APP" "$DESTINATION"

if [[ "$CLEAR_QUARANTINE" -eq 1 ]]; then
    xattr -dr com.apple.quarantine "$DESTINATION" 2>/dev/null || true
fi

echo
echo "Installed app signature:"
codesign -dv --verbose=4 "$DESTINATION" 2>&1 | egrep 'Identifier|Authority|TeamIdentifier' || true

if [[ "$OPEN_AFTER_INSTALL" -eq 1 ]]; then
    open "$DESTINATION"
fi
