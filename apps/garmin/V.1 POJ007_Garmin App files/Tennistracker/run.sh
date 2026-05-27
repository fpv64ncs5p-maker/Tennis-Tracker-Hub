#!/bin/bash
# MatchMind — build and reload in simulator

PROJECT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/01 Claude in Docs/02 Projects/PROJ007_Garmin App/Tennistracker"
SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin"
SIM="$SDK/ConnectIQ.app"

# Open the simulator if it's not already running
if ! pgrep -x "ConnectIQ" > /dev/null; then
    echo "Starting simulator..."
    open "$SIM"
    echo "Waiting for simulator to be ready..."
    sleep 5
else
    echo "Simulator already running."
fi

echo "Building..."
cd "$PROJECT"
"$SDK/monkeyc" -o bin/Tennistracker.prg -f monkey.jungle -y developer_key -d vivoactive6_sim -w

if [ $? -eq 0 ]; then
    echo "Launching app..."
    "$SDK/monkeydo" bin/Tennistracker.prg vivoactive6
else
    echo "Build failed — check errors above."
fi
