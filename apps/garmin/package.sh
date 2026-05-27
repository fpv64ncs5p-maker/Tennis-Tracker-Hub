#!/bin/bash
# MatchMind — build release .iq package for Connect IQ Store submission

PROJECT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/01 Claude in Docs/02 Projects/PROJ007_Garmin App/Tennistracker"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin"

cd "$PROJECT"

echo "Building release package..."
"$SDK/monkeyc" \
    -o bin/Tennistracker.iq \
    -f monkey.jungle \
    -y developer_key \
    -e \
    -w

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Package ready: bin/Tennistracker.iq"
    echo "Upload this file to: https://developer.garmin.com/connect-iq/sdk/"
else
    echo "Build failed — check errors above."
fi
