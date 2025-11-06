# SSH Login Telegram Notifier

[English](#english) | [中文](#中文)

---

## English

### Overview

A lightweight security tool that sends instant Telegram notifications when someone logs into your VPS via SSH. Monitor login activity and track failed login attempts in real-time.

### Features

- **Real-time Login Alerts**: Instant notifications for successful SSH logins
- **Failed Login Reports**: Periodic reports of brute-force attempts
- **Detailed Information**: Username, IP, geolocation, ISP, timestamp
- **Custom Server Names**: Manage multiple VPS with friendly names
- **Interactive Management Menu**: Update, configure, and test from one script
- **Easy Installation**: One-line installation with automated setup

### Quick Start

#### 1. Create a Telegram Bot

1. Open Telegram, search for `@BotFather`
2. Send `/newbot` and follow instructions
3. Copy the **Bot Token**

#### 2. Get Your Chat ID

Search for `@userinfobot` in Telegram and start a chat to get your Chat ID.

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
- Telegram Bot Token
- Telegram Chat ID
- Server Name (optional)
- Failed Login Report Frequency (hourly/6h/12h/daily/disabled)

### Management Menu

Run the installer again to access the management menu:

```bash
# Method 1: Pipe mode
curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | sudo bash

# Method 2: Process substitution (if supported)
sudo bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh)
```

Menu options:
1. **View current configuration** - Check your settings
2. **Update configuration** - Modify Bot Token, Chat ID, server name, report frequency
3. **Update scripts** - Download latest version from GitHub
4. **Test notification** - Send a test message to verify setup
5. **Run failed login report** - Generate report immediately
6. **Uninstall** - Remove the notifier

### Common Commands

```bash
# View current configuration
sudo cat /etc/ssh-login-notifier/config

# Edit configuration manually
sudo nano /etc/ssh-login-notifier/config

# Test login notification
sudo /usr/local/bin/ssh-login-notify.sh

# Run failed login report manually
sudo /usr/local/bin/report-failed-logins.sh

# View cron jobs
crontab -l

# Check recent SSH logs
sudo journalctl -u sshd -n 50
sudo tail -50 /var/log/auth.log  # or /var/log/secure
```

### Failed Login Reports

Enable periodic reports of SSH brute-force attempts:

- **Hourly**: Every hour
- **6 Hours**: Every 6 hours
- **12 Hours**: Every 12 hours
- **Daily**: Once per day at 8:00 AM
- **Disabled**: No reports

Reports include:
- Total failed attempts
- Top 5 attacking IPs with geolocation
- Most targeted usernames
- Attack statistics

### File Locations

```
/usr/local/bin/ssh-login-notify.sh       # Login notification script
/usr/local/bin/report-failed-logins.sh   # Failed login report script
/usr/local/bin/ssh-login-notifier-uninstall.sh  # Uninstaller
/etc/ssh-login-notifier/config           # Configuration file
/etc/pam.d/sshd                          # PAM configuration
```

### How It Works

Uses Linux PAM (Pluggable Authentication Modules) to trigger notifications on SSH authentication events. The script collects login information, queries geolocation data, and sends formatted messages via Telegram Bot API.

### Troubleshooting

**Not receiving notifications?**

1. Test manually: `sudo /usr/local/bin/ssh-login-notify.sh`
2. Check config: `cat /etc/ssh-login-notifier/config`
3. Verify PAM: `grep ssh-login-notify /etc/pam.d/sshd`

**Duplicate notifications?**

Already fixed in current version. Update scripts via management menu.

**Failed login report shows zero attempts?**

The script auto-detects your log system (journalctl or traditional logs). If issues persist, check logs manually:
```bash
sudo journalctl | grep "Failed password" | tail -20
```

### Security

- Configuration files protected with 600 permissions (root only)
- Script runs with user privileges via `seteuid`
- No passwords transmitted
- Bot token stored securely

### Uninstall

```bash
# Run management menu and choose option 6
curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | sudo bash
# Or: sudo bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh)

# Or run uninstaller directly
sudo /usr/local/bin/ssh-login-notifier-uninstall.sh
```

### License

MIT License - see [LICENSE](LICENSE) file for details.

---

## 中文

### 概述

轻量级安全工具，当有人通过SSH登录VPS时立即发送Telegram通知。实时监控登录活动和跟踪失败的登录尝试。

### 功能特点

- **实时登录警报**：成功SSH登录时即时通知
- **失败登录报告**：定期报告暴力破解尝试
- **详细信息**：用户名、IP、地理位置、ISP、时间戳
- **自定义服务器名**：用友好名称管理多个VPS
- **交互式管理菜单**：通过一个脚本更新、配置和测试
- **简易安装**：一行命令自动安装

### 快速开始

#### 1. 创建Telegram机器人

1. 打开Telegram，搜索 `@BotFather`
2. 发送 `/newbot` 并按照说明操作
3. 复制 **Bot Token**

#### 2. 获取Chat ID

在Telegram中搜索 `@userinfobot` 并开始对话以获取Chat ID。

#### 3. 安装

**方法1：管道模式**（兼容性最好）
```bash
curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | sudo bash
```

**方法2：进程替换**（如果系统支持）
```bash
sudo bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh)
```

**方法3：先下载**
```bash
curl -O https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh
sudo bash install.sh
```

> **注意**：如果方法2显示"No such file or directory"，请使用方法1或3。

安装时需要配置：
- Telegram Bot Token
- Telegram Chat ID
- 服务器名称（可选）
- 失败登录报告频率（每小时/6小时/12小时/每天/禁用）

### 管理菜单

再次运行安装脚本可访问管理菜单：

```bash
# 方法1：管道模式
curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | sudo bash

# 方法2：进程替换（如果支持）
sudo bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh)
```

菜单选项：
1. **查看当前配置** - 检查设置
2. **更新配置** - 修改Bot Token、Chat ID、服务器名、报告频率
3. **更新脚本** - 从GitHub下载最新版本
4. **测试通知** - 发送测试消息验证设置
5. **立即运行失败登录报告** - 立即生成报告
6. **卸载** - 移除通知器

### 常用命令

```bash
# 查看当前配置
sudo cat /etc/ssh-login-notifier/config

# 手动编辑配置
sudo nano /etc/ssh-login-notifier/config

# 测试登录通知
sudo /usr/local/bin/ssh-login-notify.sh

# 手动运行失败登录报告
sudo /usr/local/bin/report-failed-logins.sh

# 查看定时任务
crontab -l

# 查看最近的SSH日志
sudo journalctl -u sshd -n 50
sudo tail -50 /var/log/auth.log  # 或 /var/log/secure
```

### 失败登录报告

启用SSH暴力破解尝试的定期报告：

- **每小时**：每小时一次
- **6小时**：每6小时一次
- **12小时**：每12小时一次
- **每天**：每天早上8:00一次
- **禁用**：不发送报告

报告包括：
- 失败尝试总数
- 前5个攻击IP及地理位置
- 最常被攻击的用户名
- 攻击统计信息

### 文件位置

```
/usr/local/bin/ssh-login-notify.sh       # 登录通知脚本
/usr/local/bin/report-failed-logins.sh   # 失败登录报告脚本
/usr/local/bin/ssh-login-notifier-uninstall.sh  # 卸载程序
/etc/ssh-login-notifier/config           # 配置文件
/etc/pam.d/sshd                          # PAM配置
```

### 工作原理

使用Linux PAM（可插拔认证模块）在SSH认证事件时触发通知。脚本收集登录信息，查询地理位置数据，通过Telegram Bot API发送格式化消息。

### 故障排除

**没有收到通知？**

1. 手动测试：`sudo /usr/local/bin/ssh-login-notify.sh`
2. 检查配置：`cat /etc/ssh-login-notifier/config`
3. 验证PAM：`grep ssh-login-notify /etc/pam.d/sshd`

**收到重复通知？**

当前版本已修复。通过管理菜单更新脚本即可。

**失败登录报告显示零次尝试？**

脚本会自动检测日志系统（journalctl或传统日志）。如仍有问题，手动检查日志：
```bash
sudo journalctl | grep "Failed password" | tail -20
```

### 安全性

- 配置文件使用600权限保护（仅root）
- 脚本通过 `seteuid` 以用户权限运行
- 不传输密码
- Bot token安全存储

### 卸载

```bash
# 运行管理菜单并选择选项6
curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh | sudo bash
# 或：sudo bash <(curl -Ls https://raw.githubusercontent.com/uniquMonte/ssh-login-notifier/main/install.sh)

# 或直接运行卸载程序
sudo /usr/local/bin/ssh-login-notifier-uninstall.sh
```

### 许可证

MIT许可证 - 详见 [LICENSE](LICENSE) 文件。

---

## Support / 支持

For issues or questions / 如有问题：
- Check the troubleshooting section / 查看故障排除部分
- Open an issue on GitHub / 在GitHub上提交issue
- Verify your bot token and chat ID / 验证bot token和chat ID

## Acknowledgments / 致谢

- Telegram Bot API
- Linux PAM project
- ip-api.com for geolocation services
