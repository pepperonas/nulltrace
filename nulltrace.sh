#!/bin/bash

# nulltrace Control Script
# Zentrales Steuerungsskript für Privacy-Tools
# (c) 2025 Martin Pfeffer - MIT License

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Shared Utility Library laden
source "$SCRIPT_DIR/scripts/lib/utils.sh"

# Konfiguration laden
load_config

# Migration von xxxOS (einmalig)
migrate_from_xxxos

# Install-Pfad speichern
save_install_path "$SCRIPT_DIR"

# Script-Pfade
TOR_SCRIPT="$SCRIPT_DIR/scripts/tor_control.sh"
MAC_SCRIPT="$SCRIPT_DIR/scripts/mac_spoofer.sh"
PRIVACY_SCRIPT="$SCRIPT_DIR/scripts/privacy_enhance.sh"
PROXYCHAINS_SCRIPT="$SCRIPT_DIR/scripts/proxychains_setup.sh"
VPN_SCRIPT="$SCRIPT_DIR/scripts/vpn_control.sh"
KILLSWITCH_SCRIPT="$SCRIPT_DIR/scripts/lib/killswitch.sh"

# Sudo-Berechtigung am Anfang anfordern und für Session cachen
cache_sudo() {
    # IMMER erst prüfen ob sudoers-Konfiguration funktioniert
    if sudo -n dscacheutil -flushcache >/dev/null 2>&1; then
        return 0
    fi

    # Verwende globalen Sudo-Cache nur wenn sudoers nicht funktioniert
    if ! sudo -n true 2>/dev/null; then
        "$SCRIPT_DIR/scripts/sudo_cache_helper.sh" start
    fi
}

# Cleanup-Funktion
cleanup() {
    # Runtime-Dateien aufräumen bei Exit
    :
}
trap cleanup EXIT INT TERM HUP

# Banner anzeigen
show_banner() {
echo ""
echo -e "${PURPLE}  ███╗   ██╗██╗   ██╗██╗     ██╗  ████████╗██████╗  █████╗  ██████╗███████╗${NC}"
echo -e "${PURPLE}  ████╗  ██║██║   ██║██║     ██║  ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝${NC}"
echo -e "${PURPLE}  ██╔██╗ ██║██║   ██║██║     ██║     ██║   ██████╔╝███████║██║     █████╗${NC}"
echo -e "${PURPLE}  ██║╚██╗██║██║   ██║██║     ██║     ██║   ██╔══██╗██╔══██║██║     ██╔══╝${NC}"
echo -e "${PURPLE}  ██║ ╚████║╚██████╔╝███████╗███████╗██║   ██║  ██║██║  ██║╚██████╗███████╗${NC}"
echo -e "${PURPLE}  ╚═╝  ╚═══╝ ╚═════╝ ╚══════╝╚══════╝╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝${NC}"
echo -e "  ${GREEN}─────────────────────────────────────────────────────────────────────────${NC}"
echo -e "        ${YELLOW}Fire & Forget Privacy for macOS${NC}  ${RED}·${NC}  ${BLUE}v3.0${NC}  ${RED}·${NC}  ${GREEN}Martin Pfeffer${NC}"
echo ""
}

# Hilfe anzeigen
show_help() {
    echo -e "${BLUE}  ╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}  ║                    nulltrace HILFE                         ║${NC}"
    echo -e "${BLUE}  ╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Hauptfunktionen:${NC}"
    echo ""
    echo -e "  ${YELLOW}./nulltrace.sh${NC}              → Interaktives Menü"
    echo -e "  ${YELLOW}./nulltrace.sh privacy-on${NC}   → 🔒 Maximale Privatsphäre aktivieren"
    echo -e "  ${YELLOW}./nulltrace.sh privacy-off${NC}  → 🌐 Normale Einstellungen wiederherstellen"
    echo -e "  ${YELLOW}./nulltrace.sh status${NC}       → 📊 Privacy-Status anzeigen"
    echo -e "  ${YELLOW}./nulltrace.sh help${NC}         → Diese Hilfe anzeigen"
    echo ""
    echo -e "${GREEN}🔥 Was macht 'privacy-on'?${NC}"
    echo -e "  ${GREEN}✓${NC} MAC-Adresse ändern (bleibt permanent)"
    echo -e "  ${GREEN}✓${NC} Hostname auf '$(get_config PRIVACY_HOSTNAME Lisa)' setzen"
    echo -e "  ${GREEN}✓${NC} Tor system-weit aktivieren"
    echo -e "  ${GREEN}✓${NC} DNS auf Cloudflare umstellen"
    echo -e "  ${GREEN}✓${NC} Firewall mit Stealth-Mode"
    echo -e "  ${GREEN}✓${NC} Tracking-Domains blockieren"
    echo -e "  ${GREEN}✓${NC} Kill-Switch (optional, konfigurierbar)"
    echo -e "  ${GREEN}✓${NC} Browser-Daten bleiben erhalten!"
    echo ""
    echo -e "${GREEN}🔄 Was macht 'privacy-off'?${NC}"
    echo -e "  ${GREEN}✓${NC} Original-Hostname wiederherstellen"
    echo -e "  ${GREEN}✓${NC} Tor deaktivieren"
    echo -e "  ${GREEN}✓${NC} DNS-Einstellungen zurücksetzen"
    echo -e "  ${GREEN}✓${NC} Tracking-Blocks entfernen"
    echo -e "  ${GREEN}✓${NC} Kill-Switch deaktivieren"
    echo -e "  ${YELLOW}!${NC} MAC-Adresse bleibt geändert (Sicherheit)"
    echo ""
    echo -e "${GREEN}Erweiterte Befehle:${NC}"
    echo -e "  ${YELLOW}./nulltrace.sh killswitch on${NC}   → Kill-Switch aktivieren"
    echo -e "  ${YELLOW}./nulltrace.sh killswitch off${NC}  → Kill-Switch deaktivieren"
    echo ""
    echo -e "${RED}💡 Tipp:${NC} Für maximale Sicherheit verwende den Tor Browser!"
    echo ""
}

