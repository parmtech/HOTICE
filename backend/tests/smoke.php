<?php
declare(strict_types=1);
require_once dirname(__DIR__) . '/src/Support.php';
require_once dirname(__DIR__) . '/src/AdminSecurity.php';
require_once dirname(__DIR__) . '/src/ProviderAdapter.php';
require_once dirname(__DIR__) . '/src/MockProviderAdapter.php';
use Hotice\ApiError;
use Hotice\AdminSecurity;
use Hotice\Support;
$assertions = 0;
function check(bool $ok, string $label): void {
    global $assertions;
    $assertions++;
    if (!$ok) { fwrite(STDERR, "FAIL: $label\n"); exit(1); }
}
for ($i = 0; $i < 100; $i++) {
    $uuid = Support::uuid();
    check(Support::isUuid($uuid), 'uuid4 generation');
    check(!Support::isUuid(str_replace('-', '', $uuid)), 'no malformed uuid');
}
check(AdminSecurity::base32Encode('12345678901234567890') === 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', 'TOTP base32 encoding');
check(AdminSecurity::totp('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', 59) === '287082', 'RFC 6238 TOTP vector');
check(AdminSecurity::verifyTotp('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', '287082', 59), 'valid TOTP accepted');
check(!AdminSecurity::verifyTotp('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', '000000', 59), 'invalid TOTP rejected');
$appKey = str_repeat('ab', 32);
$sealed = AdminSecurity::encryptProviderKey('openai', 'secret-example', $appKey);
check(AdminSecurity::decryptProviderKey('openai', $sealed['ciphertext'], $sealed['nonce'], $sealed['tag'], $appKey) === 'secret-example', 'provider secret encryption roundtrip');
try { AdminSecurity::decryptProviderKey('google', $sealed['ciphertext'], $sealed['nonce'], $sealed['tag'], $appKey); check(false, 'provider keys bound to provider'); } catch (RuntimeException) { check(true, 'provider keys bound to provider'); }
$mockProvider = new Hotice\MockProviderAdapter();
$providerRegistry = new Hotice\ProviderRegistry([$mockProvider]);
check($providerRegistry->enabledModelIds() === [Hotice\MockProviderAdapter::MODEL_ID], 'registry exposes only registered mock model');
check($providerRegistry->forModel(Hotice\MockProviderAdapter::MODEL_ID) === $mockProvider, 'model routes to its registered adapter');
try { $providerRegistry->forModel('unknown.provider.model'); check(false, 'unknown provider model fails closed'); } catch (ApiError $e) { check($e->status === 422, 'unknown provider model fails closed'); }
$providerRequest = new Hotice\ProviderRequest(Hotice\MockProviderAdapter::MODEL_ID, 'synthetic prompt must not be returned', [], ['simulate' => 'success', 'attempt' => 1]);
check($providerRegistry->validateRequest($providerRequest) === $mockProvider, 'model capability accepts its supported empty attachment set');
$providerMedia = ['mediaId' => Support::uuid(), 'role' => 'reference_image', 'mime' => 'image/jpeg', 'byteSize' => 1024, 'sha256' => str_repeat('a', 64)];
try { new Hotice\ProviderRequest(Hotice\MockProviderAdapter::MODEL_ID, 'prompt', [$providerMedia + ['path' => '/private/file']]); check(false, 'provider attachment rejects local path metadata'); } catch (InvalidArgumentException) { check(true, 'provider attachment rejects local path metadata'); }
try { $providerRegistry->validateRequest(new Hotice\ProviderRequest(Hotice\MockProviderAdapter::MODEL_ID, 'prompt', [$providerMedia])); check(false, 'mock model rejects unsupported attachment before dispatch'); } catch (ApiError $e) { check($e->status === 422, 'mock model rejects unsupported attachment before dispatch'); }
$imageAdapter = new class implements Hotice\ProviderAdapter {
    public function id(): string { return 'fixture'; }
    public function modelCapabilities(): array { return [new Hotice\ProviderModelCapabilities('fixture.video.v1', ['reference_image' => ['image/jpeg', 'image/png']], 2, 2 * 1024 * 1024, [
        ['durationSeconds' => 4, 'aspectRatio' => '16:9'],
        ['durationSeconds' => 8, 'aspectRatio' => '9:16'],
    ], 120)]; }
    public function submit(Hotice\ProviderRequest $request, string $idempotencyKey): Hotice\ProviderOperation { return new Hotice\ProviderOperation(Support::uuid(), 'queued'); }
    public function poll(string $operationId): Hotice\ProviderOperation { return new Hotice\ProviderOperation($operationId, 'processing'); }
    public function cancel(string $operationId): Hotice\ProviderOperation { return new Hotice\ProviderOperation($operationId, 'cancelled'); }
};
$capabilityRegistry = new Hotice\ProviderRegistry([$imageAdapter]);
check($capabilityRegistry->validateRequest(new Hotice\ProviderRequest('fixture.video.v1', 'prompt', [$providerMedia], [], 4, '16:9')) === $imageAdapter, 'declared reference image and duration/aspect capabilities accept the request');
try { $capabilityRegistry->validateRequest(new Hotice\ProviderRequest('fixture.video.v1', 'prompt', [$providerMedia], [], 4, '9:16')); check(false, 'model rejects unsupported duration/aspect pair'); } catch (ApiError $e) { check($e->status === 422, 'model rejects unsupported duration/aspect pair'); }
try { $capabilityRegistry->validateRequest(new Hotice\ProviderRequest('fixture.video.v1', str_repeat('p', 121), [], [], 4, '16:9')); check(false, 'model enforces per-model prompt limit'); } catch (ApiError $e) { check($e->status === 422, 'model enforces per-model prompt limit'); }
try { new Hotice\ProviderRequest('fixture.video.v1', 'prompt', [], [], 4); check(false, 'generation settings require a complete duration/aspect pair'); } catch (InvalidArgumentException) { check(true, 'generation settings require a complete duration/aspect pair'); }
try { $capabilityRegistry->validateRequest(new Hotice\ProviderRequest('fixture.video.v1', 'prompt', [array_merge($providerMedia, ['mime' => 'video/mp4'])], [], 4, '16:9')); check(false, 'model rejects unsupported attachment MIME before dispatch'); } catch (ApiError $e) { check($e->status === 422, 'model rejects unsupported attachment MIME before dispatch'); }
try { $capabilityRegistry->validateRequest(new Hotice\ProviderRequest('fixture.video.v1', 'prompt', [
    $providerMedia,
    array_merge($providerMedia, ['mediaId' => Support::uuid(), 'byteSize' => 2 * 1024 * 1024]),
], [], 4, '16:9')); check(false, 'model enforces aggregate attachment byte limit'); } catch (ApiError $e) { check($e->status === 422, 'model enforces aggregate attachment byte limit'); }
try { new Hotice\ProviderRequest('fixture.video.v1', 'prompt', [$providerMedia, $providerMedia]); check(false, 'duplicate media IDs rejected before dispatch'); } catch (InvalidArgumentException) { check(true, 'duplicate media IDs rejected before dispatch'); }
try { new Hotice\ProviderModelCapabilities('fixture.video.v1', ['reference_image' => ['image/jpeg']], 2, 0); check(false, 'attachment capabilities require a positive byte limit'); } catch (InvalidArgumentException) { check(true, 'attachment capabilities require a positive byte limit'); }
$providerOperation = $mockProvider->submit($providerRequest, str_repeat('a', 64));
check($providerOperation->status === 'queued', 'mock provider submit is asynchronous');
check($mockProvider->submit($providerRequest, str_repeat('a', 64))->operationId === $providerOperation->operationId, 'provider idempotency reuses operation');
check($mockProvider->poll($providerOperation->operationId)->status === 'processing', 'provider polling normalizes processing state');
$providerOperation = $mockProvider->poll($providerOperation->operationId);
check($providerOperation->status === 'succeeded', 'mock provider reaches normalized success');
check(($providerOperation->result['mode'] ?? null) === 'mock_dry_run' && !isset($providerOperation->result['prompt']), 'mock provider returns no prompt or generated media');
try { $mockProvider->submit($providerRequest, str_repeat('b', 64)); $changedRequest = new Hotice\ProviderRequest(Hotice\MockProviderAdapter::MODEL_ID, 'different prompt', [], ['simulate' => 'success', 'attempt' => 1]); $mockProvider->submit($changedRequest, str_repeat('a', 64)); check(false, 'provider idempotency key request binding'); } catch (ApiError $e) { check($e->status === 409, 'provider idempotency key request binding'); }
$retryable = $mockProvider->submit(new Hotice\ProviderRequest(Hotice\MockProviderAdapter::MODEL_ID, '', [], ['simulate' => 'rate_limit_once', 'attempt' => 1]), str_repeat('c', 64));
$mockProvider->poll($retryable->operationId);
$retryable = $mockProvider->poll($retryable->operationId);
check($retryable->status === 'failed' && $retryable->retryable && $retryable->errorCode === 'mock_rate_limited', 'mock provider returns retryable normalized error');
$cancel = $mockProvider->submit(new Hotice\ProviderRequest(Hotice\MockProviderAdapter::MODEL_ID, '', [], ['simulate' => 'success', 'attempt' => 1]), str_repeat('d', 64));
check($mockProvider->cancel($cancel->operationId)->status === 'cancelled', 'mock provider cancellation contract');
try { new Hotice\ProviderRegistry([$mockProvider, new Hotice\MockProviderAdapter()]); check(false, 'duplicate model provider registration rejected'); } catch (InvalidArgumentException) { check(true, 'duplicate model provider registration rejected'); }
check(Support::email(' A@EXAMPLE.COM ') === 'a@example.com', 'normalize email');
try { Support::email('not-an-email'); check(false, 'invalid email rejected'); } catch (ApiError $e) { check($e->status === 422, 'invalid email'); }
check(Support::secureFileName(str_repeat('a', 64)), 'valid storage name');
check(!Support::secureFileName('../secret'), 'reject traversal');
check(Support::jsonString(['a' => 'b'], 50) === '{"a":"b"}', 'JSON serialization');
try { Support::jsonString(['a' => str_repeat('X', 50)], 10); check(false, 'reject oversized document'); } catch (ApiError $e) { check($e->status === 413, 'oversized JSON'); }
// Validate that storage cannot be public (including ancestor and symlink
// cases) even if an operator configures a cPanel document root incorrectly.
$tmpBase = sys_get_temp_dir() . '/hotice-safe-' . bin2hex(random_bytes(8));
mkdir($tmpBase . '/public/uploads', 0700, true);
mkdir($tmpBase . '/private', 0700, true);
try {
    check(Support::assertPrivateStorage($tmpBase . '/private', [$tmpBase . '/public'])
        === realpath($tmpBase . '/private'), 'separate private storage accepted');
    foreach ([$tmpBase . '/public', $tmpBase, $tmpBase . '/public/uploads'] as $unsafe) {
        try {
            Support::assertPrivateStorage($unsafe, [$tmpBase . '/public']);
            check(false, 'webroot path rejected');
        } catch (\RuntimeException $e) {
            check(true, 'webroot path rejected');
        }
    }
    if (function_exists('symlink') && @symlink($tmpBase . '/public/uploads', $tmpBase . '/alias')) {
        try {
            Support::assertPrivateStorage($tmpBase . '/alias', [$tmpBase . '/public']);
            check(false, 'symlink bypass rejected');
        } catch (\RuntimeException $e) {
            check(true, 'symlink bypass rejected');
        }
        unlink($tmpBase . '/alias');
    }
    try {
        Support::assertPrivateStorage($tmpBase . '/private', [$tmpBase . '/nonexistent']);
        check(false, 'nonexistent public root rejected');
    } catch (\RuntimeException $e) {
        check(true, 'nonexistent public root rejected');
    }
} finally {
    rmdir($tmpBase . '/public/uploads');
    rmdir($tmpBase . '/public');
    rmdir($tmpBase . '/private');
    rmdir($tmpBase);
}
echo "HOTICE backend core: $assertions assertions passed.\n";
