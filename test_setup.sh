#!/bin/bash

# Test-Skript für nulltrace sudo-freie Konfiguration

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              nulltrace Setup Test                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. Prüfe ob sudoers installiert ist
echo -e "${YELLOW}1. Prüfe sudoers-Konfiguration...${NC}"
if [ -f "/etc/sudoers.d/nulltrace" ]; then
    echo -e "${GREEN}✅ nulltrace sudoers-Datei gefunden${NC}"
else
    echo -e "${RED}❌ nulltrace sudoers-Datei nicht gefunden${NC}"
    echo -e "${YELLOW}   Installiere mit: ./scripts/nulltrace_sudoers_setup.sh${NC}"
fi

# 2. Teste sudo-freie Befehle
echo ""
echo -e "${YELLOW}2. Teste sudo-freie Befehle...${NC}"

echo -n "   Teste hostname ändern... "
if sudo -n scutil --set ComputerName "TestName" 2>/dev/null; then
    sudo scutil --set ComputerName "$(scutil --get ComputerName)"
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ (Passwort erforderlich)${NC}"
fi

echo -n "   Teste SwiftBar neustarten... "
if sudo -n /usr/bin/killall SwiftBar 2>/dev/null || [ $? -eq 1 ]; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ (Passwort erforderlich)${NC}"
fi

echo -n "   Teste Netzwerk-Konfiguration... "
if sudo -n networksetup -listallnetworkservices >/dev/null 2>&1; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌ (Passwort erforderlich)${NC}"
fi

# 3. Teste SwiftBar Helper
echo ""
echo -e "${YELLOW}3. Teste SwiftBar Helper...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/scripts/swiftbar_helper.sh" ]; then
    echo -e "${GREEN}✅ SwiftBar Helper gefunden${NC}"
    source "$SCRIPT_DIR/scripts/swiftbar_helper.sh"

    echo -n "   Teste SwiftBar-Neustart... "
    if type restart_swiftbar >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Funktion verfügbar${NC}"
    else
        echo -e "${RED}❌ Funktion nicht verfügbar${NC}"
    fi
else
    echo -e "${RED}❌ SwiftBar Helper nicht gefunden${NC}"
fi

# 4. Zusammenfassung
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Zusammenfassung:${NC}"
echo ""

if [ -f "/etc/sudoers.d/nulltrace" ] && sudo -n dscacheutil -flushcache >/dev/null 2>&1; then
    echo -e "${GREEN}✅ System ist korrekt konfiguriert!${NC}"
    echo -e "${GREEN}   Du kannst nulltrace ohne Passwort-Eingaben verwenden.${NC}"
else
    echo -e "${YELLOW}⚠️  Setup noch nicht vollständig.${NC}"
    echo ""
    echo -e "${BLUE}Nächste Schritte:${NC}"
    echo "1. Führe aus: ./scripts/nulltrace_sudoers_setup.sh"
    echo "2. Starte Terminal neu"
    echo "3. Teste erneut mit diesem Skript"
fi

echo ""
