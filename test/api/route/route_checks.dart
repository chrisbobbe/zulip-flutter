import 'package:checks/checks.dart';
import 'package:zulip/api/model/model.dart';
import 'package:zulip/api/route/channels.dart';
import 'package:zulip/api/route/drafts.dart';
import 'package:zulip/api/route/messages.dart';
import 'package:zulip/api/route/realm.dart';
import 'package:zulip/api/route/saved_snippets.dart';

extension SendMessageResultChecks on Subject<SendMessageResult> {
  Subject<int> get id => has((e) => e.id, 'id');
}

extension GetDraftsResultChecks on Subject<GetDraftsResult> {
  Subject<int> get count => has((e) => e.count, 'count');
  Subject<List<Draft>> get drafts => has((e) => e.drafts, 'drafts');
}

extension CreateDraftsResultChecks on Subject<CreateDraftsResult> {
  Subject<List<int>> get ids => has((e) => e.ids, 'ids');
}

extension CreateSavedSnippetResultChecks on Subject<CreateSavedSnippetResult> {
  Subject<int> get savedSnippetId => has((e) => e.savedSnippetId, 'savedSnippetId');
}

extension GetServerSettingsResultChecks on Subject<GetServerSettingsResult> {
  Subject<Uri> get realmUrl => has((e) => e.realmUrl, 'realmUrl');
}

extension GetChannelTopicsEntryChecks on Subject<GetChannelTopicsEntry> {
  Subject<int> get maxId => has((e) => e.maxId, 'maxId');
  Subject<TopicName> get name => has((e) => e.name, 'name');
}

// TODO add similar extensions for other classes in api/route/*.dart