# Dependency-Check und Auto-Installation
check_dependencies() {
    local missing_deps=()
    local missing_scripts=()

    echo -e "${BLUE}🔍 Prüfe System-Abhängigkeiten...${NC}"

    command -v curl >/dev/null 2>&1 || missing_deps+=("curl")
    command -v jq >/dev/null 2>&1 || missing_deps+=("jq")
    command -v networksetup >/dev/null 2>&1 || missing_deps+=("networksetup")
    command -v ifconfig >/dev/null 2>&1 || missing_deps+=("ifconfig")
    command -v scutil >/dev/null 2>&1 || missing_deps+=("scutil")

    if ! command -v brew >/dev/null 2>&1; then
        missing_deps+=("homebrew")
    fi

    command -v tor >/dev/null 2>&1 || missing_deps+=("tor")
    command -v proxychains4 >/dev/null 2>&1 || missing_deps+=("proxychains-ng")

    [ ! -f "$TOR_SCRIPT" ] && missing_scripts+=("tor_control.sh")
    [ ! -f "$MAC_SCRIPT" ] && missing_scripts+=("mac_spoofer.sh")
    [ ! -f "$PRIVACY_SCRIPT" ] && missing_scripts+=("privacy_enhance.sh")

    if [ ${#missing_deps[@]} -eq 0 ] && [ ${#missing_scripts[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ Alle Abhängigkeiten vorhanden${NC}"
        return 0
    fi

    echo ""
    echo -e "${YELLOW}⚠️  Fehlende Abhängigkeiten gefunden:${NC}"

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        echo "Fehlende Programme:"
        for dep in "${missing_deps[@]}"; do
            echo "  ❌ $dep"
        done
    fi

    if [ ${#missing_scripts[@]} -gt 0 ]; then
        echo ""
        echo "Fehlende Skripte:"
        for script in "${missing_scripts[@]}"; do
            echo "  ❌ $script"
        done
        echo -e "${RED}Kritische Skripte fehlen! Prüfe die Installation.${NC}"
        exit 1
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        read -p "Möchtest du die fehlenden Abhängigkeiten automatisch installieren? (j/N): " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Jj]$ ]]; then
            install_dependencies "${missing_deps[@]}"
        else
            echo -e "${YELLOW}⚠️  Einige Funktionen funktionieren möglicherweise nicht korrekt.${NC}"
            echo ""
        fi
    fi
}

install_dependencies() {
    local deps=("$@")

    echo -e "${BLUE}📦 Installiere fehlende Abhängigkeiten...${NC}"
    echo ""

    for dep in "${deps[@]}"; do
        case "$dep" in
            homebrew)
                echo "🍺 Installiere Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                ;;
            tor)
                echo "🧅 Installiere Tor..."
                brew install tor
                ;;
            jq)
                echo "📋 Installiere jq..."
                brew install jq
                ;;
            proxychains-ng)
                echo "🔗 Installiere ProxyChains..."
                brew install proxychains-ng
                ;;
            curl)
                echo "🌐 curl sollte bereits installiert sein..."
                ;;
            *)
                echo "❓ Unbekannte Abhängigkeit: $dep"
                ;;
        esac
    done

    echo ""
    echo -e "${GREEN}✅ Installation abgeschlossen!${NC}"
    echo ""
}

