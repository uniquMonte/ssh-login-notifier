# SSH Login Notifier

### Features

- **Real-time Login Alerts**: Instant notifications for successful SSH logins
- **Failed Login Reports**: Periodic reports of brute-force attempts
- **Detailed Information**: Username, IP, geolocation, ISP, timestamp
- **Custom Server Names**: Manage multiple VPS with friendly names
- **Interactive Management Menu**: Update, configure, and test from one script
- **Easy Installation**: One-line installation with automated setup

### Quick Start

**Method 1: Pipe Mode** (Best compatibility)
```bash
curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | sudo bash
```

**Method 2: Process Substitution** (If your system supports it)
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh)
```

**Method 3: Download First**
```bash
curl -O https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh
sudo bash install.sh
```

> **Note**: If Method 2 shows "No such file or directory", use Method 1 or 3.

### License

MIT License - see [LICENSE](LICENSE) file for details.
