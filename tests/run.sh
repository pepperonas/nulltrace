#!/bin/bash
# nulltrace — Unit-Tests fuer die Bibliotheksfunktionen (reines bash, keine Abhaengigkeiten).
#
#   bash tests/run.sh
#
# SICHERHEIT: Die Tests laufen mit einem Wegwerf-HOME unter mktemp -d. `sudo`,
# `_pfctl`, `curl` und `osascript` sind durch Attrappen ersetzt, die nur
# protokollieren — es wird NIE echtes pf, sudo, networksetup oder ein echtes
# Nutzerverzeichnis angefasst.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/nulltrace-test.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

REAL_HOME="$HOME"
export HOME="$TMP/home"
mkdir -p "$HOME"
case "$HOME" in "$TMP"/*) ;; *) echo "Abbruch: HOME zeigt nicht ins Temp-Verzeichnis" >&2; exit 2 ;; esac
[ "$HOME" != "$REAL_HOME" ] || { echo "Abbruch: HOME unveraendert" >&2; exit 2; }

# Attrappen-Verzeichnis VOR dem echten PATH: selbst ein vergessener Stub laeuft
# nie gegen das echte System.
STUBS="$TMP/stubs"; mkdir -p "$STUBS"
CALLS="$TMP/calls.log"; : > "$CALLS"
for cmd in sudo pfctl osascript networksetup scutil ifconfig; do
    printf '#!/bin/sh\necho "%s $*" >> "%s"\nexit 0\n' "$cmd" "$CALLS" > "$STUBS/$cmd"
    chmod +x "$STUBS/$cmd"
done
export PATH="$STUBS:$PATH"

# shellcheck source=../scripts/lib/utils.sh
source "$ROOT/scripts/lib/utils.sh"
# shellcheck source=../scripts/lib/killswitch.sh
source "$ROOT/scripts/lib/killswitch.sh"

# Bibliothek darf nichts ausserhalb des Wegwerf-HOME ansteuern.
case "$NULLTRACE_RUNTIME_DIR" in "$TMP"/*) ;; *) echo "Abbruch: Runtime-Dir ausserhalb" >&2; exit 2 ;; esac
case "$KILLSWITCH_PF_BACKUP" in "$TMP"/*) ;; *) echo "Abbruch: pf-Backup ausserhalb: $KILLSWITCH_PF_BACKUP" >&2; exit 2 ;; esac

sudo() { echo "sudo $*" >> "$CALLS"; return 0; }
osascript() { return 0; }

PASS=0; FAIL=0; CURRENT=""
t() { CURRENT="$1"; }
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "FAIL [$CURRENT] $*"; }
check() { if "$@"; then ok; else bad "$*"; fi; }
refute() { if "$@"; then bad "erwartet falsch: $*"; else ok; fi; }
eq() { if [ "$1" = "$2" ]; then ok; else bad "erwartet '$2', bekommen '$1'"; fi; }
has() { if grep -qF -- "$2" "$1"; then ok; else bad "'$2' fehlt in $1"; fi; }

# ─── validate_input ─────────────────────────────────────────────────────────
t validate_input
check  validate_input "server-01.example" '^[a-z0-9.-]+$'
refute validate_input "abc" '^[0-9]+$'
refute validate_input "$(printf 'a%.0s' {1..300})" '^a+$'
check  validate_input "$(printf 'a%.0s' {1..5})" '^a+$' 5
refute validate_input "$(printf 'a%.0s' {1..6})" '^a+$' 5
for meta in ';' '|' '&' '$' '`' '\'; do
    refute validate_input "a${meta}b" '.*'
done

# ─── validate_country_code ──────────────────────────────────────────────────
t validate_country_code
check  validate_country_code DE
check  validate_country_code TR
refute validate_country_code de
refute validate_country_code XX
refute validate_country_code ""
refute validate_country_code "DE US"     # Teilstring der Liste
refute validate_country_code " DE"
refute validate_country_code "DEU"

# ─── secure_curl ────────────────────────────────────────────────────────────
t secure_curl
curl() { printf '%s\n' "$@"; }
out="$(secure_curl "http://example.com/a?next=http://x" -H "X: 1")"
eq "$(sed -n 1p <<<"$out")" "-4"
check grep -qx "https://example.com/a?next=http://x" <<<"$out"
check grep -qx -- "--connect-timeout" <<<"$out"
check grep -qx "X: 1" <<<"$out"
out="$(secure_curl "HTTP://example.com/")"
check grep -qx "https://example.com/" <<<"$out"
out="$(secure_curl "https://example.com/?u=http://y")"
check grep -qx "https://example.com/?u=http://y" <<<"$out"
unset -f curl

# ─── init_config / load_config / get_config ─────────────────────────────────
t config
refute test -e "$NULLTRACE_CONFIG_FILE"
load_config
check test -f "$NULLTRACE_CONFIG_FILE"
eq "$(get_config TOR_SOCKS_PORT 1)" "9050"
eq "$(get_config PRIVACY_HOSTNAME x)" "Lisa"
eq "$(get_config LOG_FILE x)" "$HOME/.nulltrace/nulltrace.log"   # $HOME expandiert
eq "$(get_config WIFI_INTERFACE en9)" "en9"                       # leer -> Default
eq "$(get_config GIBT_ES_NICHT fallback)" "fallback"
cat > "$NULLTRACE_CONFIG_FILE" <<'CONF'
# Kommentar
  # eingerueckter Kommentar

TOR_SOCKS_PORT='9150'
 SPACED_KEY = "wert"
GEO_API_URL="https://api.example/?a=1&b=2"
CONF
load_config
eq "$(get_config TOR_SOCKS_PORT 1)" "9150"
eq "$(get_config GEO_API_URL x)" "https://api.example/?a=1&b=2"
# init_config ueberschreibt eine bestehende Konfiguration nicht
init_config
check grep -q "9150" "$NULLTRACE_CONFIG_FILE"

# ─── log_to_file ────────────────────────────────────────────────────────────
t log_to_file
export NULLTRACE_LOG_FILE="$TMP/logs/nt.log"
log_to_file WARN "hallo welt"
check grep -qE '^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:]{8}\] \[WARN\] hallo welt$' "$NULLTRACE_LOG_FILE"
head -c 1048600 /dev/zero | tr '\0' 'x' > "$NULLTRACE_LOG_FILE"
log_to_file INFO "danach"
check test -f "$NULLTRACE_LOG_FILE.1"
refute test -e "$NULLTRACE_LOG_FILE"            # rotiert, neue Datei kommt mit dem naechsten Eintrag
log_to_file INFO "neu"
eq "$(cat "$NULLTRACE_LOG_FILE" | wc -l | tr -d ' ')" "1"
unset NULLTRACE_LOG_FILE

# ─── Runtime / Temp ─────────────────────────────────────────────────────────
t runtime
d1="$(create_secure_temp probe)"; d2="$(create_secure_temp probe)"
check test -d "$d1"
refute test "$d1" = "$d2"
case "$d1" in "$NULLTRACE_RUNTIME_DIR"/probe.*) ok ;; *) bad "falscher Ort: $d1" ;; esac
eq "$(stat -f %Lp "$NULLTRACE_RUNTIME_DIR" 2>/dev/null || stat -c %a "$NULLTRACE_RUNTIME_DIR")" "700"
touch "$HOME/.nulltrace/bleibt"
cleanup_runtime
refute test -e "$d1"
check test -d "$NULLTRACE_RUNTIME_DIR"
check test -e "$HOME/.nulltrace/bleibt"

# ─── detect_nulltrace_dir ───────────────────────────────────────────────────
t detect_nulltrace_dir
inst="$TMP/install"; mkdir -p "$inst"; touch "$inst/nulltrace.sh"
save_install_path "$inst"
eq "$(detect_nulltrace_dir)" "$inst"
save_install_path "$TMP/weg"                    # gespeicherter Pfad ungueltig -> Suche aufwaerts
eq "$(detect_nulltrace_dir)" "$ROOT"

# ─── pf_load_and_enable (Exit-Code von "pfctl -e" ist kein Fehlersignal) ────
t pf_load_and_enable
PF_LOAD_OK=1; PF_ENABLED=0; PF_ENABLE_WORKS=1; PF_CALLS=""
_pfctl() {
    PF_CALLS="$PF_CALLS|$*"
    case "$1" in
        -f) [ "$PF_LOAD_OK" = 1 ] ;;
        -n) echo "syntax error"; return 1 ;;
        -e) [ "$PF_ENABLE_WORKS" = 1 ] && PF_ENABLED=1; return 1 ;;   # meldet "already enabled"
        -s) [ "$PF_ENABLED" = 1 ] && echo "Status: Enabled for 1 days" || echo "Status: Disabled"; return 0 ;;
        -sr) echo "${PF_RULES:-}" ;;
    esac
}
PF_ENABLED=1; PF_CALLS=""
check pf_load_and_enable "$TMP/rules.conf"
case "$PF_CALLS" in *"|-e"*) bad "pf war schon an, -e trotzdem gerufen" ;; *) ok ;; esac
PF_ENABLED=0; PF_CALLS=""
check pf_load_and_enable "$TMP/rules.conf"
case "$PF_CALLS" in *"|-e"*) ok ;; *) bad "-e nicht gerufen" ;; esac
PF_ENABLED=0; PF_ENABLE_WORKS=0
refute pf_load_and_enable "$TMP/rules.conf"      # pf bleibt aus -> Fehler, kein falsches OK
PF_LOAD_OK=0; PF_ENABLED=1; PF_ENABLE_WORKS=1
refute pf_load_and_enable "$TMP/rules.conf" 2>/dev/null

# ─── pf_nulltrace_rules_loaded ──────────────────────────────────────────────
t pf_nulltrace_rules_loaded
id() { if [ "${1:-}" = "-u" ] && [ "${2:-}" = "_nulltrace_tor" ]; then echo 399; else command id "$@"; fi; }
PF_RULES='pass out quick proto tcp all user = 399 flags S/SA keep state'
check pf_nulltrace_rules_loaded
PF_RULES='pass out quick proto tcp all user = 501 flags S/SA keep state'
refute pf_nulltrace_rules_loaded
id() { if [ "${1:-}" = "-u" ] && [ "${2:-}" = "_nulltrace_tor" ]; then return 1; else command id "$@"; fi; }
PF_RULES='user = 399'
refute pf_nulltrace_rules_loaded                  # ohne Systemnutzer nie "geladen"
unset -f id

# ─── enable_killswitch / disable_killswitch ─────────────────────────────────
t killswitch
LOADED=""
pf_load_and_enable() { LOADED="$1"; return 0; }
export NULLTRACE_TOR_SOCKS_PORT=9150
check enable_killswitch >/dev/null
eq "$LOADED" "$KILLSWITCH_PF_RULES"
R="$KILLSWITCH_PF_RULES"
has "$R" "block all"
has "$R" "pass out quick proto tcp to 127.0.0.1 port 9150"
has "$R" "user _nulltrace_tor"
has "$R" "pass out quick proto udp from any port 68 to any port 67 no state"
has "$R" "pass in  quick proto udp from any port 67 to any port 68 no state"
check test -f "$KILLSWITCH_PF_BACKUP"
pf_load_and_enable() { return 1; }
refute enable_killswitch >/dev/null 2>&1
echo "pass all" > "$KILLSWITCH_PF_BACKUP"
: > "$CALLS"
disable_killswitch >/dev/null
has "$CALLS" "sudo pfctl -f $KILLSWITCH_PF_BACKUP"
has "$CALLS" "sudo pfctl -d"
refute test -e "$KILLSWITCH_PF_RULES"
refute test -e "$KILLSWITCH_PF_BACKUP"
unset NULLTRACE_TOR_SOCKS_PORT

# ─── stop_monitor ───────────────────────────────────────────────────────────
t stop_monitor
sleep 30 & SPID=$!
echo "$SPID" > "$KILLSWITCH_PID_FILE"
stop_monitor >/dev/null
sleep 0.2
refute kill -0 "$SPID" 2>/dev/null
refute test -e "$KILLSWITCH_PID_FILE"
echo 999999 > "$KILLSWITCH_PID_FILE"             # verwaiste PID-Datei
stop_monitor >/dev/null
refute test -e "$KILLSWITCH_PID_FILE"

# ─── migrate_from_xxxos ─────────────────────────────────────────────────────
t migrate_from_xxxos
rm -rf "$HOME/.nulltrace" "$HOME/.xxxos"
mkdir -p "$HOME/.xxxos"; echo alt > "$HOME/.xxxos/config"
migrate_from_xxxos >/dev/null
check test -f "$HOME/.nulltrace/config"
refute test -e "$HOME/.xxxos"
mkdir -p "$HOME/.xxxos"; echo alt > "$HOME/.xxxos/config"; echo nur-alt > "$HOME/.xxxos/extra"
echo neu > "$HOME/.nulltrace/config"
migrate_from_xxxos >/dev/null
eq "$(cat "$HOME/.nulltrace/config")" "neu"      # nie ueberschreiben
eq "$(cat "$HOME/.nulltrace/extra")" "nur-alt"   # fehlende Dateien uebernehmen
refute test -e "$HOME/.xxxos"

# ─── Ergebnis ───────────────────────────────────────────────────────────────
echo ""
echo "nulltrace tests: $PASS bestanden, $FAIL fehlgeschlagen"
[ "$FAIL" -eq 0 ]