# Tor-Kontrolle
handle_tor() {
    local transparent_script="$SCRIPT_DIR/scripts/tor_transparent.sh"

    if [ -z "${1:-}" ]; then
        echo -e "${RED}Fehler: Keine Aktion angegeben${NC}"
        echo "Verwende: tor {start|stop|status|full-on|full-off|trans-on|trans-off|test}"
        return 1
    fi

    case "$1" in
        trans-on)
            if [ ! -f "$transparent_script" ]; then
                echo -e "${RED}❌ Transparenter Tor-Skript nicht gefunden${NC}"
                return 1
            fi
            cache_sudo
            echo -e "${YELLOW}⚠️  Transparentes Tor benötigt sudo-Rechte${NC}"
            sudo "$transparent_script" start
            ;;
        trans-off)
            if [ ! -f "$transparent_script" ]; then
                echo -e "${RED}❌ Transparenter Tor-Skript nicht gefunden${NC}"
                return 1
            fi
            cache_sudo
            echo -e "${YELLOW}⚠️  Transparentes Tor benötigt sudo-Rechte${NC}"
            sudo "$transparent_script" stop
            ;;
        trans-status)
            if [ ! -f "$transparent_script" ]; then
                echo -e "${RED}❌ Transparenter Tor-Skript nicht gefunden${NC}"
                return 1
            fi
            "$transparent_script" status
            ;;
        full-on|full-off)
            cache_sudo
            "$TOR_SCRIPT" "$1"
            ;;
        *)
            "$TOR_SCRIPT" "$1"
            ;;
    esac
}

# Status-Ausgaben
show_progress() {
    echo -e "${GREEN}🔥 $1${NC}"
}

show_success() {
    echo -e "${GREEN}$1${NC}"
}

# Hostname setzen
set_hostname_privacy() {
    local hostname
    hostname="$(get_config PRIVACY_HOSTNAME Lisa)"
    echo "🔄 Setze Hostname auf '$hostname'..."

    if [ ! -f "$HOME/.nulltrace/original_hostname" ]; then
        mkdir -p "$HOME/.nulltrace"
        scutil --get ComputerName > "$HOME/.nulltrace/original_hostname" 2>/dev/null || echo "MacBook" > "$HOME/.nulltrace/original_hostname"
    fi

    sudo scutil --set ComputerName "$hostname"
    sudo scutil --set LocalHostName "$hostname"
    sudo scutil --set HostName "$hostname"
    echo "✅ Hostname gesetzt auf: $hostname"
}

# Original-Hostname wiederherstellen
restore_original_hostname() {
    echo "🔄 Stelle Original-Hostname wieder her..."

    if [ -f "$HOME/.nulltrace/original_hostname" ]; then
        local original_name
        original_name=$(cat "$HOME/.nulltrace/original_hostname")
        sudo scutil --set ComputerName "$original_name"
        sudo scutil --set LocalHostName "$original_name"
        sudo scutil --set HostName "$original_name"
        echo "✅ Hostname wiederhergestellt: $original_name"
    else
        echo "⚠️  Keine Original-Hostname-Datei gefunden - verwende Standard"
        sudo scutil --set ComputerName "MacBook"
        sudo scutil --set LocalHostName "MacBook"
        sudo scutil --set HostName "MacBook"
    fi
}

# DNS-Cache leeren
clear_dns_cache() {
    echo "🧹 Leere DNS-Cache..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null
    echo "✅ DNS-Cache geleert"
}

# Firewall aktivieren
enable_firewall() {
    echo "🔥 Aktiviere Firewall mit Stealth-Mode..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    echo "✅ Firewall aktiviert"
}

# DNS auf Privacy-Provider setzen
set_privacy_dns() {
    local provider
    provider="$(get_config DNS_PROVIDER cloudflare)"
    local dns1 dns2
    local service
    service="$(get_effective_wifi_service)"

    case "$provider" in
        cloudflare)
            dns1="1.1.1.1"; dns2="1.0.0.1"
            echo "🔒 Setze Privacy-DNS (Cloudflare)..."
            ;;
        quad9)
            dns1="9.9.9.9"; dns2="149.112.112.112"
            echo "🔒 Setze Privacy-DNS (Quad9)..."
            ;;
        custom)
            dns1="$(get_config CUSTOM_DNS_1 1.1.1.1)"
            dns2="$(get_config CUSTOM_DNS_2 1.0.0.1)"
            echo "🔒 Setze Privacy-DNS (Custom)..."
            ;;
        *)
            dns1="1.1.1.1"; dns2="1.0.0.1"
            echo "🔒 Setze Privacy-DNS (Cloudflare)..."
            ;;
    esac

    networksetup -setdnsservers "$service" "$dns1" "$dns2"
    echo "✅ DNS geändert zu $dns1"
}

# DNS-Einstellungen zurücksetzen
reset_dns_settings() {
    echo "🔄 Setze DNS-Einstellungen zurück..."
    local service
    service="$(get_effective_wifi_service)"
    networksetup -setdnsservers "$service" "Empty"
    echo "✅ DNS-Einstellungen zurückgesetzt"
}

