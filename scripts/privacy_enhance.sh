#!/bin/bash

# nulltrace Erweiterte Privacy-Funktionen
# (c) 2025 Martin Pfeffer - MIT License
# Vereinfachte Version - Hauptfunktionen sind in nulltrace.sh implementiert

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
NULLTRACE_MAIN="$(dirname "$SCRIPT_DIR")/nulltrace.sh"

# SwiftBar Helper einbinden
if [ -f "$SCRIPT_DIR/swiftbar_helper.sh" ]; then
    source "$SCRIPT_DIR/swiftbar_helper.sh"
fi

# Hostname wiederherstellen
restore_hostname() {
    echo "🔄 Stelle Original-Hostname wieder her..."

    if [ -f "$HOME/.nulltrace/original_hostname" ]; then
        local original_name
        original_name=$(cat "$HOME/.nulltrace/original_hostname")
        sudo scutil --set ComputerName "$original_name"
        sudo scutil --set LocalHostName "$original_name"
        sudo scutil --set HostName "$original_name"
        echo "✅ Hostname wiederhergestellt: $original_name"
        rm -f "$HOME/.nulltrace/original_hostname"
    else
        echo "⚠️  Keine Original-Hostname-Datei gefunden"
        echo "   Verwende Standard: MacBook"
        sudo scutil --set ComputerName "MacBook"
        sudo scutil --set LocalHostName "MacBook"
        sudo scutil --set HostName "MacBook"
    fi
}

# Browser-Cache und Cookies löschen (optional)
clear_browser_data() {
    echo "🗑️  Browser-Daten löschen"
    echo "========================"
    echo ""
    echo "⚠️  WARNUNG: Diese Aktion löscht Browserverlauf und Cookies!"
    echo ""
    echo "💡 Hinweis: nulltrace (privacy-on) löscht KEINE Browser-Daten."
    echo "   Passwörter und Verläufe bleiben erhalten für bessere Benutzerfreundlichkeit."
    echo ""
    read -p "Trotzdem fortfahren? (j/N): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Jj]$ ]]; then
        echo "❌ Abgebrochen."
        return
    fi

    echo ""
    echo "🗑️  Lösche Browser-Daten..."

    if [ -d ~/Library/Safari ]; then
        rm -rf ~/Library/Safari/History.db* 2>/dev/null
        rm -rf ~/Library/Safari/Downloads.plist 2>/dev/null
        rm -rf ~/Library/Caches/com.apple.Safari/* 2>/dev/null
        echo "✅ Safari-Daten gelöscht"
    fi

    if [ -d ~/Library/Application\ Support/Google/Chrome ]; then
        rm -rf ~/Library/Application\ Support/Google/Chrome/Default/History* 2>/dev/null
        rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cookies* 2>/dev/null
        rm -rf ~/Library/Caches/Google/Chrome/* 2>/dev/null
        echo "✅ Chrome-Daten gelöscht"
    fi

    if [ -d ~/Library/Application\ Support/Firefox ]; then
        find ~/Library/Application\ Support/Firefox/Profiles -name "*.sqlite" -delete 2>/dev/null
        rm -rf ~/Library/Caches/Firefox/* 2>/dev/null
        echo "✅ Firefox-Daten gelöscht"
    fi
}

# WebRTC-Leak Protection Info
show_webrtc_info() {
    echo ""
    echo "⚠️  WebRTC-Leak Schutz:"
    echo "WebRTC kann deine echte IP-Adresse preisgeben, auch wenn du Tor/VPN nutzt!"
    echo ""
    echo "Empfohlene Browser-Einstellungen:"
    echo ""
    echo "🦊 Firefox:"
    echo "   1. Öffne about:config"
    echo "   2. Setze media.peerconnection.enabled auf false"
    echo ""
    echo "🌐 Chrome/Brave:"
    echo "   - Installiere WebRTC Leak Prevent Extension"
    echo ""
    echo "🧅 Tor Browser:"
    echo "   - WebRTC ist bereits deaktiviert"
}

# Legacy-Wrapper
clear_dns_cache()   { echo "ℹ️  DNS-Cache wird vom Hauptskript verwaltet. Verwende: ./nulltrace.sh privacy-on"; }
set_hostname_lisa() { echo "ℹ️  Hostname wird vom Hauptskript verwaltet. Verwende: ./nulltrace.sh privacy-on"; }
enable_firewall()   { echo "ℹ️  Firewall wird vom Hauptskript verwaltet. Verwende: ./nulltrace.sh privacy-on"; }
set_privacy_dns()   { echo "ℹ️  DNS-Einstellungen werden vom Hauptskript verwaltet. Verwende: ./nulltrace.sh privacy-on"; }
block_tracking()    { echo "ℹ️  Tracking-Schutz wird vom Hauptskript verwaltet. Verwende: ./nulltrace.sh privacy-on"; }
disable_location()  { echo "ℹ️  Ortungsdienste werden vom Hauptskript verwaltet. Verwende: ./nulltrace.sh privacy-on"; }
randomize_hostname() { set_hostname_lisa; }

case "${1:-}" in
    hostname-restore)
        restore_hostname
        ;;
    browser-clear)
        clear_browser_data
        ;;
    webrtc-info)
        show_webrtc_info
        ;;
    dns-clear|hostname|hostname-lisa|firewall|dns-privacy|block-tracking|location-off|all)
        echo "ℹ️  Diese Funktionen wurden ins Hauptskript integriert."
        echo "💡 Verwende: $NULLTRACE_MAIN privacy-on"
        echo ""
        echo "Soll das Hauptskript gestartet werden? (j/N)"
        read -p "> " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Jj]$ ]]; then
            "$NULLTRACE_MAIN"
        fi
        ;;
    *)
        echo "🔒 Erweiterte Privacy-Funktionen (Vereinfacht)"
        echo "=============================================="
        echo ""
        echo "💡 Die meisten Funktionen sind jetzt im Hauptskript:"
        echo "   ./nulltrace.sh privacy-on    - Aktiviert alle Privacy-Funktionen"
        echo "   ./nulltrace.sh privacy-off   - Deaktiviert Privacy-Funktionen"
        echo ""
        echo "Verfügbare spezielle Funktionen:"
        echo "  hostname-restore  - Original-Hostname wiederherstellen"
        echo "  browser-clear     - Browser-Daten löschen (⚠️  nicht empfohlen)"
        echo "  webrtc-info       - WebRTC-Leak Schutz Information"
        echo ""
        echo "🚀 Starte das Hauptskript für alle Privacy-Funktionen:"
        echo "   $NULLTRACE_MAIN"
        ;;
esac
