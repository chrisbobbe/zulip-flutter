import 'package:json_annotation/json_annotation.dart';

import '../core.dart';
import '../model/model.dart';

part 'drafts.g.dart';

/// https://zulip.com/api/get-drafts
Future<GetDraftsResult> getDrafts(ApiConnection connection) {
  return connection.get('getDrafts', GetDraftsResult.fromJson, 'drafts', null);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class GetDraftsResult {
  final int count;
  final List<Draft> drafts;

  GetDraftsResult({
    required this.count,
    required this.drafts,
  });

  factory GetDraftsResult.fromJson(Map<String, dynamic> json) =>
    _$GetDraftsResultFromJson(json);

  Map<String, dynamic> toJson() => _$GetDraftsResultToJson(this);
}

/// https://zulip.com/api/create-drafts
Future<CreateDraftsResult> createDrafts(ApiConnection connection, {
  required List<DraftData> drafts,
}) {
  return connection.post('createDrafts', CreateDraftsResult.fromJson, 'drafts', {
    'drafts': drafts,
  });
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CreateDraftsResult {
  /// The new drafts' IDs, in the order the drafts were passed.
  final List<int> ids;

  CreateDraftsResult({
    required this.ids,
  });

  factory CreateDraftsResult.fromJson(Map<String, dynamic> json) =>
    _$CreateDraftsResultFromJson(json);

  Map<String, dynamic> toJson() => _$CreateDraftsResultToJson(this);
}

/// https://zulip.com/api/edit-draft
Future<void> editDraft(ApiConnection connection, {
  required int draftId,
  required DraftData draft,
}) {
  return connection.patch('editDraft', (_) {}, 'drafts/$draftId', {
    'draft': draft,
  });
}

/// https://zulip.com/api/delete-draft
Future<void> deleteDraft(ApiConnection connection, {
  required int draftId,
}) {
  return connection.delete('deleteDraft', (_) {}, 'drafts/$draftId', {});
}