# Tracking-Domains blockieren
block_tracking() {
    echo "🚫 Blockiere Tracking-Domains..."

    if [ ! -f "/etc/hosts.nulltrace.backup" ]; then
        sudo cp /etc/hosts /etc/hosts.nulltrace.backup
    fi

    cat << 'EOF' | sudo tee -a /etc/hosts > /dev/null

# nulltrace Privacy Block List
0.0.0.0 google-analytics.com
0.0.0.0 www.google-analytics.com
0.0.0.0 googletagmanager.com
0.0.0.0 doubleclick.net
0.0.0.0 facebook.com
0.0.0.0 connect.facebook.net
0.0.0.0 analytics.twitter.com
0.0.0.0 amazon-adsystem.com
EOF

    echo "✅ Tracking-Domains blockiert"
}

# Tracking-Blocks entfernen
remove_tracking_blocks() {
    echo "🔄 Entferne Tracking-Blocks..."

    if [ -f "/etc/hosts.nulltrace.backup" ]; then
        sudo cp /etc/hosts.nulltrace.backup /etc/hosts
        sudo rm -f /etc/hosts.nulltrace.backup
        echo "✅ Tracking-Blocks entfernt"
    else
        echo "⚠️  Kein Backup gefunden - entferne manuell"
        sudo sed -i.bak '/# nulltrace Privacy Block List/,$ d' /etc/hosts
        echo "✅ Tracking-Blocks entfernt"
    fi
}

# Ortungsdienste deaktivieren
disable_location() {
    echo "📍 Deaktiviere Ortungsdienste..."
    sudo launchctl unload /System/Library/LaunchDaemons/com.apple.locationd.plist 2>/dev/null
    echo "✅ Ortungsdienste deaktiviert"
}

# MAC-Adresse ändern
handle_mac() {
    cache_sudo
    echo -e "${YELLOW}MAC-Adresse wird geändert...${NC}"
    "$MAC_SCRIPT"
}

# Privacy-Funktionen
handle_privacy() {
    case "$1" in
        on)
            cache_sudo

            show_banner
            show_progress "Maximale Privatsphäre wird aktiviert"
            echo ""

            echo -e "${BLUE}[❶] MAC-Adresse spoofing...${NC}"
            "$MAC_SCRIPT"
            echo ""

            echo -e "${BLUE}[❷] Privacy-Funktionen aktivieren...${NC}"
            clear_dns_cache
            set_hostname_privacy
            enable_firewall
            # Bei transparent Tor: DNS wird durch pf auf Tor's DNSPort umgeleitet
            if [ "$(get_config TOR_MODE transparent)" != "transparent" ]; then
                set_privacy_dns
            fi
            block_tracking
            disable_location
            echo ""

            echo -e "${BLUE}[❸] Tor-Netzwerk aktivieren (transparent)...${NC}"
            local tor_mode
            tor_mode="$(get_config TOR_MODE transparent)"
            if [ "$tor_mode" = "transparent" ]; then
                sudo "$SCRIPT_DIR/scripts/tor_transparent.sh" start
            else
                "$TOR_SCRIPT" full-on
            fi
            echo ""

            echo -e "${BLUE}[❹] ProxyChains konfigurieren...${NC}"
            "$PROXYCHAINS_SCRIPT" config
            echo ""

            show_success "🔥 MAXIMALE PRIVATSPHÄRE AKTIVIERT!"
            echo ""
            echo -e "${GREEN}✓ Aktiviert:${NC}"
            echo "  • MAC-Adresse geändert (permanent)"
            echo "  • Hostname: $(get_config PRIVACY_HOSTNAME Lisa)"
            if [ "$tor_mode" = "transparent" ]; then
                echo "  • Tor: ALLER Traffic über Tor (pf transparent)"
            else
                echo "  • Tor: System-SOCKS-Proxy"
            fi
            echo "  • DNS: über Tor DNSPort"
            echo "  • Firewall: Stealth-Mode"
            echo "  • Tracking blockiert"
            echo "  • IPv6: Deaktiviert"
            echo ""
            echo -e "${YELLOW}Hinweis:${NC} Nicht-Tor-Traffic wird von pf blockiert."
            ;;

        off)
            cache_sudo

            show_banner
            show_progress "Normale Einstellungen werden wiederhergestellt"
            echo ""

            # Kill-Switch deaktivieren
            echo -e "${BLUE}[❶] Kill-Switch deaktivieren...${NC}"
            "$KILLSWITCH_SCRIPT" disable 2>/dev/null
            echo ""

            echo -e "${BLUE}[❷] Tor deaktivieren...${NC}"
            # Transparentes Tor stoppen (inkl. pf-Regeln)
            if pgrep -u _nulltrace_tor tor >/dev/null 2>&1 || [ -f "$NULLTRACE_RUNTIME_DIR/tor_transparent.pid" ]; then
                sudo "$SCRIPT_DIR/scripts/tor_transparent.sh" stop
            else
                "$TOR_SCRIPT" full-off
            fi
            echo ""

            echo -e "${BLUE}[❸] Einstellungen zurücksetzen...${NC}"
            restore_original_hostname
            reset_dns_settings
            remove_tracking_blocks
            echo ""

            show_success "🌐 NORMALE EINSTELLUNGEN WIEDERHERGESTELLT!"
            echo ""
            echo -e "${GREEN}✓ Zurückgesetzt:${NC}"
            echo "  • Original-Hostname wiederhergestellt"
            echo "  • Tor + pf-Routing deaktiviert"
            echo "  • DNS-Einstellungen zurückgesetzt"
            echo "  • Tracking-Blocks entfernt"
            echo "  • IPv6 reaktiviert"
            echo ""
            echo -e "${YELLOW}Hinweis:${NC} MAC-Adresse bleibt geändert (Sicherheit)"
            ;;

        *)
            echo -e "${RED}Fehler: Ungültige Option '${1:-}'${NC}"
            echo "Verwende: privacy-on oder privacy-off"
            return 1
            ;;
    esac
}

