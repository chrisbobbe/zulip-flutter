import 'package:flutter/material.dart';

import 'store.dart';
import '../model/autocomplete.dart';
import '../model/compose.dart';
import '../model/narrow.dart';
import 'compose_box.dart';

class ComposeAutocomplete extends StatefulWidget {
  const ComposeAutocomplete({
    super.key,
    required this.narrow,
    required this.controller,
    required this.focusNode,
    required this.fieldViewBuilder,
  });

  /// The message list's narrow.
  final Narrow narrow;

  final ComposeContentController controller;
  final FocusNode focusNode;
  final WidgetBuilder fieldViewBuilder;

  @override
  State<ComposeAutocomplete> createState() => _ComposeAutocompleteState();
}

class _ComposeAutocompleteState extends State<ComposeAutocomplete> {
  late RawAutocompleteController<MentionAutocompleteResult> _autocompleteController;
  MentionAutocompleteView? _viewModel; // TODO different autocomplete view types

  void _composeContentChanged() {
    _autocompleteController.selection = null;

    final newAutocompleteIntent = widget.controller.autocompleteIntent();
    if (newAutocompleteIntent != null) {
      final store = PerAccountStoreWidget.of(context);
      _viewModel ??= MentionAutocompleteView.init(store: store, narrow: widget.narrow)
        ..addListener(_viewModelChanged);
      _viewModel!.query = newAutocompleteIntent.query;
    } else {
      if (_viewModel != null) {
        _viewModel!.dispose(); // removes our listener
        _viewModel = null;
        _autocompleteController.options = [];
      }
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_composeContentChanged);
    _autocompleteController = RawAutocompleteController<MentionAutocompleteResult>();
  }

  @override
  void didUpdateWidget(covariant ComposeAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_composeContentChanged);
      widget.controller.addListener(_composeContentChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_composeContentChanged);
    _viewModel?.dispose(); // removes our listener
    super.dispose();
  }

  void _viewModelChanged() {
    setState((){
      _autocompleteController.options = _viewModel!.results.toList();
    });
  }

  void _onTapOption(MentionAutocompleteResult option) {
    _autocompleteController.selection = option; // dismisses list of options

    // Probably the same intent that brought up the option that was tapped.
    // If not, it still shouldn't be off by more than the time it takes
    // to compute the autocomplete results, which we do asynchronously.
    final intent = widget.controller.autocompleteIntent();
    if (intent == null) {
      return; // Shrug.
    }

    final store = PerAccountStoreWidget.of(context);
    final String replacementString;
    switch (option) {
      case UserMentionAutocompleteResult(:var userId):
        // TODO(i18n) language-appropriate space character; check active keyboard?
        //   (maybe handle centrally in `widget.controller`)
        replacementString = '${mention(store.users[userId]!, silent: intent.query.silent, users: store.users)} ';
      case WildcardMentionAutocompleteResult():
        replacementString = '[unimplemented]'; // TODO
      case UserGroupMentionAutocompleteResult():
        replacementString = '[unimplemented]'; // TODO
    }

    widget.controller.value = intent.textEditingValue.replaced(
      TextRange(
        start: intent.syntaxStart,
        end: intent.textEditingValue.selection.end),
      replacementString,
    );
  }

  Widget _buildItem(BuildContext _, int index) {
    final options = _autocompleteController.options as List<MentionAutocompleteResult>;
    final option = options[index];
    String label;
    switch (option) {
      case UserMentionAutocompleteResult(:var userId):
        // TODO avatar
        label = PerAccountStoreWidget.of(context).users[userId]!.fullName;
      case WildcardMentionAutocompleteResult():
        label = '[unimplemented]'; // TODO
      case UserGroupMentionAutocompleteResult():
        label = '[unimplemented]'; // TODO
    }
    return InkWell(
      onTap: () {
        _onTapOption(option);
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(label)));
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<MentionAutocompleteResult>(
      controller: _autocompleteController,
      focusNode: widget.focusNode,
      optionsViewOpenDirection: OptionsViewOpenDirection.up,
      optionsViewBuilder: (context, controller) {
        return Align(
          alignment: Alignment.bottomLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300), // TODO not hard-coded
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: controller.options.length,
                itemBuilder: _buildItem))));
      },
      // RawAutocomplete passes a FocusNode when it calls fieldViewBuilder.
      // We ignore it; we've opted out of having RawAutocomplete create it for us.
      fieldViewBuilder: (context, _) => widget.fieldViewBuilder(context),
    );
  }
}
