import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_activity.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/brand_widgets.dart';
import 'support/ui_preview.dart';

void main() {
  setUpAll(loadPreviewFonts);
  testWidgets('flower animates and stops when reduced motion is enabled',
      (tester) async {
    Widget screen(bool reduced) => MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const Scaffold(
                body: Center(child: FloralProgressIndicator()))));
    BrandFlowerPainter painter() => tester
        .widget<CustomPaint>(find.descendant(
            of: find.byType(FloralProgressIndicator),
            matching: find.byType(CustomPaint)))
        .painter! as BrandFlowerPainter;
    await tester.pumpWidget(screen(false));
    final initial = painter().phase;
    await tester.pump(const Duration(milliseconds: 300));
    expect(painter().phase, isNot(initial));
    await tester.pumpWidget(screen(true));
    expect(painter().phase, isNull);
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('floral request overlay renders over the existing app',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final activity = AppActivityController();
    final response = Completer<void>();
    final request =
        activity.run('Sending verification code…', () => response.future);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: previewTheme(),
      home: RepaintBoundary(
          key: key,
          child: AppActivityOverlay(
              controller: activity,
              child: const Scaffold(
                  body: SafeArea(
                      child: AppPage(children: [
                AppPageHeading(eyebrow: 'Mahila Mitr', title: 'Sign in'),
                TextField(
                    decoration: InputDecoration(labelText: 'Email address')),
              ]))))),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FloralProgressIndicator), findsOneWidget);
    await capturePreview(tester, key, 'floral-loader');
    response.complete();
    await request;
    await tester.pumpAndSettle();
    expect(find.byType(FloralProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    activity.dispose();
  });
}
