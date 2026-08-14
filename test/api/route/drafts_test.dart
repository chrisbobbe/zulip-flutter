import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:test/scaffolding.dart';
import 'package:zulip/api/model/model.dart';
import 'package:zulip/api/route/drafts.dart';

import '../../example_data.dart' as eg;
import '../../stdlib_checks.dart';
import '../fake_api.dart';
import '../model/model_checks.dart';
import 'route_checks.dart';

void main() {
  group('getDrafts', () {
    test('smoke', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: GetDraftsResult(count: 1, drafts: [
          eg.draft(id: 17, type: DraftType.channel, to: [123],
            topic: const TopicName('sync drafts'), content: "let's sync",
            timestamp: 1595479019),
        ]).toJson());
        final result = await getDrafts(connection);
        check(connection.takeRequests()).single.isA<http.Request>()
          ..method.equals('GET')
          ..url.path.equals('/api/v1/drafts')
          ..url.queryParameters.isEmpty();
        check(result).count.equals(1);
        check(result).drafts.single
          ..id.equals(17)
          ..type.equals(DraftType.channel)
          ..to.deepEquals([123])
          ..topic.equals(const TopicName('sync drafts'))
          ..content.equals("let's sync")
          ..timestamp.equals(1595479019);
      });
    });

    test('unaddressed draft', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: GetDraftsResult(count: 1, drafts: [
          eg.draft(type: DraftType.unaddressed, to: <int>[]),
        ]).toJson());
        final result = await getDrafts(connection);
        check(result).drafts.single
          ..type.equals(DraftType.unaddressed)
          ..to.isEmpty();
      });
    });
  });

  group('createDrafts', () {
    /// The value of the request's `drafts` parameter, JSON-decoded.
    Object? draftsParam(http.Request request) =>
      jsonDecode(request.bodyFields['drafts']!);

    test('smoke', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: CreateDraftsResult(ids: [1, 2]).toJson());
        final result = await createDrafts(connection, drafts: [
          eg.draftData(type: DraftType.channel, to: [123],
            topic: const TopicName('questions'), content: 'first'),
          eg.draftData(type: DraftType.dm, to: [4, 10], content: 'second'),
        ]);
        final request = connection.takeRequests().single as http.Request;
        check(request)
          ..method.equals('POST')
          ..url.path.equals('/api/v1/drafts');
        check(draftsParam(request)).jsonEquals([
          {'type': 'stream', 'to': [123], 'topic': 'questions',
            'content': 'first'},
          {'type': 'private', 'to': [4, 10], 'topic': '',
            'content': 'second'},
        ]);
        check(result).ids.deepEquals([1, 2]);
      });
    });

    test('unaddressed draft sends empty type', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: CreateDraftsResult(ids: [1]).toJson());
        await createDrafts(connection, drafts: [
          eg.draftData(type: DraftType.unaddressed, to: <int>[], content: 'whatever'),
        ]);
        final request = connection.takeRequests().single as http.Request;
        check(draftsParam(request)).jsonEquals([
          {'type': '', 'to': <int>[], 'topic': '', 'content': 'whatever'},
        ]);
      });
    });

    test('timestamp sent when given', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: CreateDraftsResult(ids: [1]).toJson());
        await createDrafts(connection, drafts: [
          eg.draftData(content: 'foo', timestamp: 1595479019),
        ]);
        final request = connection.takeRequests().single as http.Request;
        check(draftsParam(request)).isA<List<dynamic>>().single
          .isA<Map<String, dynamic>>()['timestamp'].equals(1595479019);
      });
    });

    // The server's request schema forbids unknown keys,
    // so a draft object that still had its ID would be rejected.
    test('no id sent for a draft from the server', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: CreateDraftsResult(ids: [1]).toJson());
        await createDrafts(connection,
          drafts: [eg.draft(id: 17, content: 'foo').toData()]);
        final request = connection.takeRequests().single as http.Request;
        check(draftsParam(request)).isA<List<dynamic>>().single
          .isA<Map<String, dynamic>>().not((it) => it.containsKey('id'));
      });
    });
  });

  group('editDraft', () {
    test('smoke', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: {});
        await editDraft(connection, draftId: 17, draft: eg.draftData(
          type: DraftType.channel, to: [123],
          topic: const TopicName('questions'), content: 'edited'));
        final request = connection.takeRequests().single as http.Request;
        check(request)
          ..method.equals('PATCH')
          ..url.path.equals('/api/v1/drafts/17');
        check(jsonDecode(request.bodyFields['draft']!)).jsonEquals({
          'type': 'stream', 'to': [123], 'topic': 'questions',
          'content': 'edited',
        });
      });
    });
  });

  group('deleteDraft', () {
    test('smoke', () {
      return FakeApiConnection.with_((connection) async {
        connection.prepare(json: {});
        await deleteDraft(connection, draftId: 17);
        check(connection.takeRequests()).single.isA<http.Request>()
          ..method.equals('DELETE')
          ..url.path.equals('/api/v1/drafts/17')
          ..bodyFields.isEmpty();
      });
    });
  });
}
