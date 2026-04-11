<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS"/>
  <img src="https://img.shields.io/badge/shell-bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" alt="Bash"/>
  <img src="https://img.shields.io/badge/license-MIT-blue?style=for-the-badge" alt="MIT License"/>
  <img src="https://img.shields.io/github/v/tag/pepperonas/nulltrace?style=for-the-badge&label=version&color=purple" alt="Version"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Tor-7D4698?style=flat-square&logo=torproject&logoColor=white" alt="Tor"/>
  <img src="https://img.shields.io/badge/Homebrew-FBB040?style=flat-square&logo=homebrew&logoColor=black" alt="Homebrew"/>
  <img src="https://img.shields.io/badge/ProxyChains-333333?style=flat-square&logo=chainguard&logoColor=white" alt="ProxyChains"/>
  <img src="https://img.shields.io/badge/Cloudflare_DNS-F38020?style=flat-square&logo=cloudflare&logoColor=white" alt="Cloudflare DNS"/>
  <img src="https://img.shields.io/badge/pfctl_Firewall-FF3E00?style=flat-square&logo=fireship&logoColor=white" alt="pfctl"/>
  <img src="https://img.shields.io/badge/WireGuard-88171A?style=flat-square&logo=wireguard&logoColor=white" alt="WireGuard"/>
</p>

<p align="center">
  <img src="https://img.shields.io/github/last-commit/pepperonas/nulltrace?style=flat-square&color=blue" alt="Last Commit"/>
  <img src="https://img.shields.io/github/commit-activity/m/pepperonas/nulltrace?style=flat-square&color=green" alt="Commit Activity"/>
  <img src="https://img.shields.io/github/repo-size/pepperonas/nulltrace?style=flat-square&color=orange" alt="Repo Size"/>
  <img src="https://img.shields.io/github/languages/code-size/pepperonas/nulltrace?style=flat-square&color=yellow" alt="Code Size"/>
  <img src="https://img.shields.io/github/stars/pepperonas/nulltrace?style=flat-square" alt="Stars"/>
  <img src="https://img.shields.io/github/forks/pepperonas/nulltrace?style=flat-square" alt="Forks"/>
  <img src="https://img.shields.io/github/issues/pepperonas/nulltrace?style=flat-square" alt="Issues"/>
  <img src="https://img.shields.io/github/languages/top/pepperonas/nulltrace?style=flat-square&color=4EAA25" alt="Top Language"/>
  <img src="https://img.shields.io/badge/shellcheck-passing-brightgreen?style=flat-square" alt="ShellCheck"/>
  <img src="https://img.shields.io/badge/dependencies-4-informational?style=flat-square" alt="Dependencies"/>
  <img src="https://img.shields.io/badge/sudo--free-supported-success?style=flat-square" alt="Sudo-free"/>
  <img src="https://img.shields.io/badge/IPv6_leak_protection-enabled-critical?style=flat-square" alt="IPv6 Protection"/>
  <img src="https://img.shields.io/badge/transparent_proxy-pf%20based-blueviolet?style=flat-square" alt="Transparent Proxy"/>
  <img src="https://img.shields.io/badge/traffic_leak-zero-red?style=flat-square" alt="Zero Leak"/>
</p>

<p align="center">
  <img src="banner.png" alt="nulltrace — Fire & Forget Privacy for macOS" width="100%"/>
</p>

<p align="center">
  One command. Full privacy. Zero traces.
</p>

---

## What It Does

nulltrace activates a complete privacy stack on macOS with a single command:

```
$ ./nulltrace.sh privacy-on
```

This will:

| Step | Action | Detail |
|------|--------|--------|
| 1 | **MAC Spoofing** | Random unicast MAC on Wi-Fi (persists after privacy-off) |
| 2 | **Hostname Change** | Sets hostname to configurable alias (default: "Lisa") |
| 3 | **Firewall** | Enables macOS ALF firewall + stealth mode |
| 4 | **Tracking Block** | Adds tracking domains to `/etc/hosts` |
| 5 | **Location Services** | Disables `locationd` |
| 6 | **Transparent Tor** | ALL network traffic forced through Tor via `pf` packet filter |
| 7 | **DNS over Tor** | All DNS queries routed through Tor's DNSPort |
| 8 | **IPv6 Block** | IPv6 completely disabled to prevent leaks |
| 9 | **ProxyChains** | Configures for Tor routing |

