import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotice/src/account_api.dart';
import 'package:hotice/src/account_credits.dart';
import 'package:hotice/src/state.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('cloud project upload waits for project-specific consent',
      (tester) async {
    final store = HotIceStore()..signInDemo('creator@example.com');
    addTearDown(store.dispose);
    final id = store.addProject('Private short film');
    final requests = <http.Request>[];
    var saved = false;
    final api = AccountApi(
        baseUrl: 'https://api.example.com',
        tokenStore: _Tokens(),
        client: _Client((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(
                jsonEncode({
                  'projects': saved
                      ? [
                          {
                            'id': id,
                            'title': 'Private short film',
                            'revision': 1,
                            'updated_at': '2026-11-01 00:00:00'
                          }
                        ]
                      : []
                }),
                200);
          }
          if (request.method == 'PUT') {
            saved = true;
            return http.Response(jsonEncode({'revision': 1}), 200);
          }
          if (request.method == 'DELETE') {
            return http.Response(jsonEncode({'deleted': true}), 200);
          }
          throw StateError(
              'Unexpected request ${request.method} ${request.url}');
        }));
    addTearDown(api.dispose);

    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AccountsPage(
                store: store,
                accountApi: api,
                authenticatedEmail: 'creator@example.com'))));
    await tester.ensureVisible(find.text('Review and save this project'));
    await tester.tap(find.text('Review and save this project'));
    await tester.pumpAndSettle();
    expect(find.text('Save this project to HOTICE cloud?'), findsOneWidget);
    expect(
        find.textContaining('Source files, media bytes, reference filenames'),
        findsOneWidget);
    expect(requests, isEmpty);

    await tester.tap(find.text('Keep on this device'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty);
    expect(store.cloudRevision(id), 0);

    await tester.ensureVisible(find.text('Review and save this project'));
    await tester.tap(find.text('Review and save this project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save selected project'));
    await tester.pumpAndSettle();
    expect(requests.map((request) => request.method), ['GET', 'PUT', 'GET']);
    expect(store.cloudRevision(id), 1);
    expect(
        find.text(
            'Cloud copy saved. Your device project remains available offline.'),
        findsOneWidget);
    expect(find.byTooltip('Delete cloud copy'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'Cloud controls should fit a 360px phone viewport.');
  });

  testWidgets(
      'a newer remote revision blocks overwrite and preserves the local project',
      (tester) async {
    final store = HotIceStore()..signInDemo('creator@example.com');
    addTearDown(store.dispose);
    final id = store.addProject('Keep local edits');
    store.markCloudRevision(id, 3);
    var putCount = 0;
    final api = AccountApi(
        baseUrl: 'https://api.example.com',
        tokenStore: _Tokens(),
        client: _Client((request) async {
          if (request.method == 'GET')
            return http.Response(
                jsonEncode({
                  'projects': [
                    {
                      'id': id,
                      'title': 'Keep local edits',
                      'revision': 4,
                      'updated_at': '2026-11-01 00:00:00'
                    }
                  ]
                }),
                200);
          if (request.method == 'PUT') putCount++;
          return http.Response(jsonEncode({'revision': 5}), 200);
        }));
    addTearDown(api.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AccountsPage(
                store: store,
                accountApi: api,
                authenticatedEmail: 'creator@example.com'))));
    await tester.ensureVisible(find.text('Review and save this project'));
    await tester.tap(find.text('Review and save this project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save selected project'));
    await tester.pumpAndSettle();
    expect(putCount, 0);
    expect(store.cloudRevision(id), 3);
    expect(find.textContaining('This cloud project changed elsewhere.'),
        findsOneWidget);
  });
}

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
        Stream.value(utf8.encode(response.body)), response.statusCode,
        headers: response.headers);
  }
}
