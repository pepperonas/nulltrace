#!/bin/bash

# nulltrace SwiftBar Helper Functions
# Stellt Funktionen zum automatischen Neustarten von SwiftBar bereit

SWIFTBAR_APP="/Applications/SwiftBar.app"

restart_swiftbar() {
    if [ ! -d "$SWIFTBAR_APP" ]; then
        return 0
    fi

    if pgrep -f "SwiftBar" >/dev/null 2>&1; then
        sudo killall SwiftBar 2>/dev/null
        sleep 0.5
        open "$SWIFTBAR_APP" 2>/dev/null &
    else
        open "$SWIFTBAR_APP" 2>/dev/null &
    fi
}

refresh_swiftbar() {
    if pgrep -f "SwiftBar" >/dev/null 2>&1; then
        osascript -e 'tell application "SwiftBar" to refresh' 2>/dev/null || true
    fi
}

silent_restart_swiftbar() {
    restart_swiftbar >/dev/null 2>&1
}

export -f restart_swiftbar
export -f refresh_swiftbar
export -f silent_restart_swiftbar
