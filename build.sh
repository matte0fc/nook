#!/bin/bash
# Builds Nook.app. Pass --install to copy it to ~/Applications and launch it.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP=build/Nook.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Nook "$APP/Contents/MacOS/Nook"
cp Resources/Info.plist "$APP/Contents/Info.plist"
# A stable local certificate keeps the Accessibility permission across rebuilds;
# fall back to ad-hoc signing (permission must be re-granted after each build).
IDENTITY=$(security find-certificate -c "Nook Local Signing" -Z 2>/dev/null | awk '/SHA-1/ {print $3}')
codesign --force --sign "${IDENTITY:--}" --identifier com.mattiasandersson.nook "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x Nook || true
    rm -rf ~/Applications/Nook.app
    cp -R "$APP" ~/Applications/
    open ~/Applications/Nook.app
    echo "Installed and launched ~/Applications/Nook.app"
fi
