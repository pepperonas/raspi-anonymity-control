# 🔒 Raspi Anonymity Control

[![English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![Deutsch](https://img.shields.io/badge/lang-Deutsch-yellow.svg)](README.de.md)

Ein umfassendes Anonymitäts-Gateway für Raspberry Pi, das Tor, VPN und DNS-over-HTTPS für maximale Privatsphäre und Sicherheit kombiniert.

## 🌟 Funktionen

- **Tor-Integration**: Vollständiges Tor-Gateway mit SOCKS5-Proxy
- **VPN-Unterstützung**: OpenVPN und WireGuard-Kompatibilität
- **DNS-over-HTTPS**: Verschlüsselte DNS-Anfragen über Cloudflare
- **Firewall-Schutz**: Umfassende iptables-Regeln
- **Web-Dashboard**: Echtzeitüberwachung und -steuerung
- **Multi-Client**: Unterstützung für mehrere gleichzeitige Geräte
- **Automatisches Failover**: Nahtloser Wechsel zwischen Anonymitätsmodi

## 📋 Voraussetzungen

- Raspberry Pi 4 oder 5 (empfohlen: 4GB+ RAM)
- Raspberry Pi OS (64-bit empfohlen)
- Mindestens 16GB SD-Karte
- Ethernet-Verbindung für Gateway-Modus
- Optional: WiFi für Access Point-Modus

## 🚀 Schnellinstallation

```bash
# Repository klonen
git clone https://github.com/yourusername/anonymity-control.git
cd anonymity-control

# Installationsskript ausführen
chmod +x install.sh
sudo ./install.sh
```

Das Installationsskript führt dich durch den gesamten Einrichtungsprozess und konfiguriert alle notwendigen Dienste automatisch.

## 🔧 Manuelle Installation

### 1. System vorbereiten

```bash
# System aktualisieren
sudo apt update && sudo apt upgrade -y

# Erforderliche Pakete installieren
sudo apt install -y tor obfs4proxy openvpn wireguard \
  dnsmasq hostapd iptables-persistent nodejs npm \
  python3-pip git curl wget net-tools
```

### 2. Tor konfigurieren

```bash
# Tor-Konfiguration bearbeiten
sudo nano /etc/tor/torrc
```

Füge folgende Zeilen hinzu:
```
SocksPort 0.0.0.0:9050
SocksPolicy accept *
TransPort 0.0.0.0:9040
DNSPort 0.0.0.0:5353
AutomapHostsOnResolve 1
```

### 3. Anwendung einrichten

```bash
# Node.js-Abhängigkeiten installieren
npm install

# Umgebungsvariablen konfigurieren
cp .env.example .env
nano .env

# Anwendung starten
npm start
```

## 💻 Client-Konfiguration

### Windows
1. Öffne **Einstellungen** → **Netzwerk & Internet** → **Proxy**
2. Aktiviere "Proxyserver verwenden"
3. Adresse: `[Raspberry-Pi-IP]`
4. Port: `9050`
5. Aktiviere "Proxy nicht für lokale Adressen verwenden"

### macOS
1. Öffne **Systemeinstellungen** → **Netzwerk**
2. Wähle deine Verbindung → **Erweitert** → **Proxys**
3. Aktiviere "SOCKS-Proxy"
4. Server: `[Raspberry-Pi-IP]`
5. Port: `9050`

### Linux
```bash
# Systemweite Proxy-Einstellungen
export ALL_PROXY=socks5://[Raspberry-Pi-IP]:9050
export HTTP_PROXY=socks5://[Raspberry-Pi-IP]:9050
export HTTPS_PROXY=socks5://[Raspberry-Pi-IP]:9050
```

### iOS
1. **Einstellungen** → **WLAN** → Info-Symbol neben deinem Netzwerk
2. **HTTP-Proxy konfigurieren** → **Manuell**
3. Server: `[Raspberry-Pi-IP]`
4. Port: `9050`
5. Authentifizierung: Aus

### Android
1. **Einstellungen** → **WLAN** → Lange auf dein Netzwerk drücken
2. **Netzwerk ändern** → **Erweiterte Optionen**
3. Proxy: **Manuell**
4. Proxy-Hostname: `[Raspberry-Pi-IP]`
5. Proxy-Port: `9050`

## 🌐 Web-Dashboard

Greife auf das Dashboard zu unter:
```
http://[Raspberry-Pi-IP]:3000
```

### Dashboard-Funktionen:
- **Verbindungsstatus**: Echtzeitüberwachung aller aktiven Verbindungen
- **Bandbreitennutzung**: Grafische Darstellung des Datenverkehrs
- **Tor-Schaltkreise**: Anzeige aktiver Tor-Verbindungen
- **DNS-Anfragen**: Überwachung von DNS-over-HTTPS-Anfragen
- **Firewall-Regeln**: Verwaltung von iptables-Regeln
- **Systemmetriken**: CPU, RAM und Netzwerkauslastung

## 🛡️ Sicherheitsfunktionen

### Firewall-Regeln
Das System implementiert strenge iptables-Regeln:
- Blockiert alle eingehenden Verbindungen außer konfigurierten Diensten
- Erzwingt Tor-Routing für ausgewählten Datenverkehr
- Verhindert DNS-Leaks
- Blockiert IPv6-Datenverkehr (optional)

### DNS-over-HTTPS
Alle DNS-Anfragen werden verschlüsselt über Cloudflare geleitet:
```bash
# DNS-Konfiguration testen
nslookup example.com 127.0.0.1
```

### Automatische Sicherheitsupdates
```bash
# Unattended-upgrades aktivieren
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

## 📊 Überwachung

### Tor-Status prüfen
```bash
# Tor-Dienststatus
sudo systemctl status tor

# Tor-Verbindungen
sudo netstat -tlnp | grep tor

# Tor-Logs
sudo journalctl -u tor -f
```

### Netzwerkstatistiken
```bash
# Aktive Verbindungen
sudo netstat -tunap

# Bandbreitennutzung
sudo iftop -i eth0

# DNS-Anfragen
sudo tcpdump -i any port 53
```

## 🔧 Erweiterte Konfiguration

### VPN-Integration

#### OpenVPN einrichten
```bash
# OpenVPN-Konfiguration platzieren
sudo cp your-vpn.ovpn /etc/openvpn/client.conf

# OpenVPN starten
sudo systemctl start openvpn@client
sudo systemctl enable openvpn@client
```

#### WireGuard einrichten
```bash
# WireGuard-Konfiguration
sudo nano /etc/wireguard/wg0.conf

# WireGuard aktivieren
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

### Access Point-Modus

Erstelle einen WiFi-Hotspot mit automatischem Tor-Routing:

```bash
# hostapd konfigurieren
sudo nano /etc/hostapd/hostapd.conf
```

Beispielkonfiguration:
```
interface=wlan0
driver=nl80211
ssid=AnonymityGateway
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=DeinSicheresPasswort
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

## 🐛 Fehlerbehebung

### Tor startet nicht
```bash
# Tor-Konfiguration überprüfen
sudo tor --verify-config

# Tor-Benutzerberechtigungen
sudo chown -R debian-tor:debian-tor /var/lib/tor
```

### Keine Internetverbindung über Tor
```bash
# iptables-Regeln prüfen
sudo iptables -L -v -n

# DNS-Auflösung testen
dig @127.0.0.1 -p 5353 google.com
```

### Dashboard nicht erreichbar
```bash
# Node.js-Anwendung prüfen
pm2 status
pm2 logs anonymity-control

# Port-Verfügbarkeit prüfen
sudo lsof -i :3000
```

## 📝 Logs

Wichtige Log-Dateien:
- Tor: `/var/log/tor/log`
- System: `/var/log/syslog`
- Anwendung: `~/apps/anonymity-control/logs/`
- DNS: `/var/log/dnsmasq.log`

## 🤝 Beitragen

Beiträge sind willkommen! Bitte lies unsere [Beitragsrichtlinien](CONTRIBUTING.md) für Details.

1. Forke das Repository
2. Erstelle deinen Feature-Branch (`git checkout -b feature/AmazingFeature`)
3. Committe deine Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Pushe zum Branch (`git push origin feature/AmazingFeature`)
5. Öffne einen Pull Request

## 📄 Lizenz

Dieses Projekt ist unter der MIT-Lizenz lizenziert - siehe [LICENSE](LICENSE) Datei für Details.

## ⚠️ Haftungsausschluss

Dieses Tool ist nur für legale Zwecke gedacht. Nutzer sind verantwortlich für die Einhaltung aller anwendbaren Gesetze und Vorschriften. Die Entwickler übernehmen keine Verantwortung für Missbrauch oder illegale Aktivitäten.

## 🙏 Danksagungen

- [Tor Project](https://www.torproject.org/) für ihr Anonymitätsnetzwerk
- [Cloudflare](https://cloudflare.com/) für DNS-over-HTTPS
- [OpenVPN](https://openvpn.net/) und [WireGuard](https://www.wireguard.com/) für VPN-Protokolle
- Die Open-Source-Community für kontinuierliche Unterstützung

## 📞 Support

Für Probleme und Fragen:
- Öffne ein [GitHub Issue](https://github.com/yourusername/anonymity-control/issues)
- Besuche unser [Wiki](https://github.com/yourusername/anonymity-control/wiki)
- Tritt unserer [Community](https://discord.gg/yourinvite) bei

---

**Gebaut mit ❤️ für Privatsphäre und Sicherheit**