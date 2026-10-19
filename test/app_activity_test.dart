import 'package:mahila_mitr/brand_widgets.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_activity.dart';
import 'package:mahila_mitr/app_design.dart';

void main() {
  test(
      'concurrent requests stay visible until the last one finishes, including errors',
      () async {
    final activity = AppActivityController();
    final first = Completer<int>();
    final second = Completer<int>();
    final firstRequest = activity.run('Sending code…', () => first.future);
    final secondRequest = activity.run('Saving…', () => second.future);
    expect(activity.active, isTrue);
    expect(activity.label, 'Saving…');
    first.complete(42);
    expect(await firstRequest, 42);
    expect(activity.active, isTrue);
    final failedRequest = expectLater(secondRequest, throwsStateError);
    second.completeError(StateError('Connection failed'));
    await failedRequest;
    expect(activity.active, isFalse);
    activity.dispose();
  });

  test('a request may finish after its overlay is disposed', () async {
    final activity = AppActivityController();
    final response = Completer<void>();
    final request = activity.run('Sending…', () => response.future);
    activity.dispose();
    response.complete();
    await request;
  });

  for (final fails in [false, true]) {
    testWidgets(
        'request loader blocks duplicates and clears on ${fails ? 'failure' : 'success'}',
        (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final activity = AppActivityController();
      final response = Completer<void>();
      var requests = 0;
      var failed = false;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: AppActivityScope(
                controller: activity,
                child:
                    AppActivityOverlay(controller: activity, child: child!))),
        home: Builder(
            builder: (context) => Scaffold(
                body: Center(
                    child: FilledButton(
                        onPressed: () async {
                          requests++;
                          try {
                            await runWithAppActivity(
                                context,
                                'Sending verification code…',
                                () => response.future);
                          } catch (_) {
                            failed = true;
                          }
                        },
                        child: const Text('Send code'))))),
      ));
      final target = tester.getCenter(find.text('Send code'));
      await tester.tapAt(target);
      await tester.pump();
      expect(find.byType(FloralProgressIndicator), findsOneWidget);
      expect(find.text('Sending verification code…'), findsOneWidget);
      await tester.tapAt(target);
      expect(requests, 1);
      if (fails) {
        response.completeError(StateError('Offline'));
      } else {
        response.complete();
      }
      await tester.pumpAndSettle();
      expect(find.byType(FloralProgressIndicator), findsNothing);
      expect(failed, fails);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      activity.dispose();
    });
  }

  testWidgets('finishing a request leaves the current route in place',
      (tester) async {
    final activity = AppActivityController();
    final response = Completer<void>();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      builder: (context, child) => AppActivityScope(
          controller: activity,
          child: AppActivityOverlay(controller: activity, child: child!)),
      home: const Scaffold(body: Text('Original page')),
    ));
    final request = activity.run('Verifying code…', () => response.future);
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Profile'))));
    await tester.pump();
    response.complete();
    await request;
    await tester.pumpAndSettle();
    expect(find.text('Profile'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(find.byType(FloralProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    activity.dispose();
  });
}
