#!/bin/bash

# nulltrace Transparentes Tor-Routing
# Erzwingt ALL traffic über Tor via pf (packet filter)
# Benötigt dedizierten _nulltrace_tor User für Loop-Vermeidung
# (c) 2025 Martin Pfeffer - MIT License

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# Konfiguration
TOR_USER="_nulltrace_tor"
TOR_UID="399"
TOR_GID="399"
TOR_PORT="$(get_config TOR_SOCKS_PORT 9050)"
TOR_TRANS_PORT="$(get_config TOR_TRANS_PORT 9040)"
TOR_DNS_PORT="$(get_config TOR_DNS_PORT 9053)"
HOMEBREW_PREFIX="$(detect_homebrew_prefix)"
WIFI_IFACE="$(get_effective_wifi_interface)"
WIFI_SERVICE="$(get_effective_wifi_service)"
TOR_DATA_DIR="/var/lib/nulltrace-tor"
TOR_CONFIG="$TOR_DATA_DIR/torrc"
PF_RULES="$NULLTRACE_RUNTIME_DIR/pf_transparent.conf"
PF_BACKUP="$NULLTRACE_RUNTIME_DIR/pf_backup.conf"
TOR_PID_FILE="$TOR_DATA_DIR/tor.pid"

# ─── Voraussetzungen ─────────────────────────────────────────────────────────

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "Dieses Skript benötigt root-Rechte"
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

    # Freie GID finden (399 kann belegt sein)
    local gid="$TOR_GID"
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

    # User verstecken (nicht im Login-Screen anzeigen)
    dscl . -create /Users/$TOR_USER IsHidden 1

    log_ok "System-User '$TOR_USER' erstellt (UID $TOR_UID, GID $gid)"
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
# nulltrace Transparent Tor Configuration
SocksPort $TOR_PORT
TransPort 127.0.0.1:$TOR_TRANS_PORT
DNSPort 127.0.0.1:$TOR_DNS_PORT
AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10

DataDirectory $TOR_DATA_DIR
Log notice file $TOR_DATA_DIR/tor.log
PidFile $TOR_PID_FILE

# Sicherheit
ClientUseIPv6 0
ClientPreferIPv6ORPort 0
SafeSocks 1
EOF

    chown "$TOR_USER" "$TOR_CONFIG"
    chmod 600 "$TOR_CONFIG"
    log_ok "Tor-Konfiguration erstellt ($TOR_CONFIG)"
}

# ─── pf-Regeln ───────────────────────────────────────────────────────────────

write_pf_rules() {
    ensure_runtime_dir 2>/dev/null || mkdir -p "$NULLTRACE_RUNTIME_DIR" 2>/dev/null || true

    cat > "$PF_RULES" << EOF
# nulltrace Transparent Tor Routing
# Leitet ALLEN Traffic über Tor um

# Interface
ext_if = "$WIFI_IFACE"

# Tor-Ports
tor_trans = "$TOR_TRANS_PORT"
tor_dns = "$TOR_DNS_PORT"

# NAT: TCP auf TransPort umleiten
rdr pass on lo0 proto tcp from any to !127.0.0.0/8 -> 127.0.0.1 port \$tor_trans

# NAT: DNS auf DNSPort umleiten
rdr pass on lo0 proto udp from any to any port 53 -> 127.0.0.1 port \$tor_dns

# Alles blockieren
block drop all

# Loopback erlauben
pass quick on lo0 all

# Tor-Daemon darf direkt raus (läuft als $TOR_USER)
pass out quick proto tcp user $TOR_USER flags S/SA keep state

# DHCP erlauben
pass out quick proto udp from any port 68 to any port 67 keep state

# Ausgehenden TCP über lo0 routen (für TransPort-Interception)
pass out on \$ext_if route-to (lo0 127.0.0.1) proto tcp from any to !127.0.0.0/8 flags S/SA keep state

# Ausgehenden DNS über lo0 routen (für DNSPort-Interception)
pass out on \$ext_if route-to (lo0 127.0.0.1) proto udp from any to any port 53 keep state

# IPv6 komplett blockieren
block quick inet6 all
EOF

    log_ok "pf-Regeln erstellt"
}

# ─── Start ───────────────────────────────────────────────────────────────────

