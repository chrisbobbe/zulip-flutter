/// Probe: drive the real API bindings against a live Zulip dev server.
///
/// Not part of the normal test suite; needs a dev server at [realmUrl].
/// Run with:
///   flutter test --no-pub test/api/live_server_probe.dart \
///     --dart-define=ZULIP_API_KEY=...
library;

// This probe reports what the live server said; printing is its whole point.
// ignore_for_file: avoid_print

import 'package:checks/checks.dart';
import 'package:http/http.dart' as http;
import 'package:test/scaffolding.dart';

import 'package:zulip/api/core.dart';
import 'package:zulip/api/model/narrow.dart';
import 'package:zulip/api/route/messages.dart';
import 'package:zulip/api/route/realm.dart';
import 'package:zulip/api/route/users.dart';

final realmUrl = Uri.parse('http://zulip.vm:9991');

const email = 'iago@zulip.com';
const apiKey = String.fromEnvironment('ZULIP_API_KEY');

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

void main() {
  test('getServerSettings', () async {
    final result = await getServerSettings(connect());
    print('server ${result.zulipVersion}, feature level ${result.zulipFeatureLevel}');
    print('realm "${result.realmName}" at ${result.realmUrl}');
    check(result.zulipFeatureLevel).isGreaterThan(0);
  });

  test('getOwnUser', () async {
    final result = await getOwnUser(await connectVersioned());
    print('self user id: ${result.userId}');
    check(result.userId).isGreaterThan(0);
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
    final self = await getOwnUser(connection);

    final sendResult = await sendMessage(connection,
      destination: DmDestination(userIds: [self.userId]),
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
