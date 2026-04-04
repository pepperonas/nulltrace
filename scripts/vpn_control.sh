#!/usr/bin/env bash

# nulltrace VPN Control with Geo Location Selection
# Unterstützt mehrere VPN-Provider mit Länderauswahl
# (c) 2025 Martin Pfeffer - MIT License

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

CONFIG_DIR="$HOME/.nulltrace/vpn"
PROFILES_DIR="$CONFIG_DIR/profiles"

# SwiftBar Helper einbinden
if [ -f "$SCRIPT_DIR/swiftbar_helper.sh" ]; then
    source "$SCRIPT_DIR/swiftbar_helper.sh"
fi

# VPN-Provider Namen abrufen
get_provider_name() {
    case "$1" in
        "nordvpn") echo "NordVPN" ;;
        "expressvpn") echo "ExpressVPN" ;;
        "surfshark") echo "Surfshark" ;;
        "mullvad") echo "Mullvad" ;;
        "protonvpn") echo "ProtonVPN" ;;
        "wireguard") echo "WireGuard (Custom)" ;;
        "openvpn") echo "OpenVPN (Custom)" ;;
        *) echo "Unbekannt" ;;
    esac
}

# Länder-Namen abrufen
get_country_name() {
    case "$1" in
        "DE") echo "Deutschland" ;;
        "US") echo "United States" ;;
        "UK") echo "United Kingdom" ;;
        "FR") echo "Frankreich" ;;
        "NL") echo "Niederlande" ;;
        "CH") echo "Schweiz" ;;
        "AT") echo "Österreich" ;;
        "SE") echo "Schweden" ;;
        "NO") echo "Norwegen" ;;
        "DK") echo "Dänemark" ;;
        "FI") echo "Finnland" ;;
        "IS") echo "Island" ;;
        "CA") echo "Kanada" ;;
        "AU") echo "Australien" ;;
        "JP") echo "Japan" ;;
        "SG") echo "Singapur" ;;
        "HK") echo "Hong Kong" ;;
        "ES") echo "Spanien" ;;
        "IT") echo "Italien" ;;
        "BE") echo "Belgien" ;;
        "LU") echo "Luxemburg" ;;
        "CZ") echo "Tschechien" ;;
        "PL") echo "Polen" ;;
        "RO") echo "Rumänien" ;;
        "BG") echo "Bulgarien" ;;
        "EE") echo "Estland" ;;
        "LV") echo "Lettland" ;;
        "LT") echo "Litauen" ;;
        "SK") echo "Slowakei" ;;
        "SI") echo "Slowenien" ;;
        "HR") echo "Kroatien" ;;
        "HU") echo "Ungarn" ;;
        "GR") echo "Griechenland" ;;
        "CY") echo "Zypern" ;;
        "MT") echo "Malta" ;;
        "IE") echo "Irland" ;;
        "PT") echo "Portugal" ;;
        "MX") echo "Mexiko" ;;
        "BR") echo "Brasilien" ;;
        "AR") echo "Argentinien" ;;
        "CL") echo "Chile" ;;
        "IN") echo "Indien" ;;
        "KR") echo "Südkorea" ;;
        "TH") echo "Thailand" ;;
        "MY") echo "Malaysia" ;;
        "ID") echo "Indonesien" ;;
        "PH") echo "Philippinen" ;;
        "VN") echo "Vietnam" ;;
        "TW") echo "Taiwan" ;;
        "NZ") echo "Neuseeland" ;;
        "ZA") echo "Südafrika" ;;
        "IL") echo "Israel" ;;
        "AE") echo "VAE" ;;
        "TR") echo "Türkei" ;;
        *) echo "Unbekannt" ;;
    esac
}

# Initialisierung
init_vpn_config() {
    echo -e "${BLUE}🔧 VPN-Konfiguration initialisieren...${NC}"

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$PROFILES_DIR"

    if [ ! -f "$CONFIG_DIR/config" ]; then
        cat > "$CONFIG_DIR/config" << EOF
# nulltrace VPN Configuration
DEFAULT_PROVIDER=""
AUTO_CONNECT=false
KILLSWITCH=false
DNS_LEAK_PROTECTION=true
IPV6_LEAK_PROTECTION=true
PREFERRED_COUNTRIES="DE,US,UK,NL,CH"
EOF
    fi

    echo "✅ VPN-Konfiguration bereit"
}

