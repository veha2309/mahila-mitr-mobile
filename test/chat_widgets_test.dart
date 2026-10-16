import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/chat_widgets.dart';

void main() {
  test('unread has no countdown; read countdown uses expiry, not sent time',
      () {
    final now = DateTime.utc(2026, 10, 16);
    expect(messageLifetimeLabel({}, now, outgoing: true),
        'Sent · waiting to be read');
    expect(messageLifetimeLabel({}, now, outgoing: false),
        'Unread · timer paused');
    expect(
        messageLifetimeLabel({
          'expires_at': now.add(const Duration(minutes: 10)).toIso8601String()
        }, now, outgoing: true),
        'Read · 10m left');
    expect(
        messageLifetimeLabel({'expires_at': now.toIso8601String()}, now,
            outgoing: false),
        'Expired');
  });

  Future<void> mount(
      WidgetTester tester, GlobalKey viewport, Future<void> Function() onRead,
      {bool unread = true, double top = 0}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
      key: viewport,
      height: 150,
      width: 300,
      child: SingleChildScrollView(
          child: Column(children: [
        SizedBox(height: top),
        ReadAwareMessage(
            viewportKey: viewport,
            unread: unread,
            onRead: onRead,
            child: const SizedBox(height: 80, child: Text('Incoming message'))),
      ])),
    ))));
  }

  testWidgets('visible incoming message requires dwell time', (tester) async {
    var receipts = 0;
    await mount(tester, GlobalKey(), () async {
      receipts++;
    });
    await tester.pump(const Duration(milliseconds: 500));
    expect(receipts, 0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(receipts, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('offscreen cached messages stay unread', (tester) async {
    var receipts = 0;
    await mount(tester, GlobalKey(), () async {
      receipts++;
    }, top: 400);
    await tester.pump(const Duration(seconds: 2));
    expect(receipts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background and outgoing messages never acknowledge reads',
      (tester) async {
    var receipts = 0;
    await mount(tester, GlobalKey(), () async {
      receipts++;
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 2));
    expect(receipts, 0);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, GlobalKey(), () async {
      receipts++;
    }, unread: false);
    await tester.pump(const Duration(seconds: 2));
    expect(receipts, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a covering sheet does not mark messages read', (tester) async {
    var receipts = 0;
    await mount(tester, GlobalKey(), () async {
      receipts++;
    });
    final context = tester.element(find.text('Incoming message'));
    showModalBottomSheet<void>(
        context: context, builder: (_) => const SizedBox(height: 100));
    await tester.pump(const Duration(seconds: 2));
    expect(receipts, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
