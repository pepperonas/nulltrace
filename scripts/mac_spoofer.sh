#!/bin/bash

# nulltrace MAC Address Spoofer
# Ändert die MAC-Adresse des Wi-Fi-Interfaces — sofern die Hardware das zulässt.
# (c) 2025 Martin Pfeffer - MIT License

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
load_config

# Überprüfen, ob sudo-Rechte verfügbar sind
if ! sudo -n dscacheutil -flushcache >/dev/null 2>&1; then
    echo "Dieses Skript benötigt sudo-Rechte. Installiere nulltrace sudoers mit: ./scripts/nulltrace_sudoers_setup.sh"
    exit 1
fi

INTERFACE="$(get_effective_wifi_interface)"
SERVICE="$(get_effective_wifi_service)"

if ! ifconfig "$INTERFACE" > /dev/null 2>&1; then
    echo "Netzwerkschnittstelle $INTERFACE nicht gefunden!"
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    echo "openssl ist nicht installiert. Bitte installiere es (z.B. via Homebrew: brew install openssl)."
    exit 1
fi

current_mac() { ifconfig "$INTERFACE" 2>/dev/null | awk '/ether/{print $2; exit}'; }

hardware_mac() {
    networksetup -getmacaddress "$INTERFACE" 2>/dev/null \
        | awk '/Ethernet Address/{print $3; exit}'
}

# Zufällige MAC: lokal verwaltet (Bit 1 gesetzt), unicast (Bit 0 gelöscht).
# Die alte Variante korrigierte nur ungerade Nibbles und konnte dadurch echte
# Hersteller-OUIs erzeugen.
random_mac() {
    local raw first
    raw=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')
    first=$(printf '%02x' $(( (0x${raw:0:2} | 0x02) & 0xfe )))
    echo "${first}${raw:2}"
}

OLD_MAC="$(current_mac)"
HW_MAC="$(hardware_mac)"
NEW_MAC="$(random_mac)"

echo "Aktuelle MAC-Adresse von $INTERFACE: ${OLD_MAC:-unbekannt}"
echo "Setze neue MAC-Adresse: $NEW_MAC"

# Wi-Fi MUSS eingeschaltet sein: mit abgeschaltetem Interface lehnt der Treiber
# SIOCAIFADDR ab ("Can't assign requested address"). Erst ändern, dann — nur bei
# Erfolg — neu assoziieren.
set_err="$(sudo ifconfig "$INTERFACE" ether "$NEW_MAC" 2>&1)"
set_rc=$?

if [ $set_rc -eq 0 ] && [ "$(current_mac)" = "$NEW_MAC" ]; then
    echo "Assoziiere neu, damit die neue Adresse verwendet wird..."
    sudo networksetup -setairportpower "$INTERFACE" off
    sleep 2
    sudo networksetup -setairportpower "$INTERFACE" on

    if wait_for_network "$INTERFACE" 45; then
        echo "Netzwerk wieder verbunden ($(/usr/sbin/ipconfig getifaddr "$INTERFACE"))"
    else
        log_warn "Interface hat nach 45 s noch keine IP-Adresse"
    fi

    echo "Neue MAC-Adresse von $INTERFACE: $(current_mac)"
    log_ok "MAC-Adresse geändert: ${OLD_MAC:-?} → $NEW_MAC"
    log_to_file "INFO" "MAC-Adresse geändert auf $INTERFACE: $NEW_MAC"
    exit 0
fi

# ─── Fehlschlag: ehrlich melden, Netzwerk NICHT anfassen ────────────────────
# Ein Power-Cycle wäre hier rein destruktiv (Verbindungsabbruch + neue
# DHCP-Runde) ohne jeden Privacy-Gewinn.
log_error "MAC-Adresse konnte NICHT geändert werden (weiterhin ${OLD_MAC:-unbekannt})"
[ -n "$set_err" ] && echo "  ${set_err#ifconfig: }"

if [ "$(uname -m)" = "arm64" ]; then
    echo ""
    echo "  Grund: Auf Apple Silicon verweigert der Wi-Fi-Treiber das Setzen der"
    echo "  MAC-Adresse (SIOCAIFADDR). Es gibt dafür keinen Workaround —"
    echo "  /usr/sbin/airport (früher 'airport -z') ist seit macOS 14.4 entfernt."
fi

if [ -n "$HW_MAC" ] && [ -n "$OLD_MAC" ] && [ "$HW_MAC" != "$OLD_MAC" ]; then
    echo ""
    echo -e "  ${GREEN}Gute Nachricht:${NC} macOS randomisiert die Adresse bereits selbst."
    echo "    Hardware-MAC:  $HW_MAC"
    echo "    Gesendete MAC: $OLD_MAC  (Private Wi-Fi-Adresse)"
    echo "  Prüfen/erzwingen: Systemeinstellungen → WLAN → '$SERVICE' → Details →"
    echo "  'Private WLAN-Adresse' auf 'Rotierend' stellen."
else
    echo ""
    echo "  Empfehlung: Systemeinstellungen → WLAN → Details → 'Private"
    echo "  WLAN-Adresse' aktivieren (macOS-eigene MAC-Randomisierung)."
fi

log_to_file "WARN" "MAC-Spoofing auf $INTERFACE fehlgeschlagen: ${set_err:-unbekannt}"
exit 1
