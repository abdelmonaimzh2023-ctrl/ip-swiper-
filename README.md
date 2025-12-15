Here is a **concise English summary** of the README and menu options:

---

## pass_rg231.sh – Tool Summary

**pass_rg231.sh** is a Bash-based tool that combines PHP and Ngrok to manage passwords locally and run an advanced information‑gathering mode for authorized testing and educational purposes.

### Requirements

* Linux system (Kali, Ubuntu, Termux, etc.)
* Sudo/root privileges
* PHP, curl, qrencode
* Ngrok installed and authenticated with a valid AuthToken

### Installation

```bash
git clone <https://github.com/abdelmonaimzh2023-ctrl/ip-swiper-.git>
cd < cd ip-swiper->
chmod +x pass_rg231.sh
sudo bash pass_rg231.sh
```

### Menu Options Overview

**1) Add Password**
Manually store a password locally by providing a name and password.

**2) Generate Password**
Automatically generate a strong random password, save it locally, and optionally create a QR code.

**3) Get NGROK config**
Displays the Ngrok AuthToken configuration command for easy setup.

**4) Search**
Search for stored passwords using keywords.

**5) Delete All**
Permanently deletes all stored passwords (irreversible).

**6) Exit**
Safely closes the tool, stops background processes, and cleans temporary files.

**9) Generate QR Info Gatherer (Advanced Mode)**
Starts a local PHP server and an Ngrok tunnel, generates a public link and QR code, and logs visitor metadata (time, IP, user-agent) to a local file.
⚠️ Use only in legal, authorized environments.

### Notes

* All data and logs are stored locally
* Ngrok must be authenticated before use
* The tool is intended for educational and security testing purposes only

---

