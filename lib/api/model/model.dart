import 'package:json_annotation/json_annotation.dart';

part 'model.g.dart';

/// As in [InitialSnapshot.customProfileFields].
///
/// https://zulip.com/api/register-queue#response
@JsonSerializable(fieldRename: FieldRename.snake)
class CustomProfileField {
  final int id;
  final int type; // TODO enum; also TODO(server-6) a value added
  final int order;
  final String name;
  final String hint;
  final String fieldData;
  final bool? displayInProfileSummary; // TODO(server-6)

  CustomProfileField({
    required this.id,
    required this.type,
    required this.order,
    required this.name,
    required this.hint,
    required this.fieldData,
    required this.displayInProfileSummary,
  });

  factory CustomProfileField.fromJson(Map<String, dynamic> json) =>
      _$CustomProfileFieldFromJson(json);

  Map<String, dynamic> toJson() => _$CustomProfileFieldToJson(this);
}

/// As in `subscriptions` in the initial snapshot.
@JsonSerializable(fieldRename: FieldRename.snake)
class Subscription {
  final int streamId;
  final String name;
  final String description;
  final String renderedDescription;
  final int dateCreated;
  final bool inviteOnly;

  // final List<int> subscribers; // we register with includeSubscribers false

  final bool? desktopNotifications;
  final bool? emailNotifications;
  final bool? wildcardMentionsNotify;
  final bool? pushNotifications;
  final bool? audibleNotifications;

  final bool pinToTop;

  final String emailAddress;

  final bool isMuted;

  // final bool? inHomeView; // deprecated; ignore

  // final bool? isAnnouncementOnly; // deprecated; ignore
  final bool? isWebPublic; // TODO(server-??): doc doesn't say when added

  final String color;

  final int streamPostPolicy; // TODO enum
  final int? messageRetentionDays;
  final bool historyPublicToSubscribers;

  final int? firstMessageId;
  final int? streamWeeklyTraffic;

  final int? canRemoveSubscribersGroupId; // TODO(server-6)

