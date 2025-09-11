#!/bin/bash

# Raspi Anonymity Control - Installation Script
# Author: Martin Pfeffer
# Description: Complete setup script for Raspberry Pi anonymity control system

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_DIR="/home/pi/apps/anonymity-control"
WEB_USER="pi"

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_os() {
    if ! grep -q "Raspberry Pi OS\|Raspbian" /etc/os-release 2>/dev/null; then
        print_warning "This script is designed for Raspberry Pi OS. Proceeding anyway..."
    fi
}

update_system() {
    print_status "Updating system packages..."
    apt update
    apt upgrade -y
    print_success "System updated"
}

install_packages() {
    print_status "Installing required packages..."
    
    # Core packages
    apt install -y \
        tor \
        privoxy \
        proxychains4 \
        iptables-persistent \
        curl \
        wget \
        net-tools \
        macchanger \
        dnsutils \
        htop \
        git
    
    # Node.js (if not already installed)
    if ! command -v node &> /dev/null; then
        print_status "Installing Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt install -y nodejs
    fi
    
    # PM2 (if not already installed)
    if ! command -v pm2 &> /dev/null; then
        print_status "Installing PM2..."
        npm install -g pm2
        # Setup PM2 startup for pi user
        sudo -u $WEB_USER pm2 startup
        env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $WEB_USER --hp /home/$WEB_USER
    fi
    
    print_success "Packages installed"
}

configure_tor() {
    print_status "Configuring Tor..."
    
    # Backup original config
    cp /etc/tor/torrc /etc/tor/torrc.backup 2>/dev/null || true
    
    # Create new torrc
    cat > /etc/tor/torrc << 'EOF'
# Tor Configuration for Raspberry Pi
User debian-tor
DataDirectory /var/lib/tor

# SOCKS Port für lokale und externe Verbindungen
SocksPort 0.0.0.0:9050

# Transparent Proxy Port (nicht 53 wegen Pi-hole!)
TransPort 9040
DNSPort 9053

# Automatische IP-Wechsel alle 10 Minuten
MaxCircuitDirtiness 600

# Nur Exit-Nodes aus sicheren Ländern
ExitNodes {ch},{is},{ro},{se},{no},{dk},{nl}
StrictNodes 1

# Verhindere Exit-Nodes aus unsicheren Ländern
ExcludeExitNodes {us},{ca},{gb},{au},{nz},{cn},{ru},{ir},{kp}

# Logging
Log notice file /var/log/tor/notices.log

# Control Port für Verwaltung
ControlPort 9051
CookieAuthentication 1

# Performance
NumEntryGuards 3
EOF
    
    # Set permissions
    chown root:root /etc/tor/torrc
    chmod 644 /etc/tor/torrc
    
    # Create log directory
    mkdir -p /var/log/tor
    chown debian-tor:debian-tor /var/log/tor
    
    print_success "Tor configured"
}

configure_privoxy() {
    print_status "Configuring Privoxy..."
    
    # Backup original config
    cp /etc/privoxy/config /etc/privoxy/config.backup 2>/dev/null || true
    
    # Add Tor forwarding to privoxy config
    echo "forward-socks5t / 127.0.0.1:9050 ." >> /etc/privoxy/config
    sed -i 's/^listen-address.*/listen-address  0.0.0.0:8118/' /etc/privoxy/config
    
    print_success "Privoxy configured"
}

configure_proxychains() {
    print_status "Configuring ProxyChains..."
    
    # Backup original config
    cp /etc/proxychains4.conf /etc/proxychains4.conf.backup 2>/dev/null || true
    
    # Configure proxychains
    cat > /etc/proxychains4.conf << 'EOF'
# proxychains.conf  VER 4.x
strict_chain
proxy_dns 
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0
quiet_mode

[ProxyList]
socks5 127.0.0.1 9050
EOF
    
    print_success "ProxyChains configured"
}

