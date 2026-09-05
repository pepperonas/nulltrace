#!/bin/bash

# nulltrace Tor Status Bar Plugin for SwiftBar
# Shows Tor connection status in macOS menu bar
# File should be named: nulltrace_status.5s.sh (updates every 5 seconds)

# Dynamische Pfaderkennung
# Plugin läuft aus SwiftBar Plugins-Verzeichnis, nicht aus dem Repo
NULLTRACE_DIR=""

# 1. Gespeicherter Install-Pfad
if [ -f "$HOME/.nulltrace/install_path" ]; then
    NULLTRACE_DIR="$(cat "$HOME/.nulltrace/install_path")"
fi

# 2. Bekannte Orte
if [ -z "$NULLTRACE_DIR" ] || [ ! -f "$NULLTRACE_DIR/nulltrace.sh" ]; then
    for dir in "$HOME/claude/nulltrace" "$HOME/nulltrace" "$HOME/apps/nulltrace"; do
        if [ -f "$dir/nulltrace.sh" ]; then
            NULLTRACE_DIR="$dir"
            break
        fi
    done
fi

# 3. Fallback: relativ zum Script
if [ -z "$NULLTRACE_DIR" ] || [ ! -f "$NULLTRACE_DIR/nulltrace.sh" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    NULLTRACE_DIR="$(dirname "$SCRIPT_DIR")"
fi

TOR_CONTROL="$NULLTRACE_DIR/scripts/tor_control.sh"
NULLTRACE_MAIN="$NULLTRACE_DIR/nulltrace.sh"
WRAPPER="$NULLTRACE_DIR/scripts/statusbar_wrappers.sh"

# Check if Tor is running
tor_running() {
    pgrep -x "tor" > /dev/null 2>&1 || lsof -i :9050 > /dev/null 2>&1
}

# Check if we're connected through Tor
tor_connected() {
    local result
    result=$(curl -4 -s --connect-timeout 2 --socks5-hostname localhost:9050 https://check.torproject.org/api/ip 2>/dev/null | grep -o '"IsTor":true' 2>/dev/null)
    [ -n "$result" ]
}

# Check if system proxy is enabled
proxy_enabled() {
    networksetup -getsocksfirewallproxy "Wi-Fi" 2>/dev/null | grep "Enabled: Yes" > /dev/null 2>&1
}

# Get current IP (HTTPS only)
get_ip() {
    if tor_connected; then
        curl -4 -s --connect-timeout 2 --socks5-hostname localhost:9050 https://icanhazip.com 2>/dev/null || echo "Unknown"
    else
        curl -4 -s --connect-timeout 2 https://icanhazip.com 2>/dev/null || echo "Unknown"
    fi
}

# Get location (HTTPS only)
get_location() {
    local ip="$1"
    if [ "$ip" = "Unknown" ]; then
        echo "Unknown"
        return
    fi

    local location_info
    if tor_connected; then
        location_info=$(curl -4 -s --connect-timeout 3 --socks5-hostname localhost:9050 "https://ipapi.co/${ip}/json/" 2>/dev/null)
    else
        location_info=$(curl -4 -s --connect-timeout 3 "https://ipapi.co/${ip}/json/" 2>/dev/null)
    fi

    if [ -n "$location_info" ]; then
        local city country
        city=$(echo "$location_info" | jq -r '.city // empty' 2>/dev/null)
        country=$(echo "$location_info" | jq -r '.country_name // empty' 2>/dev/null)

        if [ -n "$city" ] && [ -n "$country" ]; then
            echo "$city, $country"
        elif [ -n "$country" ]; then
            echo "$country"
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
}

# Main status check
if tor_running; then
    if tor_connected; then
        echo "🧅"
        echo "---"
        echo "✅ Verbunden via Tor | color=green"

        tor_info=$(curl -4 -s --connect-timeout 2 --socks5-hostname localhost:9050 https://check.torproject.org/api/ip 2>/dev/null)
        if [ -n "$tor_info" ]; then
            tor_ip=$(echo "$tor_info" | jq -r '.IP // empty' 2>/dev/null)
            if [ -n "$tor_ip" ]; then
                echo "🌐 IP: $tor_ip | color=green"
                tor_location=$(get_location "$tor_ip")
                echo "📍 Standort: $tor_location | color=green"
            fi
        fi
    else
        echo "🟡"
        echo "---"
        echo "⚠️  Tor läuft, aber nicht verbunden | color=orange"

        if proxy_enabled; then
            echo "✅ System-Proxy aktiviert | color=green"
        else
            echo "❌ System-Proxy deaktiviert | color=red"
        fi

        current_ip=$(get_ip)
        echo "🌐 Echte IP: $current_ip | color=orange"
        current_location=$(get_location "$current_ip")
        echo "📍 Standort: $current_location | color=orange"
    fi
else
    echo "⚫"
    echo "---"
    echo "❌ Tor ist nicht aktiv | color=red"
    current_ip=$(get_ip)
    echo "�� Echte IP: $current_ip | color=red"
    current_location=$(get_location "$current_ip")
    echo "📍 Standort: $current_location | color=red"
fi

echo "---"

# Quick actions
echo "🚀 Tor Aktionen"
echo "-- Tor starten | bash='$TOR_CONTROL' param1=start terminal=false refresh=true"
echo "-- Tor stoppen | bash='$TOR_CONTROL' param1=stop terminal=false refresh=true"
echo "---"
echo "🔒 System-weites Tor"
echo "-- Browser/Apps aktivieren | bash='$TOR_CONTROL' param1=full-on terminal=false refresh=true"
echo "-- Browser/Apps deaktivieren | bash='$TOR_CONTROL' param1=full-off terminal=false refresh=true"
echo "---"
echo "🛡️  Transparentes Tor"
echo "-- Alles über Tor (sudo) | bash='$NULLTRACE_MAIN' param1=tor param2=trans-on terminal=true refresh=true"
echo "-- Transparentes Tor aus (sudo) | bash='$NULLTRACE_MAIN' param1=tor param2=trans-off terminal=true refresh=true"
echo "---"

# Privacy status
echo "🔒 Privacy"
echo "-- Status anzeigen | bash='$WRAPPER' param1=status terminal=true refresh=false"
echo "-- 🔥 Privacy ON | bash='$WRAPPER' param1=privacy-on terminal=true refresh=false"
echo "-- 🌐 Privacy OFF | bash='$WRAPPER' param1=privacy-off terminal=true refresh=false"
echo "---"

# Additional info
echo "📊 Details"
echo "-- Tor Status | bash='$WRAPPER' param1=tor-status terminal=true refresh=false"
echo "-- Transparentes Tor Status | bash='$WRAPPER' param1=tor-transparent-status terminal=true refresh=false"
echo "-- IP Info | bash='$WRAPPER' param1=ipinfo terminal=true refresh=false"
echo "-- Security Check | bash='$WRAPPER' param1=security-full terminal=true refresh=false"
echo "---"

# Settings
echo "⚙️  Einstellungen"
echo "-- 🔄 Neuer Standort (Exit Node) | bash='$TOR_CONTROL' param1=new-identity terminal=false refresh=true"
echo "-- nulltrace öffnen | bash='$WRAPPER' param1=nulltrace terminal=true refresh=false"
echo "-- Terminal Tor-Konfiguration | bash='$WRAPPER' param1=tor-terminal terminal=true refresh=false"
echo "---"
echo "Aktualisieren | refresh=true"
