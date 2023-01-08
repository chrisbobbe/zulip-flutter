import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/route/messages.dart';

/// A compose box for writing a stream message.
// Possibly this would work well as a "persistent bottom sheet" defined by
// passing the bottomSheet param to Scaffold:
//   https://api.flutter.dev/flutter/material/Scaffold/bottomSheet.html
// That might make for a nice way to implement full-screen compose:
//   https://github.com/zulip/zulip-mobile/issues/4873
// It looks like the bottom-sheet API offers a mechanism to handle drag
// gestures, so one could e.g. drag a handle upward to make the compose box fill
// the screen.
//
// To investigate before using bottomSheet: A SafeArea in this position
// doesn't pad the bottom inset, because the ambient `MediaQueryData.padding`
// has `bottom: zero`. That happens because Scaffold zeros out the bottom
// padding with MediaQuery.of(context).removePadding(). It doesn't do that when
// you set `resizeToAvoidBottomInset: false` on the Scaffold…but why? And don't
// we want that to be true, so the Scaffold's body resizes when the keyboard
// appears?
class StreamComposeBox extends StatefulWidget {
  const StreamComposeBox({Key? key}) : super(key: key);

  @override
  State<StreamComposeBox> createState() => _StreamComposeBoxState();
}

class _StreamComposeBoxState extends State<StreamComposeBox> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.canvas,

      // Not sure what to choose here; 4 is AppBar's default.
      elevation: 4,

      child: SafeArea(
          // A non-ancestor (the app bar) pads the top inset. But no
          // need to prevent extra padding with `top: false`, because
          // Scaffold, which knows about the app bar, sets `body`'s
          // ambient `MediaQueryData.padding` to have `top: 0`:
          //   https://github.com/flutter/flutter/blob/3.7.0-1.2.pre/packages/flutter/lib/src/material/scaffold.dart#L2778

          minimum: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,

                // Give the topic- and message-input fields a special
                // InputDecorationTheme that other text fields won't want,
                // mainly because vertical whitespace is so expensive here.
                child: Theme(
                    data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                      // Hack: Shrink distance between the bottom of the input
                      // and the baseline of the supporting text so they read
                      // together. Really we want to decrease the Material
                      // library's hard-coded `subtextGap` from 8.0 to 2.0:
                      //   https://github.com/flutter/flutter/blob/3.7.0-1.2.pre/packages/flutter/lib/src/material/input_decorator.dart#L720
                      // Hack inspired by
                      //   https://stackoverflow.com/questions/64941217/how-do-i-remove-margin-above-error-text-in-textformfield
                      counterStyle: TextStyle(height: 0.5),
                      helperStyle: TextStyle(height: 0.5),
                      errorStyle: TextStyle(height: 0.5),

                      // Override the default, which is
                      // `EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 12.0)`; see
                      //   https://github.com/flutter/flutter/blob/3.7.0-1.2.pre/packages/flutter/lib/src/material/input_decorator.dart#L2360
                      // That's already adjusted for `isDense: true`, but we'd like
                      // to be even denser.
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),

                      isDense: true,
                      border: OutlineInputBorder(),
                    )),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                            maxLength: kMaxTopicLength,

                            // Extends InputDecorationTheme above
                            decoration: const InputDecoration(
                              label: Text('Topic'),

                              // https://api.flutter.dev/flutter/widgets/FormField/validator.html :
                              // > To create a field whose height is fixed regardless of
                              // > whether or not an error is displayed, […] set the
                              // > InputDecoration.helperText parameter to a space.
                              helperText: '\u200b', // U+200B ZERO WIDTH SPACE
                            )),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          // TODO find the right way to constrain height adaptively
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: TextFormField(
                              maxLines: null,

                              // Extends InputDecorationTheme above
                              decoration: InputDecoration(
                                suffixIcon: IconButton(
                                    icon: const Icon(Icons.send),
                                    onPressed: () {
                                      if (_formKey.currentState!.validate()) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text('Processing Data')));
                                      }
                                    }),

                                // TODO: fill in
                                label: Text('Message #stream > topic'),

                                // https://api.flutter.dev/flutter/widgets/FormField/validator.html :
                                // > To create a field whose height is fixed regardless of
                                // > whether or not an error is displayed, […] set the
                                // > InputDecoration.helperText parameter to a space.
                                helperText: '\u200b', // U+200B ZERO WIDTH SPACE
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  // The server accepts empty but puts "(deleted)"
                                  // for the contents, which isn't appropriate
                                  // for sending a new message. (It would be OK
                                  // for editing an existing message).
                                  return 'Message is empty.';
                                }
                                // TODO upload in progress
                                // TODO quote-and-reply in progress
                                return null;
                              }),
                        ),
                      ],
                    ))),
          )),
    );
  }
}
