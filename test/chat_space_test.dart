import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/chat_widgets.dart';

void main() {
  for (final scale in [1.0, 1.8]) {
    testWidgets(
        'compact chat keeps reply and mood controls usable with keyboard at $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      final controller = TextEditingController();
      final focus = FocusNode();
      var replies = 0;
      var options = 0;
      var moods = 0;
      var sends = 0;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: Scaffold(
            body: Column(children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(10), children: [
            ChatMessageBubble(
                body: 'See you at seven.',
                outgoing: false,
                time: '18:30',
                onReply: () => replies++,
                onOptions: () => options++),
          ])),
          ChatComposer(
              controller: controller,
              focusNode: focus,
              sending: false,
              onSend: () => sends++,
              onMood: () => moods++),
        ])),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See you at seven.'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('See you at seven.'));
      await tester.pumpAndSettle();
      expect(replies, 1);
      await tester.longPress(find.text('See you at seven.'));
      expect(options, 1);
      await tester.tap(find.byTooltip('Share mood'));
      expect(moods, 1);
      await tester.enterText(find.byType(TextField), 'Okay');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      expect(sends, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    });
  }
}
