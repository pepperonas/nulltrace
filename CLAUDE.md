# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nulltrace is a macOS privacy/anonymity shell toolkit. Hub-and-spoke architecture: `nulltrace.sh` is the entry point that dispatches to sub-scripts in `scripts/`. All scripts source `scripts/lib/utils.sh` for shared utilities.

## Commands

```bash
# Run interactively
./nulltrace.sh

# Privacy commands
./nulltrace.sh privacy-on       # Full privacy stack (MAC, Tor, firewall, pf killswitch)
./nulltrace.sh privacy-off      # Restore normal settings
./nulltrace.sh status           # Privacy status dashboard

# Individual modules
./nulltrace.sh tor start|stop|full-on|full-off|new-identity|test
./nulltrace.sh mac              # Spoof MAC address
./nulltrace.sh killswitch on|off
./nulltrace.sh security full    # Complete security analysis
./nulltrace.sh vpn menu         # VPN management

# Transparent Tor (standalone)
sudo ./scripts/tor_transparent.sh setup   # One-time user creation
sudo ./scripts/tor_transparent.sh start   # Start enforcement
sudo ./scripts/tor_transparent.sh stop    # Stop enforcement

# Sudoers setup (one-time, enables passwordless operation)
sudo ./scripts/nulltrace_sudoers_setup.sh

# Syntax check (no CI — run manually)
shellcheck nulltrace.sh scripts/*.sh scripts/lib/*.sh
```

## Architecture

### Script Loading & Shared State

All scripts use `set -uo pipefail` (or should). Every sub-script sources utils.sh:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"    # from scripts/
source "$SCRIPT_DIR/scripts/lib/utils.sh"  # from root
```

utils.sh has a double-load guard: `[ -n "${_NULLTRACE_UTILS_LOADED:-}" ] && return 0`. The `:-` is critical — without it, `set -u` causes an unbound variable error on first load.

### Config System

Config lives at `~/.nulltrace/config`. `load_config()` reads key=value pairs and exports them as `NULLTRACE_*` env vars. `get_config KEY default` retrieves values via indirect expansion:
```bash
local var="NULLTRACE_$key"
local val="${!var:-}"       # ← The :- is mandatory with set -u
echo "${val:-$default}"
```

**When adding new config keys:** Add defaults to `init_config()` in utils.sh AND document in README.

### Tor Enforcement (TOR_MODE=transparent)

The default mode uses a three-layer approach because Homebrew Tor has TransPort disabled:

1. **System SOCKS proxy** — `networksetup -setsocksfirewallproxy` routes browser/app traffic through Tor
2. **Proxy env vars** — `ALL_PROXY`/`http_proxy`/`https_proxy` in `/tmp/nulltrace_proxy_env` for terminal tools
3. **pf killswitch** — `pfctl` blocks ALL outgoing traffic except from user `_nulltrace_tor`

The `_nulltrace_tor` system user (UID 399) exists solely so pf can distinguish Tor's relay connections from regular user traffic:
```pf
pass out quick proto tcp user _nulltrace_tor flags S/SA keep state
block drop all
```

Tor runs as this user via `sudo -u _nulltrace_tor tor -f /var/lib/nulltrace-tor/torrc`.

### Tor Proxy Mode (TOR_MODE=proxy)

Fallback mode: `tor_control.sh full-on` starts Tor as current user, sets system SOCKS proxy. No pf enforcement — apps that ignore the proxy leak traffic directly.

### privacy-on Flow

1. MAC spoof → `mac_spoofer.sh`
2. Hostname/firewall/tracking/location → inline functions in nulltrace.sh
3. Tor → checks `get_config TOR_MODE transparent`:
   - transparent: `sudo tor_transparent.sh start` (creates user, starts Tor, sets proxy, applies pf)
   - proxy: `tor_control.sh full-on` (starts Tor, sets SOCKS proxy)
4. ProxyChains → `proxychains_setup.sh config`
5. Sources `/tmp/nulltrace_proxy_env` for current shell

### privacy-off Flow

1. Kill-switch disable
2. Detect mode (checks `pgrep -u _nulltrace_tor tor` or PID file):
   - transparent: `sudo tor_transparent.sh stop` (removes pf, stops Tor, restores proxy/DNS/IPv6)
   - proxy: `tor_control.sh full-off`
3. Restore hostname, DNS, tracking blocks

## Conventions

- All scripts use `#!/bin/bash` with `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` for path resolution.
- Never hardcode paths — use `detect_nulltrace_dir()`, `detect_homebrew_prefix()`, `get_wifi_interface()`.
- Never use HTTP — use `secure_curl()` which forces HTTPS and IPv4 (`curl -4`).
- Config values via `get_config KEY default_value`. Always provide a default.
- User data in `~/.nulltrace/`, runtime files in `~/.nulltrace/runtime/` (mode 700).
- German UI text throughout (user-facing strings, menus, help text). Comments may be German or English.
- The sudoers file is at `/etc/sudoers.d/nulltrace`.

