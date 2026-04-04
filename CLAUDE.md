# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

nulltrace is a macOS privacy/anonymity shell toolkit. Hub-and-spoke architecture: `nulltrace.sh` is the entry point that dispatches to sub-scripts in `scripts/`. All scripts source `scripts/lib/utils.sh` for shared utilities.

## Key Commands

```bash
# Run interactively
./nulltrace.sh

# Run specific command
./nulltrace.sh privacy-on
./nulltrace.sh status
./nulltrace.sh tor start

# Test sudoers setup
./test_setup.sh

# Syntax check (no shellcheck CI, run manually)
shellcheck nulltrace.sh scripts/*.sh scripts/lib/*.sh
```

## Architecture

- **`nulltrace.sh`** — Main script, interactive menu + CLI routing. Sources `scripts/lib/utils.sh` for config, logging, path detection.
- **`scripts/lib/utils.sh`** — Shared library loaded by all scripts. Contains: color constants, `secure_curl()` (forces HTTPS+IPv4), `get_wifi_interface()`/`get_wifi_service()` (auto-detection), `detect_homebrew_prefix()`, config system (`~/.nulltrace/config`), input validation, secure temp file creation, migration logic.
- **`scripts/lib/killswitch.sh`** — pfctl-based kill-switch with background connection monitor.
- **Sub-scripts** in `scripts/` handle specific domains (tor, mac, vpn, proxychains, security). Each sources `utils.sh` via `source "$SCRIPT_DIR/lib/utils.sh"`.

## Conventions

- All scripts use `#!/bin/bash` with `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` for path resolution.
- Never hardcode paths — use `detect_nulltrace_dir()`, `detect_homebrew_prefix()`, `get_wifi_interface()`.
- Never use HTTP for API calls — use `secure_curl()` which forces HTTPS.
- Config values accessed via `get_config KEY default_value`.
- User data in `~/.nulltrace/`, runtime files in `~/.nulltrace/runtime/` (mode 700, created via `create_secure_temp()`).
- German UI text throughout (user-facing strings, menus, help text). Comments may be German or English.
- The sudoers file is at `/etc/sudoers.d/nulltrace` (not xxxos).
- SwiftBar plugin should be named `nulltrace_status.5s.sh`.

## Security Constraints

- All external HTTP calls must use HTTPS (enforced by `secure_curl()`).
- Temp files must use `mktemp` via `create_secure_temp()`, never predictable paths.
- IPv6 must be verified after disabling (`verify_ipv6_disabled()`).
- Shell metacharacters must be validated in user input (`validate_input()`).
- Country codes validated via `validate_country_code()`.
