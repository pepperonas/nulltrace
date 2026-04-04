# nulltrace

**Privacy & Anonymity Suite for macOS**

nulltrace is a comprehensive privacy toolkit that provides integrated control over Tor, MAC spoofing, DNS privacy, firewall management, VPN integration, and more — all from a single command-line interface with optional SwiftBar menu bar integration.

## Features

- **One-command privacy**: `./nulltrace.sh privacy-on` activates MAC spoofing, Tor, DNS privacy, firewall stealth mode, and tracking protection
- **Tor integration**: Full Tor service management with system-wide proxy, transparent routing, and new identity requests
- **MAC address spoofing**: Random MAC generation with automatic Wi-Fi interface detection
- **Kill-Switch**: pfctl-based traffic blocking when Tor/VPN connection drops (opt-in)
- **VPN Geo-Selection**: Multi-provider support (NordVPN, ExpressVPN, Mullvad, Surfshark, ProtonVPN) with country selection
- **VPN+Tor Chaining**: Tor-over-VPN and VPN-over-Tor configurations
- **ProxyChains**: Pre-configured for Tor with shell aliases
- **Security analysis**: System security checks, network scans, DNS leak tests, privacy audits
- **SwiftBar plugin**: Real-time Tor status in the macOS menu bar
- **Configuration system**: `~/.nulltrace/config` for all settings
- **IPv6 leak protection**: Automatic disabling with verification

## Quick Start

```bash
# Clone the repository
git clone https://github.com/pepperonas/nulltrace.git
cd nulltrace

# Optional: Install sudo-free operation
./scripts/nulltrace_sudoers_setup.sh

# Activate full privacy mode
./nulltrace.sh privacy-on

# Check privacy status
./nulltrace.sh status

# Deactivate and restore normal settings
./nulltrace.sh privacy-off
```

## Usage

### Interactive Mode
```bash
./nulltrace.sh
```

### CLI Commands
```bash
./nulltrace.sh privacy-on       # Activate all privacy features
./nulltrace.sh privacy-off      # Restore normal settings
./nulltrace.sh status           # Show privacy status dashboard
./nulltrace.sh tor start        # Start Tor service
./nulltrace.sh tor full-on      # Start Tor + system proxy
./nulltrace.sh tor trans-on     # Transparent Tor routing
./nulltrace.sh tor new-identity # New Tor exit node
./nulltrace.sh mac              # Spoof MAC address
./nulltrace.sh ipinfo           # Show IP & geolocation info
./nulltrace.sh vpn menu         # Interactive VPN menu
./nulltrace.sh security full    # Complete security analysis
./nulltrace.sh killswitch on    # Enable kill-switch
./nulltrace.sh killswitch off   # Disable kill-switch
./nulltrace.sh help             # Show help
```

## What `privacy-on` Does

1. **MAC spoofing** — random unicast MAC on Wi-Fi interface (persists after privacy-off)
2. **Hostname change** — sets hostname to configurable name (default: "Lisa")
3. **Firewall** — enables macOS firewall with stealth mode
4. **DNS** — switches to Cloudflare (1.1.1.1) or configurable provider
5. **Tracking blocks** — adds tracking domains to /etc/hosts
6. **Location services** — disables locationd
7. **Tor** — starts Tor service + system-wide SOCKS5 proxy
8. **ProxyChains** — configures for Tor routing
9. **Kill-Switch** — optionally blocks all non-Tor traffic (if enabled in config)

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
```

## Architecture

```
nulltrace.sh                    # Main entry point (interactive + CLI)
scripts/
├── lib/
│   ├── utils.sh                # Shared utility library
│   └── killswitch.sh           # pfctl-based kill-switch
├── tor_control.sh              # Tor service management
├── tor_transparent.sh          # Transparent Tor routing + wrappers
├── tor_statusbar.sh            # SwiftBar plugin
├── mac_spoofer.sh              # MAC address randomization
├── vpn_control.sh              # Multi-provider VPN management
├── proxychains_setup.sh        # ProxyChains configuration
├── security_tools.sh           # Security analysis suite
├── privacy_enhance.sh          # Extended privacy functions
├── sudo_cache_helper.sh        # Sudo credential caching
├── nulltrace_sudoers_setup.sh  # Sudoers installation
├── swiftbar_helper.sh          # SwiftBar helper functions
├── statusbar_wrappers.sh       # StatusBar terminal wrappers
└── statusbar_launcher.sh       # SwiftBar auto-launcher
```

## Requirements

- macOS (tested on macOS 13+)
- Homebrew
- Tor (`brew install tor`)
- jq (`brew install jq`)
- ProxyChains (`brew install proxychains-ng`)
- SwiftBar (optional, for menu bar integration)

## Migration from xxxOS

nulltrace automatically migrates from xxxOS on first run:
- `~/.xxxos/` → `~/.nulltrace/`
- Hosts backup file renamed
- Shell aliases updated
- Sudoers file needs manual re-installation

## Security Notes

- All external API calls use HTTPS (no HTTP leaks)
- Temporary files use `mktemp` in `~/.nulltrace/runtime/` (mode 700)
- IPv6 leak verification after disabling
- Stale lock detection in sudo cache
- Input validation for country codes and user input

## License

MIT License — (c) 2025 Martin Pfeffer
