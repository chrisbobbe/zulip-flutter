import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/model/model.dart';
import '../model/content.dart';
import '../model/message_list.dart';
import '../model/narrow.dart';
import '../model/store.dart';
import 'app.dart';
import 'content.dart';
import 'sticky_header.dart';

class MessageList extends StatefulWidget {
  const MessageList({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  Narrow get narrow => const AllMessagesNarrow(); // TODO specify in widget

  MessageListView? model;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = PerAccountStoreWidget.of(context);
    if (model != null && model!.store == store) {
      // We already have a model, and it's for the right store.
      return;
    }
    // Otherwise, set up the model.  Dispose of any old model.
    model?.dispose();
    _initModel(store);
  }

  @override
  void dispose() {
    model?.dispose();
    super.dispose();
  }

  void _initModel(PerAccountStore store) {
    model = MessageListView.init(store: store, narrow: narrow);
    model!.addListener(_modelChanged);
    model!.fetch();
  }

  void _modelChanged() {
    setState(() {
      // The actual state lives in the [MessageListView] model.
      // This method was called because that just changed.
    });
  }

  @override
  Widget build(BuildContext context) {
    assert(model != null);
    if (!model!.fetched) return const Center(child: CircularProgressIndicator());

    return DefaultTextStyle(
        // TODO figure out text color -- web is supposedly hsl(0deg 0% 20%),
        //   but seems much darker than that
        style: const TextStyle(color: Color.fromRGBO(0, 0, 0, 1)),
        child: ColoredBox(
            color: Colors.white,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _buildListView(context)))));
  }

  Widget _buildListView(context) {
    final length = model!.messages.length;
    assert(model!.contents.length == length);
    return StickyHeaderListView.builder(
        itemCount: length,
        // Setting reverse: true means the scroll starts at the bottom.
        // Flipping the indexes (in itemBuilder) means the start/bottom
        // has the latest messages.
        // This works great when we want to start from the latest.
        // TODO handle scroll starting at first unread, or link anchor
        reverse: true,
        // Dismiss compose-box keyboard when dragging up or down.
        // TODO refine with custom implementation, e.g.:
        //   - Only dismiss when scrolling up to older messages
        //   - Show keyboard (focus compose box) on overscroll up to new
        //     messages (OverscrollNotification)
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemBuilder: (context, i) => MessageItem(
            trailing: i == 0 ? null : const SizedBox(height: 11),
            message: model!.messages[length - 1 - i],
            content: model!.contents[length - 1 - i]));
  }
}

class MessageItem extends StatelessWidget {
  const MessageItem({
    super.key,
    required this.message,
    required this.content,
    this.trailing,
  });

  final Message message;
  final ZulipContent content;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // TODO recipient headings depend on narrow

    final store = PerAccountStoreWidget.of(context);

    Color highlightBorderColor;
    Color restBorderColor;
    Widget recipientHeader;
    if (message is StreamMessage) {
      final msg = (message as StreamMessage);
      final subscription = store.subscriptions[msg.stream_id];
      highlightBorderColor = colorForStream(subscription);
      restBorderColor = _kStreamMessageBorderColor;
      recipientHeader = StreamTopicRecipientHeader(
          message: msg, streamColor: highlightBorderColor);
    } else if (message is PmMessage) {
      final msg = (message as PmMessage);
      highlightBorderColor = _kPmRecipientHeaderColor;
      restBorderColor = _kPmRecipientHeaderColor;
      recipientHeader = PmRecipientHeader(message: msg);
    } else {
      throw Exception("impossible message type: ${message.runtimeType}");
    }

    // This 3px border seems to accurately reproduce something much more
    // complicated on web, involving CSS box-shadow; see comment below.
    final recipientBorder = BorderSide(color: highlightBorderColor, width: 3);
    final restBorder = BorderSide(color: restBorderColor, width: 1);
    var borderDecoration = ShapeDecoration(
        // Web actually uses, for stream messages, a slightly lighter border at
        // right than at bottom and in the recipient header: black 10% alpha,
        // vs. 88% lightness.  Assume that's an accident.
        shape: Border(
            left: recipientBorder, bottom: restBorder, right: restBorder));

    return StickyHeader(
        header: recipientHeader,
        content: Column(children: [
          DecoratedBox(
              decoration: borderDecoration,
              child: MessageWithSender(message: message, content: content)),
          if (trailing != null) trailing!,
        ]));

