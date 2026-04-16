# WIFI-Cracker

WIFI-Cracker is a menu-driven Bash wrapper around common wireless auditing tools such as `airmon-ng`, `airodump-ng`, `aireplay-ng`, `aircrack-ng`, `hashcat`, and `macchanger`.

It is designed for authorized WiFi security research on Linux systems with a compatible adapter. It is not a full wireless auditing platform, and it does not replace the underlying aircrack-ng or hashcat toolchains.

## What It Does Well

- Detects wireless interfaces and helps switch them into monitor mode.
- Saves scan results to CSV and lets you pick a target from the latest scan.
- Starts focused handshake capture on a chosen BSSID and channel.
- Sends a deauthentication burst to encourage client re-association.
- Verifies whether the resulting capture appears to contain a handshake.
- Supports `aircrack-ng` dictionary attacks and `hashcat` workflows when `hcxpcapngtool` is installed.

## Current Limits

- It depends completely on external WiFi hardware and the aircrack/hashcat ecosystem.
- PMKID handling is only capture-oriented guidance, not a full automated PMKID workflow.
- Handshake verification still depends on `aircrack-ng` output and should be manually reviewed.
- There is no automated client discovery, WPA3 support, or persistent session management.

## Requirements

- Linux
- Root privileges
- Wireless adapter with monitor-mode and injection support

Required tools:

- `iwconfig`
- `ip`
- `airmon-ng`
- `airodump-ng`
- `aireplay-ng`
- `aircrack-ng`
- `hashcat`
- `macchanger`
- `curl`

Optional but recommended:

- `hcxpcapngtool`

## Usage

```bash
sudo ./wifi-cracker.sh
```

Typical workflow:

1. Start monitor mode on a wireless interface.
2. Run a scan and stop it with `Ctrl+C` when enough targets appear.
3. Select a target from the saved CSV.
4. Start handshake capture and stop it with `Ctrl+C` when you want to verify.
5. Pick a captured `.cap` file and choose a cracking method.

## Project Layout

```text
.
├── wifi-cracker.sh
├── lib/
│   ├── utils.sh
│   ├── interface.sh
│   ├── scanner.sh
│   ├── attacker.sh
│   └── cracker.sh
├── captures/
├── wordlists/
└── tests/
    └── smoke.sh
```

## Verification

Basic syntax smoke test:

```bash
./tests/smoke.sh
```

## Positioning

This project is a hardened research wrapper, not an industry-standard wireless auditing suite. Trust in this kind of tool comes from:

- correct monitor-mode handling
- predictable capture control
- honest documentation
- safe parsing of scan results
- manual validation of security findings

This repository is closer to that standard now, but serious use still depends on testing with real hardware and target labs.

## Legal

Use this tool only on networks you own or are explicitly authorized to assess.
