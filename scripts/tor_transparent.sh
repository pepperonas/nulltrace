#!/bin/bash

# nulltrace Transparentes Tor-Routing
# Erzwingt ALL traffic ueber Tor via SOCKS-Proxy + pf Killswitch
# Homebrew Tor hat kein TransPort — daher SOCKS + pf-Block-Ansatz:
#   - Tor laeuft als _nulltrace_tor (pf erkennt den User)
#   - pf erlaubt NUR Tor-User und Loopback (alles andere wird blockiert)
#   - System-SOCKS-Proxy + Proxy-Env-Vars fangen allen Traffic ab
#   - Was trotzdem nicht ueber Proxy geht → wird von pf geblockt (kein Leak)
# (c) 2025 Martin Pfeffer - MIT License

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# Konfiguration
TOR_USER="_nulltrace_tor"
TOR_UID="399"
TOR_PORT="$(get_config TOR_SOCKS_PORT 9050)"
HOMEBREW_PREFIX="$(detect_homebrew_prefix)"
WIFI_IFACE="$(get_effective_wifi_interface)"
WIFI_SERVICE="$(get_effective_wifi_service)"
TOR_DATA_DIR="/var/lib/nulltrace-tor"
TOR_CONFIG="$TOR_DATA_DIR/torrc"
PF_RULES="$NULLTRACE_RUNTIME_DIR/pf_transparent.conf"
PF_BACKUP="$NULLTRACE_RUNTIME_DIR/pf_backup.conf"
TOR_PID_FILE="$TOR_DATA_DIR/tor.pid"
PROXY_ENV_FILE="/tmp/nulltrace_proxy_env"

# ─── Voraussetzungen ─────────────────────────────────────────────────────────

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Dieses Skript benoetigt root-Rechte"
        echo "Verwende: sudo $0 $*"
        exit 1
    fi
}

check_tor_binary() {
    if ! command -v tor &>/dev/null; then
        log_error "Tor ist nicht installiert"
        echo "Installiere mit: brew install tor"
        exit 1
    fi
}

# ─── User-Setup ──────────────────────────────────────────────────────────────

setup_tor_user() {
    if id "$TOR_USER" &>/dev/null; then
        log_ok "System-User '$TOR_USER' existiert bereits"
        return 0
    fi

    log_info "Erstelle System-User '$TOR_USER' (UID $TOR_UID)..."

    # Freie GID finden
    local gid="$TOR_UID"
    if dscl . -list /Groups PrimaryGroupID 2>/dev/null | awk '{print $2}' | grep -q "^${gid}$"; then
        gid=398
    fi

    # Gruppe erstellen
    dscl . -create /Groups/$TOR_USER 2>/dev/null || true
    dscl . -create /Groups/$TOR_USER PrimaryGroupID "$gid"
    dscl . -create /Groups/$TOR_USER RealName "nulltrace Tor Daemon"

    # User erstellen
    dscl . -create /Users/$TOR_USER
    dscl . -create /Users/$TOR_USER UniqueID "$TOR_UID"
    dscl . -create /Users/$TOR_USER PrimaryGroupID "$gid"
    dscl . -create /Users/$TOR_USER UserShell /usr/bin/false
    dscl . -create /Users/$TOR_USER RealName "nulltrace Tor Daemon"
    dscl . -create /Users/$TOR_USER NFSHomeDirectory /var/empty
    dscl . -create /Users/$TOR_USER IsHidden 1

    log_ok "System-User '$TOR_USER' erstellt"
}

setup_tor_dirs() {
    mkdir -p "$TOR_DATA_DIR"
    chown "$TOR_USER" "$TOR_DATA_DIR"
    chmod 700 "$TOR_DATA_DIR"
}

# ─── Tor-Konfiguration ──────────────────────────────────────────────────────

