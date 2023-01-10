// ignore_for_file: non_constant_identifier_names

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import '../core.dart';
import '../model/model.dart';

part 'messages.g.dart';

/// https://zulip.com/api/get-messages
Future<GetMessagesResult> getMessages(ApiConnection connection, {
  required int num_before,
  required int num_after,
}) async {
  final data = await connection.get('messages', {
    // 'narrow': [], // TODO parametrize
    'anchor': 999999999, // TODO parametrize; needs raw for strings
    'num_before': num_before,
    'num_after': num_after,
  });
  return GetMessagesResult.fromJson(jsonDecode(data));
}

@JsonSerializable()
class GetMessagesResult {
  final int anchor;
  final bool found_newest;
  final bool found_oldest;
  final bool found_anchor;
  final bool history_limited;
  final List<Message> messages;

  GetMessagesResult({
    required this.anchor,
    required this.found_newest,
    required this.found_oldest,
    required this.found_anchor,
    required this.history_limited,
    required this.messages,
  });

  factory GetMessagesResult.fromJson(Map<String, dynamic> json) =>
      _$GetMessagesResultFromJson(json);

  Map<String, dynamic> toJson() => _$GetMessagesResultToJson(this);
}

// https://zulip.com/api/send-message#parameter-topic
const int kMaxTopicLength = 60;

/// https://zulip.com/api/send-message
// TODO currently only handles stream messages; fix
Future<SendMessageResult> sendMessage(
  ApiConnection connection, {
  required String content,
  required String topic,
}) async {
  final data = await connection.post('messages', {
    'type': 'stream', // TODO parametrize
    'to': 7, // TODO parametrize; this is `#test here`
    'topic': topic,
    'content': content,
  });
  return SendMessageResult.fromJson(jsonDecode(data));
}

@JsonSerializable()
class SendMessageResult {
  final int id;
  final String? deliver_at;

  SendMessageResult({
    required this.id,
    this.deliver_at,
  });

  factory SendMessageResult.fromJson(Map<String, dynamic> json) =>
      _$SendMessageResultFromJson(json);

  Map<String, dynamic> toJson() => _$SendMessageResultToJson(this);
}