# VPN-Provider erkennen
detect_vpn_providers() {
    local providers=()

    command -v nordvpn >/dev/null 2>&1 && providers+=("nordvpn")
    command -v expressvpn >/dev/null 2>&1 && providers+=("expressvpn")
    command -v surfshark-vpn >/dev/null 2>&1 && providers+=("surfshark")
    command -v mullvad >/dev/null 2>&1 && providers+=("mullvad")
    command -v protonvpn-cli >/dev/null 2>&1 && providers+=("protonvpn")
    command -v wg >/dev/null 2>&1 && providers+=("wireguard")
    command -v openvpn >/dev/null 2>&1 && providers+=("openvpn")

    printf '%s\n' "${providers[@]}"
}

# Verfügbare Länder für Provider anzeigen
show_countries() {
    local provider="$1"

    echo -e "${BLUE}🌍 Verfügbare Länder für $(get_provider_name "$provider"):${NC}"
    echo ""

    case "$provider" in
        "nordvpn")
            if command -v nordvpn >/dev/null 2>&1; then
                nordvpn countries 2>/dev/null | head -20
            fi
            ;;
        "expressvpn")
            echo "ExpressVPN Länder-Liste:"
            for code in DE US UK FR NL CH AT SE NO DK FI IS CA AU JP SG HK ES IT BE; do
                echo "  $code - $(get_country_name "$code")"
            done
            ;;
        "mullvad")
            if command -v mullvad >/dev/null 2>&1; then
                mullvad relay list | grep -E "^[A-Z]{2}" | head -20
            fi
            ;;
        *)
            echo "Häufig verfügbare Länder:"
            for code in DE US UK FR NL CH AT SE NO DK; do
                echo "  $code - $(get_country_name "$code")"
            done
            ;;
    esac
    echo ""
    echo "Vollständige Liste der Länder-Codes:"
    for code in DE US UK FR NL CH AT SE NO DK FI IS CA AU JP SG HK ES IT BE LU CZ PL RO BG EE LV LT SK SI HR HU GR CY MT IE PT MX BR AR CL IN KR TH MY ID PH VN TW NZ ZA IL AE TR; do
        echo "  $code - $(get_country_name "$code")"
    done | column -t
}

# VPN-Status prüfen
check_vpn_status() {
    local provider="$1"

    case "$provider" in
        "nordvpn")
            if command -v nordvpn >/dev/null 2>&1; then
                local status
                status=$(nordvpn status 2>/dev/null)
                if echo "$status" | grep -q "Status: Connected"; then
                    echo "connected"
                    echo "$status" | grep "Country\|City\|Server\|IP"
                else
                    echo "disconnected"
                fi
            fi
            ;;
        "expressvpn")
            if command -v expressvpn >/dev/null 2>&1; then
                local status
                status=$(expressvpn status 2>/dev/null)
                if echo "$status" | grep -q "Connected"; then
                    echo "connected"
                    echo "$status"
                else
                    echo "disconnected"
                fi
            fi
            ;;
        "mullvad")
            if command -v mullvad >/dev/null 2>&1; then
                local status
                status=$(mullvad status 2>/dev/null)
                if echo "$status" | grep -q "Connected"; then
                    echo "connected"
                    echo "$status"
                else
                    echo "disconnected"
                fi
            fi
            ;;
        "surfshark")
            if command -v surfshark-vpn >/dev/null 2>&1; then
                local status
                status=$(surfshark-vpn status 2>/dev/null)
                if echo "$status" | grep -q "Connected"; then
                    echo "connected"
                    echo "$status"
                else
                    echo "disconnected"
                fi
            fi
            ;;
        "protonvpn")
            if command -v protonvpn-cli >/dev/null 2>&1; then
                local status
                status=$(protonvpn-cli status 2>/dev/null)
                if echo "$status" | grep -q "Connected"; then
                    echo "connected"
                    echo "$status"
                else
                    echo "disconnected"
                fi
            fi
            ;;
        *)
            if ifconfig 2>/dev/null | grep -q "utun"; then
                echo "connected"
                echo "VPN-Interface aktiv"
            else
                echo "disconnected"
            fi
            ;;
    esac
}

