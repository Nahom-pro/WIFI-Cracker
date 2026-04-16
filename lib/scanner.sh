#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

scan_networks() {
    local interface=$1
    RETURN_TO_MENU=0
    stop_scan_files
    log_info "Scanning for networks on $interface. Press Ctrl+C to stop and keep the latest CSV."
    airodump-ng --write "$SCAN_PREFIX" --output-format csv "$interface" &
    local scan_pid=$!
    register_pid "$scan_pid"
    wait "$scan_pid" 2>/dev/null
    remove_pid "$scan_pid"
    RETURN_TO_MENU=0

    if [ -f "${SCAN_PREFIX}-01.csv" ]; then
        log_success "Scan results saved to ${SCAN_PREFIX}-01.csv"
    else
        log_warn "No scan results were captured."
    fi
}

parse_scan_results() {
    local csv_file="${SCAN_PREFIX}-01.csv"
    if [ ! -f "$csv_file" ]; then
        log_error "Scan results file not found."
        return 1
    fi

    awk -F, '
        /Station MAC/ {exit}
        NR <= 2 {next}
        $1 ~ /^[[:space:]]*$/ {next}
        {
            bssid=$1; ch=$4; enc=$6; ssid=$14;
            gsub(/^[ \t]+|[ \t]+$/, "", bssid);
            gsub(/^[ \t]+|[ \t]+$/, "", ch);
            gsub(/^[ \t]+|[ \t]+$/, "", enc);
            gsub(/^[ \t]+|[ \t]+$/, "", ssid);
            printf "%d) SSID: %s | BSSID: %s | CH: %s | ENC: %s\n", ++count, ssid, bssid, ch, enc;
        }
    ' "$csv_file"
}

select_target() {
    local csv_file="${SCAN_PREFIX}-01.csv"
    if [ ! -f "$csv_file" ]; then
        log_error "No scan CSV found. Run a scan first."
        return 1
    fi

    local -a aps=()
    local line
    while IFS= read -r line; do
        aps+=("$line")
    done < <(
        awk -F, '
            /Station MAC/ {exit}
            NR <= 2 {next}
            $1 ~ /^[[:space:]]*$/ {next}
            {
                bssid=$1; ch=$4; ssid=$14;
                gsub(/^[ \t]+|[ \t]+$/, "", bssid);
                gsub(/^[ \t]+|[ \t]+$/, "", ch);
                gsub(/^[ \t]+|[ \t]+$/, "", ssid);
                if (ssid == "") ssid = "<hidden>";
                print bssid "|" ch "|" ssid;
            }
        ' "$csv_file"
    )

    if [ "${#aps[@]}" -eq 0 ]; then
        log_error "No access points found in the saved scan."
        return 1
    fi

    echo -e "${YELLOW}Available Access Points:${NC}"
    local i
    for i in "${!aps[@]}"; do
        IFS='|' read -r bssid ch ssid <<< "${aps[$i]}"
        echo "$((i + 1))) $ssid ($bssid) [CH: $ch]"
    done

    echo -ne "${YELLOW}Select target number: ${NC}"
    local choice
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#aps[@]}" ]; then
        printf '%s\n' "${aps[$((choice - 1))]}"
        return 0
    fi

    log_error "Invalid choice."
    return 1
}
