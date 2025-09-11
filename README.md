# 🛡️ Raspi Anonymity Control

[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![Deutsch](https://img.shields.io/badge/lang-Deutsch-yellow.svg)](README.de.md)

A comprehensive anonymity and privacy control system for Raspberry Pi, featuring Tor integration, ProxyChains configuration, MAC address spoofing, and a modern web interface.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Node](https://img.shields.io/badge/node-%3E%3D18.0.0-green.svg)
![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi-red.svg)

## 🌟 Features

- **🌐 Tor Integration**: Route all network traffic through the Tor network
- **🔄 ProxyChains Support**: Chain multiple proxy servers for enhanced anonymity
- **🎭 MAC Address Spoofing**: Automatically randomize MAC addresses on boot
- **🏷️ Hostname Randomization**: Generate random hostnames for better privacy
- **🖥️ Web Interface**: Modern, responsive control panel on port 5555
- **🛡️ Firewall Rules**: Automatic iptables configuration for secure routing
- **🔌 Pi-hole Compatible**: Works seamlessly with Pi-hole DNS filtering
- **📊 Real-time Status**: Monitor Tor connection, exit IP, and service status

## ⚠️ Security Warnings

**IMPORTANT: This project has several security vulnerabilities that need attention before production use:**

### 🚨 Critical Issues
- **SOCKS Proxy exposed on all interfaces (0.0.0.0:9050)**: Any device on your network can use your Tor connection, creating accountability and abuse risks
- **Web interface without authentication**: The control panel on port 5555 is accessible to anyone on your network without login
- **DNS leak potential**: Pi-hole, if installed, may intercept DNS requests before they reach Tor's DNS resolver
- **~~Incomplete transparent proxy~~**: ✅ **FIXED** - Now routes all TCP traffic through Tor with proper local network exceptions

### 🔧 Recommended Security Hardening
- Bind SOCKS proxy to specific IPs only (`127.0.0.1:9050` or specific client IPs)
- Add authentication to the web interface (HTTP Auth or token-based)
- Configure proper DNS routing to prevent leaks (Pi-hole compatibility handled automatically)
- ✅ Complete transparent proxy rules now implemented for all TCP traffic
- Use firewall rules to restrict proxy access to trusted devices

### 🔍 Pi-hole Integration
Pi-hole, if installed, can coexist with this anonymity setup:
- Local DNS queries (127.0.0.1:53) are preserved for Pi-hole ad-blocking
- External DNS queries are automatically routed through Tor's DNS resolver (port 9053)
- This maintains ad-blocking functionality while ensuring DNS privacy through Tor

### 🎯 Intended Use Case
This system is designed as a **LAN gateway** where multiple devices use the Raspberry Pi as their anonymity proxy. Without proper access controls, this creates security risks in multi-user environments.

## 📋 Prerequisites

- Raspberry Pi (tested on Pi 5)
- Debian/Raspberry Pi OS
- Node.js 18.x or higher
- PM2 process manager
- Root access for installation

## 🚀 Installation

1. **Clone the repository:**
```bash
git clone https://github.com/pepperonas/raspi-anonymity-control.git
cd raspi-anonymity-control
```

2. **Run the installation script:**
```bash
sudo chmod +x raspi-anonymity-setup.sh
sudo ./raspi-anonymity-setup.sh
```

The script will:
- Install all required packages (Tor, ProxyChains, Privoxy, etc.)
- Configure system services
- Set up firewall rules
- Deploy the web interface
- Enable automatic startup

3. **Start the services:**
```bash
sudo start-anonymity
```

## 🎮 Usage

### Web Interface
Access the control panel at: `http://<raspberry-pi-ip>:5555`

Features:
- View current Tor exit IP
- Monitor service status
- Generate new Tor circuits
- Spoof MAC addresses
- Change hostname
- Start/stop all services

### Command Line Tools

```bash
# Start all anonymity services
sudo start-anonymity

# Stop all services
sudo stop-anonymity

# Check status
sudo check-anonymity
```

### Proxy Configuration

Configure your devices to use:
- **SOCKS5 Proxy**: `raspberry-pi-ip:9050`
- **HTTP Proxy**: `raspberry-pi-ip:8118`
- **Transparent Proxy**: Automatic for devices connected through Pi

#### Client Configuration

**macOS:**
1. System Preferences → Network → Wi-Fi → Advanced → Proxies
2. **Option A (Recommended):** Enable only "SOCKS Proxy"
   - Server: `192.168.2.134` Port: `9050`
   - Disable all other proxy options
3. **Option B:** Enable "Web Proxy (HTTP)" and "Secure Web Proxy (HTTPS)"
   - Both set to: `192.168.2.134` Port: `8118`
   - Disable SOCKS Proxy
4. **Important:** Add to "Bypass proxy settings for these Hosts & Domains":
   ```
   192.168.0.0/16, 127.0.0.1, localhost, *.local
   ```
   ⚠️ **Do not enable multiple proxy types simultaneously** - this will break connectivity

**Windows:**
1. Settings → Network & Internet → Proxy
2. Use setup script: `http://192.168.2.134:8118/proxy.pac` (if available)
3. Or manual setup: SOCKS proxy `192.168.2.134:9050`

**Firefox (All platforms):**
1. Settings → Network Settings → Manual proxy configuration
2. SOCKS Host: `192.168.2.134` Port: `9050`
3. Select "SOCKS v5"
4. Enable "Proxy DNS when using SOCKS v5"

**Chrome/Safari:**
- Use system proxy settings (configured above)

#### Testing Anonymization
After configuration, verify anonymity:
- Visit: https://check.torproject.org (should show "Congratulations. This browser is configured to use Tor")
- Check IP: https://whatismyipaddress.com (should show a different IP from a foreign country)
- DNS leak test: https://dnsleaktest.com

**Troubleshooting:**
- If you lose internet connection after enabling proxies: disable all proxies first, then enable only SOCKS5
- If sites don't load: check the bypass settings include local network ranges
- If Tor check fails: verify the Pi's anonymity services are running with `sudo check-anonymity`
- **Important**: Tor must be configured to listen on all interfaces (`0.0.0.0:9050`) for external client access

⚠️ **Important**: Without proxy configuration, devices will use their normal internet connection and won't be anonymized.

## 🔧 Configuration

### Tor Configuration
Edit `/etc/tor/torrc` to customize:
- Exit node countries
- Circuit refresh intervals  
- Logging levels

**Default Configuration:**
```bash
# SOCKS Port für lokale und externe Verbindungen
SocksPort 0.0.0.0:9050

# Nur Exit-Nodes aus sicheren Ländern
ExitNodes {ch},{is},{ro},{se},{no},{dk},{nl}
StrictNodes 1

# Verhindere Exit-Nodes aus unsicheren Ländern  
ExcludeExitNodes {us},{ca},{gb},{au},{nz},{cn},{ru},{ir},{kp}
```

### Firewall Rules
The system automatically configures iptables to:
- Route traffic through Tor
- Preserve Pi-hole DNS functionality
- Allow SSH access
- Protect local services

### Protected Services
The following services remain accessible:
- SSH (Port 22)
- Pi-hole (Port 53, 80, 443)
- Web Interface (Port 5555)
- Custom apps (Ports 5000-5007, 8080)

## 📁 Project Structure

```
/home/pi/apps/anonymity-control/
├── server.js          # Express backend server
├── package.json       # Node.js dependencies
├── public/
│   └── index.html     # Web interface
└── node_modules/      # NPM packages

/usr/local/bin/
├── start-anonymity    # Start script
├── stop-anonymity     # Stop script
├── check-anonymity    # Status script
├── setup-anonymity-iptables.sh  # Firewall rules
├── spoof-mac.sh      # MAC spoofing script
└── random-hostname.sh # Hostname randomization
```

## 🔒 Security Considerations

- All traffic is routed through Tor (except local network)
- MAC addresses are randomized on each boot
- Hostname changes prevent device tracking
- Pi-hole continues to filter ads and trackers
- SSH access remains available for administration

## 🐛 Troubleshooting

### Services not starting
```bash
# Check service status
systemctl status tor
systemctl status privoxy

# View logs
pm2 logs anonymity-control
journalctl -u tor -f
```

### No internet connection
```bash
# Reset firewall rules
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
```

### Web interface not accessible
```bash
# Check PM2 process
pm2 list
pm2 restart anonymity-control

# Check port binding
sudo netstat -tulpn | grep 5555
```

## 📊 Performance

- **Tor Overhead**: Expect 30-50% speed reduction
- **CPU Usage**: Minimal (~5-10% on Pi 5)
- **Memory**: ~200MB for all services
- **Boot Time**: +10-15 seconds for MAC spoofing

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## 📄 License

MIT License

Copyright (c) 2025 Martin Pfeffer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 👨‍💻 Author

**Martin Pfeffer**  
📧 martinpaush@gmail.com  
🔗 [GitHub](https://github.com/pepperonas)

## 🙏 Acknowledgments

- Tor Project for anonymous networking
- ProxyChains developers
- PM2 for process management
- Express.js for the web framework

---

⚠️ **Disclaimer**: This tool is for educational and privacy protection purposes only. Users are responsible for complying with local laws and regulations regarding network anonymization tools.