# VPN zu Land verbinden
connect_vpn() {
    local provider="$1"
    local country="$2"

    # Input-Validierung
    if ! validate_country_code "$country"; then
        log_error "Ungültiger Länder-Code: $country"
        echo "Verwende: $0 countries $provider"
        return 1
    fi

    echo -e "${YELLOW}🌍 Verbinde zu $(get_country_name "$country") ($country) via $(get_provider_name "$provider")...${NC}"

    case "$provider" in
        "nordvpn")
            if command -v nordvpn >/dev/null 2>&1; then
                nordvpn connect "$country"
                if [ $? -eq 0 ]; then
                    log_ok "Erfolgreich verbunden via NordVPN"
                    return 0
                fi
            fi
            ;;
        "expressvpn")
            if command -v expressvpn >/dev/null 2>&1; then
                local location=""
                case "$country" in
                    "DE") location="germany" ;;
                    "US") location="usa" ;;
                    "UK") location="uk" ;;
                    "FR") location="france" ;;
                    "NL") location="netherlands" ;;
                    *) location=$(echo "$(get_country_name "$country")" | tr '[:upper:]' '[:lower:]') ;;
                esac

                expressvpn connect "$location"
                if [ $? -eq 0 ]; then
                    log_ok "Erfolgreich verbunden via ExpressVPN"
                    return 0
                fi
            fi
            ;;
        "mullvad")
            if command -v mullvad >/dev/null 2>&1; then
                log_info "Bereite Mullvad-Verbindung vor..."

                if ! mullvad account get 2>/dev/null | grep -q "Paid until\|Account:"; then
                    log_error "Mullvad-Account nicht eingeloggt oder ungültig"
                    echo ""
                    echo "Bitte führe aus:"
                    echo "  mullvad account login <account-number>"
                    return 1
                fi

                mullvad lockdown-mode set off 2>/dev/null
                mullvad dns set default 2>/dev/null

                log_info "Setze Standort auf $country..."
                if mullvad relay set location "$country" 2>/dev/null; then
                    log_info "Verbinde zu Mullvad..."
                    mullvad connect
                    sleep 3

                    local status
                    status=$(mullvad status 2>/dev/null)
                    if echo "$status" | grep -q "Connected"; then
                        log_ok "Erfolgreich verbunden via Mullvad"
                        echo "$status"
                        return 0
                    else
                        log_error "Mullvad-Verbindung fehlgeschlagen"
                        echo "Status: $status"

                        log_warn "Versuche Fehlerbehebung..."
                        mullvad relay set location any 2>/dev/null
                        mullvad disconnect 2>/dev/null
                        sleep 2
                        mullvad relay set location "$country" 2>/dev/null
                        mullvad connect 2>/dev/null

                        sleep 3
                        status=$(mullvad status 2>/dev/null)
                        if echo "$status" | grep -q "Connected"; then
                            log_ok "Verbindung nach Neuversuch erfolgreich"
                            return 0
                        fi
                        return 1
                    fi
                else
                    log_error "Ungültiger Länder-Code für Mullvad: $country"
                    return 1
                fi
            fi
            ;;
        "surfshark")
            if command -v surfshark-vpn >/dev/null 2>&1; then
                surfshark-vpn connect --country "$country"
                if [ $? -eq 0 ]; then
                    log_ok "Erfolgreich verbunden via Surfshark"
                    return 0
                fi
            fi
            ;;
        "protonvpn")
            if command -v protonvpn-cli >/dev/null 2>&1; then
                protonvpn-cli connect --country "$country"
                if [ $? -eq 0 ]; then
                    log_ok "Erfolgreich verbunden via ProtonVPN"
                    return 0
                fi
            fi
            ;;
    esac

    log_error "Verbindung fehlgeschlagen"
    return 1
}

# VPN trennen
disconnect_vpn() {
    local provider="$1"

    echo -e "${YELLOW}🔌 Trenne VPN-Verbindung...${NC}"

    case "$provider" in
        "nordvpn") command -v nordvpn >/dev/null 2>&1 && nordvpn disconnect ;;
        "expressvpn") command -v expressvpn >/dev/null 2>&1 && expressvpn disconnect ;;
        "mullvad") command -v mullvad >/dev/null 2>&1 && mullvad disconnect ;;
        "surfshark") command -v surfshark-vpn >/dev/null 2>&1 && surfshark-vpn disconnect ;;
        "protonvpn") command -v protonvpn-cli >/dev/null 2>&1 && protonvpn-cli disconnect ;;
        *)
            disconnect_all_vpn_providers
            ;;
    esac

    log_ok "VPN getrennt"
    reset_network_after_vpn
}