# Security-Analyse-Funktionen
handle_security() {
    case "${1:-}" in
        system|network|dns|privacy|vuln|full)
            "$SCRIPT_DIR/scripts/security_tools.sh" "$1"
            ;;
        "")
            show_banner
            echo -e "${BLUE}🛡️ nulltrace SECURITY TOOLS${NC}"
            echo "========================"
            echo ""
            echo "Verfügbare Security Checks:"
            echo ""
            echo "  system  - System-Sicherheitsanalyse"
            echo "  network - Netzwerk-Sicherheitsscan"
            echo "  dns     - DNS-Sicherheitscheck"
            echo "  privacy - Privacy-Audit"
            echo "  vuln    - Vulnerability-Check"
            echo "  full    - Komplette Sicherheitsanalyse"
            echo ""
            echo "Verwendung: $0 security [check-typ]"
            echo ""
            echo "Tor Security Tools:"
            echo "  1) Transparentes Tor: ./nulltrace.sh tor trans-on"
            echo "     → Browser/Apps: Automatisch über Tor"
            echo "     → Terminal: source /tmp/tor_shell_config"
            echo "  2) ProxyChains: pc <command> (z.B. pc nmap, pc sqlmap)"
            echo "  Verfügbar: curl, nmap, gobuster, sqlmap über Tor"
            ;;
        *)
            echo -e "${RED}Fehler: Ungültiger Security Check '$1'${NC}"
            echo "Verwende: security [system|network|dns|privacy|vuln|full]"
            return 1
            ;;
    esac
}

