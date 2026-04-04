#!/bin/bash

# nulltrace MAC Address Spoofer
# Ändert die MAC-Adresse des Wi-Fi-Interfaces

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# Überprüfen, ob sudo-Rechte verfügbar sind
if ! sudo -n dscacheutil -flushcache >/dev/null 2>&1; then
    echo "Dieses Skript benötigt sudo-Rechte. Installiere nulltrace sudoers mit: ./scripts/nulltrace_sudoers_setup.sh"
    exit 1
fi

# Netzwerkschnittstelle automatisch erkennen
INTERFACE="$(get_effective_wifi_interface)"

if ! ifconfig "$INTERFACE" > /dev/null 2>&1; then
    echo "Netzwerkschnittstelle $INTERFACE nicht gefunden!"
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    echo "openssl ist nicht installiert. Bitte installiere es (z.B. via Homebrew: brew install openssl)."
    exit 1
fi

# Generiere eine zufällige MAC-Adresse (Unicast)
NEW_MAC=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//; s/^\(.\)[13579bdf]/\12/')

echo "Aktuelle MAC-Adresse von $INTERFACE:"
ifconfig "$INTERFACE" | grep ether | awk '{print $2}'

echo "Deaktiviere Wi-Fi..."
sudo networksetup -setairportpower "$INTERFACE" off

echo "Setze neue MAC-Adresse: $NEW_MAC"
sudo ifconfig "$INTERFACE" ether "$NEW_MAC"

echo "Aktiviere Wi-Fi..."
sudo networksetup -setairportpower "$INTERFACE" on

sleep 2

echo "Neue MAC-Adresse von $INTERFACE:"
ifconfig "$INTERFACE" | grep ether | awk '{print $2}'

echo "MAC-Adresse erfolgreich geändert!"
log_to_file "INFO" "MAC-Adresse geändert auf $INTERFACE: $NEW_MAC"
