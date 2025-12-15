#!/bin/bash

GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

DB_FILE="passwords.txt"
TEMP_FILE="passwords.tmp"
LOG_FILE="access_logs.csv"
PHP_SERVER_PORT=8080

declare -a BACKGROUND_PIDS=()

show_banner() {
	clear
	echo -e "${CYAN}"
	echo "  __  __  ___  _   _    _    ___ __  __  ___ "
	echo " |  \/  |/ _ \| \ | |  / \  |_ _|  \/  |/ _ \\"
	echo " | |\/| | | | |  \| | / _ \  | || |\/| | | | |"
	echo " | |  | | |_| | |\  |/ ___ \ | || |  | | |_| |"
	echo " |_|  |_|\___/|_| \_/_/   \_\___|_|  |_|\___/ "
	echo -e "${RESET}"
	echo -e "${RED}============= MONAIM9 MANAGER =============${RESET}"
}

cleanup() {
	if [ ${#BACKGROUND_PIDS[@]} -gt 0 ]; then
		kill ${BACKGROUND_PIDS[@]} 2>/dev/null
	fi
	encrypt_db
	[ -f "$TEMP_FILE" ] && shred -u "$TEMP_FILE" 2>/dev/null
	exit 0
}

trap cleanup INT TERM EXIT

decrypt_db() {
	[ ! -f "$DB_FILE" ] && echo "" > "$TEMP_FILE" && return
	cat "$DB_FILE" > "$TEMP_FILE"
}

encrypt_db() {
	cat "$TEMP_FILE" > "$DB_FILE"
}

generate_password() {
	< /dev/urandom tr -dc 'A-Za-z0-9' | head -c "$1"
}

generate_qr() {
	command -v qrencode &>/dev/null || sudo apt install qrencode -y
	mkdir -p qr_codes
	qrencode -o "qr_codes/${2}_qr.png" "$1"
}

install_dependency() {
	command -v "$1" &>/dev/null || sudo apt install "$2" -y
}

install_ngrok_if_needed() {
	install_dependency php php
	install_dependency curl curl
	command -v ngrok &>/dev/null && return
	wget https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -O ngrok.tgz
	tar -xzf ngrok.tgz
	sudo mv ngrok /usr/local/bin/
	rm ngrok.tgz
}

setup_ngrok_authtoken() {
	CONF="$HOME/.config/ngrok/ngrok.yml"
	[ -f "$CONF" ] && grep -q authtoken "$CONF" && return
	read -p "Paste ngrok authtoken command: " CMD
	eval "$CMD"
}

start_collector() {
	install_ngrok_if_needed
	setup_ngrok_authtoken

	[ ! -f collector.php ] && cat <<EOF > collector.php
<?php
\$t=date('Y-m-d H:i:s');
\$ip=\$_SERVER['REMOTE_ADDR']??'N/A';
\$ua=str_replace([\"\\n\",\"\\r\",\",\"],' ',\$_SERVER['HTTP_USER_AGENT']??'N/A');
file_exists('access_logs.csv')||file_put_contents('access_logs.csv',"Time,IP,UA\n");
file_put_contents('access_logs.csv',"\"\$t\",\"\$ip\",\"\$ua\"\n",FILE_APPEND);
header("Location: https://google.com",true,303);
EOF

	php -S 127.0.0.1:$PHP_SERVER_PORT >/dev/null 2>&1 &
	BACKGROUND_PIDS+=($!)

	ngrok http $PHP_SERVER_PORT >/dev/null 2>&1 &
	BACKGROUND_PIDS+=($!)

	for i in {1..10}; do
		URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o '"public_url":"[^"]*' | head -n1 | cut -d'"' -f4)
		[ -n "$URL" ] && break
		sleep 1
	done

	read -p "Name: " N
	generate_qr "$URL/collector.php" "$N"
	read -n1 -s
}

show_banner
decrypt_db

while true; do
	echo -e "${GREEN}1) Add Password"
	echo "2) Generate Password"
	echo "3) Get NGROK config"
	echo "4) Search"
	echo "5) Delete All"
	echo "6) Exit${RESET}"
	echo -e "${YELLOW}9) Generate QR Info Gatherer${RESET}"
	read -p "Choose: " CHOICE
	case "$CHOICE" in
		1)
			read -p "Name: " NAME
			read -p "Password: " PASS
			echo "[General][$NAME] $PASS" >> "$TEMP_FILE"
			encrypt_db
			;;
		2)
			read -p "Name: " NAME
			read -p "Length: " LEN
			PASS=$(generate_password "$LEN")
			echo "[General][$NAME] $PASS" >> "$TEMP_FILE"
			encrypt_db
			read -p "QR? (y/n): " QR
			[ "$QR" = "y" ] && generate_qr "$PASS" "$NAME"
			;;
		3)
			echo "ngrok config add-authtoken 36sXDr2b4ZXK0WZu8a3pE0skRvA_4VrZuxRwc7cSbh1wcJQL3"
			read -n1 -s
			;;
		4)
			read -p "Search: " W
			grep -i "$W" "$TEMP_FILE"
			;;
		5)
			echo "" > "$TEMP_FILE"
			encrypt_db
			;;
		6) exit ;;
		9) start_collector ;;
	esac
done