# Gesamtstatus anzeigen
show_overall_status() {
    show_banner
    echo -e "${BLUE}📊 nulltrace PRIVACY STATUS${NC}"
    echo "========================"
    echo ""

    local wifi_iface
    wifi_iface="$(get_effective_wifi_interface)"
    local wifi_svc
    wifi_svc="$(get_effective_wifi_service)"

    # MAC-Adresse
    echo -e "${BLUE}[1] MAC-Adresse${NC}"
    local current_mac
    current_mac=$(ifconfig "$wifi_iface" 2>/dev/null | grep ether | awk '{print $2}' || echo "Unbekannt")
    echo "    └─ Aktuelle MAC: $current_mac"
    echo ""

    # Tor Status
    echo -e "${BLUE}[2] Tor-Netzwerk${NC}"
    local is_tor="false"
    if is_tor_running; then
        echo "    ├─ Service: ✅ Läuft (Port $(get_config TOR_SOCKS_PORT 9050))"
        local proxy_state
        proxy_state=$(networksetup -getsocksfirewallproxy "$wifi_svc" 2>/dev/null | grep "Enabled: Yes")
        if [ -n "$proxy_state" ]; then
            echo "    ├─ System-Proxy: ✅ Aktiviert"
        else
            echo "    ├─ System-Proxy: ❌ Deaktiviert"
        fi
        is_tor=$(secure_curl "https://check.torproject.org/api/ip" --socks5 "localhost:$(get_config TOR_SOCKS_PORT 9050)" 2>/dev/null | jq -r '.IsTor' 2>/dev/null || echo "false")
        if [ "$is_tor" = "true" ]; then
            echo "    └─ Verbindung: ✅ Über Tor"
        else
            echo "    └─ Verbindung: ⚠️  Direkt (nicht über Tor)"
        fi
    else
        echo "    └─ Service: ❌ Gestoppt"
    fi
    echo ""

    # Firewall Status
    echo -e "${BLUE}[3] Firewall${NC}"
    local fw_status
    fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep "enabled")
    if [ -n "$fw_status" ]; then
        echo "    ├─ Status: ✅ Aktiviert"
        local stealth
        stealth=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep "enabled")
        if [ -n "$stealth" ]; then
            echo "    └─ Stealth-Modus: ✅ Aktiviert"
        else
            echo "    └─ Stealth-Modus: ❌ Deaktiviert"
        fi
    else
        echo "    └─ Status: ❌ Deaktiviert"
    fi
    echo ""

    # DNS Status
    echo -e "${BLUE}[4] DNS-Konfiguration${NC}"
    local dns_servers
    dns_servers=$(networksetup -getdnsservers "$wifi_svc" 2>/dev/null | head -2 | tr '\n' ' ')
    if [[ "$dns_servers" == *"1.1.1.1"* ]]; then
        echo "    └─ Server: ✅ Cloudflare (Privacy)"
    elif [[ "$dns_servers" == *"9.9.9.9"* ]]; then
        echo "    └─ Server: ✅ Quad9 (Privacy)"
    elif [[ "$dns_servers" == *"There aren't any"* ]]; then
        echo "    └─ Server: ⚠️  Standard (DHCP)"
    else
        echo "    └─ Server: $dns_servers"
    fi
    echo ""

    # Hostname
    echo -e "${BLUE}[5] System-Identifikation${NC}"
    local hostname
    hostname=$(scutil --get ComputerName 2>/dev/null || echo "Unbekannt")
    echo "    └─ Hostname: $hostname"
    echo ""

    # Tracking-Schutz
    echo -e "${BLUE}[6] Tracking-Schutz${NC}"
    if grep -q "# nulltrace Privacy Block List" /etc/hosts 2>/dev/null; then
        local blocked_count
        blocked_count=$(grep -c "^0.0.0.0" /etc/hosts 2>/dev/null || echo "0")
        echo "    └─ Hosts-Datei: ✅ Modifiziert ($blocked_count Domains blockiert)"
    else
        echo "    └─ Hosts-Datei: ❌ Standard"
    fi
    echo ""

    # Ortungsdienste
    echo -e "${BLUE}[7] Ortungsdienste${NC}"
    if pgrep -x "locationd" > /dev/null 2>&1; then
        echo "    └─ Status: ⚠️  Aktiviert"
    else
        echo "    └─ Status: ✅ Deaktiviert"
    fi
    echo ""

    # Kill-Switch
    echo -e "${BLUE}[8] Kill-Switch${NC}"
    if pfctl -s info 2>/dev/null | grep -q "Status: Enabled"; then
        echo "    └─ Status: ✅ Aktiviert"
    else
        echo "    └─ Status: ❌ Deaktiviert"
    fi
    echo ""

    # Privacy-Level
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local privacy_score=0

    local tor_running_check
    tor_running_check=$(is_tor_running && echo "0" || echo "1")
    local proxy_active
    proxy_active=$(networksetup -getsocksfirewallproxy "$wifi_svc" 2>/dev/null | grep "Enabled: Yes")
    if [ "$tor_running_check" = "0" ] && ([ "$is_tor" = "true" ] || [ -n "$proxy_active" ]); then
        privacy_score=$((privacy_score + 6))
    fi
    [ -n "$fw_status" ] && privacy_score=$((privacy_score + 2))
    [[ "$dns_servers" == *"1.1.1.1"* || "$dns_servers" == *"9.9.9.9"* ]] && privacy_score=$((privacy_score + 1))
    grep -q "# nulltrace Privacy Block List" /etc/hosts 2>/dev/null && privacy_score=$((privacy_score + 1))
    ! pgrep -x "locationd" > /dev/null 2>&1 && privacy_score=$((privacy_score + 1))

    local tor_active=false
    [ "$tor_running_check" = "0" ] && ([ "$is_tor" = "true" ] || [ -n "$proxy_active" ]) && tor_active=true

    echo -n "Privacy-Level: "
    if [ "$tor_active" = true ]; then
        if [ $privacy_score -ge 9 ]; then
            echo -e "${GREEN}⬛⬛⬛⬛⬛ MAXIMUM${NC}"
        elif [ $privacy_score -ge 7 ]; then
            echo -e "${GREEN}⬛⬛⬛⬛⬜ HOCH${NC}"
        elif [ $privacy_score -ge 4 ]; then
            echo -e "${YELLOW}⬛⬛⬛⬜⬜ MITTEL${NC}"
        else
            echo -e "${YELLOW}⬛⬛⬜⬜⬜ NIEDRIG${NC}"
        fi
    else
        if [ $privacy_score -ge 4 ]; then
            echo -e "${YELLOW}⬛⬛⬜⬜⬜ NIEDRIG${NC} (⚠️ Tor inaktiv)"
        elif [ $privacy_score -ge 2 ]; then
            echo -e "${RED}⬛⬜⬜⬜⬜ MINIMAL${NC}"
        else
            echo -e "${RED}⬜⬜⬜⬜⬜ KEINE${NC}"
        fi
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# IP-Informationen
show_ip_info() {
    show_banner
    echo -e "${BLUE}📍 IP-INFORMATIONEN${NC}"
    echo "===================="
    echo ""

    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}⚠️  jq ist nicht installiert. Installiere es mit: brew install jq${NC}"
        echo ""
    fi

    echo -e "${BLUE}[1] Normale Verbindung${NC}"
    echo "────────────────────────"
    if command -v jq &> /dev/null; then
        secure_curl "https://ipapi.co/json/" | jq -r '
        "🌐 IP-Adresse:     " + .ip,
        "🏙️  Stadt:          " + .city,
        "🗺️  Region:         " + .region,
        "🏳️  Land:           " + .country_name + " (" + .country + ")",
        "📍 Koordinaten:    " + (.latitude|tostring) + ", " + (.longitude|tostring),
        "🕐 Zeitzone:       " + .timezone + " (UTC" + .utc_offset + ")",
        "🌐 ISP:            " + .isp'
    else
        echo "IP-Adresse: $(secure_curl "https://icanhazip.com")"
    fi
    echo ""

    if is_tor_running; then
        echo -e "${BLUE}[2] Tor-Verbindung${NC}"
        echo "─────────────────────"

        local tor_test
        tor_test=$(proxychains4 -q curl -4 -s --connect-timeout 10 https://check.torproject.org/api/ip 2>/dev/null | jq -r '.IsTor' 2>/dev/null)

        if [[ "$tor_test" == "true" ]]; then
            if command -v jq &> /dev/null; then
                proxychains4 -q curl -4 -s --connect-timeout 10 https://ipapi.co/json/ 2>/dev/null | jq -r '
                "🧅 Tor-IP:         " + .ip,
                "🏙️  Stadt:          " + .city,
                "🗺️  Region:         " + .region,
                "🏳️  Land:           " + .country_name + " (" + .country + ")",
                "📍 Koordinaten:    " + (.latitude|tostring) + ", " + (.longitude|tostring),
                "🕐 Zeitzone:       " + .timezone + " (UTC" + .utc_offset + ")",
                "🌐 ISP:            " + .isp'
            else
                echo "Tor-IP: $(proxychains4 -q curl -4 -s --connect-timeout 10 https://icanhazip.com 2>/dev/null)"
            fi
            echo ""
            echo -e "${GREEN}✅ Tor-Anonymisierung aktiv${NC}"
        else
            echo -e "${RED}❌ Tor-Verbindung fehlgeschlagen${NC}"
        fi
    else
        echo -e "${YELLOW}ℹ️  Tor ist nicht aktiv${NC}"
        echo "   Starte Tor mit: $0 tor start"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BLUE}💡 Tipps:${NC}"
    echo "• Für maximale Anonymität: Verwende den Tor Browser"
    echo "• Transparentes Tor: ./nulltrace.sh tor trans-on + source /tmp/tor_shell_config"
    echo "• Privacy-Status prüfen: $0 status"
}

