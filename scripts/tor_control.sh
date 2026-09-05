#!/bin/bash

# nulltrace Tor Control Script für macOS
# Usage: ./tor_control.sh {start|stop|status|proxy-on|proxy-off|full-on|full-off}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Utils laden
source "$SCRIPT_DIR/lib/utils.sh"

# SwiftBar Helper einbinden
if [ -f "$SCRIPT_DIR/swiftbar_helper.sh" ]; then
    source "$SCRIPT_DIR/swiftbar_helper.sh"
fi

# Netzwerk-Interface automatisch erkennen
NETWORK_SERVICE="$(get_effective_wifi_service)"

start_tor() {
    echo "🚀 Starte Tor..."
    brew services start tor
    sleep 3

    if lsof -i :"$(get_config TOR_SOCKS_PORT 9050)" > /dev/null 2>&1; then
        echo "✅ Tor läuft auf Port $(get_config TOR_SOCKS_PORT 9050)"
        local test_result
        test_result=$(curl --socks5-hostname "localhost:$(get_config TOR_SOCKS_PORT 9050)" --connect-timeout 5 -s https://check.torproject.org/api/ip 2>/dev/null | grep '"IsTor":true')
        if [ -n "$test_result" ]; then
            echo "✅ Tor-Verbindung erfolgreich getestet"
        else
            echo "❌ Tor-Verbindung fehlgeschlagen"
        fi
    else
        echo "❌ Tor konnte nicht gestartet werden"
    fi
}

stop_tor() {
    echo "🛑 Stoppe Tor..."

    if brew services list | grep "tor" | grep -q "root"; then
        echo "⚠️  Tor läuft als root - verwende sudo"
        sudo brew services stop tor
    else
        brew services stop tor
    fi

    killall tor 2>/dev/null
    sudo killall tor 2>/dev/null
    sleep 1

    if ! pgrep -x "tor" > /dev/null 2>&1 && ! lsof -i :"$(get_config TOR_SOCKS_PORT 9050)" > /dev/null 2>&1; then
        echo "✅ Tor gestoppt"
    else
        echo "❌ Tor läuft noch - versuche forciertes Stoppen"
        sudo pkill -f tor 2>/dev/null
        sleep 2
        if ! pgrep -x "tor" > /dev/null 2>&1; then
            echo "✅ Tor forciert gestoppt"
        else
            echo "❌ Tor konnte nicht gestoppt werden"
        fi
        silent_restart_swiftbar 2>/dev/null
    fi
}

enable_system_proxy() {
    echo "🔒 Aktiviere systemweiten SOCKS-Proxy..."

    networksetup -setsocksfirewallproxy "$NETWORK_SERVICE" 127.0.0.1 "$(get_config TOR_SOCKS_PORT 9050)"
    networksetup -setsocksfirewallproxystate "$NETWORK_SERVICE" on

    echo "🌐 Konfiguriere zusätzliche Proxy-Einstellungen..."
    networksetup -setwebproxystate "$NETWORK_SERVICE" off
    networksetup -setsecurewebproxystate "$NETWORK_SERVICE" off

    echo "✅ Systemweiter SOCKS5-Proxy aktiviert für: $NETWORK_SERVICE"
    echo "📌 Wichtig: Nicht alle Apps respektieren System-Proxy-Einstellungen"
    echo "   → Safari, Chrome: ✅ Funktioniert"
    echo "   → Terminal (curl, wget): ❌ Braucht explizite SOCKS5-Config"
    echo "   → Für Terminal: Verwende proxychains4 oder torcurl"
}

disable_system_proxy() {
    echo "🔓 Deaktiviere systemweiten SOCKS-Proxy..."
    networksetup -setsocksfirewallproxystate "$NETWORK_SERVICE" off
    networksetup -setwebproxystate "$NETWORK_SERVICE" off 2>/dev/null
    networksetup -setsecurewebproxystate "$NETWORK_SERVICE" off 2>/dev/null

    echo "✅ Systemweiter Proxy deaktiviert für: $NETWORK_SERVICE"
    echo "🌐 Normale Internet-Verbindung wiederhergestellt"
}

show_status() {
    echo "📊 Tor Status:"
    echo "=============="

    local service_status
    service_status=$(brew services list | grep tor | awk '{print $2}')
    echo "Service: $service_status"

    if lsof -i :"$(get_config TOR_SOCKS_PORT 9050)" > /dev/null 2>&1; then
        echo "Port $(get_config TOR_SOCKS_PORT 9050): ✅ Aktiv"
    else
        echo "Port $(get_config TOR_SOCKS_PORT 9050): ❌ Inaktiv"
    fi

    local proxy_state
    proxy_state=$(networksetup -getsocksfirewallproxy "$NETWORK_SERVICE" | grep "Enabled: Yes")
    if [ -n "$proxy_state" ]; then
        echo "System-Proxy: ✅ Aktiviert"
        networksetup -getsocksfirewallproxy "$NETWORK_SERVICE" | grep -E "(Server|Port)"
    else
        echo "System-Proxy: ❌ Deaktiviert"
    fi

    echo ""
    echo "🔍 Verbindungstest:"
    local tor_port
    tor_port="$(get_config TOR_SOCKS_PORT 9050)"
    local current_ip
    current_ip=$(secure_curl "https://check.torproject.org/api/ip" --socks5-hostname "localhost:$tor_port" 2>/dev/null | jq -r '.IP' 2>/dev/null || echo "Fehler")
    local is_tor
    is_tor=$(secure_curl "https://check.torproject.org/api/ip" --socks5-hostname "localhost:$tor_port" 2>/dev/null | jq -r '.IsTor' 2>/dev/null || echo "false")

    if [ "$is_tor" = "true" ]; then
        echo "Aktuelle IP: $current_ip (🔒 über Tor)"
    else
        echo "Aktuelle IP: $current_ip (🌐 direkte Verbindung)"
    fi
}

test_connection() {
    echo "🧪 Teste Tor-Verbindung..."
    local tor_port
    tor_port="$(get_config TOR_SOCKS_PORT 9050)"

    echo "Test 1: Direkter SOCKS5-Test"
    local socks_result
    socks_result=$(curl -4 --socks5-hostname "localhost:$tor_port" --connect-timeout 10 -s https://check.torproject.org/api/ip 2>/dev/null)
    if echo "$socks_result" | grep -q '"IsTor":true'; then
        echo "✅ SOCKS5: Funktioniert"
        echo "$socks_result" | jq . 2>/dev/null || echo "$socks_result"
    else
        echo "❌ SOCKS5: Fehlgeschlagen"
    fi

    echo ""
    echo "Test 2: ProxyChains-Test"
    if command -v proxychains4 > /dev/null 2>&1; then
        local proxy_result
        proxy_result=$(proxychains4 curl -4 --connect-timeout 10 -s https://check.torproject.org/api/ip 2>/dev/null)
        if echo "$proxy_result" | grep -q '"IsTor":true'; then
            echo "✅ ProxyChains: Funktioniert"
            echo "$proxy_result" | jq . 2>/dev/null || echo "$proxy_result"
        else
            echo "❌ ProxyChains: Fehlgeschlagen"
        fi
    else
        echo "⚠️  ProxyChains nicht installiert"
    fi

    echo ""
    echo "Test 3: System-Proxy-Test (funktioniert nicht mit curl)"
    echo "ℹ️  Curl nutzt System-Proxy nicht. Teste mit Safari:"
    echo "   → Öffne Safari und gehe zu: https://check.torproject.org"
    echo "   → Oder nutze: proxychains4 curl https://check.torproject.org/api/ip"
}

new_identity() {
    echo "🔄 Fordere neue Tor-Identität an..."

    if ! pgrep -x "tor" > /dev/null 2>&1; then
        echo "❌ Tor läuft nicht. Starte Tor zuerst."
        return 1
    fi

    # Signal an Tor senden (auch als _nulltrace_tor User)
    if pkill -HUP tor 2>/dev/null || sudo pkill -HUP -u _nulltrace_tor tor 2>/dev/null; then
        echo "✅ Signal gesendet. Warte auf neue Verbindung..."
        sleep 5

        local tor_port
        tor_port="$(get_config TOR_SOCKS_PORT 9050)"
        local new_ip
        new_ip=$(curl -4 -s --connect-timeout 10 --socks5-hostname "127.0.0.1:$tor_port" https://icanhazip.com 2>/dev/null)
        if [ -n "$new_ip" ]; then
            echo "✅ Neue IP-Adresse: $new_ip"

            local location_info
            location_info=$(curl -4 -s --connect-timeout 10 --socks5-hostname "127.0.0.1:$tor_port" "https://ipapi.co/${new_ip}/json/" 2>/dev/null)
            if [ -n "$location_info" ]; then
                local city country
                city=$(echo "$location_info" | jq -r '.city // empty' 2>/dev/null)
                country=$(echo "$location_info" | jq -r '.country_name // empty' 2>/dev/null)
                [ -n "$city" ] && [ -n "$country" ] && echo "📍 Neuer Standort: $city, $country"
            fi
        else
            echo "⚠️  Konnte neue IP nicht abrufen"
        fi
    else
        echo "❌ Fehler beim Senden des Signals"
        return 1
    fi
}

case "${1:-}" in
    start)
        start_tor
        ;;
    stop)
        stop_tor
        ;;
    status)
        show_status
        ;;
    proxy-on)
        enable_system_proxy
        ;;
    proxy-off)
        disable_system_proxy
        ;;
    full-on)
        start_tor
        sleep 2
        enable_system_proxy
        echo ""
        test_connection
        ;;
    full-off)
        disable_system_proxy
        stop_tor
        ;;
    test)
        test_connection
        ;;
    new-identity|newnym)
        new_identity
        ;;
    *)
        echo "🔧 Tor Control Script"
        echo "===================="
        echo "Usage: $0 {start|stop|status|proxy-on|proxy-off|full-on|full-off|test|new-identity}"
        echo ""
        echo "Befehle:"
        echo "  start      - Nur Tor-Service starten"
        echo "  stop       - Nur Tor-Service stoppen"
        echo "  proxy-on   - Nur System-Proxy aktivieren"
        echo "  proxy-off  - Nur System-Proxy deaktivieren"
        echo "  full-on    - Tor starten + System-Proxy aktivieren"
        echo "  full-off   - Tor stoppen + System-Proxy deaktivieren"
        echo "  status     - Status anzeigen"
        echo "  test       - Verbindung testen"
        echo "  new-identity - Neue Tor-Identität (neuer Exit Node)"
        echo ""
        echo "Erkanntes Netzwerk-Interface: $NETWORK_SERVICE"
        ;;
esac
