#!/bin/bash

# nulltrace Kill-Switch
# Blockiert allen Traffic wenn Tor/VPN-Verbindung abbricht
# Verwendet macOS pfctl (Packet Filter)
# (c) 2025 Martin Pfeffer - MIT License

# Utils laden
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh" 2>/dev/null

KILLSWITCH_PF_RULES="$NULLTRACE_RUNTIME_DIR/pf_killswitch.conf"
KILLSWITCH_PID_FILE="$NULLTRACE_RUNTIME_DIR/killswitch_monitor.pid"
KILLSWITCH_PF_BACKUP="/tmp/.nulltrace_pf_backup"

enable_killswitch() {
    ensure_runtime_dir

    local tor_port
    tor_port="$(get_config TOR_SOCKS_PORT 9050)"

    # Backup aktuelle pf-Konfiguration
    sudo pfctl -s rules > "$KILLSWITCH_PF_BACKUP" 2>/dev/null

    # Kill-Switch Regeln erstellen
    cat > "$KILLSWITCH_PF_RULES" << EOF
# nulltrace Kill-Switch Regeln
# Blockiert allen Traffic ausser Tor/VPN

# Loopback erlauben
set skip on lo0

# Default: alles blockieren
block all

# Lokal erlauben
pass quick on lo0 all

# Tor SOCKS-Port erlauben
pass out quick proto tcp to 127.0.0.1 port $tor_port

# Tor-Daemon von nulltrace darf direkt raus. Die Portliste unten (9001/9030)
# reicht nicht: die meisten Relays hoeren auf 443.
pass out quick proto tcp user _nulltrace_tor flags S/SA keep state

# VPN-Tunnel-Interfaces erlauben (utun*)
pass quick on utun0 all
pass quick on utun1 all
pass quick on utun2 all
pass quick on utun3 all

# DNS über Tor erlauben (Cloudflare als Fallback)
pass out quick proto {tcp udp} to 1.1.1.1 port 53
pass out quick proto {tcp udp} to 1.0.0.1 port 53

# DHCP erlauben — BEIDE Richtungen. Ohne die "in"-Regel verwirft "block all"
# die Antwort des Servers (67 -> 68) und der Mac bekommt nach einem
# Link-Wechsel nie wieder eine IP-Adresse.
pass out quick proto udp from any port 68 to any port 67 no state
pass in  quick proto udp from any port 67 to any port 68 no state

# Lokales Netzwerk erlauben (für Tor-Relay-Verbindungen)
pass out quick proto tcp to any port 9001
pass out quick proto tcp to any port 9030
EOF

    # Regeln aktivieren. NICHT den Exit-Code von "pfctl -f datei -e" pruefen:
    # laeuft pf bereits, meldet der Aufruf "pf already enabled" und Exit 1 —
    # obwohl die Regeln geladen wurden.
    if pf_load_and_enable "$KILLSWITCH_PF_RULES"; then
        log_ok "Kill-Switch aktiviert - nur Tor/VPN-Traffic erlaubt"
        log_to_file "INFO" "Kill-Switch aktiviert"
        return 0
    else
        log_error "Kill-Switch konnte nicht aktiviert werden"
        return 1
    fi
}

disable_killswitch() {
    # Monitor stoppen
    stop_monitor

    # pf deaktivieren oder auf Backup zurücksetzen
    if [ -f "$KILLSWITCH_PF_BACKUP" ] && [ -s "$KILLSWITCH_PF_BACKUP" ]; then
        sudo pfctl -f "$KILLSWITCH_PF_BACKUP" 2>/dev/null
    fi
    sudo pfctl -d 2>/dev/null

    # Aufräumen
    rm -f "$KILLSWITCH_PF_RULES" "$KILLSWITCH_PF_BACKUP"

    log_ok "Kill-Switch deaktiviert - normaler Traffic wiederhergestellt"
    log_to_file "INFO" "Kill-Switch deaktiviert"
}

