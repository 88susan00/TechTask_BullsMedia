<?php

if ($_SERVER['REQUEST_URI'] === '/healthz') {
    http_response_code(200);
    header('Content-Type: text/plain');
    echo 'OK';
    exit;
}

echo "<h1>Site 3 - PHP application</h1>";
echo "<p>Server time: " . date('Y-m-d H:i:s') . "</p>";
echo "<p>Hostname: " . gethostname() . "</p>";
