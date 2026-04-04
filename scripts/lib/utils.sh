#!/bin/bash

# nulltrace Shared Utility Library
# Zentrale Funktionen für alle Scripts
# (c) 2025 Martin Pfeffer - MIT License

# Verhindere doppeltes Laden
[ -n "$_NULLTRACE_UTILS_LOADED" ] && return 0
_NULLTRACE_UTILS_LOADED=1

# ─── Farben ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ─── Logging ─────────────────────────────────────────────────────────────────
log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { [ "${NULLTRACE_DEBUG:-0}" = "1" ] && echo -e "[DEBUG] $*" >&2; }

log_to_file() {
    local level="$1"; shift
    local log_file="${NULLTRACE_LOG_FILE:-$HOME/.nulltrace/nulltrace.log}"
    local log_dir
    log_dir="$(dirname "$log_file")"
    [ -d "$log_dir" ] || mkdir -p "$log_dir"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$log_file"
    # Rotiere bei >1MB
    if [ -f "$log_file" ] && [ "$(stat -f%z "$log_file" 2>/dev/null || echo 0)" -gt 1048576 ]; then
        mv "$log_file" "${log_file}.1"
    fi
}

# ─── Pfad-Erkennung ─────────────────────────────────────────────────────────
detect_nulltrace_dir() {
    # 1. Aus gespeichertem Install-Pfad
    if [ -f "$HOME/.nulltrace/install_path" ]; then
        local saved_dir
        saved_dir="$(cat "$HOME/.nulltrace/install_path")"
        if [ -f "$saved_dir/nulltrace.sh" ]; then
            echo "$saved_dir"
            return 0
        fi
    fi

    # 2. Relativ zum aufrufenden Script
    local caller_dir
    if [ -n "${BASH_SOURCE[1]}" ]; then
        caller_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    elif [ -n "${BASH_SOURCE[0]}" ]; then
        caller_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi

    # Suche nulltrace.sh aufwärts
    local dir="$caller_dir"
    while [ "$dir" != "/" ]; do
        if [ -f "$dir/nulltrace.sh" ]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done

    # 3. Bekannte Orte
    for dir in "$HOME/nulltrace" "$HOME/apps/nulltrace" "/opt/nulltrace"; do
        if [ -f "$dir/nulltrace.sh" ]; then
            echo "$dir"
            return 0
        fi
    done

    return 1
}

save_install_path() {
    local dir="$1"
    mkdir -p "$HOME/.nulltrace"
    echo "$dir" > "$HOME/.nulltrace/install_path"
}

# ─── Homebrew-Prefix ─────────────────────────────────────────────────────────
detect_homebrew_prefix() {
    if [ -d "/opt/homebrew" ]; then
        echo "/opt/homebrew"
    elif [ -d "/usr/local/Cellar" ]; then
        echo "/usr/local"
    else
        brew --prefix 2>/dev/null || echo "/usr/local"
    fi
}

# ─── Wi-Fi Interface Erkennung ──────────────────────────────────────────────
get_wifi_service() {
    local service
    service=$(networksetup -listallnetworkservices 2>/dev/null | grep -iE "^(Wi-Fi|WiFi|AirPort)$" | head -1)
    echo "${service:-Wi-Fi}"
}

