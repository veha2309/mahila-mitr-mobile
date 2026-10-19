import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/notes_widgets.dart';
import 'support/ui_preview.dart';

void main() {
  setUpAll(loadPreviewFonts);
  for (final role in ['owner', 'partner']) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 1.8]) {
        testWidgets('Moments $role fits $width at $scale', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final controller = TextEditingController();
          final boundary = GlobalKey();
          var opened = false;
          var chatted = false;
          var sent = false;
          var style = 'letter';
          await tester.pumpWidget(MaterialApp(
            theme: previewTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                    body: SafeArea(
                  child: StatefulBuilder(
                      builder: (context, update) => AppPage(children: [
                            const AppPageHeading(eyebrow: '', title: 'Moments'),
                            MomentsConnectionCard(
                                name: 'Ananya', onOpen: () => chatted = true),
                            const SizedBox(height: 22),
                            if (role == 'owner') ...[
                              const Text('Notes · 1 unread',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 14),
                              MomentCard(
                                  fromName: 'Ananya',
                                  note: const {
                                    'style': 'bloom',
                                    'body': 'Hidden until opened',
                                    'opened_at': null,
                                    'created_at': '2026-10-19T09:00:00Z',
                                  },
                                  onOpen: () => opened = true),
                              MomentCard(
                                  fromName: 'Ananya',
                                  note: const {
                                    'style': 'letter',
                                    'body':
                                        'I left your lunch in the fridge. See you tonight.',
                                    'opened_at': '2026-10-18T10:00:00Z',
                                    'created_at': '2026-10-18T09:00:00Z',
                                  },
                                  onOpen: () {}),
                            ] else
                              MomentComposer(
                                  controller: controller,
                                  style: style,
                                  busy: false,
                                  senderName: 'Ananya',
                                  onStyleChanged: (value) =>
                                      update(() => style = value),
                                  onSend: () => sent = true),
                          ])),
                ))),
          ));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open your private chat'));
          expect(chatted, isTrue);
          if (role == 'owner') {
            expect(find.text('Hidden until opened'), findsNothing);
            await tester.ensureVisible(find.text('Open your note'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Open your note'));
            expect(opened, isTrue);
          } else {
            await tester.enterText(find.byType(TextField),
                'I left your lunch in the fridge. See you tonight.');
            await tester
                .ensureVisible(find.byKey(const ValueKey('note-style-star')));
            await tester.tap(find.byKey(const ValueKey('note-style-star')));
            await tester.pumpAndSettle();
            expect(style, 'star');
            expect(controller.text,
                'I left your lunch in the fridge. See you tonight.');
            await tester.ensureVisible(find.text('Send note'));
            await tester.tap(find.text('Send note'));
            expect(sent, isTrue);
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final scroll =
              tester.state<ScrollableState>(find.byType(Scrollable).first);
          scroll.position.jumpTo(0);
          await tester.pumpAndSettle();
          if (width == 390 && scale == 1) {
            await capturePreview(tester, boundary,
                role == 'owner' ? 'moments-inbox' : 'moments-compose');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          controller.dispose();
        });
      }
    }
  }
}