# Verbindungsmonitor
check_connection() {
    local tor_port
    tor_port="$(get_config TOR_SOCKS_PORT 9050)"

    # Prüfe ob Tor läuft
    if is_tor_running; then
        # Prüfe ob Tor-Verbindung funktioniert
        local tor_check
        # --socks5-hostname, NICHT --socks5: letzteres loest DNS lokal auf, was
        # der Kill-Switch blockt — der Monitor haelt Tor dann faelschlich fuer tot.
        tor_check=$(secure_curl "https://check.torproject.org/api/ip" --socks5-hostname "localhost:$tor_port" 2>/dev/null)
        if echo "$tor_check" | grep -q '"IsTor":true'; then
            return 0
        fi
    fi

    # Prüfe ob VPN aktiv ist
    if is_vpn_active; then
        return 0
    fi

    return 1
}

start_monitor() {
    ensure_runtime_dir

    # Prüfe ob Monitor bereits läuft
    if [ -f "$KILLSWITCH_PID_FILE" ]; then
        local pid
        pid=$(cat "$KILLSWITCH_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "Kill-Switch Monitor läuft bereits (PID: $pid)"
            return 0
        fi
        rm -f "$KILLSWITCH_PID_FILE"
    fi

    (
        trap 'rm -f "$KILLSWITCH_PID_FILE"; exit' INT TERM EXIT
        echo $$ > "$KILLSWITCH_PID_FILE"

        local consecutive_failures=0

        while true; do
            if ! check_connection; then
                consecutive_failures=$((consecutive_failures + 1))

                if [ $consecutive_failures -ge 3 ]; then
                    log_error "Verbindung verloren! Aktiviere Kill-Switch..."
                    log_to_file "WARN" "Verbindungsverlust erkannt, Kill-Switch aktiviert"
                    enable_killswitch

                    # macOS Benachrichtigung
                    osascript -e 'display notification "Tor/VPN-Verbindung verloren! Traffic blockiert." with title "nulltrace Kill-Switch"' 2>/dev/null
                fi
            else
                consecutive_failures=0
            fi

            sleep 5
        done
    ) &

    log_ok "Kill-Switch Monitor gestartet"
}

stop_monitor() {
    if [ -f "$KILLSWITCH_PID_FILE" ]; then
        local pid
        pid=$(cat "$KILLSWITCH_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            log_ok "Kill-Switch Monitor gestoppt"
        fi
        rm -f "$KILLSWITCH_PID_FILE"
    fi
}

show_status() {
    echo -e "${BLUE}Kill-Switch Status${NC}"
    echo "══════════════════"
    echo ""

    # pf-Status
    if pf_is_enabled; then
        echo -e "  pfctl: ${GREEN}Aktiviert${NC}"
        local rule_count
        rule_count=$(sudo pfctl -s rules 2>/dev/null | grep -c "block\|pass")
        echo "  Aktive Regeln: $rule_count"
    else
        echo -e "  pfctl: ${RED}Deaktiviert${NC}"
    fi

    # Monitor-Status
    if [ -f "$KILLSWITCH_PID_FILE" ]; then
        local pid
        pid=$(cat "$KILLSWITCH_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Monitor: ${GREEN}Aktiv (PID: $pid)${NC}"
        else
            echo -e "  Monitor: ${RED}Inaktiv (verwaiste PID-Datei)${NC}"
            rm -f "$KILLSWITCH_PID_FILE"
        fi
    else
        echo -e "  Monitor: ${RED}Inaktiv${NC}"
    fi

    # Verbindungsstatus
    echo ""
    if check_connection; then
        echo -e "  Verbindung: ${GREEN}OK${NC}"
    else
        echo -e "  Verbindung: ${RED}Nicht über Tor/VPN${NC}"
    fi
    echo ""
}

# CLI-Interface
case "$1" in
    enable|on)
        enable_killswitch
        ;;
    disable|off)
        disable_killswitch
        ;;
    monitor-start)
        start_monitor
        ;;
    monitor-stop)
        stop_monitor
        ;;
    status)
        show_status
        ;;
    *)
        echo "nulltrace Kill-Switch"
        echo "====================="
        echo ""
        echo "Usage: $0 {enable|disable|monitor-start|monitor-stop|status}"
        echo ""
        echo "  enable         - Kill-Switch aktivieren (blockiert non-Tor/VPN Traffic)"
        echo "  disable        - Kill-Switch deaktivieren"
        echo "  monitor-start  - Verbindungsmonitor starten (auto-aktiviert Kill-Switch)"
        echo "  monitor-stop   - Verbindungsmonitor stoppen"
        echo "  status         - Status anzeigen"
        ;;
esac
