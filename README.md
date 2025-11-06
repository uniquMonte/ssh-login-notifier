# SSH Login Telegram Notifier

[English](#english) | [中文](#中文)

---

## English

### Overview

SSH Login Telegram Notifier is a lightweight security tool that sends instant notifications to your Telegram account whenever someone successfully logs into your VPS via SSH. This helps you monitor unauthorized access attempts and keep track of legitimate logins.

### Features

- **Instant Notifications**: Receive real-time alerts on Telegram when SSH login occurs
- **Detailed Information**: Get login details including:
  - Username
  - IP Address
  - Login timestamp
  - Server hostname
  - Geographic location (country, city, region)
  - ISP information
- **Easy Installation**: Automated setup with interactive installer
- **Minimal Dependencies**: Uses standard Linux tools (curl/wget)
- **Secure**: Configuration stored in protected directory

### Prerequisites

- Linux server with SSH access
- Root or sudo privileges
- `curl` or `wget` installed
- A Telegram account
- Internet connection on the server

### Quick Start

#### 1. Create a Telegram Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot` command
3. Follow the instructions to create your bot
4. Copy the **Bot Token** provided

#### 2. Get Your Chat ID

**Method 1**: Using @userinfobot
1. Search for `@userinfobot` in Telegram
2. Start a chat with it
3. It will display your Chat ID

**Method 2**: Manual method
1. Send any message to your bot
2. Visit: `https://api.telegram.org/bot<YourBOTToken>/getUpdates`
3. Look for `"chat":{"id":123456789}` in the response

#### 3. Install the Notifier

```bash
# Clone the repository
git clone https://github.com/uniquMonte/ssh-login-notifier.git
cd ssh-login-notifier

# Make scripts executable
chmod +x install.sh notify.sh uninstall.sh

# Run the installer
sudo ./install.sh
```

#### 4. Configure

During installation, you'll be prompted to enter:
- Your Telegram Bot Token
- Your Telegram Chat ID

The installer will automatically:
- Test the Telegram connection
- Install the notification script
- Configure PAM (Pluggable Authentication Modules)
- Set up proper permissions

### Testing

After installation, try logging in via SSH from another terminal or computer. You should receive a Telegram notification immediately upon successful authentication.

### How It Works

The notifier uses Linux PAM (Pluggable Authentication Modules) to trigger a notification script whenever SSH authentication succeeds. The script:

1. Collects login information from PAM environment variables
2. Queries geolocation data for the connecting IP address
3. Formats a message with all relevant details
4. Sends the notification via Telegram Bot API

### File Structure

```
ssh-login-notifier/
├── notify.sh              # Main notification script
├── install.sh             # Installation script
├── uninstall.sh           # Uninstallation script
├── config.example         # Configuration file example
├── .gitignore            # Git ignore rules
├── LICENSE               # MIT License
└── README.md             # This file
```

### Configuration Files

After installation:
- **Script location**: `/usr/local/bin/ssh-login-notify.sh`
- **Configuration**: `/etc/ssh-login-notifier/config`
- **PAM configuration**: `/etc/pam.d/sshd`

### Manual Configuration

If you prefer to configure manually:

1. Copy the example config:
```bash
sudo mkdir -p /etc/ssh-login-notifier
sudo cp config.example /etc/ssh-login-notifier/config
```

2. Edit the configuration:
```bash
sudo nano /etc/ssh-login-notifier/config
```

3. Set your Bot Token and Chat ID

### Uninstallation

To remove the notifier:

```bash
sudo ./uninstall.sh
```

You'll be asked whether to keep or remove configuration files.

### Troubleshooting

**Not receiving notifications?**

1. Check if the service is properly configured:
```bash
cat /etc/ssh-login-notifier/config
```

2. Test the notification script manually:
```bash
sudo /usr/local/bin/ssh-login-notify.sh
```

3. Check PAM configuration:
```bash
grep ssh-login-notify /etc/pam.d/sshd
```

4. Check system logs:
```bash
sudo tail -f /var/log/auth.log
```

### Security Considerations

- The configuration file contains sensitive information (Bot Token) and is protected with 600 permissions
- Only root can read the configuration file
- The notifier runs with user privileges (via `seteuid`)
- No passwords or sensitive data are transmitted

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 中文

### 概述

SSH登录Telegram通知器是一个轻量级安全工具，当有人通过SSH成功登录你的VPS时，会立即向你的Telegram账号发送通知。这可以帮助你监控未经授权的访问尝试，并跟踪合法的登录活动。

### 功能特点

- **即时通知**：SSH登录时实时接收Telegram警报
- **详细信息**：获取登录详情包括：
  - 用户名
  - IP地址
  - 登录时间戳
  - 服务器主机名
  - 地理位置（国家、城市、地区）
  - ISP信息
- **简易安装**：交互式自动安装程序
- **最小依赖**：使用标准Linux工具（curl/wget）
- **安全可靠**：配置存储在受保护的目录中

### 前置要求

- 具有SSH访问权限的Linux服务器
- Root或sudo权限
- 已安装`curl`或`wget`
- Telegram账号
- 服务器需要互联网连接

### 快速开始

#### 1. 创建Telegram机器人

1. 打开Telegram，搜索`@BotFather`
2. 发送`/newbot`命令
3. 按照说明创建你的机器人
4. 复制提供的**Bot Token**

#### 2. 获取你的Chat ID

**方法1**：使用@userinfobot
1. 在Telegram中搜索`@userinfobot`
2. 与它开始对话
3. 它会显示你的Chat ID

**方法2**：手动方法
1. 向你的机器人发送任意消息
2. 访问：`https://api.telegram.org/bot<你的BOT令牌>/getUpdates`
3. 在响应中查找`"chat":{"id":123456789}`

#### 3. 安装通知器

```bash
# 克隆仓库
git clone https://github.com/uniquMonte/ssh-login-notifier.git
cd ssh-login-notifier

# 添加执行权限
chmod +x install.sh notify.sh uninstall.sh

# 运行安装程序
sudo ./install.sh
```

#### 4. 配置

安装过程中，你需要输入：
- 你的Telegram Bot Token
- 你的Telegram Chat ID

安装程序会自动：
- 测试Telegram连接
- 安装通知脚本
- 配置PAM（可插拔认证模块）
- 设置适当的权限

### 测试

安装完成后，尝试从另一个终端或计算机通过SSH登录。你应该会在认证成功后立即收到Telegram通知。

### 工作原理

通知器使用Linux PAM（可插拔认证模块）在SSH认证成功时触发通知脚本。脚本会：

1. 从PAM环境变量收集登录信息
2. 查询连接IP地址的地理位置数据
3. 格式化包含所有相关详细信息的消息
4. 通过Telegram Bot API发送通知

### 文件结构

```
ssh-login-notifier/
├── notify.sh              # 主通知脚本
├── install.sh             # 安装脚本
├── uninstall.sh           # 卸载脚本
├── config.example         # 配置文件示例
├── .gitignore            # Git忽略规则
├── LICENSE               # MIT许可证
└── README.md             # 本文件
```

### 配置文件

安装后的位置：
- **脚本位置**：`/usr/local/bin/ssh-login-notify.sh`
- **配置文件**：`/etc/ssh-login-notifier/config`
- **PAM配置**：`/etc/pam.d/sshd`

### 手动配置

如果你更喜欢手动配置：

1. 复制示例配置：
```bash
sudo mkdir -p /etc/ssh-login-notifier
sudo cp config.example /etc/ssh-login-notifier/config
```

2. 编辑配置：
```bash
sudo nano /etc/ssh-login-notifier/config
```

3. 设置你的Bot Token和Chat ID

### 卸载

要删除通知器：

```bash
sudo ./uninstall.sh
```

系统会询问你是否保留或删除配置文件。

### 故障排除

**没有收到通知？**

1. 检查服务是否正确配置：
```bash
cat /etc/ssh-login-notifier/config
```

2. 手动测试通知脚本：
```bash
sudo /usr/local/bin/ssh-login-notify.sh
```

3. 检查PAM配置：
```bash
grep ssh-login-notify /etc/pam.d/sshd
```

4. 检查系统日志：
```bash
sudo tail -f /var/log/auth.log
```

### 安全考虑

- 配置文件包含敏感信息（Bot Token），使用600权限保护
- 只有root可以读取配置文件
- 通知器以用户权限运行（通过`seteuid`）
- 不传输密码或其他敏感数据

### 贡献

欢迎贡献！请随时提交Pull Request。

### 许可证

本项目采用MIT许可证 - 详见[LICENSE](LICENSE)文件。

---

## Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#troubleshooting) section
2. Open an issue on GitHub
3. Make sure your Telegram bot token and chat ID are correct

## Author

Created with security and simplicity in mind.

## Acknowledgments

- Thanks to Telegram for providing the Bot API
- Thanks to the Linux PAM project
- Thanks to ip-api.com for geolocation services
