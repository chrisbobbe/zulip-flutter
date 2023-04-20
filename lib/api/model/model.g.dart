// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomProfileField _$CustomProfileFieldFromJson(Map<String, dynamic> json) =>
    CustomProfileField(
      id: json['id'] as int,
      type: json['type'] as int,
      order: json['order'] as int,
      name: json['name'] as String,
      hint: json['hint'] as String,
      fieldData: json['field_data'] as String,
      displayInProfileSummary: json['display_in_profile_summary'] as bool?,
    );

Map<String, dynamic> _$CustomProfileFieldToJson(CustomProfileField instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'order': instance.order,
      'name': instance.name,
      'hint': instance.hint,
      'field_data': instance.fieldData,
      'display_in_profile_summary': instance.displayInProfileSummary,
    };

Subscription _$SubscriptionFromJson(Map<String, dynamic> json) => Subscription(
      streamId: json['stream_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      renderedDescription: json['rendered_description'] as String,
      dateCreated: json['date_created'] as int,
      inviteOnly: json['invite_only'] as bool,
      desktopNotifications: json['desktop_notifications'] as bool?,
      emailNotifications: json['email_notifications'] as bool?,
      wildcardMentionsNotify: json['wildcard_mentions_notify'] as bool?,
      pushNotifications: json['push_notifications'] as bool?,
      audibleNotifications: json['audible_notifications'] as bool?,
      pinToTop: json['pin_to_top'] as bool,
      emailAddress: json['email_address'] as String,
      isMuted: json['is_muted'] as bool,
      isWebPublic: json['is_web_public'] as bool?,
      color: json['color'] as String,
      streamPostPolicy: json['stream_post_policy'] as int,
      messageRetentionDays: json['message_retention_days'] as int?,
      historyPublicToSubscribers: json['history_public_to_subscribers'] as bool,
      firstMessageId: json['first_message_id'] as int?,
      streamWeeklyTraffic: json['stream_weekly_traffic'] as int?,
      canRemoveSubscribersGroupId:
          json['can_remove_subscribers_group_id'] as int?,
    );

Map<String, dynamic> _$SubscriptionToJson(Subscription instance) =>
    <String, dynamic>{
      'stream_id': instance.streamId,
      'name': instance.name,
      'description': instance.description,
      'rendered_description': instance.renderedDescription,
      'date_created': instance.dateCreated,
      'invite_only': instance.inviteOnly,
      'desktop_notifications': instance.desktopNotifications,
      'email_notifications': instance.emailNotifications,
      'wildcard_mentions_notify': instance.wildcardMentionsNotify,
      'push_notifications': instance.pushNotifications,
      'audible_notifications': instance.audibleNotifications,
      'pin_to_top': instance.pinToTop,
      'email_address': instance.emailAddress,
      'is_muted': instance.isMuted,
      'is_web_public': instance.isWebPublic,
      'color': instance.color,
      'stream_post_policy': instance.streamPostPolicy,
      'message_retention_days': instance.messageRetentionDays,
      'history_public_to_subscribers': instance.historyPublicToSubscribers,
      'first_message_id': instance.firstMessageId,
      'stream_weekly_traffic': instance.streamWeeklyTraffic,
      'can_remove_subscribers_group_id': instance.canRemoveSubscribersGroupId,
    };

StreamMessage _$StreamMessageFromJson(Map<String, dynamic> json) =>
    StreamMessage(
      avatarUrl: AvatarUrl.fromMaybeJsonNullable(
          readJsonNullable(json, 'avatar_url') as JsonNullable<String>?),
      client: json['client'] as String,
      content: json['content'] as String,
      contentType: json['content_type'] as String,
      id: json['id'] as int,
      isMeMessage: json['is_me_message'] as bool,
      lastEditTimestamp: json['last_edit_timestamp'] as int?,
      recipientId: json['recipient_id'] as int,
      senderEmail: json['sender_email'] as String,
      senderFullName: json['sender_full_name'] as String,
      senderId: json['sender_id'] as int,
      senderRealmStr: json['sender_realm_str'] as String,
      subject: json['subject'] as String,
      timestamp: json['timestamp'] as int,
      flags: (json['flags'] as List<dynamic>).map((e) => e as String).toList(),
      matchContent: json['match_content'] as String?,
      matchSubject: json['match_subject'] as String?,
      displayRecipient: json['display_recipient'] as String,
      streamId: json['stream_id'] as int,
    );

Map<String, dynamic> _$StreamMessageToJson(StreamMessage instance) =>
    <String, dynamic>{
      'avatar_url': instance.avatarUrl,
      'client': instance.client,
      'content': instance.content,
      'content_type': instance.contentType,
      'id': instance.id,
      'is_me_message': instance.isMeMessage,
      'last_edit_timestamp': instance.lastEditTimestamp,
      'recipient_id': instance.recipientId,
      'sender_email': instance.senderEmail,
      'sender_full_name': instance.senderFullName,
      'sender_id': instance.senderId,
      'sender_realm_str': instance.senderRealmStr,
      'subject': instance.subject,
      'timestamp': instance.timestamp,
      'flags': instance.flags,
      'match_content': instance.matchContent,
      'match_subject': instance.matchSubject,
      'type': instance.type,
      'display_recipient': instance.displayRecipient,
      'stream_id': instance.streamId,
    };

PmRecipient _$PmRecipientFromJson(Map<String, dynamic> json) => PmRecipient(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
    );

Map<String, dynamic> _$PmRecipientToJson(PmRecipient instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'full_name': instance.fullName,
    };

PmMessage _$PmMessageFromJson(Map<String, dynamic> json) => PmMessage(
      avatarUrl: AvatarUrl.fromMaybeJsonNullable(
          readJsonNullable(json, 'avatar_url') as JsonNullable<String>?),
      client: json['client'] as String,
      content: json['content'] as String,
      contentType: json['content_type'] as String,
      id: json['id'] as int,
      isMeMessage: json['is_me_message'] as bool,
      lastEditTimestamp: json['last_edit_timestamp'] as int?,
      recipientId: json['recipient_id'] as int,
      senderEmail: json['sender_email'] as String,
      senderFullName: json['sender_full_name'] as String,
      senderId: json['sender_id'] as int,
      senderRealmStr: json['sender_realm_str'] as String,
      subject: json['subject'] as String,
      timestamp: json['timestamp'] as int,
      flags: (json['flags'] as List<dynamic>).map((e) => e as String).toList(),
      matchContent: json['match_content'] as String?,
      matchSubject: json['match_subject'] as String?,
      displayRecipient: (json['display_recipient'] as List<dynamic>)
          .map((e) => PmRecipient.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PmMessageToJson(PmMessage instance) => <String, dynamic>{
      'avatar_url': instance.avatarUrl,
      'client': instance.client,
      'content': instance.content,
      'content_type': instance.contentType,
      'id': instance.id,
      'is_me_message': instance.isMeMessage,
      'last_edit_timestamp': instance.lastEditTimestamp,
      'recipient_id': instance.recipientId,
      'sender_email': instance.senderEmail,
      'sender_full_name': instance.senderFullName,
      'sender_id': instance.senderId,
      'sender_realm_str': instance.senderRealmStr,
      'subject': instance.subject,
      'timestamp': instance.timestamp,
      'flags': instance.flags,
      'match_content': instance.matchContent,
      'match_subject': instance.matchSubject,
      'type': instance.type,
      'display_recipient': instance.displayRecipient,
    };
