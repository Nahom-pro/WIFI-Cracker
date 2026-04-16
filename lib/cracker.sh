#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

cracking_menu() {
    local cap_file=$1
    local label=$2

    echo -e "${YELLOW}Select cracking method for $label:${NC}"
    local options=("Aircrack-ng (CPU - Dictionary)" "Hashcat (GPU - Dictionary)" "Hashcat (GPU - Brute-force)" "Back")
    select opt in "${options[@]}"; do
        case $opt in
            "Aircrack-ng (CPU - Dictionary)")
                crack_aircrack_dict "$cap_file"
                break
                ;;
            "Hashcat (GPU - Dictionary)")
                crack_hashcat_dict "$cap_file"
                break
                ;;
            "Hashcat (GPU - Brute-force)")
                crack_hashcat_brute "$cap_file"
                break
                ;;
            "Back")
                return 0
                ;;
            *)
                log_error "Invalid selection."
                ;;
        esac
    done
}

ensure_wordlist() {
    local wl_path="$WORDLIST_DIR/common.txt"
    if [ -f "$wl_path" ]; then
        return 0
    fi

    log_warn "Default wordlist not found."
    echo -ne "${YELLOW}Download a common wordlist to $wl_path? (y/n): ${NC}"
    local choice
    read -r choice
    if [[ ! "$choice" =~ ^[Yy]$ ]]; then
        return 0
    fi

    log_info "Downloading wordlist..."
    if curl -fsSL "https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt" -o "$wl_path"; then
        log_success "Wordlist downloaded to $wl_path"
        return 0
    fi

    rm -f "$wl_path"
    log_error "Wordlist download failed."
    return 1
}

convert_for_hashcat() {
    local cap_file=$1
    local hc_file="${cap_file%.cap}.hc22000"

    if ! command -v hcxpcapngtool >/dev/null 2>&1; then
        log_error "hcxpcapngtool is required for Hashcat workflows."
        return 1
    fi

    log_info "Converting capture to $hc_file"
    if ! hcxpcapngtool -o "$hc_file" "$cap_file" >/dev/null 2>&1; then
        log_error "Capture conversion failed."
        return 1
    fi

    if [ ! -s "$hc_file" ]; then
        log_error "Hashcat conversion produced an empty file."
        return 1
    fi

    printf '%s\n' "$hc_file"
}

crack_aircrack_dict() {
    local cap_file=$1
    ensure_wordlist || return 1

    echo -ne "${YELLOW}Enter path to wordlist (default: $WORDLIST_DIR/common.txt): ${NC}"
    local wordlist
    read -r wordlist
    wordlist=${wordlist:-"$WORDLIST_DIR/common.txt"}

    if [ ! -f "$wordlist" ]; then
        log_error "Wordlist $wordlist not found."
        return 1
    fi

    log_info "Starting aircrack-ng dictionary attack..."
    aircrack-ng -w "$wordlist" "$cap_file"
}

crack_hashcat_dict() {
    local cap_file=$1
    echo -ne "${YELLOW}Enter path to wordlist: ${NC}"
    local wordlist
    read -r wordlist
    if [ ! -f "$wordlist" ]; then
        log_error "Wordlist $wordlist not found."
        return 1
    fi

    local hc_file
    hc_file=$(convert_for_hashcat "$cap_file") || return 1
    log_info "Starting Hashcat dictionary attack..."
    hashcat -m 22000 "$hc_file" "$wordlist"
}

crack_hashcat_brute() {
    local cap_file=$1
    local hc_file
    hc_file=$(convert_for_hashcat "$cap_file") || return 1

    echo -e "${BLUE}--- Hashcat Mask Guide ---${NC}"
    echo -e "${YELLOW}?d${NC} = Numbers (0-9)"
    echo -e "${YELLOW}?l${NC} = Lowercase (a-z)"
    echo -e "${YELLOW}?u${NC} = Uppercase (A-Z)"
    echo -e "${YELLOW}?a${NC} = Mixed printable charset"
    echo -e "${YELLOW}?s${NC} = Special characters"
    echo -ne "${YELLOW}Enter mask (example: ?d?d?d?d?d?d?d?d): ${NC}"

    local mask
    read -r mask
    if [ -z "$mask" ]; then
        log_error "Mask cannot be empty."
        return 1
    fi

    log_info "Starting Hashcat brute-force with mask: $mask"
    hashcat -m 22000 "$hc_file" -a 3 "$mask"
}
