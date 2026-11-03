import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/account_api.dart';
import 'package:hotice/src/projects_generation.dart';
import 'package:hotice/src/state.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets(
    'native mock dry run sends only confirmed scene text and safely retries after restart',
    (tester) async {
      final store = HotIceStore()..signInDemo('creator@example.com');
      addTearDown(store.dispose);
      final projectId = store.addProject('Aurora short');
      store.addAvatar(
        'Nova',
        'Cinematic',
        identityNotes: 'private actor identity detail',
      );
      final requests = <http.Request>[];
      var failFirstSubmission = true;
      final api = AccountApi(
        baseUrl: 'https://api.example.com',
        tokenStore: _Tokens(),
        client: _Client((request) async {
          requests.add(request);
          if (request.url.path == '/v1/me') {
            return http.Response(
              jsonEncode({
                'mockGeneration': {'enabled': true, 'credits': 20}
              }),
              200,
            );
          }
          if (request.url.path == '/v1/jobs/quote') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body.keys, ['request']);
            expect(body['request'], {
              'modelId': 'hotice.mock.video.v1',
              'prompt': 'A lone astronaut beneath the aurora',
            });
            return http.Response(
              jsonEncode({
                'quoteToken': 'short-lived-quote',
                'modelId': 'hotice.mock.video.v1',
                'credits': 5,
                'expiresAt': DateTime.now()
                    .add(const Duration(minutes: 3))
                    .toUtc()
                    .toIso8601String(),
              }),
              200,
            );
          }
          if (request.url.path == '/v1/jobs') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body.keys.toSet(), {'quoteToken', 'request'});
            expect(body['request'], {
              'modelId': 'hotice.mock.video.v1',
              'prompt': 'A lone astronaut beneath the aurora',
            });
            expect(body.toString(), isNot(contains('Nova')));
            expect(body.toString(), isNot(contains('identity')));
            expect(request.headers['idempotency-key'], isNotNull);
            if (failFirstSubmission) {
              failFirstSubmission = false;
              throw const SocketException('simulated network loss after send');
            }
            return http.Response(
              jsonEncode({'job': _job}),
              201,
            );
          }
          if (request.method == 'GET' && request.url.path == '/v1/jobs') {
            return http.Response(
                jsonEncode({
                  'jobs': [_job]
                }),
                200);
          }
          throw StateError('Unexpected ${request.method} ${request.url.path}');
        }),
      );
      addTearDown(api.dispose);

      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenerationPage(
              store: store,
              accountApi: api,
              authenticatedEmail: 'creator@example.com',
              authenticatedUserId: 'creator-user-123',
              initialProjectId: projectId,
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Describe your shot'),
        'A lone astronaut beneath the aurora',
      );
      await tester.ensureVisible(find.text('Check mock queue availability'));
      await tester.tap(find.text('Check mock queue availability'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Server mock queue is available'),
          findsOneWidget);

      await tester.ensureVisible(find.text('Request simulated-credit quote'));
      await tester.tap(find.text('Request simulated-credit quote'));
      await tester.pumpAndSettle();
      expect(requests.map((request) => request.url.path), [
        '/v1/me',
        '/v1/jobs/quote',
      ]);
      expect(find.textContaining('5 simulated credits'), findsNWidgets(2));

      await tester.ensureVisible(find.text('Review and start mock dry run'));
      await tester.tap(find.text('Review and start mock dry run'));
      await tester.pumpAndSettle();
      expect(find.text('Start this mock dry run?'), findsOneWidget);
      expect(find.text('Keep local'), findsOneWidget);
      await tester.tap(find.text('Keep local'));
      await tester.pumpAndSettle();
      expect(store.pendingMockSubmissions, isEmpty);
      expect(
        requests.where((request) =>
            request.method == 'POST' && request.url.path == '/v1/jobs'),
        isEmpty,
        reason: 'Cancelling consent must not create or reserve a job.',
      );
      await tester.ensureVisible(find.text('Review and start mock dry run'));
      await tester.tap(find.text('Review and start mock dry run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm mock dry run'));
      await tester.pumpAndSettle();
      expect(store.pendingMockSubmissions, hasLength(1));
      final originalKey = store.pendingMockSubmissions.single.idempotencyKey;
      expect(find.textContaining('same retry ID is saved locally'),
          findsOneWidget);

      // Simulate app restart: restore only the encrypted local snapshot, then
      // quote again and send the same operation key. This must not duplicate a
      // server-side credit reserve if the first response was lost.
      final restoredStore = HotIceStore()
        ..restoreLocalSnapshot(store.exportLocalSnapshot());
      addTearDown(restoredStore.dispose);
      expect(restoredStore.pendingMockSubmissions.single.idempotencyKey,
          originalKey);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GenerationPage(
              store: restoredStore,
              accountApi: api,
              authenticatedEmail: 'creator@example.com',
              authenticatedUserId: 'creator-user-123',
              initialProjectId: projectId,
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Quote & retry'));
      await tester.tap(find.text('Quote & retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 simulated credits'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Review and start mock dry run'));
      await tester.tap(find.text('Review and start mock dry run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm mock dry run'));
      await tester.pumpAndSettle();

      final submissions = requests
          .where((request) =>
              request.method == 'POST' && request.url.path == '/v1/jobs')
          .toList();
      expect(submissions, hasLength(2));
      expect(
        submissions.map((request) => request.headers['idempotency-key']),
        [originalKey, originalKey],
      );
      expect(restoredStore.pendingMockSubmissions, isEmpty);
      expect(find.textContaining('Mock job queued'), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'The dry-run workflow should fit narrow phone widths.');
    },
  );
}

const _job = {
  'id': '12345678-1234-4234-8234-123456789abc',
  'modelId': 'hotice.mock.video.v1',
  'status': 'queued',
  'attempts': 0,
  'maxAttempts': 3,
  'reservedCredits': 5,
  'chargedCredits': 0,
  'result': null,
  'errorCode': null,
  'createdAt': '2026-11-03 00:00:00',
};

class _Tokens implements AccountTokenStore {
  @override
  Future<String?> read() async => List<String>.filled(64, 'a').join();

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}

class _Client extends http.BaseClient {
  _Client(this.handler);
  final Future<http.Response> Function(http.Request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
    );
  }
}