## File Locations

| Path | Purpose |
|------|---------|
| `~/.nulltrace/config` | User configuration |
| `~/.nulltrace/runtime/` | PID files, pf rules (mode 700) |
| `~/.nulltrace/original_hostname` | Hostname backup for restore |
| `~/.nulltrace/nulltrace.log` | Activity log (rotates at 1MB) |
| `/var/lib/nulltrace-tor/` | Tor data dir (owned by _nulltrace_tor) |
| `/var/lib/nulltrace-tor/torrc` | Tor config (readable by _nulltrace_tor) |
| `/tmp/nulltrace_proxy_env` | Proxy env vars for terminal sessions |
| `/etc/sudoers.d/nulltrace` | Passwordless sudo rules |

## Gotchas

- **`set -u` and indirect expansion**: Every `${!var}` must be `${!var:-}`. Omitting `:-` causes unbound variable errors that silently break config lookups and mode detection.
- **pf rules are not idempotent**: `pfctl -f <file>` replaces the entire ruleset. The backup/restore pattern in tor_transparent.sh handles this, but running privacy-on twice without privacy-off can overwrite the original pf backup.
- **SocksPort must be 127.0.0.1**: Using `0.0.0.0` triggers a Tor warning about open proxies.
- **Tor circuit bootstrap takes time**: After SOCKS port opens, circuits need ~10-30s to build. The test in tor_transparent.sh retries up to 10x with 3s intervals.
- **Sudoers path assumption**: The sudoers entry uses `/Users/*/claude/nulltrace/scripts/tor_transparent.sh *`. Moving the repo breaks passwordless sudo.
- **MAC spoofing may fail silently**: `ifconfig ioctl` errors are non-fatal. The MAC address change relies on Wi-Fi off/on cycling which may not work on all hardware.
- **Homebrew Tor has no TransPort**: Transparent TCP interception via pf rdr rules is impossible with stock Homebrew Tor. The enforcement mode uses SOCKS proxy + pf killswitch instead.
- **DNS in transparent mode**: DNS goes to Cloudflare 1.1.1.1 (allowed by pf). Terminal tools using `socks5-hostname` resolve DNS through Tor. Browser DNS depends on SOCKS proxy settings.
- **`new-identity` and the `_nulltrace_tor` user**: `pkill -HUP tor` can't signal Tor when it runs as `_nulltrace_tor`. Use `sudo pkill -HUP -u _nulltrace_tor tor` as fallback. The function in `tor_control.sh` tries both.
- **Always use `--socks5-hostname`, never `--socks5`**: With `--socks5`, curl resolves DNS locally — which pf blocks in enforcement mode. `--socks5-hostname` sends the hostname to Tor for resolution.
- **ipapi.co rate limits**: The `myip` function can fail with non-JSON responses. Always handle jq parse errors gracefully.

## Security Constraints

- All external HTTP calls must use HTTPS (enforced by `secure_curl()`).
- Temp files must use `mktemp` via `create_secure_temp()`, never predictable paths.
- IPv6 is disabled at three layers: Tor config, pf rules, networksetup.
- Shell metacharacters must be validated in user input (`validate_input()`).
- Country codes validated via `validate_country_code()`.
- The torrc and Tor data directory must be owned by `_nulltrace_tor`, not root or the current user.
