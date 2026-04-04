#!/usr/bin/env bash

# nulltrace StatusBar Launcher
# Startet SwiftBar automatisch wenn Plugin installiert ist
# (c) 2025 Martin Pfeffer - MIT License

SWIFTBAR_APP="/Applications/SwiftBar.app"
PLUGIN_TARGET="$HOME/Library/Application Support/SwiftBar/Plugins/nulltrace_status.5s.sh"

# Migration: altes Plugin umbenennen
OLD_PLUGIN="$HOME/Library/Application Support/SwiftBar/Plugins/tor_status.5s.sh"
if [ -f "$OLD_PLUGIN" ] && [ ! -f "$PLUGIN_TARGET" ]; then
    mv "$OLD_PLUGIN" "$PLUGIN_TARGET"
fi

[ ! -f "$PLUGIN_TARGET" ] && exit 0
[ ! -d "$SWIFTBAR_APP" ] && exit 0
pgrep -f "SwiftBar" >/dev/null 2>&1 && exit 0

open "$SWIFTBAR_APP" 2>/dev/null &
exit 0
