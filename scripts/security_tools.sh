#!/bin/bash

# nulltrace Security Tools Suite
# Defensive Security-Analyse-Funktionen

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# Banner
show_security_banner() {
    echo -e "${BLUE}"
    echo "🛡️  nulltrace SECURITY TOOLS"
    echo "========================"
    echo -e "${NC}"
}

# System Security Check
system_security_check() {
    echo -e "${BLUE}🔍 System Security Analysis${NC}"
    echo "============================"
    echo ""

    echo -e "${YELLOW}[1] Firewall Status:${NC}"
    local fw_status
    fw_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep "enabled")
    if [ -n "$fw_status" ]; then
        echo "    ✅ Firewall ist aktiviert"
        local stealth
        # "Firewall stealth mode is on|off" — kein "enabled" wie beim globalstate
        stealth=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null | grep -i "mode is on")
        if [ -n "$stealth" ]; then
            echo "    ✅ Stealth-Modus aktiviert"
        else
            echo "    ⚠️  Stealth-Modus deaktiviert"
        fi
    else
        echo "    ❌ Firewall ist deaktiviert!"
    fi
    echo ""

    echo -e "${YELLOW}[2] System Integrity Protection:${NC}"
    local sip_status
    sip_status=$(csrutil status | grep -o "enabled\|disabled")
    if [ "$sip_status" = "enabled" ]; then
        echo "    ✅ SIP ist aktiviert"
    else
        echo "    ⚠️  SIP ist deaktiviert"
    fi
    echo ""

    echo -e "${YELLOW}[3] Gatekeeper Status:${NC}"
    local gatekeeper_status
    gatekeeper_status=$(spctl --status 2>/dev/null | grep -o "enabled\|disabled")
    if [ "$gatekeeper_status" = "enabled" ]; then
        echo "    ✅ Gatekeeper ist aktiviert"
    else
        echo "    ❌ Gatekeeper ist deaktiviert!"
    fi
    echo ""

    echo -e "${YELLOW}[4] FileVault Verschlüsselung:${NC}"
    local filevault_status
    filevault_status=$(fdesetup status | grep -o "On\|Off")
    if [ "$filevault_status" = "On" ]; then
        echo "    ✅ FileVault ist aktiviert"
    else
        echo "    ❌ FileVault ist deaktiviert!"
    fi
    echo ""

    echo -e "${YELLOW}[5] Verdächtige Prozesse:${NC}"
    local suspicious_count
    suspicious_count=$(ps aux | grep -E "(nc -l|python -m SimpleHTTPServer|python3 -m http.server)" | grep -v grep | wc -l)
    if [ "$suspicious_count" -eq 0 ]; then
        echo "    ✅ Keine verdächtigen Prozesse gefunden"
    else
        echo "    ⚠️  $suspicious_count verdächtige Prozesse gefunden!"
        ps aux | grep -E "(nc -l|python -m SimpleHTTPServer|python3 -m http.server)" | grep -v grep | head -5
    fi
    echo ""
}

# Network Security Scan
network_security_scan() {
    echo -e "${BLUE}🌐 Network Security Scan${NC}"
    echo "========================"
    echo ""

    echo -e "${YELLOW}[1] Offene Ports (Listening):${NC}"
    echo "    Scanne lokale Ports..."
    lsof -i -P | grep LISTEN | awk '{print "    Port " $9 " - " $1}' | sort -u
    echo ""

    echo -e "${YELLOW}[2] Aktive Netzwerkverbindungen:${NC}"
    local connection_count
    connection_count=$(netstat -an | grep ESTABLISHED | wc -l)
    echo "    Gefunden: $connection_count aktive Verbindungen"

    echo ""
    echo -e "${YELLOW}[3] Ausgehende Verbindungen:${NC}"
    netstat -an | grep ESTABLISHED | grep -v "127.0.0.1" | head -10
    echo ""
}

# DNS Security Check
dns_security_check() {
    echo -e "${BLUE}🔐 DNS Security Check${NC}"
    echo "====================="
    echo ""

    echo -e "${YELLOW}[1] Konfigurierte DNS Server:${NC}"
    scutil --dns | grep "nameserver" | sort -u | head -5
    echo ""

    echo -e "${YELLOW}[2] DNS Leak Test:${NC}"
    echo "    Teste DNS Auflösung..."
    local test_ip
    test_ip=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)
    local tor_port
    tor_port="$(get_config TOR_SOCKS_PORT 9050)"
    local tor_check
    tor_check=$(secure_curl "https://check.torproject.org/api/ip" --socks5-hostname "localhost:$tor_port" 2>/dev/null | jq -r '.IsTor' 2>/dev/null)

    if [ "$tor_check" = "true" ]; then
        echo "    ✅ DNS-Anfragen gehen über Tor"
    else
        echo "    ⚠️  DNS-Anfragen gehen NICHT über Tor"
        echo "    Ihre öffentliche IP: $test_ip"
    fi
    echo ""
}

