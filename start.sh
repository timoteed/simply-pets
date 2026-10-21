#!/usr/bin/env bash
# SimplyPets Application Launcher

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

PORT="${1:-8080}"

echo "========================================================"
echo "🐾 Starting SimplyPets — Modern Pet & Medication Tracker"
echo "========================================================"

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is not installed or not in PATH."
    exit 1
fi

# Ensure flutter is in PATH if installed in ~/flutter/bin
if [ -d "$HOME/flutter/bin" ]; then
    export PATH="$HOME/flutter/bin:$PATH"
fi

# Build Flutter web app if build/web is missing
if [ ! -d "build/web" ] && command -v flutter &> /dev/null; then
    echo "📦 Building Flutter web application..."
    flutter build web --release
fi

echo "🚀 Launching SimplyPets on http://localhost:$PORT ..."

# Try to open the browser automatically in desktop environments if available
if command -v xdg-open &> /dev/null; then
    (sleep 1 && xdg-open "http://localhost:$PORT" 2>/dev/null) &
fi

exec python3 server.py "$PORT"
