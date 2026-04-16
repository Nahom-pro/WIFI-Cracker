#!/usr/bin/env bash

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/interface.sh"
source "$LIB_DIR/scanner.sh"
source "$LIB_DIR/attacker.sh"
source "$LIB_DIR/cracker.sh"

SELECTED_INTERFACE=""
SELECTED_BSSID=""
SELECTED_CHANNEL=""
SELECTED_SSID=""

if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
fi

interface_management() {
    while true; do
        clear
        show_banner
        echo -e "${BLUE}Interface Management:${NC}"
        local options=("List Interfaces" "Select & Start Monitor Mode" "Stop Monitor Mode" "Randomize MAC" "Back to Main Menu")
        select opt in "${options[@]}"; do
            case $opt in
                "List Interfaces")
                    if ! list_interfaces; then
                        log_error "No wireless interfaces found."
                    fi
                    prompt_enter
                    break
                    ;;
                "Select & Start Monitor Mode")
                    local selected
                    selected=$(select_interface) || break
                    local monitor_interface
                    monitor_interface=$(toggle_monitor "$selected" "start") || {
                        prompt_enter
                        break
                    }
                    SELECTED_INTERFACE="$monitor_interface"
                    log_success "Selected monitor interface: $SELECTED_INTERFACE"
                    prompt_enter
                    break
                    ;;
                "Stop Monitor Mode")
                    if [ -z "$SELECTED_INTERFACE" ]; then
                        log_warn "No monitor interface is currently selected."
                    else
                        toggle_monitor "$SELECTED_INTERFACE" "stop"
                        SELECTED_INTERFACE=""
                    fi
                    prompt_enter
                    break
                    ;;
                "Randomize MAC")
                    local iface
                    iface=$(select_interface) || break
                    change_mac "$iface"
                    prompt_enter
                    break
                    ;;
                "Back to Main Menu")
                    return 0
                    ;;
                *)
                    log_error "Invalid selection."
                    ;;
            esac
        done
    done
}

target_and_capture() {
    clear
    show_banner
    if [ -z "$SELECTED_INTERFACE" ]; then
        log_warn "Select a monitor-mode interface first."
        prompt_enter
        return 1
    fi

    local target
    target=$(select_target) || {
        prompt_enter
        return 1
    }

    IFS='|' read -r SELECTED_BSSID SELECTED_CHANNEL SELECTED_SSID <<< "$target"
    capture_handshake "$SELECTED_INTERFACE" "$SELECTED_BSSID" "$SELECTED_CHANNEL" "$SELECTED_SSID"
    prompt_enter
}

crack_handshake() {
    clear
    show_banner
    log_info "Available captures:"
    local -a captures=()
    local file
    while IFS= read -r file; do
        captures+=("$file")
    done < <(find "$CAPTURE_DIR" -maxdepth 1 -type f -name '*.cap' | sort)

    if [ "${#captures[@]}" -eq 0 ]; then
        log_warn "No capture files found in $CAPTURE_DIR"
        prompt_enter
        return 1
    fi

    local i
    for i in "${!captures[@]}"; do
        echo "$((i + 1))) ${captures[$i]}"
    done

    echo -ne "${YELLOW}Select capture number or enter a full path: ${NC}"
    local choice
    read -r choice

    local cap_path=""
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#captures[@]}" ]; then
        cap_path="${captures[$((choice - 1))]}"
    else
        cap_path="$choice"
    fi

    if [ ! -f "$cap_path" ]; then
        log_error "Capture file not found."
        prompt_enter
        return 1
    fi

    cracking_menu "$cap_path" "$(basename "$cap_path")"
    prompt_enter
}

main_menu() {
    while true; do
        clear
        show_banner
        echo -e "${BLUE}Main Menu:${NC}"
        local options=("Interface Management" "Scan for Networks" "Select Target & Capture Handshake" "Crack Captured Handshake" "Exit")
        select opt in "${options[@]}"; do
            case $opt in
                "Interface Management")
                    interface_management
                    break
                    ;;
                "Scan for Networks")
                    if [ -z "$SELECTED_INTERFACE" ]; then
                        log_warn "Select an interface first."
                        prompt_enter
                    else
                        scan_networks "$SELECTED_INTERFACE"
                        if [ -f "${SCAN_PREFIX}-01.csv" ]; then
                            echo
                            parse_scan_results
                        fi
                        prompt_enter
                    fi
                    break
                    ;;
                "Select Target & Capture Handshake")
                    target_and_capture
                    break
                    ;;
                "Crack Captured Handshake")
                    crack_handshake
                    break
                    ;;
                "Exit")
                    cleanup
                    ;;
                *)
                    log_error "Invalid selection."
                    ;;
            esac
        done
    done
}

ensure_directories
check_deps
main_menu
