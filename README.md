# SSH Login Notifier

### Features

- **Real-time Login Alerts**: Instant notifications for successful SSH logins
- **Failed Login Reports**: Periodic reports of brute-force attempts
- **Detailed Information**: Username, IP, geolocation, ISP, timestamp
- **Custom Server Names**: Manage multiple VPS with friendly names
- **Interactive Management Menu**: Update, configure, and test from one script
- **Easy Installation**: One-line installation with automated setup

### Quick Start

#### 1. Create a Bot

1. Search for `@BotFather`
2. Send `/newbot` and follow instructions
3. Copy the **Bot Token**

#### 2. Get Your Chat ID

Search for `@userinfobot` and start a chat to get your Chat ID.

#### 3. Install

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

During installation, you'll configure:
- Bot Token
- Chat ID
- Server Name (optional)
- Failed Login Report Frequency (hourly/6h/12h/daily/disabled)

### License

MIT License - see [LICENSE](LICENSE) file for details.