create_scripts() {
    print_status "Creating system scripts..."
    
    # Create start-anonymity script
    cat > /usr/local/bin/start-anonymity << 'EOF'
#!/bin/bash

echo "🚀 Starting Anonymity Control Services..."

# Start Tor
systemctl start tor
echo "✅ Tor started"

# Start Privoxy  
systemctl start privoxy
echo "✅ Privoxy started"

# Setup firewall rules
/usr/local/bin/setup-anonymity-iptables.sh
echo "✅ Firewall configured"

# Start web interface
sudo -u pi pm2 start /home/pi/apps/anonymity-control/server.js --name anonymity-control
echo "✅ Web interface started"

echo "🛡️  Anonymity services are now running!"
echo "📱 Web interface: http://$(hostname -I | awk '{print $1}'):5555"
EOF

    # Create stop-anonymity script
    cat > /usr/local/bin/stop-anonymity << 'EOF'
#!/bin/bash

echo "🛑 Stopping Anonymity Control Services..."

# Stop web interface
sudo -u pi pm2 stop anonymity-control 2>/dev/null || true
echo "✅ Web interface stopped"

# Reset firewall rules
iptables -F
iptables -t nat -F
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "✅ Firewall reset"

# Stop services
systemctl stop privoxy
systemctl stop tor
echo "✅ Services stopped"

echo "🔓 Anonymity services stopped - normal internet restored"
EOF

    # Create check-anonymity script
    cat > /usr/local/bin/check-anonymity << 'EOF'
#!/bin/bash

echo "🔍 Checking Anonymity Status..."
echo "=================================="

# Check Tor
if systemctl is-active --quiet tor; then
    echo "✅ Tor: Running"
    if netstat -tlnp | grep -q ":9050"; then
        echo "✅ SOCKS Proxy: Listening on port 9050"
    else
        echo "❌ SOCKS Proxy: Not listening"
    fi
else
    echo "❌ Tor: Not running"
fi

# Check Privoxy
if systemctl is-active --quiet privoxy; then
    echo "✅ Privoxy: Running"
    if netstat -tlnp | grep -q ":8118"; then
        echo "✅ HTTP Proxy: Listening on port 8118"
    else
        echo "❌ HTTP Proxy: Not listening"
    fi
else
    echo "❌ Privoxy: Not running"
fi

# Check web interface
if sudo -u pi pm2 list | grep -q "anonymity-control.*online"; then
    echo "✅ Web Interface: Running on port 5555"
else
    echo "❌ Web Interface: Not running"
fi

# Check current IP
echo ""
echo "🌐 Current Public IP:"
timeout 10 curl -s --socks5 127.0.0.1:9050 http://httpbin.org/ip 2>/dev/null || echo "❌ Cannot check IP through Tor"

echo ""
echo "🔗 Test URLs:"
echo "   Tor Check: https://check.torproject.org"
echo "   IP Check: https://whatismyipaddress.com"
echo "   DNS Leak: https://dnsleaktest.com"
EOF

    # Make scripts executable
    chmod +x /usr/local/bin/start-anonymity
    chmod +x /usr/local/bin/stop-anonymity  
    chmod +x /usr/local/bin/check-anonymity
    
    print_success "System scripts created"
}

create_firewall_script() {
    print_status "Creating firewall script..."
    
    cat > /usr/local/bin/setup-anonymity-iptables.sh << 'EOF'
#!/bin/bash

# Anonymity Control - Firewall Rules
# Routes traffic through Tor while preserving local services

echo "🔧 Setting up firewall rules..."

# Flush existing rules
iptables -F
iptables -t nat -F
iptables -X

# Set default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (port 22)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow Pi-hole (DNS, Web interface)
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# Allow local network access
iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT

# Allow Tor SOCKS proxy
iptables -A INPUT -p tcp --dport 9050 -j ACCEPT

# Allow Privoxy HTTP proxy
iptables -A INPUT -p tcp --dport 8118 -j ACCEPT

# Allow web interface
iptables -A INPUT -p tcp --dport 5555 -j ACCEPT

# Allow custom app ports
iptables -A INPUT -p tcp --dport 5000:5007 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Allow Tor transparent proxy
iptables -A INPUT -p tcp --dport 9040 -j ACCEPT
iptables -A INPUT -p tcp --dport 9053 -j ACCEPT

# Complete transparent proxy rules
# DNS through Tor (but preserve Pi-hole if running on port 53)
iptables -t nat -A OUTPUT -p udp --dport 53 -d 127.0.0.1 -j ACCEPT  # Keep local DNS
iptables -t nat -A OUTPUT -p tcp --dport 53 -d 127.0.0.1 -j ACCEPT  # Keep local DNS
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-port 9053  # Route other DNS to Tor
iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-port 9053  # Route other DNS to Tor

# HTTP/HTTPS through Tor transparent proxy
iptables -t nat -A OUTPUT -p tcp --dport 80 -j REDIRECT --to-port 9040
iptables -t nat -A OUTPUT -p tcp --dport 443 -j REDIRECT --to-port 9040

# Route all other TCP traffic through Tor (except local and Tor itself)
iptables -t nat -A OUTPUT -p tcp -d 127.0.0.0/8 -j ACCEPT  # Keep local traffic
iptables -t nat -A OUTPUT -p tcp -d 192.168.0.0/16 -j ACCEPT  # Keep LAN traffic
iptables -t nat -A OUTPUT -p tcp -d 10.0.0.0/8 -j ACCEPT  # Keep LAN traffic
iptables -t nat -A OUTPUT -p tcp -d 172.16.0.0/12 -j ACCEPT  # Keep LAN traffic
iptables -t nat -A OUTPUT -p tcp --dport 9050 -j ACCEPT  # Don't redirect Tor SOCKS
iptables -t nat -A OUTPUT -p tcp --dport 9051 -j ACCEPT  # Don't redirect Tor control
iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-port 9040  # Everything else through Tor

# Block non-Tor traffic as failsafe
iptables -A OUTPUT -p tcp --dport 80 -m owner ! --uid-owner debian-tor -j DROP
iptables -A OUTPUT -p tcp --dport 443 -m owner ! --uid-owner debian-tor -j DROP

# Save rules
iptables-save > /etc/iptables/rules.v4

echo "✅ Firewall rules applied"
EOF

    chmod +x /usr/local/bin/setup-anonymity-iptables.sh
    print_success "Firewall script created"
}