To restore everything:

```
$ ./nulltrace.sh privacy-off
```

## How Tor Enforcement Works

nulltrace uses a **SOCKS proxy + pf killswitch** architecture. Tor runs as a dedicated system user (`_nulltrace_tor`), and `pf` (macOS packet filter) blocks ALL outgoing traffic except from that user:

```
┌──────────────────────────────────────────────────────────────┐
│                      macOS Network Stack                      │
│                                                              │
│  Browser ────► System SOCKS Proxy ────► Tor (:9050) ──► Out  │
│                                                              │
│  Terminal ───► ALL_PROXY env var ──────► Tor (:9050) ──► Out  │
│                                                              │
│  Other App ──► No proxy? ──► pf block drop ──► BLOCKED       │
│                                                              │
│  Tor (_nulltrace_tor) ────────────────► pass out ────► Relays │
│                                                              │
│  IPv6 ───────────────────────────────► block drop ──► BLOCKED │
└──────────────────────────────────────────────────────────────┘
```

**Three layers of protection:**

1. **System SOCKS proxy** — Browsers and macOS-aware apps route through Tor automatically
2. **Proxy environment variables** (`ALL_PROXY`, `http_proxy`, `https_proxy`) — Terminal tools (curl, wget, git) route through Tor
3. **pf killswitch** — Everything that doesn't use the proxy gets **blocked, not leaked**

### Why a Dedicated User?

Tor needs to connect directly to relay nodes. If `pf` blocked Tor's own outgoing connections, nothing would work. nulltrace runs Tor as `_nulltrace_tor` (UID 399) so `pf` can exempt that specific user:

```pf
# Only Tor daemon can connect out
pass out quick proto tcp user _nulltrace_tor flags S/SA keep state

# Everything else is blocked
block drop all
```

### Coverage

| App Type | How it uses Tor | Leak if no proxy? |
|----------|----------------|-------------------|
| **Browsers** (Safari, Chrome, Firefox) | System SOCKS proxy | No — pf blocks |
| **Terminal** (curl, wget, git) | `ALL_PROXY` env var | No — pf blocks |
| **Electron apps** (Slack, VS Code) | System SOCKS proxy | No — pf blocks |
| **System services** (iCloud, updates) | System SOCKS proxy | No — pf blocks |
| **IPv6** | Completely disabled | No — pf blocks |

### Enforcement vs Proxy Mode

| | Enforcement (default) | Proxy |
|---|---|---|
| **Config value** | `TOR_MODE=transparent` | `TOR_MODE=proxy` |
| **Mechanism** | SOCKS proxy + pf killswitch | macOS system SOCKS proxy only |
| **Leak protection** | Complete (non-Tor traffic blocked by pf) | Partial (apps can bypass proxy) |
| **Requires** | `_nulltrace_tor` user, root | Root for proxy config |
| **Best for** | Maximum privacy | Quick setup, compatibility |

## Quick Start

```bash
# Clone
git clone https://github.com/pepperonas/nulltrace.git
cd nulltrace

# One-time: passwordless operation (installs /etc/sudoers.d/nulltrace)
sudo ./scripts/nulltrace_sudoers_setup.sh

# Go private (all traffic through Tor, leaks blocked by pf)
./nulltrace.sh privacy-on

# Check status
./nulltrace.sh status

# Restore normal settings
./nulltrace.sh privacy-off
```

### Shell Aliases (recommended)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
# Core
alias nt='/path/to/nulltrace.sh'
alias nts='/path/to/nulltrace.sh status'
alias nton='/path/to/nulltrace.sh privacy-on'
alias ntoff='/path/to/nulltrace.sh privacy-off'