# Aktuellen Standort und IP anzeigen
show_location() {
    echo -e "${BLUE}📍 Aktuelle Standort-Informationen:${NC}"
    echo ""

    local ip
    ip=$(secure_curl "https://icanhazip.com" 2>/dev/null || echo "Unbekannt")
    echo "IP-Adresse: $ip"

    local location_info
    location_info=$(secure_curl "https://ipinfo.io/$ip/json" 2>/dev/null)

    if [ -n "$location_info" ]; then
        local country region city org
        country=$(echo "$location_info" | jq -r '.country // "Unbekannt"' 2>/dev/null)
        region=$(echo "$location_info" | jq -r '.region // "Unbekannt"' 2>/dev/null)
        city=$(echo "$location_info" | jq -r '.city // "Unbekannt"' 2>/dev/null)
        org=$(echo "$location_info" | jq -r '.org // "Unbekannt"' 2>/dev/null)

        echo "Land: $country"
        echo "Region: $region"
        echo "Stadt: $city"
        echo "Provider: $org"
    fi

    echo ""
    echo -e "${BLUE}🔍 DNS-Leak-Check:${NC}"
    local dns_servers
    dns_servers=$(nslookup google.com 2>/dev/null | grep "Server:" | awk '{print $2}')
    echo "DNS-Server: $dns_servers"
}

# Netzwerk zurücksetzen
reset_network_after_vpn() {
    echo -e "${YELLOW}🔧 Stelle Netzwerkverbindung wieder her...${NC}"

    if command -v mullvad >/dev/null 2>&1; then
        mullvad lockdown-mode set off 2>/dev/null
        mullvad auto-connect set off 2>/dev/null
        mullvad dns set default 2>/dev/null
    fi

    sudo dscacheutil -flushcache 2>/dev/null
    sudo killall -HUP mDNSResponder 2>/dev/null

    local wifi_interface
    wifi_interface="$(get_effective_wifi_interface)"
    if [ -n "$wifi_interface" ]; then
        sudo ifconfig "$wifi_interface" down
        sleep 1
        sudo ifconfig "$wifi_interface" up
        sleep 2
    fi

    local wifi_svc
    wifi_svc="$(get_effective_wifi_service)"
    sudo networksetup -setdnsservers "$wifi_svc" "Empty" 2>/dev/null

    for route in $(netstat -nr | grep -E "tun|utun" | awk '{print $1}'); do
        sudo route delete "$route" 2>/dev/null
    done

    if [ -f "/etc/pf.conf.backup" ]; then
        sudo cp /etc/pf.conf.backup /etc/pf.conf 2>/dev/null
        sudo pfctl -d 2>/dev/null
        sudo pfctl -e 2>/dev/null
        sudo pfctl -f /etc/pf.conf 2>/dev/null
    fi

    sudo killall -9 mDNSResponder 2>/dev/null
    sudo killall -9 mDNSResponderHelper 2>/dev/null
    sudo dscacheutil -flushcache 2>/dev/null

    log_ok "Netzwerk-Wiederherstellung abgeschlossen"

    echo -e "${BLUE}🧪 Teste Internetverbindung...${NC}"
    if ping -c 1 -t 2 8.8.8.8 >/dev/null 2>&1; then
        log_ok "Internetverbindung funktioniert"
    else
        log_error "Keine Internetverbindung - versuche erweiterte Wiederherstellung..."

        sudo ipconfig set "$wifi_interface" DHCP 2>/dev/null

        sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist 2>/dev/null
        sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.network.identification.plist 2>/dev/null
        sudo rm -f /Library/Preferences/SystemConfiguration/com.apple.wifi.message-tracer.plist 2>/dev/null
        sudo rm -f /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist 2>/dev/null
        sudo rm -f /Library/Preferences/SystemConfiguration/preferences.plist 2>/dev/null

        log_warn "Bitte starte das System neu, falls die Verbindung nicht funktioniert"
    fi
}

