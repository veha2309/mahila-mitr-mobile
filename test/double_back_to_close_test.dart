import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/double_back_to_close.dart';

void main() {
  var exits = 0;
  setUp(() {
    exits = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> launch(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: DoubleBackToClose(
            child: Scaffold(
                body: Builder(
                    builder: (context) => Column(children: [
                          const TextField(),
                          TextButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => const Scaffold(
                                          body: Text('Chat screen')))),
                              child: const Text('Open chat')),
                          TextButton(
                              onPressed: () => showModalBottomSheet<void>(
                                  context: context,
                                  builder: (_) => const SizedBox(
                                      height: 200, child: Text('Note sheet'))),
                              child: const Text('Open sheet')),
                        ])))),
      ));

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  testWidgets('first back prompts; second back within two seconds closes',
      (tester) async {
    await launch(tester);
    await back(tester);
    expect(exits, 0);
    expect(find.text('Press back again to close'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await back(tester);
    expect(exits, 1);
  });

  testWidgets('confirmation expires after two seconds', (tester) async {
    await launch(tester);
    await back(tester);
    await tester.pump(const Duration(seconds: 3));
    await back(tester);
    expect(exits, 0);
    await back(tester);
    expect(exits, 1);
  });

  for (final target in ['chat', 'sheet']) {
    testWidgets(
        'back dismisses $target normally and resets an earlier exit prompt',
        (tester) async {
      await launch(tester);
      await back(tester);
      await tester.pump(const Duration(milliseconds: 250));
      await tester
          .tap(find.text(target == 'chat' ? 'Open chat' : 'Open sheet'));
      await tester.pumpAndSettle();
      expect(find.text(target == 'chat' ? 'Chat screen' : 'Note sheet'),
          findsOneWidget);
      await back(tester);
      await tester.pumpAndSettle();
      expect(find.text(target == 'chat' ? 'Chat screen' : 'Note sheet'),
          findsNothing);
      expect(exits, 0);
      await back(tester);
      expect(exits, 0);
      await back(tester);
      expect(exits, 1);
    });
  }

  testWidgets('backgrounding resets the confirmation', (tester) async {
    await launch(tester);
    await back(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await back(tester);
    expect(exits, 0);
    await back(tester);
    expect(exits, 1);
  });

  testWidgets('back with the keyboard visible only dismisses focus',
      (tester) async {
    await launch(tester);
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await back(tester);
    expect(exits, 0);
    expect(find.text('Press back again to close'), findsNothing);
    tester.view.resetViewInsets();
    await tester.pump();
    await back(tester);
    expect(exits, 0);
    await back(tester);
    expect(exits, 1);
  });

  testWidgets('other platforms retain normal navigation behavior',
      (tester) async {
    await launch(tester);
    expect(find.byType(PopScope<Object?>), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
