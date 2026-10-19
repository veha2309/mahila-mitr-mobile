import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/app_navigation.dart';
import 'package:mahila_mitr/appearance_settings.dart';
import 'package:mahila_mitr/navigation_card_stack.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/ui_preview.dart';

class _DeckHarness extends StatefulWidget {
  const _DeckHarness({super.key});
  @override
  State<_DeckHarness> createState() => _DeckHarnessState();
}

class _DeckHarnessState extends State<_DeckHarness> {
  var index = 0;
  var navigationAction = 0;
  void goDirectlyTo(int value) => setState(() => index = value);
  void refreshView() => setState(() {});
  final preview = ValueNotifier<double?>(null);
  final events = <double?>[];
  late final pages = List.generate(
      4,
      (i) => ColoredBox(
          key: ValueKey('sample-screen-$i'),
          color: AppPalette.canvas,
          child: AppPage(children: [
            AppPageHeading(
                eyebrow: 'Mahila Mitr',
                title: [
                  'Your day',
                  'Your patterns',
                  'Little moments',
                  'Your space'
                ][i],
                subtitle: 'A private space for your everyday care.'),
            AppSurface(
                title: [
                  'A gentle check-in',
                  'Cycle history',
                  'A thoughtful note',
                  'Display & performance'
                ][i],
                children: [
                  const SizedBox(height: 24),
                  Icon(
                      [
                        Icons.spa_outlined,
                        Icons.insights_outlined,
                        Icons.favorite_border,
                        Icons.tune
                      ][i],
                      size: 52,
                      color: AppPalette.plum),
                  const SizedBox(height: 24),
                  TextField(
                      key: ValueKey('draft-$i'),
                      decoration: const InputDecoration(
                          labelText: 'Your private draft')),
                  const SizedBox(height: 24),
                ]),
            const SizedBox(height: 800),
          ])));
  @override
  void dispose() {
    preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      extendBody: true,
      body: ValueListenableBuilder<double?>(
          valueListenable: preview,
          builder: (context, position, _) => NavigationCardStack(
              index: index,
              navigationAction: navigationAction,
              previewPosition: position,
              reduceMotion:
                  AppearanceScope.effectsOf(context) != VisualEffects.full,
              children: pages)),
      bottomNavigationBar: AppNavigation(
          index: index,
          onSelected: (value) => setState(() {
                navigationAction++;
                index = value;
              }),
          onScrubChanged: (position) {
            if (!mounted) return;
            if (preview.value == null && position != null) {
              FocusManager.instance.primaryFocus?.unfocus();
            }
            events.add(position);
            preview.value = position;
          }));
}

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(WidgetTester tester, GlobalKey<_DeckHarnessState> key,
      {AppearanceController? appearance, GlobalKey? boundary}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget home = _DeckHarness(key: key);
    if (appearance != null) {
      home = AppearanceScope(controller: appearance, child: home);
    }
    if (boundary != null) home = RepaintBoundary(key: boundary, child: home);
    await tester.pumpWidget(MaterialApp(theme: previewTheme(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'holding lifts cards and fractional lens motion previews without committing',
      (tester) async {
    final key = GlobalKey<_DeckHarnessState>();
    final boundary = GlobalKey();
    await mount(tester, key, boundary: boundary);
    final width =
        tester.getRect(find.byKey(const ValueKey('sample-screen-0'))).width;
    final home = tester.getCenter(find.text('Home'));
    final insights = tester.getCenter(find.text('Insights'));
    final gesture = await tester.startGesture(home);
    await tester.pump(const Duration(milliseconds: 100));
    expect(key.currentState!.preview.value, isNull);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 260));
    expect(key.currentState!.preview.value, 0);
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-0'))).width,
        lessThan(width * .9));
    await gesture.moveTo(Offset.lerp(home, insights, .5)!);
    await tester.pump();
    expect(key.currentState!.preview.value, closeTo(.5, .08));
    expect(key.currentState!.index, 0);
    expect(find.byKey(const ValueKey('sample-screen-1')), findsOneWidget);
    await capturePreview(tester, boundary, 'navigation-cards');
    await gesture.moveTo(tester.getCenter(find.text('Moments')));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(key.currentState!.index, 2);
    expect(key.currentState!.preview.value, isNull);
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-2'))).width,
        closeTo(width, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel restores original screen and keeps its draft',
      (tester) async {
    final key = GlobalKey<_DeckHarnessState>();
    await mount(tester, key);
    await tester.enterText(
        find.byKey(const ValueKey('draft-0')), 'Keep this draft');
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Home')));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(tester.getCenter(find.text('Moments')));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(key.currentState!.index, 0);
    expect(key.currentState!.preview.value, isNull);
    expect(find.text('Keep this draft'), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-0'))).width,
        closeTo(390, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tap navigation preserves state through keyed card reordering',
      (tester) async {
    final key = GlobalKey<_DeckHarnessState>();
    await mount(tester, key);
    await tester.enterText(
        find.byKey(const ValueKey('draft-0')), 'Saved across cards');
    await tester.tap(find.text('Moments'));
    await tester.pumpAndSettle();
    expect(key.currentState!.index, 2);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Saved across cards'), findsOneWidget);
    expect(key.currentState!.events.whereType<double>(), isEmpty);
  });

  testWidgets('switching to reduced effects during hold clears preview safely',
      (tester) async {
    final controller = AppearanceController();
    final key = GlobalKey<_DeckHarnessState>();
    await mount(tester, key, appearance: controller);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Home')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 260));
    expect(key.currentState!.preview.value, isNotNull);
    await controller.select(VisualEffects.reduced);
    await tester.pumpAndSettle();
    expect(key.currentState!.preview.value, isNull);
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-0'))).width,
        closeTo(390, .01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('preview preserves a scrolled tab offset', (tester) async {
    final key = GlobalKey<_DeckHarnessState>();
    await mount(tester, key);
    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.maxScrollExtent, greaterThan(100));
    scrollable.position.jumpTo(100);
    await tester.pump();
    final offset = scrollable.position.pixels;
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Home')));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(tester.getCenter(find.text('Moments')));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, offset);
    expect(tester.takeException(), isNull);
  });

  testWidgets('non-navigator tab changes and routine rebuilds never lift cards',
      (tester) async {
    final key = GlobalKey<_DeckHarnessState>();
    await mount(tester, key);
    key.currentState!.goDirectlyTo(2);
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-2'))).width,
        closeTo(390, .01));
    expect(find.byKey(const ValueKey('sample-screen-0')), findsNothing);
    await tester.pump(const Duration(milliseconds: 160));
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-2'))).width,
        closeTo(390, .01));
    key.currentState!.refreshView();
    await tester.pump();
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-2'))).width,
        closeTo(390, .01));
    // A navigator tap still explicitly opts into the card animation.
    await tester.tap(find.text('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.getRect(find.byKey(const ValueKey('sample-screen-0'))).width,
        lessThan(390));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('hot reload preserves a draft during card preview and return',
      (tester) async {
    final key = GlobalKey<_DeckHarnessState>();
    await mount(tester, key);
    await tester.enterText(
        find.byKey(const ValueKey('draft-0')), 'Draft before reload');
    final reload = tester.binding.reassembleApplication();
    await tester.pump();
    await reload;
    await tester.pumpAndSettle();
    expect(find.text('Draft before reload'), findsOneWidget);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Home')));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(tester.getCenter(find.text('Moments')));
    await tester.pump(const Duration(milliseconds: 100));
    final previewReload = tester.binding.reassembleApplication();
    await tester.pump();
    await previewReload;
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    key.currentState!.refreshView();
    await tester.pumpAndSettle();
    expect(find.text('Draft before reload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing while held leaves no preview timer or late callback',
      (tester) async {
    final key = GlobalKey<_DeckHarnessState>();
    await mount(tester, key);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Home')));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