# IP & Location — auto-detects Tor and routes accordingly
myip() {
  local flags=()
  pgrep -x tor >/dev/null 2>&1 \
    && flags=(--socks5-hostname 127.0.0.1:9050) && echo "🧅 Tor aktiv"
  local r
  r=$(curl -4 -s "${flags[@]}" https://ipapi.co/json/ 2>/dev/null)
  if echo "$r" | jq -e '.ip' >/dev/null 2>&1; then
    echo "$r" | jq -r '"IP:        " + .ip,
                        "Stadt:     " + .city,
                        "Region:    " + .region,
                        "Land:      " + .country_name,
                        "ISP:       " + .org,
                        "Koordinaten: " + (.latitude|tostring) + ", " + (.longitude|tostring)'
  else
    echo "Fehler: API nicht erreichbar (Rate-Limit? Warte 5s und versuche erneut)"
  fi
}

# New identity — requests a new Tor exit node and shows new location
alias newip='/path/to/nulltrace.sh tor new-identity \
  && sleep 2 && echo "───────────────────────────" && echo "Neuer Standort:" \
  && curl -4 -s --socks5-hostname 127.0.0.1:9050 https://ipapi.co/json/ \
     | jq -r "\"IP:        \" + .ip, \"Stadt:     \" + .city, \"Land:      \" + .country_name"'
```

> **Note:** `socks5-hostname` resolves DNS through Tor (not locally). The `-4` flag forces IPv4 to prevent IPv6 leaks.

| Alias | Requires Tor | What it does |
|-------|-------------|--------------|
| `nt` | No | Interactive menu |
| `nts` | No | Privacy status dashboard |
| `nton` | — | Activate all privacy features + Tor |
| `ntoff` | — | Restore normal settings |
| `myip` | Auto-detect | Show current IP & location (uses Tor if running) |
| `newip` | Yes | Request new Tor exit node, show new location |

## Usage

### Interactive Mode

```bash
./nulltrace.sh
```

Opens a full TUI menu with numbered options for all features.

### CLI Commands

```bash
# ── Privacy ──────────────────────────────────────────────
./nulltrace.sh privacy-on          # Activate all privacy features
./nulltrace.sh privacy-off         # Restore normal settings
./nulltrace.sh status              # Privacy status dashboard

# ── Tor ──────────────────────────────────────────────────
./nulltrace.sh tor start           # Start Tor service only
./nulltrace.sh tor stop            # Stop Tor service only
./nulltrace.sh tor full-on         # Tor + system-wide SOCKS proxy
./nulltrace.sh tor full-off        # Disable system-wide Tor
./nulltrace.sh tor trans-on        # Transparent Tor routing (pf-based)
./nulltrace.sh tor trans-off       # Disable transparent routing
./nulltrace.sh tor new-identity    # Request new Tor exit node
./nulltrace.sh tor test            # Test Tor connection

# ── Network ──────────────────────────────────────────────
./nulltrace.sh mac                 # Spoof MAC address
./nulltrace.sh ipinfo              # IP & geolocation info (normal + Tor)
./nulltrace.sh killswitch on       # Enable kill-switch
./nulltrace.sh killswitch off      # Disable kill-switch

# ── VPN ──────────────────────────────────────────────────
./nulltrace.sh vpn menu            # Interactive VPN menu
./nulltrace.sh vpn status          # VPN connection status
./nulltrace.sh vpn location        # Current geographic location

# ── Security ─────────────────────────────────────────────
./nulltrace.sh security system     # System security analysis
./nulltrace.sh security network    # Network security scan
./nulltrace.sh security dns        # DNS leak test
./nulltrace.sh security privacy    # Privacy audit
./nulltrace.sh security vuln       # Vulnerability check
./nulltrace.sh security full       # Complete security analysis

# ── Help ─────────────────────────────────────────────────
./nulltrace.sh help                # Show help
```

### Standalone Transparent Tor

You can also use transparent Tor independently of the full privacy suite:

```bash
# Setup (one-time): creates _nulltrace_tor system user
sudo ./scripts/tor_transparent.sh setup

# Start transparent routing
sudo ./scripts/tor_transparent.sh start

# Check status
./scripts/tor_transparent.sh status

# Stop and restore normal networking
sudo ./scripts/tor_transparent.sh stop
```

## Privacy Levels

The status dashboard shows a 5-level privacy score:

| Level | Bar | Condition |
|-------|-----|-----------|
| **MAXIMUM** | `⬛⬛⬛⬛⬛` | Tor active + all protections enabled |
| **HIGH** | `⬛⬛⬛⬛⬜` | Tor active + most protections |
| **MEDIUM** | `⬛⬛⬛⬜⬜` | Tor active + some protections |
| **LOW** | `⬛⬛⬜⬜⬜` | No Tor, but firewall/DNS active |
| **MINIMAL** | `⬛⬜⬜⬜⬜` | Only basic protections |
| **NONE** | `⬜⬜⬜⬜⬜` | No protections active |

## Configuration

Settings are stored in `~/.nulltrace/config`:

```ini
# ── Tor ──────────────────────────────────────────────────
TOR_MODE="transparent"           # transparent (SOCKS + pf killswitch) or proxy (SOCKS only)
TOR_SOCKS_PORT="9050"           # Tor SOCKS5 port

# ── Network ──────────────────────────────────────────────
DNS_PROVIDER="cloudflare"        # cloudflare, quad9, custom (proxy mode only)
CUSTOM_DNS_1="1.1.1.1"          # Custom primary DNS
CUSTOM_DNS_2="1.0.0.1"          # Custom secondary DNS
WIFI_INTERFACE=""               # Auto-detect if empty
DISABLE_IPV6="true"             # Disable IPv6 in privacy mode

# ── Privacy ──────────────────────────────────────────────
PRIVACY_HOSTNAME="Lisa"          # Hostname during privacy mode
KILLSWITCH_ENABLED="false"       # Auto-enable kill-switch (proxy mode)

# ── System ───────────────────────────────────────────────
LOG_LEVEL="info"                # debug, info, warn, error
```

### Key Config: `TOR_MODE`

| Value | Behavior |
|-------|----------|
| `transparent` | (Default) Creates `_nulltrace_tor` user, runs Tor as that user, sets system SOCKS proxy + env vars, applies `pf` killswitch that blocks all non-Tor traffic. |
| `proxy` | Sets macOS system SOCKS proxy to Tor. Only apps that respect system proxy settings use Tor. DNS goes through configured provider (Cloudflare/Quad9). Legacy mode for compatibility. |

## VPN Support

Multi-provider VPN with geographic server selection:

| Provider | Status |
|----------|--------|
| NordVPN | Supported |
| ExpressVPN | Supported |
| Mullvad | Supported |
| Surfshark | Supported |
| ProtonVPN | Supported |

Advanced chaining modes:
- **Tor-over-VPN** — VPN first, then Tor (hides Tor usage from ISP)
- **VPN-over-Tor** — Tor first, then VPN (hides VPN destination)

## Architecture

```
nulltrace.sh                        Main entry point (interactive menu + CLI)
│
├── scripts/
│   ├── lib/
│   │   ├── utils.sh                Shared library: colors, config, secure_curl,
│   │   │                           Wi-Fi interface/service auto-detection, logging,
│   │   │                           input validation, migration, temp file mgmt
│   │   └── killswitch.sh           pfctl kill-switch + background connection monitor
│   │
│   ├── tor_control.sh              Tor service: start/stop, SOCKS proxy, new identity
│   ├── tor_transparent.sh          Transparent Tor: _nulltrace_tor user, pf rules,
│   │                               TransPort/DNSPort config, full traffic redirect
│   ├── mac_spoofer.sh              MAC address randomization (permanent across sessions)
│   ├── vpn_control.sh              Multi-provider VPN: connect, geo-select, chaining
│   ├── proxychains_setup.sh        ProxyChains-ng config + shell aliases
│   ├── security_tools.sh           Security audit: system, network, DNS, privacy, vuln
│   ├── privacy_enhance.sh          Extended privacy: hostname, DNS, tracking, location
│   ├── sudo_cache_helper.sh        Sudo credential caching with stale lock detection
│   └── nulltrace_sudoers_setup.sh  Sudoers file install (passwordless operation)
│
├── ~/.nulltrace/
│   ├── config                      User configuration
│   ├── runtime/                    PID files, pf rules, torrc (mode 700)
│   └── original_hostname           Backup of original hostname
│
└── /var/lib/nulltrace-tor/         Tor data directory (owned by _nulltrace_tor)
    └── tor.log                     Tor daemon log
```

### Enforcement Data Flow

```
privacy-on:
                                                        
  ❶ MAC spoof ──► random unicast MAC on Wi-Fi           
  ❷ Hostname ──► scutil --set * "Lisa"                  
  ❸ Firewall ──► ALF on + stealth mode                  
  ❹ Tracking ──► /etc/hosts block list                  
  ❺ Location ──► launchctl unload locationd              
  ❻ Tor start ──► sudo -u _nulltrace_tor tor             
     │            SocksPort 127.0.0.1:9050                 
  ❼ Proxy ────► System SOCKS proxy → 127.0.0.1:9050     
     │           ALL_PROXY / http_proxy env vars         
     │           DNS → Cloudflare 1.1.1.1                
  ❽ pf rules ──► pass out user _nulltrace_tor only       
     │            block drop all (everything else)       
     │            block inet6 all (no IPv6)              
  ❾ ProxyChains config                                   
                                                        
privacy-off:
                                                        
  ❶ pf disable + restore previous rules                 
  ❷ Remove system SOCKS proxy                           
  ❸ Kill Tor daemon (_nulltrace_tor)                    
  ❹ Restore IPv6, DNS, hostname                         
  ❺ Remove tracking blocks                               
  ❻ Clean runtime files                                  
```

## Requirements

| Dependency | Install | Required |
|-----------|---------|----------|
| macOS 13+ | — | Yes |
| Homebrew | [brew.sh](https://brew.sh) | Yes |
| Tor | `brew install tor` | Yes |
| jq | `brew install jq` | Yes |
| ProxyChains | `brew install proxychains-ng` | Yes |

Missing dependencies are detected on startup with an option to auto-install.

### Passwordless Operation (sudoers)

nulltrace needs root for `pf` rules, hostname changes, firewall settings, and running Tor as a dedicated user. Instead of typing your password every time, run the sudoers setup **once**:

```bash
sudo ./scripts/nulltrace_sudoers_setup.sh
```

This creates `/etc/sudoers.d/nulltrace` which grants passwordless `sudo` for **only** the specific commands nulltrace needs:

| Category | Commands |
|----------|----------|
| **Hostname** | `scutil --set/--get ComputerName/LocalHostName/HostName` |
| **DNS** | `dscacheutil -flushcache`, `killall mDNSResponder` |
| **Network** | `ifconfig`, `networksetup`, `ipconfig`, `route` |
| **Firewall** | `socketfilterfw`, `pfctl` |
| **Tor Enforcement** | `dscl` (user mgmt), `sudo -u _nulltrace_tor`, `pkill -u` |
| **Services** | `launchctl`, `brew services` |
| **Hosts file** | `/etc/hosts` read/write/backup |
| **Tor script** | `tor_transparent.sh start/stop/setup` |

**Security:** No password is stored anywhere. The sudoers file only allows pre-defined commands — not arbitrary root access. Remove anytime with `sudo rm /etc/sudoers.d/nulltrace`.

### Enforcement Mode Additional Requirements

Automatically handled during first `nton` run:

- **`_nulltrace_tor` system user** — Created via `dscl` (UID 399, hidden from login screen)
- **`/var/lib/nulltrace-tor/`** — Tor data directory owned by `_nulltrace_tor`

Run `sudo ./scripts/tor_transparent.sh setup` to pre-create the user and directories manually.

### Terminal Proxy Setup

After `nton`, new terminal windows need the proxy environment loaded:

```bash
source /tmp/nulltrace_proxy_env
```

This sets `ALL_PROXY`, `http_proxy`, and `https_proxy` so that curl, wget, git, and other tools route through Tor. Without this, terminal traffic gets **blocked by pf** (not leaked — just blocked).

Add to `~/.zshrc` for automatic loading:

```bash
[ -f /tmp/nulltrace_proxy_env ] && source /tmp/nulltrace_proxy_env
```

## Security Design

- **Zero traffic leaks** — `pf` blocks all outgoing traffic except from the `_nulltrace_tor` user. Apps that don't use the SOCKS proxy have their traffic blocked, not leaked.
- **User-based enforcement** — Tor runs as `_nulltrace_tor`; `pf` allows only that user to connect out. No port-based allowlists that could be exploited.
- **HTTPS only** — All external API calls use `secure_curl()` which rejects HTTP.
- **Secure temp files** — `mktemp` in `~/.nulltrace/runtime/` (mode 700).
- **IPv6 leak protection** — Completely blocked in `pf` rules + `networksetup -setv6off`.
- **DNS privacy** — DNS routed to Cloudflare 1.1.1.1 (encrypted). Terminal tools using `socks5-hostname` resolve DNS through Tor.
- **Input validation** — Shell metacharacter filtering on all user input.
- **Country code validation** — Strict format check for VPN geo-selection.
- **No hardcoded paths** — Auto-detection for Homebrew prefix, Wi-Fi interface, services.
- **Stale lock detection** — Sudo cache helper cleans up orphaned locks.
- **Atomic pf updates** — Previous pf state backed up and restored on privacy-off.

## Verifying Your Privacy

Once `nton` is active, verify everything works:

```bash
# Check your visible IP and location (should show Tor exit node, not your real IP)
$ myip
🧅 Tor aktiv
IP:        193.189.100.202
Stadt:     Stockholm
Region:    Stockholm County
Land:      Sweden
ISP:       KeFF Networks Ltd
Koordinaten: 59.3287, 18.0717

# Not happy with the location? Get a new one:
$ newip
✅ Signal gesendet. Warte auf neue Verbindung...
✅ Neue IP-Adresse: 185.220.101.45
📍 Neuer Standort: Amsterdam, Netherlands
───────────────────────────
Neuer Standort:
IP:        185.220.101.45
Stadt:     Amsterdam
Land:      Netherlands

# Verify with Tor Project's own check:
$ curl -4 --socks5-hostname 127.0.0.1:9050 -s https://check.torproject.org/api/ip | jq .
{
  "IsTor": true,
  "IP": "185.220.101.45"
}
```

> **Important:** Always use `--socks5-hostname` (not `--socks5`) in manual curl commands.
> With `--socks5`, DNS is resolved locally — which the pf killswitch blocks.
> `--socks5-hostname` sends the hostname to Tor for resolution, avoiding DNS leaks.

If `myip` still shows your real IP after `nton`, run `ntoff` and then `nton` again.

## Troubleshooting

### Transparent Tor won't start

```bash
# Check Tor log
cat /var/lib/nulltrace-tor/tor.log

# Verify _nulltrace_tor user exists
id _nulltrace_tor

# Re-run setup
sudo ./scripts/tor_transparent.sh setup
```

### Internet not working after privacy-off

```bash
# Manually disable pf
sudo pfctl -d

# Reset DNS
networksetup -setdnsservers Wi-Fi "Empty"

# Re-enable IPv6
networksetup -setv6automatic Wi-Fi
```

### Check if traffic goes through Tor

```bash
# Via SOCKS proxy (should show IsTor: true)
curl -4 --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip

# Or use the myip alias
myip

# Check pf killswitch status
sudo pfctl -s rules
```

### Password prompt despite sudoers setup

```bash
# Re-run the sudoers installer
sudo ./scripts/nulltrace_sudoers_setup.sh

# Verify it's installed
cat /etc/sudoers.d/nulltrace | head -5
```

### `newip` says "Konnte neue IP nicht abrufen"

In enforcement mode, Tor runs as `_nulltrace_tor`. The `newip` command sends a HUP signal to request a new circuit — this requires sudo to signal a process owned by another user. The sudoers setup handles this automatically:

```bash
# If not yet done:
sudo ./scripts/nulltrace_sudoers_setup.sh

# Then retry:
newip
```

### API rate limit errors in myip

ipapi.co limits free requests. Wait a few seconds between calls. The `myip` function handles this gracefully with an error message instead of crashing.

### Switch to proxy mode (if enforcement causes issues)

Add to `~/.nulltrace/config`:
```ini
TOR_MODE=proxy
```

This uses a basic SOCKS proxy without pf killswitch — less secure but more compatible.

## License

MIT License — (c) 2025 Martin Pfeffer
