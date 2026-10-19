import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/year_calendar.dart';
import 'support/ui_preview.dart';

void main() {
  setUpAll(loadPreviewFonts);
  for (final width in [320.0, 390.0, 768.0]) {
    for (final scale in [1.0, 1.8]) {
      testWidgets('year dates and month selection fit $width at $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        DateTime? opened;
        int? year;
        final boundary = GlobalKey();
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
                      child: AppPage(children: [
                YearCalendar(
                    selectedDay: DateTime(2024, 2, 29),
                    today: DateTime(2024, 2, 29),
                    isPeriodDay: (date) => date.month == 2 && date.day >= 26,
                    isPredictedDay: (date) =>
                        date.month == 3 && date.day >= 25 && date.day <= 29,
                    onYearChanged: (value) => year = value,
                    onMonthSelected: (value) => opened = value),
              ])))),
        ));
        await tester.pumpAndSettle();
        expect(
            find.byKey(const ValueKey('year-day-2024-2-29')), findsOneWidget);
        expect(find.byKey(const ValueKey('year-day-2024-2-30')), findsNothing);
        final days = find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.key is ValueKey<String> &&
            (widget.key as ValueKey<String>).value.startsWith('year-day-'));
        expect(days, findsNWidgets(366));
        final leapDay = tester.widget<Container>(
            find.byKey(const ValueKey('year-day-2024-2-29')));
        expect((leapDay.decoration as BoxDecoration).color,
            const Color(0xffb96285));
        await tester.tap(find.byTooltip('Next year'));
        expect(year, 2025);
        await tester.tap(find.byTooltip('Previous year'));
        expect(year, 2023);
        await tester.ensureVisible(find.text('February'));
        await tester.tap(find.text('February'));
        expect(opened, DateTime(2024, 2));
        final scroll =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        scroll.position.jumpTo(0);
        await tester.pumpAndSettle();
        if (width == 390 && scale == 1) {
          await capturePreview(tester, boundary, 'year-calendar');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
