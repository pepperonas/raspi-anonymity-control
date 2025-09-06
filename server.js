const express = require('express');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 5555;

app.use(bodyParser.json());
app.use(express.static('public'));

// API Endpoints
app.get('/api/status', (req, res) => {
    const status = {};
    
    // Check Tor status
    exec('systemctl is-active tor', (error, stdout) => {
        status.tor = stdout.trim() === 'active';
        
        // Check Privoxy status
        exec('systemctl is-active privoxy', (error, stdout) => {
            status.privoxy = stdout.trim() === 'active';
            
            // Get current IP
            exec('curl -s --socks5 127.0.0.1:9050 https://check.torproject.org/api/ip 2>/dev/null', (error, stdout) => {
                try {
                    const ipData = JSON.parse(stdout);
                    status.torIp = ipData.IP || 'Unknown';
                } catch {
                    status.torIp = 'Not connected';
                }
                
                // Get hostname
                exec('hostname', (error, stdout) => {
                    status.hostname = stdout.trim();
                    
                    // Get MAC addresses
                    exec("ip link show | grep -E 'link/ether' | awk '{print $2}'", (error, stdout) => {
                        status.macAddresses = stdout.trim().split('\n');
                        
                        // Get Pi-hole status
                        exec('systemctl is-active pihole-FTL', (error, stdout) => {
                            status.pihole = stdout.trim() === 'active';
                            res.json(status);
                        });
                    });
                });
            });
        });
    });
});

app.post('/api/start', (req, res) => {
    exec('/usr/local/bin/start-anonymity', (error, stdout, stderr) => {
        if (error) {
            res.status(500).json({ success: false, message: stderr });
        } else {
            res.json({ success: true, message: 'Anonymity services started' });
        }
    });
});

app.post('/api/stop', (req, res) => {
    exec('/usr/local/bin/stop-anonymity', (error, stdout, stderr) => {
        if (error) {
            res.status(500).json({ success: false, message: stderr });
        } else {
            res.json({ success: true, message: 'Anonymity services stopped' });
        }
    });
});

app.post('/api/spoof-mac', (req, res) => {
    exec('/usr/local/bin/spoof-mac.sh', (error, stdout, stderr) => {
        if (error) {
            res.status(500).json({ success: false, message: stderr });
        } else {
            res.json({ success: true, message: 'MAC addresses spoofed' });
        }
    });
});

app.post('/api/change-hostname', (req, res) => {
    exec('/usr/local/bin/random-hostname.sh', (error, stdout, stderr) => {
        if (error) {
            res.status(500).json({ success: false, message: stderr });
        } else {
            res.json({ success: true, message: stdout });
        }
    });
});

app.post('/api/new-circuit', (req, res) => {
    exec('echo -e "AUTHENTICATE \"\"\r\nSIGNAL NEWNYM\r\nQUIT" | nc 127.0.0.1 9051', (error, stdout, stderr) => {
        if (error) {
            res.status(500).json({ success: false, message: 'Failed to create new circuit' });
        } else {
            res.json({ success: true, message: 'New Tor circuit created' });
        }
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Anonymity Control Panel running on port ${PORT}`);
});