# VPN komplett zurücksetzen
reset_vpn_complete() {
    echo -e "${RED}🔄 VOLLSTÄNDIGER VPN-RESET${NC}"
    echo -e "${YELLOW}Diese Funktion setzt alle VPN-Einstellungen zurück${NC}"
    echo ""

    echo "1. Trenne alle VPN-Verbindungen..."
    disconnect_all_vpn_providers

    if command -v mullvad >/dev/null 2>&1; then
        echo "2. Setze Mullvad-Einstellungen zurück..."
        mullvad lockdown-mode set off 2>/dev/null
        mullvad auto-connect set off 2>/dev/null
        mullvad dns set default 2>/dev/null
        mullvad relay set location any 2>/dev/null
        mullvad obfuscation set mode off 2>/dev/null
        mullvad tunnel set ipv6 on 2>/dev/null
    fi

    echo "3. Setze Netzwerk-Einstellungen zurück..."
    reset_network_after_vpn

    if [ -d "$CONFIG_DIR" ]; then
        read -p "Möchtest du auch die VPN-Konfigurationsdateien löschen? (j/N): " delete_config
        if [[ "$delete_config" =~ ^[jJ]$ ]]; then
            rm -rf "$CONFIG_DIR"
            log_ok "VPN-Konfigurationsdateien gelöscht"
        fi
    fi

    echo ""
    log_ok "VPN-Reset abgeschlossen"
    echo ""
    echo "Nächste Schritte:"
    echo "• Teste deine Internetverbindung"
    echo "• Bei Problemen: System neustarten"
    echo "• VPN neu konfigurieren wenn gewünscht"
}

# VPN + Tor Chaining
setup_vpn_tor_chain() {
    local mode="$1"
    local provider="$2"
    local country="$3"

    echo -e "${PURPLE}🔗 VPN + Tor Chaining Setup ($mode)...${NC}"

    case "$mode" in
        "tor-over-vpn")
            echo "1. VPN verbinden..."
            connect_vpn "$provider" "$country"
            sleep 3

            echo "2. Tor starten..."
            "$SCRIPT_DIR/tor_control.sh" start

            log_ok "Tor-over-VPN Chain aktiv"
            echo "Traffic: Computer → VPN → Tor → Internet"
            ;;
        "vpn-over-tor")
            echo "1. Tor starten..."
            "$SCRIPT_DIR/tor_control.sh" start
            sleep 3

            echo "2. VPN über Tor verbinden..."
            connect_vpn "$provider" "$country"

            log_ok "VPN-over-Tor Chain aktiv"
            echo "Traffic: Computer → Tor → VPN → Internet"
            ;;
    esac
}

# Interaktives Menü
show_vpn_menu() {
    local providers=($(detect_vpn_providers))

    if [ ${#providers[@]} -eq 0 ]; then
        log_error "Keine VPN-Provider gefunden!"
        echo ""
        echo "Installiere einen der unterstützten Provider:"
        echo "• NordVPN: https://nordvpn.com/download/mac/"
        echo "• ExpressVPN: https://www.expressvpn.com/setup"
        echo "• Mullvad: brew install mullvad-vpn"
        echo "• Surfshark: https://surfshark.com/download/mac"
        echo "• ProtonVPN: brew install protonvpn"
        return 1
    fi

    echo -e "${BLUE}🌍 VPN GEO-AUSWAHL${NC}"
    echo "==================="
    echo ""
    echo "Verfügbare Provider:"
    local i=1
    for provider in "${providers[@]}"; do
        echo "  $i) $(get_provider_name "$provider") ($provider)"
        ((i++))
    done
    echo ""
    read -p "Provider wählen (1-${#providers[@]} oder Name): " provider_choice

    local selected_provider=""

    if [[ "$provider_choice" =~ ^[0-9]+$ ]] && [[ "$provider_choice" -gt 0 && "$provider_choice" -le ${#providers[@]} ]]; then
        selected_provider="${providers[$((provider_choice-1))]}"
    else
        for provider in "${providers[@]}"; do
            if [[ "$provider_choice" == "$provider" ]] || [[ "$provider_choice" == "$(get_provider_name "$provider")" ]]; then
                selected_provider="$provider"
                break
            fi
        done
    fi

    if [ -n "$selected_provider" ]; then

        echo ""
        echo -e "${BLUE}Provider: $(get_provider_name "$selected_provider")${NC}"
        echo ""
        echo "Aktionen:"
        echo "  1) Zu Land verbinden"
        echo "  2) Status anzeigen"
        echo "  3) Verfügbare Länder anzeigen"
        echo "  4) Verbindung trennen"
        echo "  5) Standort anzeigen"
        echo "  6) VPN + Tor Chain"
        echo "  7) VPN zurücksetzen (bei Problemen)"
        echo "  8) Zurück"
        echo ""
        read -p "Aktion wählen (1-8 oder Name): " action

        case "$action" in
            1|connect)
                echo ""
                echo "Beliebte Länder:"
                echo "  DE - Deutschland"
                echo "  US - United States"
                echo "  UK - United Kingdom"
                echo "  NL - Niederlande"
                echo "  CH - Schweiz"
                echo "  FR - Frankreich"
                echo ""
                read -p "Land-Code eingeben (z.B. DE): " country_code
                country_code=$(echo "$country_code" | tr '[:lower:]' '[:upper:]')

                if validate_country_code "$country_code"; then
                    connect_vpn "$selected_provider" "$country_code"
                    echo ""
                    show_location
                else
                    log_error "Unbekannter Land-Code: $country_code"
                fi
                ;;
            2|status)
                echo ""
                check_vpn_status "$selected_provider"
                ;;
            3|countries)
                echo ""
                show_countries "$selected_provider"
                ;;
            4|disconnect)
                disconnect_vpn "$selected_provider"
                ;;
            5|location)
                echo ""
                show_location
                ;;
            6|chain)
                echo ""
                echo "VPN + Tor Chaining:"
                echo "  1) Tor-over-VPN (empfohlen)"
                echo "  2) VPN-over-Tor"
                echo ""
                read -p "Chain-Modus wählen (1-2 oder Name): " chain_mode
                read -p "Land-Code für VPN (z.B. DE): " country_code
                country_code=$(echo "$country_code" | tr '[:lower:]' '[:upper:]')

                case "$chain_mode" in
                    1|tor-over-vpn) setup_vpn_tor_chain "tor-over-vpn" "$selected_provider" "$country_code" ;;
                    2|vpn-over-tor) setup_vpn_tor_chain "vpn-over-tor" "$selected_provider" "$country_code" ;;
                esac
                ;;
            7|reset)
                echo ""
                read -p "VPN wirklich zurücksetzen? Dies behebt Netzwerkprobleme. (j/N): " confirm
                if [[ "$confirm" =~ ^[jJ]$ ]]; then
                    reset_vpn_complete
                fi
                ;;
            8|back)
                return 0
                ;;
        esac
    else
        log_error "Ungültiger Provider: $provider_choice"
        echo "Verfügbare Provider:"
        for provider in "${providers[@]}"; do
            echo "  • $provider ($(get_provider_name "$provider"))"
        done
        return 1
    fi
}

