<?php
declare(strict_types=1);
if (PHP_SAPI !== 'cli') { http_response_code(403); exit; }
require_once dirname(__DIR__) . '/src/App.php';

/** @param array<string,mixed> $config */
function runMediaScan(array $config, int $limit, int $batchSeconds): int
{
    try {
        $app = new \Hotice\App($config);
        $db = $app->database();
        $databaseName = (string)$db->query('SELECT DATABASE()')->fetchColumn();
        if ($databaseName === '') throw new RuntimeException('Scanner database unavailable.');
        // cPanel cron can start a second batch before a slow first one finishes.
        // Scope the MySQL advisory lock to this database so separate HOTICE
        // installations sharing one MySQL server do not block each other.
        $lockName = 'hotice_media_scan_' . substr(hash('sha256', $databaseName), 0, 32);
        $lock = $db->prepare('SELECT GET_LOCK(?, 0)');
        $lock->execute([$lockName]);
        $lockResult = $lock->fetchColumn();
        if ($lockResult === null || $lockResult === false) {
            throw new RuntimeException('Scanner advisory lock is unavailable.');
        }
        if ((int)$lockResult !== 1) {
            echo json_encode(['status' => 'busy'], JSON_THROW_ON_ERROR) . "\n";
            return 0;
        }

        try {
            $storage = (string)($config['storage_path'] ?? '');
            if ($storage === '' || !is_dir($storage)) throw new RuntimeException('Private storage unavailable.');
            $roots = [dirname(__DIR__) . '/public'];
            $webroot = trim((string)($config['public_webroot_path'] ?? ''));
            if ($webroot !== '') $roots[] = $webroot;
            \Hotice\Support::assertPrivateStorage($storage, $roots);
            // Only scan due uploads; an unavailable scanner/file is retried
            // later, so one broken upload cannot monopolize every cron batch.
            $q = $db->prepare("SELECT id,storage_name FROM cloud_files WHERE scan_status='pending' AND next_scan_at<=UTC_TIMESTAMP() ORDER BY next_scan_at,created_at,id LIMIT ?");
            $q->bindValue(1, max(1, min(100, $limit)), PDO::PARAM_INT);
            $q->execute();
            $defer = $db->prepare("UPDATE cloud_files SET next_scan_at=DATE_ADD(UTC_TIMESTAMP(), INTERVAL 5 MINUTE) WHERE id=? AND storage_name=? AND scan_status='pending'");
            $clean = $blocked = $retryable = 0;
            $batchStarted = microtime(true);
            $batchLimited = false;
            foreach ($q->fetchAll() as $file) {
                $remaining = $batchSeconds - (microtime(true) - $batchStarted);
                if ($remaining < 1.0) {
                    $batchLimited = true;
                    break;
                }
                $name = (string)$file['storage_name'];
                if (!\Hotice\Support::secureFileName($name)) {
                    $defer->execute([$file['id'], $name]);
                    $retryable++; continue;
                }
                $path = $storage . '/' . $name;
                if (is_link($path) || !is_file($path) || !is_readable($path)) {
                    $defer->execute([$file['id'], $name]);
                    $retryable++; continue;
                }
                $remaining = $batchSeconds - (microtime(true) - $batchStarted);
                if ($remaining < 1.0) {
                    $batchLimited = true;
                    break;
                }
                $pipes = [];
                $process = proc_open([$config['clamdscan_path'], '--no-summary', '--', $path], [
                    0 => ['file', '/dev/null', 'r'],
                    1 => ['file', '/dev/null', 'a'],
                    2 => ['file', '/dev/null', 'a'],
                ], $pipes);
                if (!is_resource($process)) {
                    $defer->execute([$file['id'], $name]);
                    $retryable++; continue;
                }
                $timeoutSeconds = min(120.0, $remaining);
                $started = microtime(true);
                $timedOut = false;
                do {
                    $state = proc_get_status($process);
                    if (!$state['running']) { $code = $state['exitcode']; break; }
                    if (microtime(true) - $started >= $timeoutSeconds) {
                        proc_terminate($process, 9);
                        $code = -1;
                        $timedOut = true;
                        break;
                    }
                    usleep(200000);
                } while (true);
                proc_close($process);
                if ($timedOut) $batchLimited = true;
                if ($code !== 0 && $code !== 1) {
                    $defer->execute([$file['id'], $name]);
                    $retryable++; continue;
                }
                $status = $code === 0 ? 'clean' : 'blocked';
                $update = $db->prepare("UPDATE cloud_files SET scan_status=? WHERE id=? AND storage_name=? AND scan_status='pending'");
                $update->execute([$status, $file['id'], $name]);
                if ($update->rowCount() === 1) $status === 'clean' ? $clean++ : $blocked++;
            }
            echo json_encode([
                'scannedClean' => $clean,
                'blocked' => $blocked,
                'retryableFailures' => $retryable,
                'batchLimited' => $batchLimited,
            ], JSON_THROW_ON_ERROR) . "\n";
            return $retryable > 0 ? 1 : 0;
        } finally {
            $release = $db->prepare('SELECT RELEASE_LOCK(?)');
            $release->execute([$lockName]);
        }
    } catch (Throwable $e) {
        fwrite(STDERR, 'Media scan failed; files remain quarantined. ' . get_class($e) . "\n");
        return 1;
    }
}

$config = require dirname(__DIR__) . '/config.php';
$scanner = (string)($config['clamdscan_path'] ?? '');
if ($scanner === '' || !str_starts_with($scanner, '/') || !is_executable($scanner)) {
    fwrite(STDERR, "Media scanning is not configured; uploads remain quarantined.\n");
    exit(2);
}
$limit = isset($argv[1]) && ctype_digit($argv[1]) ? (int)$argv[1] : 20;
$configuredBatchSeconds = max(1, min(300, (int)($config['media_scan_batch_seconds'] ?? 180)));
$batchSeconds = isset($argv[2]) && ctype_digit($argv[2])
    ? max(1, min(300, (int)$argv[2]))
    : $configuredBatchSeconds;
exit(runMediaScan($config, $limit, $batchSeconds));