start_transparent_tor() {
    check_root
    check_tor_binary

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  TRANSPARENT TOR ROUTING${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # 1. User einrichten
    echo -e "${BLUE}[1/6] System-User...${NC}"
    setup_tor_user
    setup_tor_dirs

    # 2. Bestehenden Tor stoppen
    echo -e "${BLUE}[2/6] Bestehende Tor-Instanz stoppen...${NC}"
    brew services stop tor 2>/dev/null
    killall tor 2>/dev/null
    sleep 1

    # 3. Tor-Konfiguration
    echo -e "${BLUE}[3/6] Tor konfigurieren (TransPort $TOR_TRANS_PORT, DNSPort $TOR_DNS_PORT)...${NC}"
    write_tor_config

    # 4. Tor als _nulltrace_tor starten
    echo -e "${BLUE}[4/6] Tor als User '$TOR_USER' starten...${NC}"
    sudo -u "$TOR_USER" "$HOMEBREW_PREFIX/bin/tor" -f "$TOR_CONFIG" --RunAsDaemon 1

    # Warten auf Bootstrap
    local retry=0
    while [ $retry -lt 20 ]; do
        if lsof -i :"$TOR_TRANS_PORT" >/dev/null 2>&1; then
            log_ok "Tor TransPort aktiv auf $TOR_TRANS_PORT"
            break
        fi
        echo "  Warte auf Tor-Bootstrap... ($((retry+1))/20)"
        sleep 2
        ((retry++))
    done

    if [ $retry -eq 20 ]; then
        log_error "Tor konnte nicht gestartet werden"
        echo "Log: $TOR_DATA_DIR/tor.log"
        [ -f "$TOR_DATA_DIR/tor.log" ] && tail -5 "$TOR_DATA_DIR/tor.log"
        exit 1
    fi

    # 5. pf-Regeln anwenden
    echo -e "${BLUE}[5/6] pf-Regeln aktivieren...${NC}"

    # Backup aktuelle pf-Konfiguration
    pfctl -s rules > "$PF_BACKUP" 2>/dev/null || true

    write_pf_rules

    # IPv6 deaktivieren
    networksetup -setv6off "$WIFI_SERVICE" 2>/dev/null

    if pfctl -f "$PF_RULES" -e 2>/dev/null; then
        log_ok "pf transparent routing aktiv"
    else
        log_error "pf-Regeln konnten nicht aktiviert werden"
        stop_transparent_tor
        exit 1
    fi

    # 6. Verbindungstest
    echo -e "${BLUE}[6/6] Verbindungstest...${NC}"
    sleep 3

    local test_result
    test_result=$(curl -4 -s --connect-timeout 10 https://check.torproject.org/api/ip 2>/dev/null)

    if echo "$test_result" | grep -q '"IsTor":true'; then
        local tor_ip
        tor_ip=$(echo "$test_result" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}  TRANSPARENT TOR AKTIV${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  Tor-IP:      ${YELLOW}$tor_ip${NC}"
        echo -e "  TransPort:   ${GREEN}127.0.0.1:$TOR_TRANS_PORT${NC}"
        echo -e "  DNSPort:     ${GREEN}127.0.0.1:$TOR_DNS_PORT${NC}"
        echo -e "  SOCKS5:      ${GREEN}127.0.0.1:$TOR_PORT${NC}"
        echo -e "  IPv6:        ${GREEN}Deaktiviert${NC}"
        echo ""
        echo -e "  ${YELLOW}ALLER Traffic laeuft jetzt ueber Tor.${NC}"
        echo -e "  ${YELLOW}Deaktivieren: sudo nulltrace.sh privacy-off${NC}"
        echo ""
    else
        log_error "Transparentes Routing fehlgeschlagen - Traffic geht NICHT ueber Tor"
        echo "Teste: curl https://check.torproject.org/api/ip"
        echo "Falls Problem: sudo $0 stop"
    fi
}

# ─── Stop ────────────────────────────────────────────────────────────────────

stop_transparent_tor() {
    check_root

    echo -e "${YELLOW}Stoppe transparentes Tor-Routing...${NC}"
    echo ""

    # 1. pf deaktivieren
    echo -e "${BLUE}[1/5] pf-Regeln entfernen...${NC}"
    pfctl -d 2>/dev/null
    if [ -f "$PF_BACKUP" ] && [ -s "$PF_BACKUP" ]; then
        pfctl -f "$PF_BACKUP" 2>/dev/null || true
    fi
    log_ok "pf deaktiviert"

    # 2. Tor stoppen
    echo -e "${BLUE}[2/5] Tor-Daemon stoppen...${NC}"
    if [ -f "$TOR_PID_FILE" ]; then
        local pid
        pid=$(cat "$TOR_PID_FILE")
        kill "$pid" 2>/dev/null
        sleep 1
        kill -9 "$pid" 2>/dev/null
        rm -f "$TOR_PID_FILE"
    fi
    # Alle Tor-Prozesse des _nulltrace_tor Users beenden
    pkill -u "$TOR_USER" tor 2>/dev/null
    sleep 1
    log_ok "Tor gestoppt"

    # 3. IPv6 reaktivieren
    echo -e "${BLUE}[3/5] IPv6 reaktivieren...${NC}"
    networksetup -setv6automatic "$WIFI_SERVICE" 2>/dev/null
    log_ok "IPv6 reaktiviert"

    # 4. DNS zuruecksetzen
    echo -e "${BLUE}[4/5] DNS zuruecksetzen...${NC}"
    networksetup -setdnsservers "$WIFI_SERVICE" "Empty" 2>/dev/null
    log_ok "DNS zurueckgesetzt"

    # 5. Aufraeumen
    echo -e "${BLUE}[5/5] Aufraeumen...${NC}"
    rm -f "$PF_RULES" "$PF_BACKUP" "$TOR_CONFIG"
    # Legacy-Cleanup
    find "$NULLTRACE_RUNTIME_DIR" -name "tor_wrappers.*" -type d -exec rm -rf {} + 2>/dev/null
    rm -f /tmp/tor_shell_config 2>/dev/null
    log_ok "Runtime-Dateien entfernt"

    echo ""
    echo -e "${GREEN}Transparentes Tor-Routing deaktiviert.${NC}"
    echo -e "${GREEN}Normale Internet-Verbindung wiederhergestellt.${NC}"
}

# ─── Status ──────────────────────────────────────────────────────────────────

show_status() {
    echo -e "${BLUE}Transparent Tor Status${NC}"
    echo "══════════════════════"
    echo ""

    # User
    if id "$TOR_USER" &>/dev/null; then
        echo -e "  User $TOR_USER: ${GREEN}Vorhanden${NC}"
    else
        echo -e "  User $TOR_USER: ${RED}Nicht eingerichtet${NC}"
        echo "  Setup: sudo $0 setup"
    fi

    # Tor-Prozess
    if pgrep -u "$TOR_USER" tor >/dev/null 2>&1; then
        echo -e "  Tor-Daemon:     ${GREEN}Laeuft (als $TOR_USER)${NC}"
    elif pgrep -x tor >/dev/null 2>&1; then
        echo -e "  Tor-Daemon:     ${YELLOW}Laeuft (normaler User)${NC}"
    else
        echo -e "  Tor-Daemon:     ${RED}Gestoppt${NC}"
    fi

    # Ports
    for label_port in "TransPort:$TOR_TRANS_PORT" "DNSPort:$TOR_DNS_PORT" "SOCKS:$TOR_PORT"; do
        local label="${label_port%%:*}"
        local port="${label_port##*:}"
        if lsof -i :"$port" >/dev/null 2>&1; then
            printf "  %-14s ${GREEN}Port %s aktiv${NC}\n" "$label:" "$port"
        else
            printf "  %-14s ${RED}Port %s inaktiv${NC}\n" "$label:" "$port"
        fi
    done

    # pf
    echo ""
    if pfctl -s info 2>/dev/null | grep -q "Status: Enabled"; then
        local rdr_count
        rdr_count=$(pfctl -s nat 2>/dev/null | grep -c "rdr" || echo "0")
        local filter_count
        filter_count=$(pfctl -s rules 2>/dev/null | grep -c "route-to" || echo "0")
        echo -e "  pf:            ${GREEN}Aktiv ($rdr_count NAT, $filter_count route-to)${NC}"
    else
        echo -e "  pf:            ${RED}Deaktiviert${NC}"
    fi

    # Verbindungstest
    echo ""
    echo -e "${BLUE}  Verbindungstest:${NC}"
    local test_result
    test_result=$(curl -4 -s --connect-timeout 5 https://check.torproject.org/api/ip 2>/dev/null)
    if echo "$test_result" | grep -q '"IsTor":true'; then
        local ip
        ip=$(echo "$test_result" | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        echo -e "  ${GREEN}Traffic laeuft ueber Tor ($ip)${NC}"
    else
        echo -e "  ${RED}Traffic geht NICHT ueber Tor${NC}"
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
        echo -e "${BLUE}nulltrace Transparentes Tor-Routing${NC}"
        echo "════════════════════════════════════"
        echo ""
        echo "Leitet ALLEN Netzwerk-Traffic ueber Tor"
        echo ""
        echo -e "${YELLOW}Verwendung:${NC}"
        echo "  sudo $0 start   - Transparentes Tor aktivieren"
        echo "  sudo $0 stop    - Transparentes Tor deaktivieren"
        echo "  sudo $0 setup   - Nur User/Verzeichnisse einrichten"
        echo "  $0 status       - Status anzeigen"
        echo ""
        echo -e "${RED}Hinweis:${NC}"
        echo "  Erstellt System-User '$TOR_USER' fuer Loop-Vermeidung."
        echo "  pf leitet allen TCP/DNS durch Tor's TransPort/DNSPort."
        echo "  Bei Problemen: sudo $0 stop"
        echo ""
        ;;
esac
