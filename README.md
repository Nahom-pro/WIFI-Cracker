# WIFI-Cracker

`WIFI-Cracker` is a Bash-driven wireless assessment wrapper for operators who want a fast, repeatable path through the usual WPA/WPA2 workflow without manually retyping the same `aircrack-ng` commands every time.

## What It Actually Does

- Enumerates wireless interfaces.
- Starts and stops monitor mode.
- Randomizes MAC addresses.
- Launches airodump scans and saves the latest CSV.
- Parses saved scan output into a target selection menu.
- Runs focused handshake capture against a chosen BSSID and channel.
- Fires a short deauthentication burst to force reassociation traffic.
- Checks captured `.cap` files for a handshake with `aircrack-ng`.
- Launches dictionary or mask-based cracking workflows from the menu.

## What It Does Not Do

- It does not bypass bad hardware support.
- It does not automate WPA3 attacks.
- It does not guarantee handshake capture.
- It does not validate findings beyond the output of the underlying tools.
- It is not a replacement for understanding 802.11 attack surface, RF conditions, or opsec.

## Operational Assumptions

Use this on Linux, as root, with an adapter that supports monitor mode and injection reliably enough for assessment work.

Required binaries:

- `iwconfig`
- `ip`
- `airmon-ng`
- `airodump-ng`
- `aireplay-ng`
- `aircrack-ng`
- `hashcat`
- `macchanger`
- `curl`

Optional:

- `hcxpcapngtool`

Without `hcxpcapngtool`, the hashcat conversion path is limited.

## Usage

```bash
sudo ./wifi-cracker.sh
```

Operator flow:

1. Select an interface and move it into monitor mode.
2. Run a scan and stop when target data is sufficient.
3. Pick a target from the saved CSV.
4. Start focused capture for the selected BSSID and channel.
5. Let the script send a short deauth burst.
6. Stop capture and review whether a handshake was actually obtained.
7. Choose a capture file and run a cracking workflow if that is in scope.

## File Layout

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

## Validation

Syntax smoke test:

```bash
./tests/smoke.sh
```

That test only checks shell syntax. It does not simulate live capture, adapter state transitions, deauth behavior, or hashcat execution. Real validation still requires lab hardware and controlled targets.

## Notes for Researchers

This repository is useful when you want a disposable, readable wrapper that keeps the workflow honest:

- monitor mode handling is explicit
- target selection is pulled from saved scan data
- capture output is local and inspectable
- handshake validation is visible, not hidden behind fake success messaging

If you want a polished multi-module wireless platform with persistence, richer target intelligence, and broader attack coverage, build that separately. This repo is intentionally smaller than that.

## Legal

Use only on infrastructure you own or are explicitly authorized to assess. Wireless testing without authorization is illegal in many jurisdictions and operationally reckless in all of them.
