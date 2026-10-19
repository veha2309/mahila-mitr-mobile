import 'package:mahila_mitr/home_widgets.dart';
import 'package:mahila_mitr/app_navigation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/premium_widgets.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      final loader = FontLoader('PreviewSans')
        ..addFont(File(
                '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/segoeui.ttf')
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(File.fromUri(File(Platform.resolvedExecutable)
                .parent
                .parent
                .parent
                .uri
                .resolve('material_fonts/MaterialIcons-Regular.otf'))
            .readAsBytes()
            .then((b) => ByteData.sublistView(b)));
      await icons.load();
    }
  });
  test('greeting follows the time of day', () {
    expect(greetingForHour(8), 'Good morning');
    expect(greetingForHour(14), 'Good afternoon');
    expect(greetingForHour(20), 'Good evening');
  });

  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('home layout fits width $width at text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var checkedIn = false;
        var selected = 0;
        final boundary = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          theme: const bool.fromEnvironment('CAPTURE_UI')
              ? buildAppTheme().copyWith(
                  textTheme: buildAppTheme()
                      .textTheme
                      .apply(fontFamily: 'PreviewSans'),
                  filledButtonTheme: FilledButtonThemeData(
                      style: buildAppTheme().filledButtonTheme.style!.copyWith(
                          textStyle: WidgetStatePropertyAll(buildAppTheme()
                              .textTheme
                              .labelLarge!
                              .copyWith(fontFamily: 'PreviewSans')))))
              : buildAppTheme(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                body: SafeArea(
                    child: AppPage(children: [
                  HomeHeading(
                      date: DateTime(2026, 10, 19),
                      name: 'Ananya',
                      onProfile: () => selected = 3),
                  CycleTodayHero(
                      onViewCalendar: () => selected = 1,
                      cycleDay: 12,
                      phase: 'Follicular phase',
                      nextPeriodLabel: '2 November',
                      daysToGo: 16,
                      confidence: 'Building',
                      isCheckedIn: false,
                      reduceMotion: true,
                      onCheckIn: () => checkedIn = true),
                  const SizedBox(height: 16),
                  AppActionPair(
                      first: AppActionTile(
                          icon: Icons.water_drop_outlined,
                          title: 'Log your period',
                          subtitle: 'Add a start date',
                          onTap: () {}),
                      second: AppActionTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Messages',
                          subtitle: 'Open your conversation',
                          color: AppPalette.sage,
                          onTap: () {})),
                  const SizedBox(height: 24),
                  WellnessHistoryStrip(
                      days: List.generate(7, (i) => DateTime(2026, 10, 13 + i)),
                      hasLog: (d) => d.day.isEven,
                      onSelected: (_) {}),
                  const SizedBox(height: 24),
                  DailyCheckInCard(
                      mood: 'Calm',
                      flow: 'Light',
                      energy: 'Balanced',
                      symptoms: const ['Cramps'],
                      onEdit: () => checkedIn = true),
                  PeriodHistoryTile(
                      start: DateTime(2026, 10, 12),
                      end: DateTime(2026, 10, 16),
                      onTap: () => checkedIn = true),
                ])),
                bottomNavigationBar:
                    AppNavigation(index: 0, onSelected: (i) => selected = i),
              )),
        ));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Check in for today'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Check in for today'));
        expect(checkedIn, isTrue);
        await tester.tap(find.text('Moments'));
        expect(selected, 2);

        if (const bool.fromEnvironment('CAPTURE_UI') &&
            width == 390 &&
            scale == 1) {
          // Back to the top for a preview using the production design widgets.
          final scrollable =
              tester.state<ScrollableState>(find.byType(Scrollable).first);
          scrollable.position.jumpTo(0);
          await tester.pumpAndSettle();
          final render = boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          Future<void> capture(String name) => tester.runAsync(() async {
                final image = await render.toImage(pixelRatio: 2);
                final bytes =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                final output = File('build/ui-previews/$name.png');
                await output.parent.create(recursive: true);
                await output.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
          await capture('home');
          scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
          await tester.pumpAndSettle();
          await capture('home-details');
        }
      });
    }
  }
}
