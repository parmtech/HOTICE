<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(403); exit; }
require_once dirname(__DIR__) . '/src/App.php';
$config = require dirname(__DIR__) . '/config.php';
try {
    $db = (new \Hotice\App($config))->database();
    // Keep each cPanel cron invocation bounded. Grant rows have no value after
    // expiration; audit rows are retained for 90 days unless account/file
    // deletion has already removed their identifying foreign keys.
    $grantLimit = isset($argv[1]) && ctype_digit($argv[1]) ? max(1, min(1000, (int) $argv[1])) : 500;
    $auditLimit = isset($argv[2]) && ctype_digit($argv[2]) ? max(1, min(5000, (int) $argv[2])) : 1000;
    $grants = $db->prepare('DELETE FROM media_access_grants WHERE expires_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY) LIMIT ' . $grantLimit);
    $grants->execute();
    $audit = $db->prepare('DELETE FROM media_access_audit WHERE occurred_at < DATE_SUB(UTC_TIMESTAMP(), INTERVAL 90 DAY) LIMIT ' . $auditLimit);
    $audit->execute();
    echo json_encode(['expiredGrantsPurged' => $grants->rowCount(), 'oldAuditEventsPurged' => $audit->rowCount()], JSON_THROW_ON_ERROR) . "\n";
} catch (Throwable $e) {
    fwrite(STDERR, 'Media access retention cleanup failed. ' . get_class($e) . "\n");
    exit(1);
}
