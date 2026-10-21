import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/app_navigation.dart';
import 'package:mahila_mitr/partner_dashboard.dart';

import 'support/ui_preview.dart';

void main() {
  setUpAll(loadPreviewFonts);

  PartnerDashboard dashboard(
      {bool connected = true,
      String partnerName = 'Ananya',
      DateTime? start,
      DateTime? end,
      DateTime? next,
      void Function(String)? onAction}) {
    void action(String name) => onAction?.call(name);
    return PartnerDashboard(
      today: DateTime(2026, 10, 21, 12),
      name: 'Vedant',
      partnerName: partnerName,
      connected: connected,
      periodStart: start,
      periodEnd: end,
      nextPeriod: next,
      reflectionCount: 3,
      onProfile: () => action('profile'),
      onConnect: () => action('connect'),
      onMessages: () => action('messages'),
      onNote: () => action('note'),
      onInsights: () => action('calendar'),
      onReflections: () => action('reflections'),
      onConnection: () => action('connection'),
      onNickname: () => action('nickname'),
    );
  }

  Widget app(Widget child, {double scale = 1, GlobalKey? boundary}) =>
      MaterialApp(
        theme: previewTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: SafeArea(child: AppPage(children: [child])),
              bottomNavigationBar: AppNavigation(index: 0, onSelected: (_) {}),
            )),
      );

  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 1.8]) {
      for (final connected in [true, false]) {
        testWidgets('partner Home fits $width at $scale, connected=$connected',
            (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final boundary = GlobalKey();
          await tester.pumpWidget(app(
              dashboard(
                connected: connected,
                partnerName: scale > 1 ? 'Ananya Priyadarshini' : 'Ananya',
                start: DateTime(2026, 10, 19),
              ),
              scale: scale,
              boundary: boundary));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (connected) {
            expect(find.text('Period in progress'), findsOneWidget);
            expect(find.text('Day 3 of this period'), findsOneWidget);
            expect(find.text('End this period'), findsNothing);
            expect(find.text('Log your period'), findsNothing);
            await tester.ensureVisible(find.text('Shared reflections'));
          } else {
            expect(find.text('Connect with your partner'), findsOneWidget);
            expect(find.text('Shared cycle'), findsNothing);
            expect(find.text('Write a note'), findsNothing);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (width == 390 && scale == 1) {
            final scrollable =
                tester.state<ScrollableState>(find.byType(Scrollable).first);
            scrollable.position.jumpTo(0);
            await tester.pumpAndSettle();
            await capturePreview(tester, boundary,
                connected ? 'partner-home' : 'partner-unlinked');
            if (connected) {
              scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
              await tester.pumpAndSettle();
              await capturePreview(tester, boundary, 'partner-home-details');
            }
          }
        });
      }
    }
  }

  testWidgets(
      'connected dashboard routes each action to its controller callback',
      (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(app(dashboard(onAction: actions.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Profile and settings for Vedant'));
    await tester.tap(find.byTooltip('Connection settings'));
    for (final label in [
      'Edit nickname',
      'View calendar',
      'Messages',
      'Write a note',
      'Shared reflections'
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
    }
    expect(actions, [
      'profile',
      'connection',
      'nickname',
      'calendar',
      'messages',
      'note',
      'reflections'
    ]);
  });

  testWidgets('unlinked dashboard opens pairing and hides stale shared data',
      (tester) async {
    final actions = <String>[];
    await tester.pumpWidget(app(dashboard(
        connected: false,
        start: DateTime(2026, 10, 19),
        onAction: actions.add)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Connect with your partner'));
    await tester.tap(find.text('Connect with your partner'));
    expect(actions, ['connect']);
    expect(find.text('Period in progress'), findsNothing);
    expect(find.text('Shared reflections'), findsNothing);
  });

  testWidgets(
      'cycle summary handles no history, estimates, stale timing, and future entries',
      (tester) async {
    await tester.pumpWidget(app(dashboard()));
    expect(find.text('No shared cycle entries yet'), findsOneWidget);
    await tester.pumpWidget(app(dashboard(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 5),
        next: DateTime(2026, 10, 29))));
    expect(find.text('Next period estimate'), findsOneWidget);
    expect(find.text('29 Oct 2026'), findsOneWidget);
    await tester.pumpWidget(app(dashboard(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
        next: DateTime(2026, 9, 29))));
    expect(find.text('Waiting for updated cycle timing'), findsOneWidget);
    await tester.pumpWidget(app(dashboard(start: DateTime(2026, 10, 24))));
    expect(find.text('A future entry is saved'), findsOneWidget);
    expect(find.text('Starts 24 Oct 2026'), findsOneWidget);
    expect(find.text('Period in progress'), findsNothing);
  });
}
