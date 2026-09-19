import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/premium_widgets.dart';
import 'package:mahila_mitr/wellness_guide.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('today hero explains the empty state', (tester) async {
    await tester.pumpWidget(app(CycleTodayHero(
      cycleDay: null,
      phase: 'Your cycle story',
      nextPeriodLabel: 'your next period',
      daysToGo: null,
      confidence: 'Starting',
      isCheckedIn: false,
      reduceMotion: true,
      onCheckIn: () {},
    )));

    expect(find.text('Your cycle story'), findsOneWidget);
    expect(find.text('Log your first period to begin your story.'),
        findsOneWidget);
    expect(find.text('Check in for today'), findsOneWidget);
  });

  testWidgets('today hero renders populated cycle data', (tester) async {
    await tester.pumpWidget(app(CycleTodayHero(
      cycleDay: 12,
      phase: 'Follicular phase',
      nextPeriodLabel: '24 September 2026',
      daysToGo: 6,
      confidence: 'High',
      isCheckedIn: true,
      reduceMotion: true,
      onCheckIn: () {},
    )));

    expect(find.text('12'), findsOneWidget);
    expect(find.text('Follicular phase'), findsOneWidget);
    expect(find.text('High confidence'), findsOneWidget);
    expect(find.text('Update today’s check-in'), findsOneWidget);
  });

  testWidgets('animated tab stack preserves child state', (tester) async {
    var index = 0;
    late StateSetter update;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return AnimatedTabStack(
            index: index,
            reduceMotion: true,
            children: const [
              TextField(key: Key('field')),
              Text('Second tab'),
            ],
          );
        }),
      ),
    ));

    await tester.enterText(find.byKey(const Key('field')), 'kept');
    expect(find.byKey(const Key('field')).hitTestable(), findsOneWidget);
    expect(find.text('Second tab').hitTestable(), findsNothing);
    update(() => index = 1);
    await tester.pump();
    expect(find.byKey(const Key('field')).hitTestable(), findsNothing);
    expect(find.text('Second tab').hitTestable(), findsOneWidget);
    update(() => index = 0);
    await tester.pump();

    expect(find.text('kept'), findsOneWidget);
  });

  testWidgets('wellness guide fails closed without licensed asset',
      (tester) async {
    final controller = WellnessGuideController();
    await tester.pumpWidget(app(WellnessGuide(
      controller: controller,
      screen: 0,
      isCheckedIn: false,
      reduceMotion: true,
    )));
    await tester.pumpAndSettle();

    controller.wave();
    controller.celebrate();
    expect(tester.takeException(), isNull);
    expect(find.byType(WellnessGuide), findsOneWidget);
  });

  testWidgets('privacy banner explains the sharing boundary', (tester) async {
    await tester.pumpWidget(app(const PrivacyBanner(
      title: 'You control what gets shared',
      body: 'Your private notes remain yours.',
    )));

    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.text('You control what gets shared'), findsOneWidget);
    expect(find.text('Your private notes remain yours.'), findsOneWidget);
  });

  testWidgets('expressive empty state exposes its next action', (tester) async {
    var tapped = false;
    await tester.pumpWidget(app(ExpressiveEmptyState(
      icon: Icons.mark_email_unread_outlined,
      title: 'No moments yet',
      body: 'Private moments will appear here.',
      action: FilledButton(
        onPressed: () => tapped = true,
        child: const Text('Pair securely'),
      ),
    )));

    await tester.tap(find.text('Pair securely'));
    expect(tapped, isTrue);
    expect(find.text('No moments yet'), findsOneWidget);
  });
}
