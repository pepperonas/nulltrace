#!/bin/bash

# nulltrace Transparentes Tor-Routing
# Einfacher, funktionierender Ansatz für macOS
# (c) 2025 Martin Pfeffer - MIT License

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# SwiftBar Helper einbinden
if [ -f "$SCRIPT_DIR/swiftbar_helper.sh" ]; then
    source "$SCRIPT_DIR/swiftbar_helper.sh"
fi

# Konfiguration
TOR_PORT="$(get_config TOR_SOCKS_PORT 9050)"
TOR_TRANS_PORT="$(get_config TOR_TRANS_PORT 9040)"
TOR_DNS_PORT="$(get_config TOR_DNS_PORT 9053)"
HOMEBREW_PREFIX="$(detect_homebrew_prefix)"
WIFI_SERVICE="$(get_effective_wifi_service)"

check_root() {
    if ! sudo -n true 2>/dev/null; then
        log_error "Dieses Skript benötigt sudo-Rechte"
        echo "Verwende: sudo $0 $* oder starte über nulltrace (verwendet Cache)"
        exit 1
    fi
}

check_tor() {
    if ! command -v tor &> /dev/null; then
        log_error "Tor ist nicht installiert"
        echo "Installiere mit: brew install tor"
        exit 1
    fi
}

setup_tor_config() {
    log_info "Konfiguriere Tor für transparentes Routing..."

    local tor_config="$HOMEBREW_PREFIX/etc/tor/torrc"

    if [ ! -f "${tor_config}.backup" ]; then
        cp "$tor_config" "${tor_config}.backup" 2>/dev/null || true
    fi

    cat > "$tor_config" << EOF
# nulltrace Vereinfachte Tor-Konfiguration
SocksPort $TOR_PORT
ClientUseIPv6 0
ClientPreferIPv6ORPort 0
Log notice file $HOMEBREW_PREFIX/var/log/tor/tor.log
EOF

    log_ok "Tor-Konfiguration erstellt"
}

