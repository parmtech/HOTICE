<?php
declare(strict_types=1);

namespace Hotice;

/** A model's server-verified input contract. Empty inputs mean no attachments. */
final readonly class ProviderModelCapabilities
{
    /** @param array<string,list<string>> $attachmentMimes MIME types keyed by normalized role */
    public function __construct(
        public string $modelId,
        public array $attachmentMimes = [],
        public int $maxAttachments = 0,
        public int $maxTotalAttachmentBytes = 0,
    ) {
        if (!preg_match('/^[a-z0-9][a-z0-9._:-]{2,127}$/i', $modelId)) {
            throw new \InvalidArgumentException('Invalid capability model identifier.');
        }
        if ($maxAttachments < 0 || $maxAttachments > 20 || $maxTotalAttachmentBytes < 0) {
            throw new \InvalidArgumentException('Invalid model attachment limits.');
        }
        foreach ($attachmentMimes as $role => $mimes) {
            if (!in_array($role, ProviderRequest::ATTACHMENT_ROLES, true) || !is_array($mimes) || $mimes === []) {
                throw new \InvalidArgumentException('Invalid model attachment capability.');
            }
            foreach ($mimes as $mime) {
                if (!is_string($mime) || !preg_match('#^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$#', $mime)) {
                    throw new \InvalidArgumentException('Invalid model attachment MIME capability.');
                }
            }
        }
        if (($attachmentMimes === [] && ($maxAttachments !== 0 || $maxTotalAttachmentBytes !== 0)) ||
            ($attachmentMimes !== [] && ($maxAttachments === 0 || $maxTotalAttachmentBytes === 0))) {
            throw new \InvalidArgumentException('Attachment capabilities and limits must agree.');
        }
    }

    public function accepts(ProviderRequest $request): bool
    {
        if ($request->modelId !== $this->modelId || count($request->attachments) > $this->maxAttachments) return false;
        $totalBytes = 0;
        foreach ($request->attachments as $attachment) {
            $allowedMimes = $this->attachmentMimes[$attachment['role']] ?? [];
            if (!in_array($attachment['mime'], $allowedMimes, true)) return false;
            if ($attachment['byteSize'] > $this->maxTotalAttachmentBytes - $totalBytes) return false;
            $totalBytes += $attachment['byteSize'];
        }
        return true;
    }
}

/** Ephemeral normalized input passed to a server-side provider adapter. */
final readonly class ProviderRequest
{
    public const ATTACHMENT_ROLES = ['reference_image', 'reference_video', 'reference_audio', 'source_video', 'source_audio'];

    public function __construct(
        public string $modelId,
        public string $prompt,
        public array $attachments = [],
        public array $options = [],
    ) {
        if (!preg_match('/^[a-z0-9][a-z0-9._:-]{2,127}$/i', $modelId)) {
            throw new \InvalidArgumentException('Invalid model identifier.');
        }
        if (strlen($prompt) > 30000) throw new \InvalidArgumentException('Prompt is too large.');
        if (count($attachments) > 20) throw new \InvalidArgumentException('Too many attachments.');
        $seen = [];
        foreach ($attachments as $attachment) {
            if (!is_array($attachment) || array_diff(array_keys($attachment), ['mediaId', 'role', 'mime', 'byteSize', 'sha256']) !== [] ||
                count($attachment) !== 5 || !is_string($attachment['mediaId'] ?? null) || !Support::isUuid($attachment['mediaId']) ||
                !is_string($attachment['role'] ?? null) || !in_array($attachment['role'], self::ATTACHMENT_ROLES, true) ||
                !is_string($attachment['mime'] ?? null) || !preg_match('#^[a-z0-9][a-z0-9.+-]*/[a-z0-9][a-z0-9.+-]*$#', $attachment['mime']) ||
                !is_int($attachment['byteSize'] ?? null) || $attachment['byteSize'] < 1 ||
                !is_string($attachment['sha256'] ?? null) || !preg_match('/^[a-f0-9]{64}$/i', $attachment['sha256'])) {
                throw new \InvalidArgumentException('Invalid provider attachment reference.');
            }
            if (isset($seen[$attachment['mediaId']])) throw new \InvalidArgumentException('Duplicate provider attachment reference.');
            $seen[$attachment['mediaId']] = true;
        }
    }
}

/** Provider-neutral result; error codes must be safe and contain no provider body. */
final readonly class ProviderOperation
{
    public const STATES = ['queued', 'processing', 'succeeded', 'failed', 'cancelled'];

    public function __construct(
        public string $operationId,
        public string $status,
        public array $result = [],
        public ?string $errorCode = null,
        public bool $retryable = false,
    ) {
        if (!Support::isUuid($operationId)) throw new \InvalidArgumentException('Invalid provider operation identifier.');
        if (!in_array($status, self::STATES, true)) throw new \InvalidArgumentException('Invalid provider operation state.');
        if ($errorCode !== null && !preg_match('/^[a-z][a-z0-9_]{1,63}$/', $errorCode)) {
            throw new \InvalidArgumentException('Invalid provider error code.');
        }
        if ($status !== 'failed' && ($errorCode !== null || $retryable)) {
            throw new \InvalidArgumentException('Only failed operations may carry retry information.');
        }
    }
}

/**
 * Server-only boundary for provider integrations. Implementations own their
 * credentials and must return normalized states without leaking raw responses.
 */
interface ProviderAdapter
{
    public function id(): string;

    /** @return list<ProviderModelCapabilities> */
    public function modelCapabilities(): array;

    public function submit(ProviderRequest $request, string $idempotencyKey): ProviderOperation;

    public function poll(string $operationId): ProviderOperation;

    public function cancel(string $operationId): ProviderOperation;
}

/** Fail-closed model routing; one model can be owned by exactly one adapter. */
final class ProviderRegistry
{
    /** @var array<string, ProviderAdapter> */
    private array $byModel = [];
    /** @var array<string, ProviderModelCapabilities> */
    private array $capabilitiesByModel = [];

    /** @param list<ProviderAdapter> $adapters */
    public function __construct(array $adapters)
    {
        foreach ($adapters as $adapter) {
            if (!$adapter instanceof ProviderAdapter || !preg_match('/^[a-z][a-z0-9_-]{1,31}$/', $adapter->id())) {
                throw new \InvalidArgumentException('Invalid provider adapter registration.');
            }
            foreach ($adapter->modelCapabilities() as $capabilities) {
                if (!$capabilities instanceof ProviderModelCapabilities) throw new \InvalidArgumentException('Invalid provider model registration.');
                $modelId = $capabilities->modelId;
                if (isset($this->byModel[$modelId])) throw new \InvalidArgumentException('Model is registered by multiple providers.');
                $this->byModel[$modelId] = $adapter;
                $this->capabilitiesByModel[$modelId] = $capabilities;
            }
        }
    }

    public function forModel(string $modelId): ProviderAdapter
    {
        if (!isset($this->byModel[$modelId])) throw new ApiError(422, 'No enabled provider supports this model.');
        return $this->byModel[$modelId];
    }

    /** Reject unsupported inputs before the adapter can submit a paid request. */
    public function validateRequest(ProviderRequest $request): ProviderAdapter
    {
        $adapter = $this->forModel($request->modelId);
        if (!$this->capabilitiesByModel[$request->modelId]->accepts($request)) {
            throw new ApiError(422, 'This model does not support the requested attachment combination.');
        }
        return $adapter;
    }

    /** @return list<string> */
    public function enabledModelIds(): array
    {
        return array_keys($this->byModel);
    }
}