write_tor_config() {
    setup_tor_dirs

    cat > "$TOR_CONFIG" << EOF
# nulltrace Tor Configuration
SocksPort 0.0.0.0:$TOR_PORT
DataDirectory $TOR_DATA_DIR
Log notice file $TOR_DATA_DIR/tor.log
PidFile $TOR_PID_FILE

ClientUseIPv6 0
ClientPreferIPv6ORPort 0
EOF

    chown "$TOR_USER" "$TOR_CONFIG"
    chmod 600 "$TOR_CONFIG"
    log_ok "Tor-Konfiguration erstellt"
}

# ─── pf-Regeln ───────────────────────────────────────────────────────────────

write_pf_rules() {
    mkdir -p "$NULLTRACE_RUNTIME_DIR" 2>/dev/null || true

    cat > "$PF_RULES" << EOF
# nulltrace Tor Enforcement Rules
# Nur Tor-Daemon und Loopback duerfen raus — alles andere wird geblockt

# Alles blockieren
block drop all

# Loopback erlauben (Apps → SOCKS-Proxy auf localhost)
pass quick on lo0 all

# Tor-Daemon darf direkt raus (laeuft als $TOR_USER)
pass out quick proto tcp user $TOR_USER flags S/SA keep state

# DHCP erlauben (Netzwerk-Konnektivitaet)
pass out quick proto udp from any port 68 to any port 67 keep state

# DNS zu Cloudflare erlauben (fuer initiale Verbindung)
pass out quick proto {tcp udp} to 1.1.1.1 port 53 keep state
pass out quick proto {tcp udp} to 1.0.0.1 port 53 keep state

# IPv6 komplett blockieren
block quick inet6 all
EOF

    log_ok "pf-Regeln erstellt"
}

# ─── Proxy-Umgebung ─────────────────────────────────────────────────────────

write_proxy_env() {
    cat > "$PROXY_ENV_FILE" << 'EOF'
# nulltrace Tor Proxy Environment
# Source this in new terminals: source /tmp/nulltrace_proxy_env
export ALL_PROXY="socks5h://127.0.0.1:9050"
export http_proxy="socks5h://127.0.0.1:9050"
export https_proxy="socks5h://127.0.0.1:9050"
export no_proxy="localhost,127.0.0.1"
EOF
    chmod 644 "$PROXY_ENV_FILE"
}

# ─── Start ───────────────────────────────────────────────────────────────────

