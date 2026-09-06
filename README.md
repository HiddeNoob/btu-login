# FortiGate Captive Portal Auto-Login Script

A simple Bash script to automatically authenticate with a **FortiGate captive portal** and maintain internet connectivity.

Tested with BTU-WiFi on Ubuntu Server 26.04.1 

---

## ⚙️ Usage Instructions

1. **Set permissions:**
   ```bash
   chmod +x auto_login.sh
   ```

2. **Run the script:**
   ```bash
   ./auto_login.sh
   ```

3. **Run in background (optional):**
   ```bash
   nohup ./auto_login.sh > login.log 2>&1 &
   ```
