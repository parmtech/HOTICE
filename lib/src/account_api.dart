import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AccountUser {
  const AccountUser({required this.id, required this.email});

  final String id;
  final String email;

  factory AccountUser.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic> ||
        user['id'] is! String ||
        user['email'] is! String) {
      throw const AccountApiException(
        'The account service returned an invalid response.',
      );
    }
    return AccountUser(
      id: user['id'] as String,
      email: user['email'] as String,
    );
  }
}

abstract interface class AccountTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureAccountTokenStore implements AccountTokenStore {
  SecureAccountTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'hotice.account.session.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class AccountApiException implements Exception {
  const AccountApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class CloudProjectSummary {
  const CloudProjectSummary({
    required this.id,
    required this.title,
    required this.revision,
    required this.updatedAt,
  });
  final String id;
  final String title;
  final int revision;
  final DateTime? updatedAt;
}

class CloudProjectSnapshot extends CloudProjectSummary {
  const CloudProjectSnapshot({
    required super.id,
    required super.title,
    required super.revision,
    required super.updatedAt,
    required this.document,
  });
  final Map<String, dynamic> document;
}

class MockGenerationAvailability {
  const MockGenerationAvailability({required this.enabled, this.credits});
  final bool enabled;
  final int? credits;
}

class MockGenerationQuote {
  const MockGenerationQuote({
    required this.token,
    required this.credits,
    required this.expiresAt,
  });
  final String token;
  final int credits;
  final DateTime expiresAt;
}

class MockGenerationJob {
  const MockGenerationJob({
    required this.id,
    required this.status,
    required this.attempts,
    required this.maxAttempts,
    required this.reservedCredits,
    required this.chargedCredits,
    required this.createdAt,
    this.errorCode,
    this.result,
  });
  final String id;
  final String status;
  final int attempts;
  final int maxAttempts;
  final int reservedCredits;
  final int chargedCredits;
  final DateTime? createdAt;
  final String? errorCode;
  final Map<String, dynamic>? result;

  static MockGenerationJob fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const AccountApiException(
          'The job service returned an invalid job.');
    }
    final id = value['id'];
    final status = value['status'];
    int? integer(String key) {
      final raw = value[key];
      return raw is int ? raw : int.tryParse('$raw');
    }

    final attempts = integer('attempts');
    final maxAttempts = integer('maxAttempts');
    final reserved = integer('reservedCredits');
    final charged = integer('chargedCredits');
    const states = {'queued', 'processing', 'succeeded', 'failed', 'cancelled'};
    if (id is! String ||
        !RegExp(r'^[a-f0-9-]{36}$', caseSensitive: false).hasMatch(id) ||
        status is! String ||
        !states.contains(status) ||
        attempts == null ||
        maxAttempts == null ||
        reserved == null ||
        charged == null ||
        attempts < 0 ||
        maxAttempts < 1 ||
        reserved < 0 ||
        charged < 0 ||
        (value['result'] != null && value['result'] is! Map<String, dynamic>) ||
        (value['errorCode'] != null && value['errorCode'] is! String)) {
      throw const AccountApiException(
          'The job service returned an invalid job.');
    }
    return MockGenerationJob(
      id: id,
      status: status,
      attempts: attempts,
      maxAttempts: maxAttempts,
      reservedCredits: reserved,
      chargedCredits: charged,
      createdAt: DateTime.tryParse('${value['createdAt'] ?? ''}'),
      errorCode: value['errorCode'] as String?,
      result: value['result'] as Map<String, dynamic>?,
    );
  }
}

/// Shared authenticated HOTICE account API client. No API key is stored here;
/// the optional base URL is a public deployment address supplied at build time.
class AccountApi {
  AccountApi({
    String? baseUrl,
    http.Client? client,
    AccountTokenStore? tokenStore,
  })  : _baseUrl =
            (baseUrl ?? const String.fromEnvironment('HOTICE_API_BASE_URL'))
                .trim(),
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _tokenStore = tokenStore ?? SecureAccountTokenStore();

  final String _baseUrl;
  final http.Client _client;
  final bool _ownsClient;
  final AccountTokenStore _tokenStore;

  bool get isConfigured => _validBaseUri() != null;

