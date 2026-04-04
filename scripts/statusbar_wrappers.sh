#!/bin/bash

# nulltrace StatusBar-Wrapper - halten Terminal offen
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NULLTRACE_DIR="$(dirname "$SCRIPT_DIR")"

# Globaler Sudo-Cache vor allen Aktionen
start_sudo_cache() {
    if sudo -n dscacheutil -flushcache >/dev/null 2>&1; then
        return 0
    fi

    if ! sudo -n true 2>/dev/null; then
        "$SCRIPT_DIR/sudo_cache_helper.sh" start
    fi
}

# Funktion um Terminal offen zu halten
keep_terminal_open() {
    echo ""
    echo "Drücke Enter zum Schließen oder Cmd+W..."
    read -r
}

case "${1:-}" in
    "status")
        "$NULLTRACE_DIR/nulltrace.sh" status
        keep_terminal_open
        ;;
    "privacy-on")
        "$NULLTRACE_DIR/nulltrace.sh" privacy-on
        keep_terminal_open
        ;;
    "privacy-off")
        "$NULLTRACE_DIR/nulltrace.sh" privacy-off
        keep_terminal_open
        ;;
    "privacy-ultra")
        echo "⚠️  Ultra Privacy Mode wurde vereinfacht."
        echo "Verwende stattdessen: privacy-on"
        echo ""
        "$NULLTRACE_DIR/nulltrace.sh" privacy-on
        keep_terminal_open
        ;;
    "tor-status")
        "$NULLTRACE_DIR/scripts/tor_control.sh" status
        keep_terminal_open
        ;;
    "tor-transparent-status")
        "$NULLTRACE_DIR/scripts/tor_transparent.sh" status
        keep_terminal_open
        ;;
    "ipinfo")
        "$NULLTRACE_DIR/nulltrace.sh" ipinfo
        keep_terminal_open
        ;;
    "security-full")
        "$NULLTRACE_DIR/nulltrace.sh" security full
        keep_terminal_open
        ;;
    "nulltrace")
        cd "$NULLTRACE_DIR" && ./nulltrace.sh
        ;;
    "tor-terminal")
        echo "🔒 Tor-Terminal Konfiguration"
        echo "=========================="
        echo ""
        echo "Nach transparentem Tor aktivieren:"
        echo "  ./nulltrace.sh tor trans-on"
        echo ""
        echo "Dann in neuer Terminal-Session:"
        echo "  source /tmp/tor_shell_config"
        echo "  curl https://check.torproject.org/api/ip"
        echo ""
        echo "Verfügbare Tor-Befehle:"
        echo "  curl, git, gobuster, nmap, sqlmap"
        echo ""
        keep_terminal_open
        ;;
    *)
        echo "Usage: $0 [status|privacy-on|privacy-off|tor-status|ipinfo|nulltrace|tor-terminal]"
        echo ""
        echo "nulltrace StatusBar-Wrapper"
        ;;
esac
