/// Probe: drive the real API bindings against a live Zulip dev server.
///
/// Not part of the normal test suite; needs a dev server at [realmUrl],
/// which `tools/cloud-dev-server` starts in a cloud session.  Run with:
///
///   flutter test --no-pub test/api/live_server_probe.dart
library;

// This probe reports what the live server said; printing is its whole point.
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:test/scaffolding.dart';

import 'package:zulip/api/core.dart';
import 'package:zulip/api/model/narrow.dart';
import 'package:zulip/api/route/messages.dart';
import 'package:zulip/api/route/realm.dart';

final realmUrl = Uri.parse('http://localhost:9991');

const email = 'iago@zulip.com';

/// Log in the way only a dev server allows, without a password.
///
/// Sent with plain `package:http`, not a binding: this route exists only
/// in a development environment, so `lib/api` has nothing for it.
Future<({String apiKey, int userId})> devFetchApiKey() async {
  final response = await http.post(
    realmUrl.replace(path: '/api/v1/dev_fetch_api_key'),
    body: {'username': email});
  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return (apiKey: json['api_key'] as String, userId: json['user_id'] as int);
}

void main() {
  late String apiKey;
  late int selfUserId;

  setUpAll(() async {
    final credentials = await devFetchApiKey();
    apiKey = credentials.apiKey;
    selfUserId = credentials.userId;
  });

  ApiConnection connect({int? zulipFeatureLevel}) {
    return ApiConnection(
      realmUrl: realmUrl,
      zulipFeatureLevel: zulipFeatureLevel,
      email: email,
      apiKey: apiKey,
      client: http.Client(),
      useBinding: false);
  }

  /// A connection whose feature level matches the live server's.
  Future<ApiConnection> connectVersioned() async {
    final settings = await getServerSettings(connect());
    return connect(zulipFeatureLevel: settings.zulipFeatureLevel);
  }

  test('dev_fetch_api_key', () {
    print('self user id: $selfUserId');
    check(selfUserId).isGreaterThan(0);
  });

  test('getServerSettings', () async {
    final result = await getServerSettings(connect());
    print('server ${result.zulipVersion}, feature level ${result.zulipFeatureLevel}');
    print('realm "${result.realmName}" at ${result.realmUrl}');
    check(result.zulipFeatureLevel).isGreaterThan(0);
  });

  test('getMessages', () async {
    final result = await getMessages(await connectVersioned(),
      narrow: [], anchor: AnchorCode.newest, numBefore: 5, numAfter: 0,
      allowEmptyTopicName: true);
    print('fetched ${result.messages.length} messages; newest:');
    print('  ${result.messages.last.senderFullName}: '
      '${result.messages.last.content}');
    check(result.messages).isNotEmpty();
  });

  test('sendMessage then read it back', () async {
    final connection = await connectVersioned();

    final sendResult = await sendMessage(connection,
      destination: DmDestination(userIds: [selfUserId]),
      content: 'Sent through the Dart API bindings.',
      readBySender: true);
    print('sent message id ${sendResult.id}');

    final getResult = await getMessages(connection,
      narrow: [ApiNarrowMessageId(sendResult.id)],
      anchor: NumericAnchor(sendResult.id), numBefore: 0, numAfter: 0,
      allowEmptyTopicName: true);
    check(getResult.messages.single.id).equals(sendResult.id);
    print('read back: ${getResult.messages.single.content}');
  });
}