  Subscription({
    required this.streamId,
    required this.name,
    required this.description,
    required this.renderedDescription,
    required this.dateCreated,
    required this.inviteOnly,
    this.desktopNotifications,
    this.emailNotifications,
    this.wildcardMentionsNotify,
    this.pushNotifications,
    this.audibleNotifications,
    required this.pinToTop,
    required this.emailAddress,
    required this.isMuted,
    this.isWebPublic,
    required this.color,
    required this.streamPostPolicy,
    this.messageRetentionDays,
    required this.historyPublicToSubscribers,
    this.firstMessageId,
    this.streamWeeklyTraffic,
    this.canRemoveSubscribersGroupId,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionFromJson(json);

  Map<String, dynamic> toJson() => _$SubscriptionToJson(this);
}

/// A value parsed from JSON as either `null` or another value.
///
/// This can be used to represent JSON properties where absence, null, and some
/// other type are distinguished. For example, with the following field definition:
/// ```dart
///   JsonNullable<String>? name;
/// ```
/// a `name` value of `null` (as a Dart value) represents the `name` property
/// being absent in JSON; a value of `JsonNullable(null)` represents `'name': null`
/// in JSON; and a value of `JsonNullable("foo")` represents `'name': 'foo'` in JSON.
class JsonNullable<T> {
  const JsonNullable(this.value);
  final T? value;
}

JsonNullable<T>? readJsonNullable<T>(Map map, String key) {
  return map.containsKey(key) ? JsonNullable(map[key]) : null;
}

abstract class AvatarUrl {
  AvatarUrl();
  // Uri get(User user, int sizePhysicalPx); // add this when we need it

  factory AvatarUrl.fromMaybeJsonNullable(JsonNullable<String>? maybeJsonNullable) {
    if (maybeJsonNullable == null) {
      return FallbackAvatarUrl();
    }
    final JsonNullable(:value) = maybeJsonNullable;
    return value == null
      ? GravatarAvatarUrl(urlFromServer: value)
      : UploadedAvatarUrl(urlFromServer: value);
  }

  String? toJson();
}

class FallbackAvatarUrl extends AvatarUrl {
  FallbackAvatarUrl();

  @override
  String? toJson() => 'foo'; // TODO how??
}

class GravatarAvatarUrl extends AvatarUrl {
  GravatarAvatarUrl({this.urlFromServer});
  final String? urlFromServer;

  @override
  String? toJson() => 'foo'; // TODO how??
}

class UploadedAvatarUrl extends AvatarUrl {
  UploadedAvatarUrl({required this.urlFromServer});
  final String urlFromServer;

  @override
  String? toJson() => 'foo'; // TODO how??
}

/// As in the get-messages response.
///
/// https://zulip.com/api/get-messages#response
abstract class Message {
  @JsonKey(readValue: readJsonNullable<String>, fromJson: AvatarUrl.fromMaybeJsonNullable)
  final AvatarUrl avatarUrl;

  final String client;
  final String content;
  final String contentType;

  // final List<MessageEditHistory> editHistory; // TODO handle
  final int id;
  final bool isMeMessage;
  final int? lastEditTimestamp;

  // final List<Reaction> reactions; // TODO handle
  final int recipientId;
  final String senderEmail;
  final String senderFullName;
  final int senderId;
  final String senderRealmStr;
  final String subject; // TODO call it "topic" internally; also similar others
  // final List<string> submessages; // TODO handle
  final int timestamp;
  String get type;

  // final List<TopicLink> topicLinks; // TODO handle
  // final string type; // handled by runtime type of object
  final List<String> flags; // TODO enum
  final String? matchContent;
  final String? matchSubject;

  Message({
    required this.avatarUrl,
    required this.client,
    required this.content,
    required this.contentType,
    required this.id,
    required this.isMeMessage,
    this.lastEditTimestamp,
    required this.recipientId,
    required this.senderEmail,
    required this.senderFullName,
    required this.senderId,
    required this.senderRealmStr,
    required this.subject,
    required this.timestamp,
    required this.flags,
    this.matchContent,
    this.matchSubject,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    if (type == 'stream') return StreamMessage.fromJson(json);
    if (type == 'private') return PmMessage.fromJson(json);
    throw Exception("Message.fromJson: unexpected message type $type");
  }

  Map<String, dynamic> toJson();
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StreamMessage extends Message {
  @override
  @JsonKey(includeToJson: true)
  String get type => 'stream';

  final String displayRecipient;
  final int streamId;

  StreamMessage({
    required super.avatarUrl,
    required super.client,
    required super.content,
    required super.contentType,
    required super.id,
    required super.isMeMessage,
    super.lastEditTimestamp,
    required super.recipientId,
    required super.senderEmail,
    required super.senderFullName,
    required super.senderId,
    required super.senderRealmStr,
    required super.subject,
    required super.timestamp,
    required super.flags,
    super.matchContent,
    super.matchSubject,
    required this.displayRecipient,
    required this.streamId,
  });

  factory StreamMessage.fromJson(Map<String, dynamic> json) =>
      _$StreamMessageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$StreamMessageToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class PmRecipient {
  final int id;
  final String email;
  final String fullName;

  // final String? shortName; // obsolete, ignore
  // final bool? isMirrorDummy; // obsolete, ignore

  PmRecipient({required this.id, required this.email, required this.fullName});

  factory PmRecipient.fromJson(Map<String, dynamic> json) =>
      _$PmRecipientFromJson(json);

  Map<String, dynamic> toJson() => _$PmRecipientToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class PmMessage extends Message {
  @override
  @JsonKey(includeToJson: true)
  String get type => 'private';

  final List<PmRecipient> displayRecipient;

  PmMessage({
    required super.avatarUrl,
    required super.client,
    required super.content,
    required super.contentType,
    required super.id,
    required super.isMeMessage,
    super.lastEditTimestamp,
    required super.recipientId,
    required super.senderEmail,
    required super.senderFullName,
    required super.senderId,
    required super.senderRealmStr,
    required super.subject,
    required super.timestamp,
    required super.flags,
    super.matchContent,
    super.matchSubject,
    required this.displayRecipient,
  });

  factory PmMessage.fromJson(Map<String, dynamic> json) =>
      _$PmMessageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$PmMessageToJson(this);
}