# Hauptfunktion
main() {
    init_vpn_config

    case "${1:-}" in
        "menu"|"")
            show_vpn_menu
            ;;
        "connect")
            if [ -z "${2:-}" ] || [ -z "${3:-}" ]; then
                echo "Usage: $0 connect <provider> <country>"
                echo "Beispiel: $0 connect nordvpn DE"
                exit 1
            fi
            connect_vpn "$2" "$3"
            ;;
        "disconnect")
            disconnect_vpn "${2:-}"
            ;;
        "reset")
            reset_vpn_complete
            ;;
        "status")
            if [ -n "${2:-}" ]; then
                check_vpn_status "$2"
            else
                local providers=($(detect_vpn_providers))
                for provider in "${providers[@]}"; do
                    echo -e "${BLUE}$(get_provider_name "$provider"):${NC}"
                    check_vpn_status "$provider"
                    echo ""
                done
            fi
            ;;
        "location")
            show_location
            ;;
        "countries")
            if [ -n "${2:-}" ]; then
                show_countries "$2"
            else
                echo "Usage: $0 countries <provider>"
            fi
            ;;
        "chain")
            if [ -z "${2:-}" ] || [ -z "${3:-}" ] || [ -z "${4:-}" ]; then
                echo "Usage: $0 chain <mode> <provider> <country>"
                echo "Modi: tor-over-vpn, vpn-over-tor"
                exit 1
            fi
            setup_vpn_tor_chain "$2" "$3" "$4"
            ;;
        "providers")
            echo "Erkannte VPN-Provider:"
            local providers=($(detect_vpn_providers))
            for provider in "${providers[@]}"; do
                echo "  $(get_provider_name "$provider") ($provider)"
            done
            ;;
        *)
            echo "Usage: $0 [menu|connect|disconnect|reset|status|location|countries|chain|providers]"
            echo ""
            echo "Beispiele:"
            echo "  $0 menu                          # Interaktives Menü"
            echo "  $0 connect nordvpn DE           # Zu Deutschland via NordVPN"
            echo "  $0 disconnect nordvpn           # NordVPN trennen"
            echo "  $0 reset                        # VPN zurücksetzen & Netzwerk reparieren"
            echo "  $0 status                       # Status aller VPNs"
            echo "  $0 location                     # Aktueller Standort"
            echo "  $0 chain tor-over-vpn nordvpn DE # VPN+Tor Chain"
            ;;
    esac
}

main "$@"
