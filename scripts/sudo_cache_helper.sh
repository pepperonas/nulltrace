#!/bin/bash

# nulltrace Sudo Cache Helper
# Globaler Sudo-Cache der zwischen Sessions funktioniert

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh" 2>/dev/null

ensure_runtime_dir 2>/dev/null || mkdir -p "$HOME/.nulltrace/runtime"

CACHE_PID_FILE="$HOME/.nulltrace/runtime/sudo_cache.pid"
CACHE_LOCK_FILE="$HOME/.nulltrace/runtime/sudo_cache.lock"

# Prüfe ob bereits eine Cache-Session aktiv ist
is_cache_active() {
    if [ -f "$CACHE_PID_FILE" ]; then
        local pid
        pid=$(cat "$CACHE_PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
    else
        return 1
    fi
}

# Starte globalen Sudo-Cache
start_cache() {
    if is_cache_active; then
        if sudo -n true 2>/dev/null; then
            echo -e "${GREEN}✅ Sudo-Cache bereits aktiv${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Cache aktiv aber sudo abgelaufen - erneuere...${NC}"
            stop_cache
        fi
    fi

    # Lock-Datei erstellen mit Stale-Lock-Erkennung
    local lock_attempts=0
    while ! (set -C; echo $$ > "$CACHE_LOCK_FILE") 2>/dev/null; do
        # Prüfe ob Lock-Halter noch lebt
        local lock_pid
        lock_pid=$(cat "$CACHE_LOCK_FILE" 2>/dev/null)
        if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
            rm -f "$CACHE_LOCK_FILE"
            continue
        fi
        lock_attempts=$((lock_attempts + 1))
        if [ $lock_attempts -ge 5 ]; then
            echo -e "${RED}❌ Konnte Lock nicht erwerben${NC}"
            return 1
        fi
        sleep 1
    done

    echo -e "${YELLOW}🔐 Administrator-Berechtigung erforderlich${NC}"
    echo -e "${BLUE}Diese Berechtigung wird für alle nulltrace-Sessions gecached.${NC}"
    echo ""

    if ! sudo -v 2>/dev/null; then
        echo -e "${RED}❌ Sudo-Berechtigung fehlgeschlagen${NC}"
        rm -f "$CACHE_LOCK_FILE"
        return 1
    fi

    echo -e "${GREEN}✅ Sudo-Cache gestartet${NC}"

    # Hintergrund-Prozess für Cache-Erneuerung
    (
        trap 'rm -f "$CACHE_PID_FILE" "$CACHE_LOCK_FILE"; exit' INT TERM EXIT

        echo $$ > "$CACHE_PID_FILE"

        while true; do
            if ! sudo -n true 2>/dev/null; then
                echo -e "${RED}❌ Sudo-Cache verloren${NC}"
                break
            fi
            sleep 240
        done
    ) &

    rm -f "$CACHE_LOCK_FILE"
    return 0
}

# Stoppe Sudo-Cache
stop_cache() {
    if [ -f "$CACHE_PID_FILE" ]; then
        local pid
        pid=$(cat "$CACHE_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            echo -e "${GREEN}✅ Sudo-Cache gestoppt${NC}"
        fi
        rm -f "$CACHE_PID_FILE"
    fi
    rm -f "$CACHE_LOCK_FILE"
}

# Cache-Status prüfen
check_cache() {
    if is_cache_active; then
        echo -e "${GREEN}✅ Sudo-Cache aktiv${NC}"
        if sudo -n true 2>/dev/null; then
            echo -e "${GREEN}✅ Sudo-Berechtigung verfügbar${NC}"
        else
            echo -e "${RED}❌ Sudo-Berechtigung nicht verfügbar${NC}"
        fi
    else
        echo -e "${RED}❌ Sudo-Cache nicht aktiv${NC}"
    fi
}

# Sudo mit Auto-Cache
cached_sudo() {
    if ! is_cache_active; then
        echo -e "${BLUE}🔐 Starte Sudo-Cache...${NC}"
        start_cache || return 1
    fi

    if ! sudo -n true 2>/dev/null; then
        echo -e "${BLUE}🔐 Sudo-Berechtigung erforderlich...${NC}"
        start_cache || return 1
    fi

    sudo "$@"
}

case "${1:-}" in
    start)
        start_cache
        ;;
    stop)
        stop_cache
        ;;
    status)
        check_cache
        ;;
    cached-sudo)
        shift
        cached_sudo "$@"
        ;;
    "")
        start_cache
        ;;
    *)
        echo "Usage: $0 {start|stop|status|cached-sudo <command>}"
        echo ""
        echo "Globaler Sudo-Cache für nulltrace"
        echo ""
        echo "  start        - Starte Sudo-Cache"
        echo "  stop         - Stoppe Sudo-Cache"
        echo "  status       - Prüfe Cache-Status"
        echo "  cached-sudo  - Führe sudo-Befehl mit Auto-Cache aus"
        ;;
esac