    // Web handles the left-side recipient marker in a funky way:
    //   box-shadow: inset 3px 0px 0px -1px #c2726a, -1px 0px 0px 0px #c2726a;
    // (where the color is the stream color.)  That is, it's a pair of
    // box shadows.  One of them is inset.
    //
    // At attempt at a literal translation might look like this:
    //
    // DecoratedBox(
    //     decoration: ShapeDecoration(shadows: [
    //       BoxShadow(offset: Offset(3, 0), spreadRadius: -1, color: highlightBorderColor),
    //       BoxShadow(offset: Offset(-1, 0), color: highlightBorderColor),
    //     ], shape: Border.fromBorderSide(BorderSide.none)),
    //     child: MessageWithSender(message: message)),
    //
    // But CSS `box-shadow` seems to not apply under the item itself, while
    // Flutter's BoxShadow does.
  }
}

Color colorForStream(Subscription? subscription) {
  final color = subscription?.color;
  if (color == null) return const Color(0x00c2c2c2);
  assert(RegExp(r'^#[0-9a-f]{6}$').hasMatch(color));
  return Color(0xff000000 | int.parse(color.substring(1), radix: 16));
}

class StreamTopicRecipientHeader extends StatelessWidget {
  const StreamTopicRecipientHeader(
      {super.key, required this.message, required this.streamColor});

  final StreamMessage message;
  final Color streamColor;

  @override
  Widget build(BuildContext context) {
    final streamName = message.display_recipient; // TODO get from stream data
    final topic = message.subject;
    final contrastingColor =
        ThemeData.estimateBrightnessForColor(streamColor) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return ColoredBox(
        color: _kStreamMessageBorderColor,
        child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
          RecipientHeaderChevronContainer(
              color: streamColor,
              // TODO globe/lock icons for web-public and private streams
              child:
                  Text(streamName, style: TextStyle(color: contrastingColor))),
          Padding(
              // Web has padding 9, 3, 3, 2 here; but 5px is the chevron.
              padding: const EdgeInsets.fromLTRB(4, 3, 3, 2),
              child: Text(topic,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          // TODO topic links?
          // Then web also has edit/resolve/mute buttons. Skip those for mobile.
        ]));
  }
}

final _kStreamMessageBorderColor =
    const HSLColor.fromAHSL(1, 0, 0, 0.88).toColor();

class PmRecipientHeader extends StatelessWidget {
  const PmRecipientHeader({super.key, required this.message});

  final PmMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: Alignment.centerLeft,
        child: RecipientHeaderChevronContainer(
            color: _kPmRecipientHeaderColor,
            child: const Text("Private message", // TODO PM recipient headers
                style: TextStyle(color: Colors.white))));
  }
}

final _kPmRecipientHeaderColor =
    const HSLColor.fromAHSL(1, 0, 0, 0.27).toColor();

/// A widget with the distinctive chevron-tailed shape in Zulip recipient headers.
class RecipientHeaderChevronContainer extends StatelessWidget {
  const RecipientHeaderChevronContainer(
      {super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const chevronLength = 5.0;
    const recipientBorderShape = BeveledRectangleBorder(
        borderRadius: BorderRadius.only(
            topRight: Radius.elliptical(chevronLength, double.infinity),
            bottomRight: Radius.elliptical(chevronLength, double.infinity)));
    return Container(
        decoration: ShapeDecoration(color: color, shape: recipientBorderShape),
        padding: const EdgeInsets.only(right: chevronLength),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 3), child: child));
  }
}

/// A Zulip message, showing the sender's name and avatar.
class MessageWithSender extends StatelessWidget {
  const MessageWithSender(
      {super.key, required this.message, required this.content});

  final Message message;
  final ZulipContent content;

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);

    final avatarUrl = message.avatar_url == null // TODO get from user data
        ? null // TODO handle computing gravatars
        : rewriteImageUrl(message.avatar_url!, store.account);
    final avatar = (avatarUrl == null)
        ? const SizedBox.shrink()
        : Image.network(
            avatarUrl,
            filterQuality: FilterQuality.medium,
          );

    final time = _kMessageTimestampFormat
        .format(DateTime.fromMillisecondsSinceEpoch(1000 * message.timestamp));

    // TODO clean up this layout, by less precisely imitating web
    return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 3, left: 8, right: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(3, 6, 11, 0),
              child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(4))),
                  width: 35,
                  height: 35,
                  child: avatar)),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const SizedBox(height: 3),
                Text(message.sender_full_name, // TODO get from user data
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                MessageContent(content: content),
              ])),
          Container(
              width: 80,
              padding: const EdgeInsets.only(top: 4, right: 2),
              alignment: Alignment.topRight,
              child: Text(time, style: _kMessageTimestampStyle))
        ]));
  }
}

// TODO web seems to ignore locale in formatting time, but we could do better
final _kMessageTimestampFormat = DateFormat('h:mm aa', 'en_US');

// TODO this seems to come out lighter than on web
final _kMessageTimestampStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: const HSLColor.fromAHSL(0.4, 0, 0, 0.2).toColor());
