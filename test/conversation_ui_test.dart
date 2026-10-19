import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/chat_widgets.dart';
import 'package:mahila_mitr/floral_widgets.dart';
import 'package:mahila_mitr/notes_widgets.dart';
import 'support/ui_preview.dart';

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('unread note cards keep the content private', (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        theme: previewTheme(),
        home: Scaffold(
            body: MomentCard(note: {
          'style': 'bloom',
          'body': 'Private content',
          'opened_at': null,
          'created_at': '2026-10-17T09:00:00Z'
        }, onOpen: () => opened = true))));
    expect(find.text('Private content'), findsNothing);
    await tester.tap(find.text('Open your note'));
    expect(opened, isTrue);
  });
  testWidgets('composer blocks empty notes and previews without sending',
      (tester) async {
    final controller = TextEditingController();
    var sent = 0;
    await tester.pumpWidget(MaterialApp(
        theme: previewTheme(),
        home: Scaffold(
            body: AppPage(children: [
          MomentComposer(
              controller: controller,
              style: 'bloom',
              onStyleChanged: (_) {},
              onSend: () => sent++,
              busy: false,
              senderName: 'Your partner')
        ]))));
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send note'));
    expect(button.onPressed, isNull);
    await tester.enterText(
        find.byType(TextField), 'You make ordinary days feel special.');
    await tester.ensureVisible(find.text('Preview note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview note'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteReadingSheet), findsOneWidget);
    expect(sent, 0);
    expect(find.text('You make ordinary days feel special.'), findsWidgets);
    await tester.tap(find.byTooltip('Close note'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Send note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send note'));
    expect(sent, 1);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  for (final scale in [1.0, 1.8]) {
    testWidgets('long floral notes and chat fit narrow screens at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: previewTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: NoteReadingSheet(
                  design: noteDesign['bloom']!,
                  message:
                      '${List.filled(30, 'A gentle reminder that you are loved.').join('\n')}\nThe very last line.',
                  fromName: 'Someone who cares'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scroll.position.maxScrollExtent, greaterThan(0));
      scroll.position.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(MaterialApp(
          theme: previewTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: ChatMessageBubble(
                      body:
                          'Taking a slower day today. Could we talk a little later?',
                      outgoing: false,
                      status: true,
                      replyBody: 'Of course, I am here whenever you need.',
                      time: '10:42 AM',
                      onReply: () {},
                      onOptions: () {})))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('chat composer blocks whitespace and sending duplicates',
      (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    var sent = 0;
    Widget app(bool sending) => MaterialApp(
        theme: previewTheme(),
        home: Scaffold(
            bottomNavigationBar: ChatComposer(
                controller: controller,
                focusNode: focus,
                sending: sending,
                onSend: () => sent++)));
    await tester.pumpWidget(app(false));
    await tester.enterText(find.byType(TextField), '   ');
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Send message'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextField), 'Hello');
    await tester.pump();
    await tester.tap(find.byTooltip('Send message'));
    expect(sent, 1);
    await tester.pumpWidget(app(true));
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Send message'))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
  testWidgets('render floral chat and note previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final controller = TextEditingController();
    final focus = FocusNode();
    await tester.pumpWidget(MaterialApp(
        theme: previewTheme(),
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                appBar: AppBar(title: const Text('Your private room')),
                body: FloralBackdrop(
                    dense: true,
                    child:
                        ListView(padding: const EdgeInsets.all(16), children: [
                      const Center(
                          child: Text('TODAY',
                              style: TextStyle(
                                  fontSize: 10, color: AppPalette.muted))),
                      const SizedBox(height: 22),
                      ChatMessageBubble(
                          body: 'Can you pick up dinner on your way home?',
                          outgoing: false,
                          time: '10:42 AM',
                          onReply: () {},
                          onOptions: () {}),
                      const SizedBox(height: 14),
                      ChatMessageBubble(
                          body: 'Yes. I’ll be home around seven.',
                          outgoing: true,
                          time: '10:44 AM',
                          onReply: () {},
                          onOptions: () {}),
                      const Align(
                          alignment: Alignment.centerRight,
                          child: Text('Read · 59m left',
                              style: TextStyle(
                                  fontSize: 10, color: AppPalette.muted))),
                      const SizedBox(height: 20),
                      ChatMessageBubble(
                          body: 'Feeling good',
                          outgoing: false,
                          status: true,
                          time: '10:45 AM',
                          onReply: () {},
                          onOptions: () {}),
                    ])),
                bottomNavigationBar: ChatComposer(
                    controller: controller,
                    focusNode: focus,
                    sending: false,
                    onMood: () {},
                    onSend: () {})))));
    await tester.pumpAndSettle();
    await capturePreview(tester, key, 'floral-chat');
    for (final entry in noteDesign.entries) {
      final noteKey = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: previewTheme(),
        home: RepaintBoundary(
            key: noteKey,
            child: Scaffold(
                body: NoteReadingSheet(
              design: entry.value,
              message:
                  'I booked our table for Saturday at seven.\n\nLet’s leave our phones at home this time. I want to hear all about your week.',
              fromName: 'Ananya',
              createdAt: '2026-10-19T09:00:00Z',
            ))),
      ));
      await tester.pumpAndSettle();
      await capturePreview(tester, noteKey, 'note-${entry.key}');
      if (entry.key == 'bloom') {
        await capturePreview(tester, noteKey, 'floral-note');
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    focus.dispose();
  });
}
