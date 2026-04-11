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
</p>

<h1 align="center">
  <br/>
  nulltrace
  <br/>
</h1>

<h4 align="center">Fire & Forget Privacy for macOS</h4>

<p align="center">
  One command. Full privacy. Zero traces.
</p>

---

## What It Does

nulltrace activates a complete privacy stack on macOS with a single command:

```
$ nulltrace privacy-on
```

This will:

| Step | Action | Detail |
|------|--------|--------|
| 1 | **MAC Spoofing** | Random unicast MAC on Wi-Fi (persists after privacy-off) |
| 2 | **Hostname Change** | Sets hostname to configurable alias (default: "Lisa") |
| 3 | **Firewall** | Enables macOS ALF firewall + stealth mode |
| 4 | **DNS Privacy** | Switches to Cloudflare 1.1.1.1 (or Quad9, custom) |
| 5 | **Tracking Block** | Adds tracking domains to `/etc/hosts` |
| 6 | **Location Services** | Disables `locationd` |
| 7 | **Tor** | Starts Tor + system-wide SOCKS5 proxy |
| 8 | **ProxyChains** | Configures for Tor routing |
| 9 | **Kill-Switch** | Optional pfctl-based traffic blocking when Tor drops |

To restore everything:

```
$ nulltrace privacy-off
```

## Quick Start

```bash
# Install
git clone https://github.com/pepperonas/nulltrace.git
cd nulltrace

# Optional: sudo-free operation (recommended)
./scripts/nulltrace_sudoers_setup.sh

# Go private
./nulltrace.sh privacy-on

# Check status
./nulltrace.sh status

# Restore
./nulltrace.sh privacy-off
```

### Shell Aliases (recommended)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias nt='./path/to/nulltrace.sh'
alias nts='./path/to/nulltrace.sh status'
alias nton='./path/to/nulltrace.sh privacy-on'
alias ntoff='./path/to/nulltrace.sh privacy-off'
```

## Usage

### Interactive Mode

```bash
./nulltrace.sh
```

Opens a full TUI menu with numbered options for all features.

### CLI Commands

```bash
# Privacy
./nulltrace.sh privacy-on          # Activate all privacy features
./nulltrace.sh privacy-off         # Restore normal settings
./nulltrace.sh status              # Privacy status dashboard

# Tor
./nulltrace.sh tor start           # Start Tor service
./nulltrace.sh tor stop            # Stop Tor service
./nulltrace.sh tor full-on         # Tor + system-wide proxy
./nulltrace.sh tor full-off        # Disable system-wide Tor
./nulltrace.sh tor trans-on        # Transparent Tor routing (all traffic)
./nulltrace.sh tor trans-off       # Disable transparent routing
./nulltrace.sh tor new-identity    # New Tor exit node
./nulltrace.sh tor test            # Test Tor connection

# Network
./nulltrace.sh mac                 # Spoof MAC address
./nulltrace.sh ipinfo              # IP & geolocation info (normal + Tor)
./nulltrace.sh killswitch on       # Enable kill-switch
./nulltrace.sh killswitch off      # Disable kill-switch

# VPN
./nulltrace.sh vpn menu            # Interactive VPN menu
./nulltrace.sh vpn status          # VPN connection status

# Security
./nulltrace.sh security system     # System security analysis
./nulltrace.sh security network    # Network security scan
./nulltrace.sh security dns        # DNS leak test
./nulltrace.sh security privacy    # Privacy audit
./nulltrace.sh security full       # Complete security analysis

# Help
./nulltrace.sh help                # Show help
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
DNS_PROVIDER="cloudflare"        # cloudflare, quad9, custom
PRIVACY_HOSTNAME="Lisa"          # Hostname during privacy mode
TOR_SOCKS_PORT="9050"           # Tor SOCKS port
KILLSWITCH_ENABLED="false"       # Auto-enable kill-switch with privacy-on
DISABLE_IPV6="true"             # Disable IPv6 in privacy mode
WIFI_INTERFACE=""               # Auto-detect if empty
LOG_LEVEL="info"                # debug, info, warn, error
CUSTOM_DNS_1="1.1.1.1"         # Custom primary DNS
CUSTOM_DNS_2="1.0.0.1"         # Custom secondary DNS
```

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
nulltrace.sh                     Main entry point (interactive + CLI)
scripts/
├── lib/
│   ├── utils.sh                 Shared utility library (colors, config,
│   │                            secure_curl, interface detection, logging)
│   └── killswitch.sh            pfctl-based kill-switch + connection monitor
├── tor_control.sh               Tor service management
├── tor_transparent.sh           Transparent Tor routing via pfctl
├── mac_spoofer.sh               MAC address randomization
├── vpn_control.sh               Multi-provider VPN management
├── proxychains_setup.sh         ProxyChains configuration
├── security_tools.sh            Security analysis suite
├── privacy_enhance.sh           Extended privacy functions (hostname, DNS, etc.)
├── sudo_cache_helper.sh         Sudo credential caching
└── nulltrace_sudoers_setup.sh   Sudoers file installation
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

## Security Design

- **HTTPS only** — All external API calls use `secure_curl()` which rejects HTTP
- **Secure temp files** — `mktemp` in `~/.nulltrace/runtime/` (mode 700)
- **IPv6 leak protection** — Automatic disabling with post-check verification
- **Input validation** — Shell metacharacter filtering on all user input
- **Country code validation** — Strict format check for VPN geo-selection
- **No hardcoded paths** — Auto-detection for Homebrew prefix, Wi-Fi interface, services
- **Stale lock detection** — Sudo cache helper cleans up orphaned locks

## License

MIT License — (c) 2025 Martin Pfeffer