get_wifi_interface() {
    local service
    service="$(get_wifi_service)"
    local iface
    iface=$(networksetup -listallhardwareports 2>/dev/null | awk -v svc="$service" '
        $0 ~ svc {getline; print $2}')
    echo "${iface:-en0}"
}

# ─── macOS Version ───────────────────────────────────────────────────────────
get_macos_version() {
    sw_vers -productVersion 2>/dev/null | cut -d. -f1
}

# ─── Sichere HTTP-Anfragen ──────────────────────────────────────────────────
secure_curl() {
    local url="$1"; shift
    # Erzwinge HTTPS
    url="${url/http:\/\//https:\/\/}"
    curl -4 -s --connect-timeout 5 "$url" "$@"
}

# ─── Input-Validierung ──────────────────────────────────────────────────────
validate_input() {
    local input="$1"
    local pattern="$2"
    local max_length="${3:-256}"

    # Längenprüfung
    [ ${#input} -gt "$max_length" ] && return 1
    # Pattern-Prüfung
    [[ "$input" =~ $pattern ]] || return 1
    # Keine Shell-Metazeichen
    [[ "$input" =~ [\;\|\&\$\`\\] ]] && return 1
    return 0
}

validate_country_code() {
    local code="$1"
    local valid_codes="DE US UK FR NL CH AT SE NO DK FI IS CA AU JP SG HK ES IT BE LU CZ PL RO BG EE LV LT SK SI HR HU GR CY MT IE PT MX BR AR CL IN KR TH MY ID PH VN TW NZ ZA IL AE TR"
    [[ " $valid_codes " == *" $code "* ]]
}

# ─── Sichere temporäre Dateien ───────────────────────────────────────────────
NULLTRACE_RUNTIME_DIR="$HOME/.nulltrace/runtime"

ensure_runtime_dir() {
    if [ ! -d "$NULLTRACE_RUNTIME_DIR" ]; then
        mkdir -p "$NULLTRACE_RUNTIME_DIR"
        chmod 700 "$NULLTRACE_RUNTIME_DIR"
    fi
}

create_secure_temp() {
    local prefix="${1:-nulltrace}"
    ensure_runtime_dir
    mktemp -d "$NULLTRACE_RUNTIME_DIR/${prefix}.XXXXXX"
}

cleanup_runtime() {
    rm -rf "${NULLTRACE_RUNTIME_DIR:?}/"* 2>/dev/null
}

# ─── Konfigurationssystem ───────────────────────────────────────────────────
NULLTRACE_CONFIG_DIR="$HOME/.nulltrace"
NULLTRACE_CONFIG_FILE="$NULLTRACE_CONFIG_DIR/config"

init_config() {
    mkdir -p "$NULLTRACE_CONFIG_DIR"

    [ -f "$NULLTRACE_CONFIG_FILE" ] && return 0

    cat > "$NULLTRACE_CONFIG_FILE" << 'CONF'
# nulltrace Konfiguration
# Erstellt von nulltrace v3.0

# Netzwerk-Interface (leer = Auto-Erkennung)
WIFI_INTERFACE=""
WIFI_SERVICE=""

# DNS-Provider: cloudflare, quad9, custom
DNS_PROVIDER="cloudflare"
CUSTOM_DNS_1=""
CUSTOM_DNS_2=""

# Privacy-Hostname
PRIVACY_HOSTNAME="Lisa"

# Tor-Einstellungen
TOR_SOCKS_PORT="9050"
TOR_TRANS_PORT="9040"
TOR_DNS_PORT="9053"

# Kill-Switch (Traffic blockieren wenn Tor/VPN ausfällt)
KILLSWITCH_ENABLED="false"

# IPv6-Behandlung
DISABLE_IPV6="true"

# API-Endpunkte (alle HTTPS)
IP_CHECK_URL="https://icanhazip.com"
TOR_CHECK_URL="https://check.torproject.org/api/ip"
GEO_API_URL="https://ipapi.co"

# Logging
LOG_LEVEL="info"
LOG_FILE="$HOME/.nulltrace/nulltrace.log"

# SwiftBar
SWIFTBAR_REFRESH_INTERVAL="5s"
CONF
}

load_config() {
    init_config

    while IFS='=' read -r key value; do
        # Kommentare und Leerzeilen überspringen
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | sed 's/^"//;s/"$//;s/^'"'"'//;s/'"'"'$//')
        # Variablenexpansion nur für $HOME
        value="${value/\$HOME/$HOME}"
        export "NULLTRACE_$key=$value"
    done < "$NULLTRACE_CONFIG_FILE"
}

get_config() {
    local key="$1"
    local default="$2"
    local var="NULLTRACE_$key"
    local val="${!var}"
    echo "${val:-$default}"
}

# ─── Netzwerk-Hilfsfunktionen ───────────────────────────────────────────────
get_effective_wifi_service() {
    local configured
    configured="$(get_config WIFI_SERVICE "")"
    if [ -n "$configured" ]; then
        echo "$configured"
    else
        get_wifi_service
    fi
}

get_effective_wifi_interface() {
    local configured
    configured="$(get_config WIFI_INTERFACE "")"
    if [ -n "$configured" ]; then
        echo "$configured"
    else
        get_wifi_interface
    fi
}

is_tor_running() {
    pgrep -x "tor" > /dev/null 2>&1 || lsof -i :"$(get_config TOR_SOCKS_PORT 9050)" > /dev/null 2>&1
}

is_vpn_active() {
    ifconfig | grep -q "utun" 2>/dev/null
}

# ─── IPv6-Leak-Prüfung ──────────────────────────────────────────────────────
verify_ipv6_disabled() {
    local service
    service="$(get_effective_wifi_service)"

    # Prüfe ob IPv6 noch per networksetup aktiv ist
    local v6_status
    v6_status=$(networksetup -getinfo "$service" 2>/dev/null | grep "IPv6:" | awk '{print $2}')
    if [ "$v6_status" = "Automatic" ] || [ "$v6_status" = "Manual" ]; then
        log_warn "IPv6 ist noch aktiv ($v6_status) auf $service"
        return 1
    fi

    # Teste ob tatsächlich IPv6-Konnektivität besteht
    if curl -6 -s --connect-timeout 2 https://ipv6.icanhazip.com 2>/dev/null | grep -q ":"; then
        log_error "KRITISCH: IPv6-Leak erkannt! IPv6-Verbindung möglich."
        return 1
    fi

    return 0
}

# ─── VPN-Helfer ──────────────────────────────────────────────────────────────
disconnect_all_vpn_providers() {
    for provider_cmd in nordvpn expressvpn mullvad surfshark-vpn protonvpn-cli; do
        if command -v "$provider_cmd" >/dev/null 2>&1; then
            case "$provider_cmd" in
                "nordvpn") nordvpn disconnect 2>/dev/null ;;
                "expressvpn") expressvpn disconnect 2>/dev/null ;;
                "mullvad") mullvad disconnect 2>/dev/null ;;
                "surfshark-vpn") surfshark-vpn disconnect 2>/dev/null ;;
                "protonvpn-cli") protonvpn-cli disconnect 2>/dev/null ;;
            esac
        fi
    done
}

# ─── Migration von xxxOS ────────────────────────────────────────────────────
migrate_from_xxxos() {
    local migrated=false

    # Config-Verzeichnis migrieren
    if [ -d "$HOME/.xxxos" ] && [ ! -d "$HOME/.nulltrace" ]; then
        mv "$HOME/.xxxos" "$HOME/.nulltrace"
        log_info "Migriert: ~/.xxxos -> ~/.nulltrace"
        migrated=true
    elif [ -d "$HOME/.xxxos" ] && [ -d "$HOME/.nulltrace" ]; then
        # Einzelne Dateien übernehmen die noch nicht existieren
        for f in "$HOME/.xxxos/"*; do
            local base
            base="$(basename "$f")"
            if [ ! -e "$HOME/.nulltrace/$base" ]; then
                mv "$f" "$HOME/.nulltrace/$base"
            fi
        done
        rm -rf "$HOME/.xxxos"
        migrated=true
    fi

    # Hosts-Backup umbenennen
    if [ -f "/etc/hosts.xxxos.backup" ] && [ ! -f "/etc/hosts.nulltrace.backup" ]; then
        sudo mv /etc/hosts.xxxos.backup /etc/hosts.nulltrace.backup 2>/dev/null
        migrated=true
    fi

    # Hosts-Datei Marker aktualisieren
    if grep -q "# xxxOS Privacy Block List" /etc/hosts 2>/dev/null; then
        sudo sed -i '' 's/# xxxOS Privacy Block List/# nulltrace Privacy Block List/' /etc/hosts 2>/dev/null
        migrated=true
    fi

    # Shell-Aliase aktualisieren
    for rcfile in "$HOME/.zshrc" "$HOME/.bash_profile"; do
        if [ -f "$rcfile" ] && grep -q "xxxOS ProxyChains Aliase" "$rcfile"; then
            sed -i '' 's/xxxOS ProxyChains Aliase/nulltrace ProxyChains Aliase/' "$rcfile"
            migrated=true
        fi
    done

    # Sudoers-Warnung
    if [ -f "/etc/sudoers.d/xxxos" ]; then
        log_warn "Alte sudoers-Datei gefunden: /etc/sudoers.d/xxxos"
        log_warn "Bitte führe aus: ./scripts/nulltrace_sudoers_setup.sh"
        log_warn "Dann entferne die alte: sudo rm /etc/sudoers.d/xxxos"
    fi

    if [ "$migrated" = true ]; then
        log_ok "Migration von xxxOS abgeschlossen"
    fi
}