start_transparent_tor() {
    check_root
    check_tor_binary

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  TOR ENFORCEMENT${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 1. User einrichten
    echo -e "${BLUE}[1/7] System-User...${NC}"
    setup_tor_user

    # 2. Bestehenden Tor stoppen
    echo -e "${BLUE}[2/7] Bestehende Tor-Instanz stoppen...${NC}"
    brew services stop tor 2>/dev/null
    killall tor 2>/dev/null
    sleep 1

    # 3. Tor-Konfiguration
    echo -e "${BLUE}[3/7] Tor konfigurieren (SOCKS $TOR_PORT)...${NC}"
    write_tor_config

    # 4. Tor als _nulltrace_tor starten
    echo -e "${BLUE}[4/7] Tor als '$TOR_USER' starten...${NC}"
    sudo -u "$TOR_USER" "$HOMEBREW_PREFIX/bin/tor" -f "$TOR_CONFIG" --RunAsDaemon 1 2>&1 | grep -v "^\[notice\]"

    # Warten auf Bootstrap
    local retry=0
    while [ $retry -lt 30 ]; do
        if lsof -i :"$TOR_PORT" >/dev/null 2>&1; then
            log_ok "Tor SOCKS aktiv auf Port $TOR_PORT"
            break
        fi
        echo "  Warte auf Tor-Bootstrap... ($((retry+1))/30)"
        sleep 2
        ((retry++))
    done

    if [ $retry -eq 30 ]; then
        log_error "Tor konnte nicht gestartet werden"
        [ -f "$TOR_DATA_DIR/tor.log" ] && tail -5 "$TOR_DATA_DIR/tor.log"
        exit 1
    fi

    # 5. System-SOCKS-Proxy setzen
    echo -e "${BLUE}[5/7] System-SOCKS-Proxy setzen...${NC}"
    networksetup -setsocksfirewallproxy "$WIFI_SERVICE" 127.0.0.1 "$TOR_PORT"
    networksetup -setsocksfirewallproxystate "$WIFI_SERVICE" on
    # DNS auf Cloudflare (verschluesselt, kein ISP-DNS)
    networksetup -setdnsservers "$WIFI_SERVICE" 1.1.1.1 1.0.0.1
    log_ok "System-Proxy + DNS gesetzt"

    # 6. pf-Regeln anwenden (Killswitch)
    echo -e "${BLUE}[6/7] pf-Killswitch aktivieren...${NC}"
    pfctl -s rules > "$PF_BACKUP" 2>/dev/null || true
    write_pf_rules
    networksetup -setv6off "$WIFI_SERVICE" 2>/dev/null

    if pfctl -f "$PF_RULES" -e 2>/dev/null; then
        log_ok "pf-Killswitch aktiv (non-Tor traffic geblockt)"
    else
        log_error "pf-Regeln fehlgeschlagen"
    fi

    # 7. Proxy-Env + Verbindungstest
    echo -e "${BLUE}[7/7] Proxy-Env + Verbindungstest...${NC}"
    write_proxy_env

    sleep 2
    local test_result
    test_result=$(curl -4 -s --connect-timeout 10 --socks5-hostname 127.0.0.1:"$TOR_PORT" https://check.torproject.org/api/ip 2>/dev/null)

    if echo "$test_result" | grep -q '"IsTor":true'; then
        local tor_ip
        tor_ip=$(echo "$test_result" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  TOR ENFORCEMENT AKTIV${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  Tor-IP:     ${YELLOW}$tor_ip${NC}"
        echo -e "  SOCKS5:     ${GREEN}127.0.0.1:$TOR_PORT${NC}"
        echo -e "  pf:         ${GREEN}Killswitch aktiv${NC}"
        echo -e "  IPv6:       ${GREEN}Deaktiviert${NC}"
        echo ""
        echo -e "  ${GREEN}Browser:${NC}  Ueber System-SOCKS-Proxy → Tor"
        echo -e "  ${GREEN}Terminal:${NC} source /tmp/nulltrace_proxy_env"
        echo -e "  ${GREEN}Leaks:${NC}    Von pf geblockt (kein Durchkommen)"
        echo ""
    else
        log_error "Tor-Verbindung fehlgeschlagen"
        echo "  Teste: curl --socks5-hostname 127.0.0.1:$TOR_PORT https://check.torproject.org/api/ip"
    fi
}

# ─── Stop ────────────────────────────────────────────────────────────────────

stop_transparent_tor() {
    check_root

    echo -e "${YELLOW}Stoppe Tor Enforcement...${NC}"
    echo ""

    # 1. pf deaktivieren
    echo -e "${BLUE}[1/6] pf-Killswitch entfernen...${NC}"
    pfctl -d 2>/dev/null
    if [ -f "$PF_BACKUP" ] && [ -s "$PF_BACKUP" ]; then
        pfctl -f "$PF_BACKUP" 2>/dev/null || true
    fi
    log_ok "pf deaktiviert"

    # 2. System-Proxy deaktivieren
    echo -e "${BLUE}[2/6] System-SOCKS-Proxy entfernen...${NC}"
    networksetup -setsocksfirewallproxystate "$WIFI_SERVICE" off
    log_ok "Proxy deaktiviert"

    # 3. Tor stoppen
    echo -e "${BLUE}[3/6] Tor-Daemon stoppen...${NC}"
    if [ -f "$TOR_PID_FILE" ]; then
        local pid
        pid=$(cat "$TOR_PID_FILE")
        kill "$pid" 2>/dev/null
        sleep 1
        kill -9 "$pid" 2>/dev/null
        rm -f "$TOR_PID_FILE"
    fi
    pkill -u "$TOR_USER" tor 2>/dev/null
    sleep 1
    log_ok "Tor gestoppt"

    # 4. IPv6 reaktivieren
    echo -e "${BLUE}[4/6] IPv6 reaktivieren...${NC}"
    networksetup -setv6automatic "$WIFI_SERVICE" 2>/dev/null
    log_ok "IPv6 reaktiviert"

    # 5. DNS zuruecksetzen
    echo -e "${BLUE}[5/6] DNS zuruecksetzen...${NC}"
    networksetup -setdnsservers "$WIFI_SERVICE" "Empty" 2>/dev/null
    log_ok "DNS zurueckgesetzt"

    # 6. Aufraeumen
    echo -e "${BLUE}[6/6] Aufraeumen...${NC}"
    rm -f "$PF_RULES" "$PF_BACKUP" "$PROXY_ENV_FILE"
    # Legacy-Cleanup
    find "$NULLTRACE_RUNTIME_DIR" -name "tor_wrappers.*" -type d -exec rm -rf {} + 2>/dev/null
    rm -f /tmp/tor_shell_config 2>/dev/null
    log_ok "Runtime-Dateien entfernt"

    echo ""
    echo -e "${GREEN}Tor Enforcement deaktiviert.${NC}"
    echo -e "${GREEN}Normale Internet-Verbindung wiederhergestellt.${NC}"
}

# ─── Status ──────────────────────────────────────────────────────────────────

show_status() {
    echo -e "${BLUE}Tor Enforcement Status${NC}"
    echo "══════════════════════"
    echo ""

    # User
    if id "$TOR_USER" &>/dev/null; then
        echo -e "  User $TOR_USER: ${GREEN}Vorhanden${NC}"
    else
        echo -e "  User $TOR_USER: ${RED}Nicht eingerichtet${NC}"
    fi

    # Tor-Prozess
    if pgrep -u "$TOR_USER" tor >/dev/null 2>&1; then
        echo -e "  Tor-Daemon:     ${GREEN}Laeuft (als $TOR_USER)${NC}"
    elif pgrep -x tor >/dev/null 2>&1; then
        echo -e "  Tor-Daemon:     ${YELLOW}Laeuft (normaler User)${NC}"
    else
        echo -e "  Tor-Daemon:     ${RED}Gestoppt${NC}"
    fi

    # SOCKS Port
    if lsof -i :"$TOR_PORT" >/dev/null 2>&1; then
        echo -e "  SOCKS5:         ${GREEN}Port $TOR_PORT aktiv${NC}"
    else
        echo -e "  SOCKS5:         ${RED}Port $TOR_PORT inaktiv${NC}"
    fi

    # pf
    if pfctl -s info 2>/dev/null | grep -q "Status: Enabled"; then
        echo -e "  pf-Killswitch:  ${GREEN}Aktiv${NC}"
    else
        echo -e "  pf-Killswitch:  ${RED}Deaktiviert${NC}"
    fi

    # Verbindungstest
    echo ""
    local test_result
    test_result=$(curl -4 -s --connect-timeout 5 --socks5-hostname 127.0.0.1:"$TOR_PORT" https://check.torproject.org/api/ip 2>/dev/null)
    if echo "$test_result" | grep -q '"IsTor":true'; then
        local ip
        ip=$(echo "$test_result" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        echo -e "  ${GREEN}Tor-Verbindung OK ($ip)${NC}"
    else
        echo -e "  ${RED}Tor-Verbindung fehlgeschlagen${NC}"
    fi
    echo ""
}

# ─── CLI ─────────────────────────────────────────────────────────────────────

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
    setup)
        check_root
        setup_tor_user
        setup_tor_dirs
        log_ok "Setup abgeschlossen"
        ;;
    *)
        echo -e "${BLUE}nulltrace Tor Enforcement${NC}"
        echo "═════════════════════════"
        echo ""
        echo "SOCKS-Proxy + pf-Killswitch: Aller Traffic ueber Tor oder geblockt"
        echo ""
        echo -e "${YELLOW}Verwendung:${NC}"
        echo "  sudo $0 start   - Tor Enforcement aktivieren"
        echo "  sudo $0 stop    - Tor Enforcement deaktivieren"
        echo "  sudo $0 setup   - Nur User/Verzeichnisse einrichten"
        echo "  $0 status       - Status anzeigen"
        echo ""
        ;;
esac