# Interaktives Hauptmenü
show_interactive_menu() {
    show_banner
    echo -e "${BLUE}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}  ║                 🔧 nulltrace HAUPTMENÜ 🔧                   ║${NC}"
    echo -e "${BLUE}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}🔥 Hauptfunktionen:${NC}"
    echo ""
    echo -e "  ${YELLOW}1) privacy-on${NC}        🔒 Maximale Privatsphäre aktivieren"
    echo -e "  ${YELLOW}2) privacy-off${NC}       🌐 Normale Einstellungen wiederherstellen"
    echo -e "  ${YELLOW}3) status${NC}            📊 Privacy-Status anzeigen"
    echo -e "  ${YELLOW}4) help${NC}              💡 Hilfe anzeigen"
    echo ""
    echo -e "${BLUE}⚙️ Erweiterte Funktionen:${NC}"
    echo ""
    echo -e "  ${YELLOW}5) ipinfo${NC}            📍 Detaillierte IP-Informationen"
    echo -e "  ${YELLOW}6) mac${NC}               🔀 MAC-Adresse ändern"
    echo -e "  ${YELLOW}7) tor${NC}               🧅 Tor-Kontrolle (erweitert)"
    echo -e "  ${YELLOW}8) killswitch${NC}        🛡️  Kill-Switch Steuerung"
    echo ""
    echo -e "  ${YELLOW}0) exit${NC}              👋 Beenden"
    echo ""
}