  Uri? _validBaseUri() {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }
    final local = uri.host == 'localhost' || uri.host == '127.0.0.1';
    if (uri.scheme != 'https' && !(local && uri.scheme == 'http')) return null;
    return uri;
  }

  Future<AccountUser?> restoreSession() async {
    String? token;
    try {
      token = await _tokenStore.read();
    } on Exception {
      // Secure-storage plugin initialization can fail on unsupported or test
      // platforms. Keep guest mode available; never fall back to plain storage.
      return null;
    }
    if (token == null || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) {
      if (token != null) await _tokenStore.clear();
      return null;
    }
    try {
      return AccountUser.fromJson(
        await _request('GET', '/v1/me', token: token),
      );
    } on AccountApiException catch (error) {
      // A network/service outage must not destroy a still-valid local session.
      // Only an explicit authorization rejection invalidates the stored token.
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _tokenStore.clear();
        return null;
      }
      rethrow;
    }
  }

  Future<AccountUser> signIn(String email, String password) async {
    final response = await _request(
      'POST',
      '/v1/auth/login',
      body: {'email': email.trim(), 'password': password},
    );
    final token = response['accessToken'];
    if (token is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) {
      throw const AccountApiException(
        'The account service returned an invalid sign-in response.',
      );
    }
    final user = AccountUser.fromJson(
      await _request('GET', '/v1/me', token: token),
    );
    await _tokenStore.write(token);
    return user;
  }

  Future<void> register(String email, String password) async {
    await _request(
      'POST',
      '/v1/auth/register',
      body: {'email': email.trim(), 'password': password},
    );
  }

  Future<void> resendVerification(String email) async {
    await _request(
      'POST',
      '/v1/auth/verification/resend',
      body: {'email': email.trim()},
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await _request(
      'POST',
      '/v1/auth/password-reset/request',
      body: {'email': email.trim()},
    );
  }

  Future<void> signOut() async {
    String? token;
    try {
      token = await _tokenStore.read();
    } on Exception {
      await _tokenStore.clear();
      return;
    }
    try {
      if (token != null) {
        await _request('POST', '/v1/auth/logout', token: token);
      }
    } finally {
      await _tokenStore.clear();
    }
  }

  /// Reads only projects belonging to the authenticated account. Calling this
  /// method does not enable background sync or upload local work.
  Future<List<CloudProjectSummary>> listCloudProjects() async {
    final data = await _authorizedRequest('GET', '/v1/projects');
    final rows = data['projects'];
    if (rows is! List) {
      throw const AccountApiException(
        'The cloud service returned an invalid project list.',
      );
    }
    return rows.map((row) {
      if (row is! Map<String, dynamic>) {
        throw const AccountApiException(
          'The cloud service returned an invalid project.',
        );
      }
      final id = row['id'];
      final title = row['title'];
      final revision = row['revision'];
      if (id is! String ||
          title is! String ||
          int.tryParse('$revision') == null) {
        throw const AccountApiException(
          'The cloud service returned an invalid project.',
        );
      }
      return CloudProjectSummary(
        id: id,
        title: title,
        revision: int.parse('$revision'),
        updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
      );
    }).toList(growable: false);
  }

  Future<CloudProjectSnapshot> getCloudProject(String id) async {
    final data = await _authorizedRequest(
      'GET',
      '/v1/projects/${_projectId(id)}',
    );
    final row = data['project'];
    if (row is! Map<String, dynamic> ||
        row['id'] is! String ||
        row['title'] is! String ||
        row['document'] is! Map<String, dynamic> ||
        int.tryParse('${row['revision']}') == null) {
      throw const AccountApiException(
        'The cloud service returned an invalid project.',
      );
    }
    return CloudProjectSnapshot(
      id: row['id'] as String,
      title: row['title'] as String,
      revision: int.parse('${row['revision']}'),
      updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
      document: row['document'] as Map<String, dynamic>,
    );
  }

  Future<int> saveCloudProject({
    required String id,
    required String title,
    required int expectedRevision,
    required Map<String, dynamic> document,
  }) async {
    if (expectedRevision < 0) {
      throw const AccountApiException('Invalid cloud revision.');
    }
    final data = await _authorizedRequest(
      'PUT',
      '/v1/projects/${_projectId(id)}',
      body: {
        'title': title,
        'expectedRevision': expectedRevision,
        'document': document,
      },
    );
    final revision = int.tryParse('${data['revision']}');
    if (revision == null || revision < 1) {
      throw const AccountApiException(
        'The cloud service returned an invalid save result.',
      );
    }
    return revision;
  }

  Future<void> deleteCloudProject(String id) async {
    await _authorizedRequest('DELETE', '/v1/projects/${_projectId(id)}');
  }

  Future<MockGenerationAvailability> getMockGenerationAvailability() async {
    final data = await _authorizedRequest('GET', '/v1/me');
    final mock = data['mockGeneration'];
    if (mock is! Map<String, dynamic> || mock['enabled'] is! bool) {
      throw const AccountApiException(
        'The service did not return mock-generation availability.',
      );
    }
    final rawCredits = mock['credits'];
    final credits = rawCredits == null
        ? null
        : rawCredits is int
            ? rawCredits
            : int.tryParse('$rawCredits');
    if (rawCredits != null && (credits == null || credits < 0)) {
      throw const AccountApiException(
          'The service returned invalid credit data.');
    }
    return MockGenerationAvailability(
      enabled: mock['enabled'] as bool,
      credits: credits,
    );
  }

  Future<MockGenerationQuote> quoteMockGeneration(String prompt) async {
    final text = prompt.trim();
    if (text.isEmpty || text.length > 2000) {
      throw const AccountApiException('Scene text must be 1–2000 characters.');
    }
    final data = await _authorizedRequest(
      'POST',
      '/v1/jobs/quote',
      body: {
        'request': {'modelId': 'hotice.mock.video.v1', 'prompt': text},
      },
    );
    final token = data['quoteToken'];
    final credits = data['credits'];
    final modelId = data['modelId'];
    final expiresAt = DateTime.tryParse('${data['expiresAt'] ?? ''}');
    if (token is! String ||
        token.isEmpty ||
        token.length > 4096 ||
        credits is! int ||
        credits < 0 ||
        modelId != 'hotice.mock.video.v1' ||
        expiresAt == null ||
        !expiresAt.isAfter(DateTime.now())) {
      throw const AccountApiException(
          'The job service returned an invalid quote.');
    }
    return MockGenerationQuote(
      token: token,
      credits: credits,
      expiresAt: expiresAt,
    );
  }

  /// Reusing the same local intent key makes an uncertain network retry
  /// idempotent, including after app restart. The server checks replays before
  /// consuming a quote, so an existing job is returned without a second reserve.
  Future<MockGenerationJob> submitMockGeneration({
    required String quoteToken,
    required String prompt,
    required String idempotencyKey,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9._~:-]{16,128}$').hasMatch(idempotencyKey)) {
      throw const AccountApiException('Invalid generation request identifier.');
    }
    if (quoteToken.isEmpty || quoteToken.length > 4096) {
      throw const AccountApiException('Request a fresh mock-generation quote.');
    }
    final text = prompt.trim();
    if (text.isEmpty || text.length > 2000) {
      throw const AccountApiException('Scene text must be 1–2000 characters.');
    }
    final data = await _authorizedRequest(
      'POST',
      '/v1/jobs',
      headers: {'Idempotency-Key': idempotencyKey},
      body: {
        'quoteToken': quoteToken,
        'request': {'modelId': 'hotice.mock.video.v1', 'prompt': text},
      },
    );
    return MockGenerationJob.fromJson(data['job']);
  }

  Future<List<MockGenerationJob>> listMockGenerationJobs() async {
    final data = await _authorizedRequest('GET', '/v1/jobs');
    final jobs = data['jobs'];
    if (jobs is! List || jobs.length > 50) {
      throw const AccountApiException(
          'The job service returned an invalid job list.');
    }
    return jobs.map(MockGenerationJob.fromJson).toList(growable: false);
  }

  Future<MockGenerationJob> cancelMockGenerationJob(String id) async {
    final data = await _authorizedRequest(
      'POST',
      '/v1/jobs/${_projectId(id)}/cancel',
    );
    return MockGenerationJob.fromJson(data['job']);
  }

  String _projectId(String id) {
    if (!RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
      caseSensitive: false,
    ).hasMatch(id)) {
      throw const AccountApiException('Invalid project identifier.');
    }
    return id;
  }

  Future<Map<String, dynamic>> _authorizedRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    String? token;
    try {
      token = await _tokenStore.read();
    } on Exception {
      throw const AccountApiException(
        'Secure account session is unavailable. Sign in again.',
      );
    }
    if (token == null || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(token)) {
      throw const AccountApiException(
        'Sign in to use cloud projects.',
        statusCode: 401,
      );
    }
    return _request(
      method,
      path,
      token: token,
      body: body,
      headers: headers,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final base = _validBaseUri();
    if (base == null) {
      throw const AccountApiException(
        'Account sign-in is not configured. Install a build connected to the secure HOTICE service.',
      );
    }
    final uri = base.resolve(path);
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };
    if (body != null) requestHeaders['Content-Type'] = 'application/json';
    if (token != null) requestHeaders['Authorization'] = 'Bearer $token';
    late http.Response response;
    try {
      final payload = body == null ? null : jsonEncode(body);
      final request = http.Request(method, uri)..headers.addAll(requestHeaders);
      // Do not forward a bearer token across an unexpected API redirect.
      request.followRedirects = false;
      if (payload != null) request.body = payload;
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 30));
      response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 15));
    } on Exception {
      throw const AccountApiException(
        'Could not reach the HOTICE account service. Check your connection and try again.',
      );
    }
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const FormatException();
      decoded = value;
    } on FormatException {
      throw const AccountApiException(
        'The HOTICE account service returned an invalid response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final serverMessage = decoded['error'];
      final safeMessage = serverMessage is String && serverMessage.length <= 160
          ? serverMessage
          : 'Account request failed. Please try again.';
      throw AccountApiException(safeMessage, statusCode: response.statusCode);
    }
    return decoded;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
