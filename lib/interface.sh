#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

list_interfaces() {
    local interfaces
    interfaces=$(iwconfig 2>/dev/null | awk '/IEEE 802.11/ {print $1}')
    if [ -z "$interfaces" ]; then
        return 1
    fi
    printf '%s\n' "$interfaces"
}

detect_monitor_interface() {
    local base_interface=$1
    local candidate
    local candidates=("${base_interface}mon" "$base_interface")

    for candidate in "${candidates[@]}"; do
        if ip link show "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    candidate=$(iwconfig 2>/dev/null | awk '/Mode:Monitor/ {print $1; exit}')
    if [ -n "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    return 1
}

toggle_monitor() {
    local interface=$1
    local mode=$2

    if [ "$mode" = "start" ]; then
        log_info "Enabling monitor mode on $interface..."
        if ! airmon-ng start "$interface" >/dev/null 2>&1; then
            log_error "Failed to enable monitor mode on $interface."
            return 1
        fi
        local monitor_interface
        monitor_interface=$(detect_monitor_interface "$interface") || {
            log_error "Monitor mode started, but no monitor interface could be detected."
            return 1
        }
        log_success "Monitor mode enabled on $monitor_interface."
        printf '%s\n' "$monitor_interface"
        return 0
    fi

    log_info "Disabling monitor mode on $interface..."
    if ! airmon-ng stop "$interface" >/dev/null 2>&1; then
        log_error "Failed to disable monitor mode on $interface."
        return 1
    fi
    log_success "Monitor mode disabled."
}

change_mac() {
    local interface=$1
    log_info "Changing MAC address for $interface..."
    ip link set "$interface" down || {
        log_error "Failed to bring $interface down."
        return 1
    }
    macchanger -r "$interface" >/dev/null 2>&1 || {
        ip link set "$interface" up >/dev/null 2>&1
        log_error "Failed to randomize MAC address on $interface."
        return 1
    }
    ip link set "$interface" up || {
        log_error "MAC randomized, but failed to bring $interface back up."
        return 1
    }
    log_success "MAC address randomized for $interface."
}

select_interface() {
    log_info "Scanning for available wireless interfaces..."
    mapfile -t interfaces < <(list_interfaces)
    if [ "${#interfaces[@]}" -eq 0 ]; then
        log_error "No wireless interfaces found."
        return 1
    fi

    echo -e "${YELLOW}Please select an interface:${NC}"
    select opt in "${interfaces[@]}"; do
        if [ -n "$opt" ]; then
            printf '%s\n' "$opt"
            return 0
        fi
        log_error "Invalid selection."
    done
}