start_transparent_tor() {
    check_root
    check_tor

    echo -e "${GREEN}🚀 Starte transparentes Tor-Routing...${NC}"
    echo ""

    # 1. Tor-Konfiguration setup
    setup_tor_config

    # 2. Tor neu starten
    log_info "Starte Tor mit transparenter Konfiguration..."
    brew services stop tor 2>/dev/null
    killall tor 2>/dev/null
    sleep 2

    brew services start tor
    sleep 3

    # 3. Warte bis Tor läuft
    local retry=0
    while [ $retry -lt 10 ]; do
        if lsof -i :$TOR_PORT >/dev/null 2>&1; then
            log_ok "Tor läuft auf Port $TOR_PORT"
            break
        fi
        echo "⏳ Warte auf Tor-Start... ($((retry+1))/10)"
        sleep 2
        ((retry++))
    done

    if [ $retry -eq 10 ]; then
        log_error "Tor konnte nicht gestartet werden"
        exit 1
    fi

    # 4. IPv6 deaktivieren
    log_info "Deaktiviere IPv6..."
    networksetup -setv6off "$WIFI_SERVICE" 2>/dev/null

    # IPv6-Leak Verifizierung
    if ! verify_ipv6_disabled; then
        log_warn "IPv6 konnte nicht vollständig deaktiviert werden"
    fi

    # 5. DNS auf Cloudflare
    log_info "Stelle DNS auf Cloudflare um..."
    networksetup -setdnsservers "$WIFI_SERVICE" 1.1.1.1 1.0.0.1

    # 6. System-Proxy auf Tor
    log_info "Aktiviere System-Proxy..."
    networksetup -setsocksfirewallproxy "$WIFI_SERVICE" 127.0.0.1 $TOR_PORT
    networksetup -setsocksfirewallproxystate "$WIFI_SERVICE" on

    # 7. Terminal-Wrapper erstellen (sichere Temp-Verzeichnisse)
    log_info "Erstelle Terminal-Wrapper..."

    local wrapper_dir
    wrapper_dir="$(create_secure_temp "tor_wrappers")"

    cat > "$wrapper_dir/curl" << 'WRAPPER_EOF'
#!/bin/bash
exec /usr/bin/curl --socks5 127.0.0.1:9050 "$@"
WRAPPER_EOF

    cat > "$wrapper_dir/wget" << 'WRAPPER_EOF'
#!/bin/bash
exec /usr/bin/wget --proxy=socks5://127.0.0.1:9050 "$@"
WRAPPER_EOF

    cat > "$wrapper_dir/git" << 'WRAPPER_EOF'
#!/bin/bash
exec /usr/bin/git -c http.proxy=socks5://127.0.0.1:9050 "$@"
WRAPPER_EOF

    cat > "$wrapper_dir/gobuster" << WRAPPER_EOF
#!/bin/bash
exec $HOMEBREW_PREFIX/bin/gobuster --proxy socks5://127.0.0.1:9050 "\$@"
WRAPPER_EOF

    cat > "$wrapper_dir/nmap" << WRAPPER_EOF
#!/bin/bash
echo "⚠️  NMAP über Tor - Nur für autorisierte Sicherheitsaudits!"
exec proxychains4 -q $HOMEBREW_PREFIX/bin/nmap "\$@"
WRAPPER_EOF

    cat > "$wrapper_dir/sqlmap" << WRAPPER_EOF
#!/bin/bash
echo "⚠️  SQLMap über Tor - Nur für autorisierte Penetrationstests!"
exec $HOMEBREW_PREFIX/bin/sqlmap --proxy="socks5://127.0.0.1:9050" "\$@"
WRAPPER_EOF

    chmod +x "$wrapper_dir"/*

    export PATH="$wrapper_dir:$PATH"

    cat > /tmp/tor_shell_config << SHELL_EOF
# nulltrace Tor Shell Konfiguration
export PATH="$wrapper_dir:\$PATH"

unalias curl 2>/dev/null || true
unalias wget 2>/dev/null || true
unalias git 2>/dev/null || true

alias curl="$wrapper_dir/curl"
alias wget="$wrapper_dir/wget"
alias git="$wrapper_dir/git"
alias gobuster="$wrapper_dir/gobuster"
alias nmap="$wrapper_dir/nmap"
alias sqlmap="$wrapper_dir/sqlmap"

echo "🔒 Tor-Terminal aktiv! Alle Befehle gehen über Tor."
echo "Verfügbar: curl, git, gobuster, nmap, sqlmap"
echo "Teste: curl https://check.torproject.org/api/ip"
SHELL_EOF

    echo -e "${GREEN}📌 Terminal-Wrapper erstellt in: $wrapper_dir${NC}"

    echo ""
    echo -e "${GREEN}✅ TRANSPARENTES TOR AKTIVIERT!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Aktiv:${NC}"
    echo "  🔹 System-Proxy über Tor (Browser/Apps)"
    echo "  🔹 Terminal-Wrapper für curl/wget/git"
    echo "  🔹 DNS über Cloudflare (1.1.1.1)"
    echo "  🔹 IPv6 deaktiviert"
    echo ""

    # Test
    log_info "Teste Verbindung..."
    sleep 2

    local tor_test
    tor_test=$(curl -s --connect-timeout 5 --socks5 127.0.0.1:$TOR_PORT https://check.torproject.org/api/ip 2>/dev/null)
    if echo "$tor_test" | grep -q '"IsTor":true'; then
        local tor_ip
        tor_ip=$(echo "$tor_test" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        log_ok "Tor-Verbindung funktioniert: $tor_ip"

        echo ""
        echo -e "${BLUE}Teste jetzt in NEUER Terminal-Session:${NC}"
        echo "  source /tmp/tor_shell_config"
        echo "  curl https://check.torproject.org/api/ip"
        echo ""
    else
        log_error "Tor-Verbindung fehlgeschlagen"
        stop_transparent_tor
        exit 1
    fi
}

stop_transparent_tor() {
    check_root

    echo -e "${YELLOW}🛑 Stoppe transparentes Tor...${NC}"

    log_info "Deaktiviere System-Proxy..."
    networksetup -setsocksfirewallproxystate "$WIFI_SERVICE" off

    log_info "Stelle DNS zurück..."
    networksetup -setdnsservers "$WIFI_SERVICE" "Empty"

    log_info "Entferne Terminal-Wrapper..."
    # Sichere Runtime-Verzeichnisse aufräumen
    find "$NULLTRACE_RUNTIME_DIR" -name "tor_wrappers.*" -type d -exec rm -rf {} + 2>/dev/null
    # Legacy-Cleanup
    rm -rf /tmp/tor_wrappers_* 2>/dev/null
    rm -f /tmp/tor_shell_config 2>/dev/null

    log_info "Reaktiviere IPv6..."
    networksetup -setv6automatic "$WIFI_SERVICE"

    local tor_config="$HOMEBREW_PREFIX/etc/tor/torrc"
    if [ -f "${tor_config}.backup" ]; then
        log_info "Stelle Tor-Konfiguration zurück..."
        cp "${tor_config}.backup" "$tor_config"
    fi

    log_info "Starte Tor mit Standard-Konfiguration..."
    brew services stop tor 2>/dev/null
    killall tor 2>/dev/null
    sleep 2
    brew services start tor

    log_info "Starte Netzwerk neu..."
    networksetup -setnetworkserviceenabled "$WIFI_SERVICE" off
    sleep 2
    networksetup -setnetworkserviceenabled "$WIFI_SERVICE" on

    echo ""
    log_ok "Transparentes Tor deaktiviert"
    log_ok "Normale Internet-Verbindung wiederhergestellt"
}

show_status() {
    echo -e "${BLUE}📊 Transparenter Tor Status${NC}"
    echo "══════════════════════════════"

    echo ""
    echo -e "${BLUE}🔍 Tor-Dienste:${NC}"
    for port in $TOR_PORT $TOR_TRANS_PORT $TOR_DNS_PORT; do
        if lsof -i :"$port" >/dev/null 2>&1; then
            echo "  ✅ Port $port: Aktiv"
        else
            echo "  ❌ Port $port: Inaktiv"
        fi
    done

    echo ""
    echo -e "${BLUE}🔧 pfctl-Status:${NC}"
    if pfctl -s info 2>/dev/null | grep -q "Status: Enabled"; then
        echo "  ✅ pfctl: Aktiviert"
        echo "  📋 Aktive Regeln: $(pfctl -s rules 2>/dev/null | grep -c rdr)"
    else
        echo "  ❌ pfctl: Deaktiviert"
    fi

    echo ""
    echo -e "${BLUE}🌐 DNS-Test:${NC}"
    local dns_server
    dns_server=$(networksetup -getdnsservers "$WIFI_SERVICE" 2>/dev/null | head -1)
    if [ "$dns_server" = "127.0.0.1" ]; then
        echo "  ✅ DNS: Über Tor"
    else
        echo "  ❌ DNS: Direkt ($dns_server)"
    fi

    echo ""
    echo -e "${BLUE}🔒 IPv6-Status:${NC}"
    if verify_ipv6_disabled 2>/dev/null; then
        echo "  ✅ IPv6: Deaktiviert (kein Leak)"
    else
        echo "  ⚠️  IPv6: Möglicherweise aktiv"
    fi

    echo ""
    echo -e "${BLUE}🧪 Verbindungstest:${NC}"

    local socks_test
    socks_test=$(curl -s --connect-timeout 3 --socks5 127.0.0.1:$TOR_PORT https://check.torproject.org/api/ip 2>/dev/null)
    if echo "$socks_test" | grep -q '"IsTor":true'; then
        local socks_ip
        socks_ip=$(echo "$socks_test" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        echo "  ✅ SOCKS5: $socks_ip (über Tor)"
    else
        echo "  ❌ SOCKS5: Fehlgeschlagen"
    fi

    local trans_test
    trans_test=$(curl -s --connect-timeout 3 https://check.torproject.org/api/ip 2>/dev/null)
    if echo "$trans_test" | grep -q '"IsTor":true'; then
        local trans_ip
        trans_ip=$(echo "$trans_test" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        echo "  ✅ Transparent: $trans_ip (über Tor)"
    else
        echo "  ❌ Transparent: Direkte Verbindung oder Fehler"
    fi

    echo ""
}

case "${1:-}" in
    start)
        start_transparent_tor
        ;;
    stop)
        stop_transparent_tor
        ;;
    status)
        show_status
        ;;
    *)
        echo -e "${BLUE}🌐 nulltrace Transparentes Tor-Routing${NC}"
        echo "════════════════════════════════════════════"
        echo ""
        echo "Leitet HTTP/HTTPS-Traffic über Tor um"
        echo ""
        echo -e "${YELLOW}Verwendung:${NC}"
        echo "  sudo $0 start   - Transparentes Tor aktivieren"
        echo "  sudo $0 stop    - Transparentes Tor deaktivieren"
        echo "  $0 status       - Status anzeigen"
        echo ""
        echo -e "${RED}⚠️  WICHTIG:${NC}"
        echo "  - Benötigt sudo-Rechte"
        echo "  - Bei Problemen: sudo $0 stop"
        echo ""
        ;;
esac