# Eingabeverarbeitung
handle_interactive_input() {
    local choice="$1"
    local param="${2:-}"

    case "$choice" in
        1|privacy-on)
            handle_privacy "on"
            ;;
        2|privacy-off)
            handle_privacy "off"
            ;;
        3|status)
            show_overall_status
            ;;
        4|help)
            show_help
            ;;
        5|ipinfo)
            show_ip_info
            ;;
        6|mac)
            handle_mac
            ;;
        7|tor)
            if [ -z "$param" ]; then
                echo ""
                echo -e "${BLUE}Tor-Aktionen:${NC}"
                echo ""
                echo "  start      - Nur Tor-Service starten"
                echo "  stop       - Nur Tor-Service stoppen"
                echo "  status     - Status anzeigen"
                echo "  full-on    - 🔒 System-weites Tor"
                echo "  full-off   - 🌐 System-weites Tor aus"
                echo "  trans-on   - 🛡️  Transparentes Tor"
                echo "  trans-off  - 🌐 Transparentes Tor aus"
                echo "  test       - Verbindung testen"
                echo ""
                read -p "Welche Tor-Aktion? (start/stop/status/full-on/full-off/trans-on/trans-off/test): " param
            fi
            handle_tor "$param"
            ;;
        8|killswitch)
            if [ -z "$param" ]; then
                echo ""
                echo -e "${BLUE}Kill-Switch Aktionen:${NC}"
                echo ""
                echo "  on     - Kill-Switch aktivieren"
                echo "  off    - Kill-Switch deaktivieren"
                echo "  status - Status anzeigen"
                echo ""
                read -p "Welche Aktion? (on/off/status): " param
            fi
            "$KILLSWITCH_SCRIPT" "$param"
            ;;
        0|exit)
            echo ""
            echo -e "${GREEN}👋 Auf Wiedersehen!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Ungültige Eingabe: $choice${NC}"
            echo "Bitte Nummer (0-8) oder Funktionsname eingeben."
            return 1
            ;;
    esac
}

# VPN-Funktionen
handle_vpn() {
    local action="${1:-}"

    if [ -z "$action" ]; then
        echo ""
        echo -e "${BLUE}🌍 VPN-Funktionen:${NC}"
        echo "  1) menu      - Interaktives VPN-Menü"
        echo "  2) status    - VPN-Status anzeigen"
        echo "  3) location  - Aktueller Standort"
        echo "  4) providers - Verfügbare Provider"
        echo "  5) reset     - VPN zurücksetzen (bei Problemen)"
        echo ""
        read -p "Welche VPN-Funktion möchtest du? (1-5 oder Name): " action
    fi

    case "$action" in
        1|menu|"")
            "$VPN_SCRIPT" menu
            ;;
        2|status)
            "$VPN_SCRIPT" status
            ;;
        3|location)
            "$VPN_SCRIPT" location
            ;;
        4|providers)
            "$VPN_SCRIPT" providers
            ;;
        5|reset)
            "$VPN_SCRIPT" reset
            ;;
        connect)
            shift 2>/dev/null
            "$VPN_SCRIPT" connect "$@"
            ;;
        disconnect)
            shift 2>/dev/null
            "$VPN_SCRIPT" disconnect "$@"
            ;;
        *)
            echo -e "${RED}❌ Unbekannte VPN-Aktion: $action${NC}"
            echo "Verfügbare Aktionen: 1-5, menu, status, location, providers, reset, connect, disconnect"
            return 1
            ;;
    esac
}

# StatusBar automatisch starten
auto_start_statusbar() {
    "$SCRIPT_DIR/scripts/statusbar_launcher.sh" 2>/dev/null &
}

# Hauptprogramm
main() {
    check_dependencies

    auto_start_statusbar

    if [ $# -eq 0 ]; then
        while true; do
            show_interactive_menu
            echo ""
            read -p "Funktion wählen (0-8 oder Name): " user_choice

            choice=$(echo "$user_choice" | awk '{print $1}')
            param=$(echo "$user_choice" | awk '{print $2}')

            if [[ "$choice" == "0" || "$choice" == "exit" || "$choice" == "quit" ]]; then
                echo "Auf Wiedersehen!"
                exit 0
            fi

            echo ""
            handle_interactive_input "$choice" "$param"

            echo ""
            echo "Drücke Enter um zum Hauptmenü zurückzukehren..."
            read -r
        done
    fi

    case "$1" in
        privacy-on)
            handle_privacy "on"
            ;;
        privacy-off)
            handle_privacy "off"
            ;;
        status)
            show_overall_status
            ;;
        help|-h|--help)
            show_banner
            show_help
            ;;
        ipinfo)
            show_ip_info
            ;;
        mac)
            handle_mac
            ;;
        tor)
            handle_tor "${2:-}"
            ;;
        proxychains)
            "$PROXYCHAINS_SCRIPT" install
            ;;
        security)
            handle_security "${2:-}"
            ;;
        vpn)
            handle_vpn "${2:-}"
            ;;
        killswitch)
            "$KILLSWITCH_SCRIPT" "${2:-status}"
            ;;
        # Legacy support
        privacy)
            if [ "${2:-}" = "on" ] || [ "${2:-}" = "off" ]; then
                handle_privacy "$2"
            else
                echo -e "${YELLOW}💡 Tipp: Verwende 'privacy-on' oder 'privacy-off'${NC}"
                show_help
            fi
            ;;
        *)
            echo -e "${RED}❌ Unbekannter Befehl '$1'${NC}"
            echo -e "${YELLOW}💡 Verwende: $0 help für Hilfe${NC}"
            exit 1
            ;;
    esac
}

main "$@"