create_mac_spoofing_script() {
    print_status "Creating MAC spoofing script..."
    
    cat > /usr/local/bin/spoof-mac.sh << 'EOF'
#!/bin/bash

# MAC Address Spoofing Script
# Randomizes MAC addresses on boot for privacy

INTERFACES=$(ip link show | grep -E "^[0-9]+: (eth|wlan)" | cut -d: -f2 | tr -d ' ')

for INTERFACE in $INTERFACES; do
    if [[ $INTERFACE != "lo" ]]; then
        echo "🎭 Spoofing MAC address for $INTERFACE..."
        
        # Bring interface down
        ip link set dev $INTERFACE down
        
        # Change MAC address
        macchanger -r $INTERFACE
        
        # Bring interface back up
        ip link set dev $INTERFACE up
        
        echo "✅ MAC address changed for $INTERFACE"
    fi
done

echo "🔒 MAC address spoofing completed"
EOF

    chmod +x /usr/local/bin/spoof-mac.sh
    print_success "MAC spoofing script created"
}

create_hostname_script() {
    print_status "Creating hostname randomization script..."
    
    cat > /usr/local/bin/random-hostname.sh << 'EOF'
#!/bin/bash

# Random Hostname Generator
# Changes hostname on each boot for privacy

ADJECTIVES=("ninja" "shadow" "ghost" "phantom" "stealth" "cyber" "digital" "quantum" "crypto" "dark")
ANIMALS=("wolf" "fox" "hawk" "raven" "panther" "tiger" "dragon" "falcon" "viper" "lynx")

# Generate random numbers
ADJ_INDEX=$((RANDOM % ${#ADJECTIVES[@]}))
ANIMAL_INDEX=$((RANDOM % ${#ANIMALS[@]}))
NUMBER=$((RANDOM % 10000))

NEW_HOSTNAME="${ADJECTIVES[$ADJ_INDEX]}-${ANIMALS[$ANIMAL_INDEX]}-$NUMBER"

echo "🏷️  Changing hostname to: $NEW_HOSTNAME"

# Update hostname
hostnamectl set-hostname $NEW_HOSTNAME

# Update /etc/hosts
sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts

echo "✅ Hostname changed to: $NEW_HOSTNAME"
EOF

    chmod +x /usr/local/bin/random-hostname.sh
    print_success "Hostname randomization script created"
}

setup_web_interface() {
    print_status "Setting up web interface..."
    
    if [[ ! -d "$APP_DIR" ]]; then
        print_error "Application directory not found: $APP_DIR"
        print_error "Please clone the repository first!"
        exit 1
    fi
    
    cd $APP_DIR
    
    # Install dependencies
    sudo -u $WEB_USER npm install
    
    # Setup PM2 process
    sudo -u $WEB_USER pm2 delete anonymity-control 2>/dev/null || true
    sudo -u $WEB_USER pm2 start server.js --name anonymity-control
    sudo -u $WEB_USER pm2 save
    sudo -u $WEB_USER pm2 startup
    
    print_success "Web interface configured"
}

setup_boot_services() {
    print_status "Setting up boot services..."
    
    # Create systemd service for MAC spoofing
    cat > /etc/systemd/system/mac-spoof.service << 'EOF'
[Unit]
Description=MAC Address Spoofing
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/spoof-mac.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd service for hostname randomization
    cat > /etc/systemd/system/random-hostname.service << 'EOF'
[Unit]
Description=Random Hostname Generator
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/random-hostname.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    # Enable boot services
    systemctl daemon-reload
    systemctl enable tor
    systemctl enable privoxy
    systemctl enable mac-spoof
    systemctl enable random-hostname
    
    print_success "Boot services configured"
}

main() {
    echo "🛡️  Raspi Anonymity Control - Installation Script"
    echo "=================================================="
    
    check_root
    check_os
    
    update_system
    install_packages
    configure_tor
    configure_privoxy
    configure_proxychains
    create_scripts
    create_firewall_script
    create_mac_spoofing_script
    create_hostname_script
    setup_web_interface
    setup_boot_services
    
    print_success "Installation completed successfully!"
    echo ""
    echo "🚀 To start the anonymity services, run:"
    echo "   sudo start-anonymity"
    echo ""
    echo "📱 Web interface will be available at:"
    echo "   http://$(hostname -I | awk '{print $1}'):5555"
    echo ""
    echo "🔧 Management commands:"
    echo "   sudo start-anonymity  - Start all services"
    echo "   sudo stop-anonymity   - Stop all services"  
    echo "   sudo check-anonymity  - Check service status"
    echo ""
    echo "⚠️  Reboot recommended to apply all changes!"
}

main "$@"