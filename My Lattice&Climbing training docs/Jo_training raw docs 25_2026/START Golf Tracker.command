#!/bin/bash
cd "$(dirname "$0")"
clear
echo "========================================="
echo "   ⛳  Jo's Golf Tracker — Web Server"
echo "========================================="
echo ""

# Get local IP address
IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")

if [ "$IP" = "unknown" ]; then
  echo "⚠️  Could not detect your IP. Make sure your Mac is on WiFi."
else
  echo "✅ Server is running!"
  echo ""
  echo "👉 On your iPhone, open Safari and go to:"
  echo ""
  echo "   http://$IP:8080/GolfTracker.html"
  echo ""
  echo "📱 Then tap Share → Add to Home Screen"
  echo ""
  echo "-----------------------------------------"
  echo "⚠️  Keep this window open while using the app on iPhone"
  echo "    Press Ctrl+C to stop the server"
  echo "-----------------------------------------"
fi

python3 -m http.server 8080