# Privacy Audit
privacy_audit() {
    echo -e "${BLUE}🕵️ Privacy Audit${NC}"
    echo "================"
    echo ""

    echo -e "${YELLOW}[1] Browser-Daten:${NC}"
    local safari_history
    safari_history=$(find ~/Library/Safari -name "History.db" 2>/dev/null | wc -l)
    local chrome_history
    chrome_history=$(find ~/Library/Application\ Support/Google/Chrome -name "History" 2>/dev/null | wc -l)

    [ "$safari_history" -gt 0 ] && echo "    ⚠️  Safari-Verlauf vorhanden"
    [ "$chrome_history" -gt 0 ] && echo "    ⚠️  Chrome-Verlauf vorhanden"
    echo ""

    echo -e "${YELLOW}[2] Zwischenablage:${NC}"
    local clipboard_size
    clipboard_size=$(pbpaste 2>/dev/null | wc -c)
    if [ "$clipboard_size" -gt 0 ]; then
        echo "    ⚠️  Zwischenablage enthält $clipboard_size Zeichen"
        echo "    Tipp: Leeren mit: pbcopy < /dev/null"
    else
        echo "    ✅ Zwischenablage ist leer"
    fi
    echo ""

    echo -e "${YELLOW}[3] Zuletzt verwendete Objekte:${NC}"
    local recent_count
    recent_count=$(ls -la ~/Library/Application\ Support/com.apple.sharedfilelist/*.sfl2 2>/dev/null | wc -l)
    if [ "$recent_count" -gt 0 ]; then
        echo "    ⚠️  $recent_count Listen mit zuletzt verwendeten Objekten"
        echo "    Tipp: Löschen über Systemeinstellungen → Allgemein → Zuletzt benutzte Objekte"
    else
        echo "    ✅ Keine Listen gefunden"
    fi
    echo ""
}

# Vulnerability Check
vulnerability_check() {
    echo -e "${BLUE}🐛 Vulnerability Check${NC}"
    echo "======================"
    echo ""

    echo -e "${YELLOW}[1] System Version:${NC}"
    sw_vers
    echo ""

    echo -e "${YELLOW}[2] Veraltete Homebrew-Pakete:${NC}"
    if command -v brew > /dev/null 2>&1; then
        local outdated
        outdated=$(brew outdated | wc -l)
        if [ "$outdated" -gt 0 ]; then
            echo "    ⚠️  $outdated veraltete Pakete gefunden"
            brew outdated | head -5
            echo "    Tipp: Aktualisieren mit: brew upgrade"
        else
            echo "    ✅ Alle Pakete sind aktuell"
        fi
    else
        echo "    ℹ️  Homebrew nicht installiert"
    fi
    echo ""

    echo -e "${YELLOW}[3] SSH-Schlüssel Sicherheit:${NC}"
    if [ -d ~/.ssh ]; then
        local weak_keys
        weak_keys=$(find ~/.ssh -name "*.pub" -exec ssh-keygen -l -f {} \; 2>/dev/null | grep -E "(1024|weak)" | wc -l)
        if [ "$weak_keys" -gt 0 ]; then
            echo "    ⚠️  $weak_keys schwache SSH-Schlüssel gefunden"
        else
            echo "    ✅ Keine schwachen SSH-Schlüssel gefunden"
        fi

        local bad_perms
        bad_perms=$(find ~/.ssh -type f -name "id_*" ! -name "*.pub" -perm +044 2>/dev/null | wc -l)
        if [ "$bad_perms" -gt 0 ]; then
            echo "    ❌ $bad_perms private Schlüssel mit unsicheren Berechtigungen!"
        else
            echo "    ✅ SSH-Schlüssel-Berechtigungen sind sicher"
        fi
    else
        echo "    ℹ️  Kein SSH-Verzeichnis gefunden"
    fi
    echo ""
}

case "${1:-}" in
    "system")
        show_security_banner
        system_security_check
        ;;
    "network")
        show_security_banner
        network_security_scan
        ;;
    "dns")
        show_security_banner
        dns_security_check
        ;;
    "privacy")
        show_security_banner
        privacy_audit
        ;;
    "vuln")
        show_security_banner
        vulnerability_check
        ;;
    "full")
        show_security_banner
        system_security_check
        echo ""
        network_security_scan
        echo ""
        dns_security_check
        echo ""
        privacy_audit
        echo ""
        vulnerability_check
        ;;
    *)
        show_security_banner
        echo "Verfügbare Security Checks:"
        echo ""
        echo "  system  - System-Sicherheitsanalyse"
        echo "  network - Netzwerk-Sicherheitsscan"
        echo "  dns     - DNS-Sicherheitscheck"
        echo "  privacy - Privacy-Audit"
        echo "  vuln    - Vulnerability-Check"
        echo "  full    - Komplette Sicherheitsanalyse"
        echo ""
        echo "Verwendung: $0 [system|network|dns|privacy|vuln|full]"
        ;;
esac
