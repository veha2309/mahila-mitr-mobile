import 'package:mahila_mitr/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_glass_navigation/platform_glass_navigation.dart';
import 'package:mahila_mitr/app_design.dart';
import 'package:mahila_mitr/appearance_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('effects persist across controller reloads', () async {
    final first = AppearanceController();
    await first.select(VisualEffects.off);
    final reloaded = AppearanceController();
    await reloaded.load();
    expect(reloaded.choice, VisualEffects.off);
    first.dispose();
    reloaded.dispose();
  });
  test('automatic reduces sustained slow rendering, manual choices stay fixed',
      () async {
    final controller = AppearanceController();
    for (var i = 0; i < 90; i++) {
      controller.recordFrame(const Duration(milliseconds: 45));
    }
    expect(controller.effective, VisualEffects.reduced);
    for (var i = 0; i < 60; i++) {
      controller.recordFrame(const Duration(milliseconds: 45));
    }
    expect(controller.effective, VisualEffects.off);
    for (var i = 0; i < 120; i++) {
      controller.recordFrame(const Duration(milliseconds: 4));
    }
    expect(controller.effective, VisualEffects.off);
    await controller.select(VisualEffects.full);
    for (var i = 0; i < 150; i++) {
      controller.recordFrame(const Duration(milliseconds: 45));
    }
    expect(controller.effective, VisualEffects.full);
    controller.dispose();
  });
  test('background and startup work do not disable effects', () {
    final controller = AppearanceController();
    for (var i = 0; i < 30; i++) {
      controller.recordFrame(const Duration(milliseconds: 100));
    }
    expect(controller.effective, VisualEffects.full);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    for (var i = 0; i < 200; i++) {
      controller.recordFrame(const Duration(milliseconds: 100));
    }
    expect(controller.effective, VisualEffects.full);
    controller.dispose();
  });
  testWidgets(
      'effect settings replace expensive navigation and preserve tab selection',
      (tester) async {
    final controller = AppearanceController();
    var selected = 0;
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: AppearanceScope(
            controller: controller,
            child: Scaffold(
                body: AppPage(children: const [AppearanceSettingsPanel()]),
                bottomNavigationBar: AppNavigation(
                    index: 0, onSelected: (i) => selected = i)))));
    expect(find.byType(PlatformGlassNavigationBar), findsOneWidget);
    await tester.tap(find.text('Reduced effects'));
    await tester.pumpAndSettle();
    expect(find.byType(PlatformGlassNavigationBar), findsNothing);
    await tester.tap(find.text('Moments'));
    expect(selected, 2);
    await tester.tap(find.text('Off').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppearanceController.preferenceKey), 'off');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('system reduce motion avoids refraction even with full effects',
      (tester) async {
    final controller = AppearanceController();
    await controller.select(VisualEffects.full);
    await tester.pumpWidget(MaterialApp(
        home: AppearanceScope(
            controller: controller,
            child: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: Scaffold(
                    bottomNavigationBar:
                        AppNavigation(index: 0, onSelected: (_) {}))))));
    expect(find.byType(PlatformGlassNavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
