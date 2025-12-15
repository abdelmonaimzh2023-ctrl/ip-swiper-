README

The pass_rg231.sh tool is a powerful script built in Bash that uses advanced protocols such as PHP and Ngrok to collect information and store passwords in an organized manner.

This guide explains how to install, configure, and use the tool correctly in advanced mode for information gathering (Option 9).

1. Basic Requirements ⚙️

To run the script successfully, the following environment must be available:

A Linux-based operating system (e.g. Kali Linux, Ubuntu, Termux, etc.)

Root/Sudo privileges to install required packages

Required tools installed (such as php and qrencode)

Ngrok installed with a valid and activated AuthToken

2. Installation & Preparation 🚀

The script is designed to automatically install dependencies, but you must follow these steps first:

Step 1: Clone the repository
git clone <REPOSITORY_URL>
cd <REPOSITORY_FOLDER>
Step 2: Grant execute permissions
chmod +x pass_rg231.sh
Step 3: Run the tool
sudo bash pass_rg231.sh
3. Usage 📌

After launching the tool, follow the on-screen menu and select Option 9 to enable the advanced information-gathering mode.

The script will:

Launch a PHP server

Create an Ngrok tunnel

Generate a QR code (if supported)

Collect and store received credentials in an organized file

4. Notes ⚠️

Make sure Ngrok is correctly authenticated before running the script

Use this tool only in authorized and legal environments

Logs and collected data are stored locally in the project directory

✅ The tool is ready to use once all steps above are completed.
