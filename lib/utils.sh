#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$SCRIPT_DIR/wifi-cracker.log"
CAPTURE_DIR="$SCRIPT_DIR/captures"
WORDLIST_DIR="$SCRIPT_DIR/wordlists"
SCAN_PREFIX="/tmp/sectools-scan"

PIDS_TO_KILL=()
RETURN_TO_MENU=0

log_info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"; }

show_banner() {
    echo -e "${BLUE}"
    echo "  ██╗    ██╗██╗███████╗██╗    ██████╗██████╗  █████╗  ██████╗██╗  ██╗███████╗██████╗ "
    echo "  ██║    ██║██║██╔════╝██║   ██╔════╝██╔══██╗██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗"
    echo "  ██║ █╗ ██║██║█████╗  ██║   ██║     ██████╔╝███████║██║     █████╔╝ █████╗  ██████╔╝"
    echo "  ██║███╗██║██║██╔══╝  ██║   ██║     ██╔══██╗██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗"
    echo "  ╚███╔███╔╝██║██║     ██║   ╚██████╗██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║"
    echo "   ╚══╝╚══╝ ╚═╝╚═╝     ╚═╝    ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝"
    echo "                              WiFi Research Toolkit"
    echo -e "${NC}"
}

ensure_directories() {
    mkdir -p "$CAPTURE_DIR" "$WORDLIST_DIR"
}

check_deps() {
    local deps=("iwconfig" "ip" "airmon-ng" "airodump-ng" "aireplay-ng" "aircrack-ng" "hashcat" "macchanger" "curl")
    local missing=()
    local optional=("hcxpcapngtool")
    local optional_missing=()

    log_info "Checking dependencies..."
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    for dep in "${optional[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            optional_missing+=("$dep")
        fi
    done

    if [ "${#missing[@]}" -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_warn "Install them before running the toolkit."
        exit 1
    fi

    if [ "${#optional_missing[@]}" -ne 0 ]; then
        log_warn "Optional tools not found: ${optional_missing[*]}"
        log_warn "Hashcat conversion workflows will be unavailable until they are installed."
    fi

    log_success "Required dependencies are installed."
}

register_pid() {
    local pid=$1
    if [ -n "$pid" ]; then
        PIDS_TO_KILL+=("$pid")
    fi
}

remove_pid() {
    local pid=$1
    local kept=()
    local entry
    for entry in "${PIDS_TO_KILL[@]}"; do
        if [ "$entry" != "$pid" ]; then
            kept+=("$entry")
        fi
    done
    PIDS_TO_KILL=("${kept[@]}")
}

kill_registered_pids() {
    local pid
    for pid in "${PIDS_TO_KILL[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
        fi
    done
    PIDS_TO_KILL=()
}

stop_scan_files() {
    rm -f "${SCAN_PREFIX}"-*.csv "${SCAN_PREFIX}"-*.cap "${SCAN_PREFIX}"-*.netxml "${SCAN_PREFIX}"-*.kismet.csv "${SCAN_PREFIX}"-*.kismet.netxml 2>/dev/null
}

prompt_enter() {
    echo
    read -r -p "Press Enter to continue... " _
}

on_interrupt() {
    echo
    if [ "${#PIDS_TO_KILL[@]}" -gt 0 ]; then
        log_warn "Stopping active capture or scan..."
        kill_registered_pids
        RETURN_TO_MENU=1
        return
    fi
    cleanup
}

cleanup() {
    echo
    log_info "Cleaning up and exiting..."
    kill_registered_pids
    exit 0
}

trap on_interrupt SIGINT
trap cleanup SIGTERM
