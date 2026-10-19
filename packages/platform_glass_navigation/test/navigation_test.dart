import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_glass_navigation/platform_glass_navigation.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

const tabs = [
  GlassNavigationItem(label: 'Home', icon: Icons.home),
  GlassNavigationItem(label: 'Chats', icon: Icons.chat),
];
void main() {
  testWidgets(
    'uses the host palette, follows theme changes and accepts overrides',
    (tester) async {
      final light = ColorScheme.fromSeed(seedColor: Colors.orange).copyWith(
        primary: Colors.orange,
        onSurfaceVariant: Colors.brown,
        surface: Colors.yellow,
      );
      final dark =
          ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ).copyWith(
            primary: Colors.tealAccent,
            onSurfaceVariant: Colors.cyan,
            surface: Colors.blueGrey,
          );
      final bar = PlatformGlassNavigationBar(
        items: tabs,
        selectedIndex: 0,
        onTap: (_) {},
      );
      Widget app(ColorScheme scheme, Widget navigation) => MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: Scaffold(bottomNavigationBar: navigation),
      );
      void expectPalette(Color primary, Color inactive, Color surface) {
        expect(tester.widget<Icon>(find.byIcon(Icons.home)).color, primary);
        expect(tester.widget<Icon>(find.byIcon(Icons.chat)).color, inactive);
        final surfaceBox = find.descendant(
          of: find.byKey(const ValueKey('android-glass-surface')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color != null,
          ),
        );
        expect(
          (tester.widget<DecoratedBox>(surfaceBox).decoration as BoxDecoration)
              .color,
          surface,
        );
      }

      await tester.pumpWidget(app(light, bar));
      expectPalette(
        light.primary,
        light.onSurfaceVariant,
        light.surface.withValues(alpha: 0.30),
      );
      // Reuse the exact same bar so this exercises inherited theme notifications.
      await tester.pumpWidget(app(dark, bar));
      await tester.pumpAndSettle();
      expectPalette(
        dark.primary,
        dark.onSurfaceVariant,
        dark.surface.withValues(alpha: 0.45),
      );
      await tester.pumpWidget(
        app(
          dark,
          PlatformGlassNavigationBar(
            items: tabs,
            selectedIndex: 0,
            onTap: (_) {},
            tintColor: Colors.pink,
            unselectedColor: Colors.amber,
            surfaceColor: Colors.indigo,
          ),
        ),
      );
      expectPalette(
        Colors.pink,
        Colors.amber,
        Colors.indigo.withValues(alpha: 0.45),
      );
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets('Material fallback uses the host palette', (tester) async {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.green);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: scheme),
        home: Scaffold(
          bottomNavigationBar: PlatformGlassNavigationBar(
            items: tabs,
            selectedIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).backgroundColor,
      scheme.surface,
    );
    expect(tester.widget<Icon>(find.byIcon(Icons.home)).color, scheme.primary);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.chat)).color,
      scheme.onSurfaceVariant,
    );
  }, variant: TargetPlatformVariant({TargetPlatform.linux}));
  test('rejects invalid tab configuration', () {
    expect(
      () => PlatformGlassNavigationBar(
        items: [],
        selectedIndex: 0,
        onTap: (_) {},
      ),
      throwsArgumentError,
    );
    expect(
      () => PlatformGlassNavigationBar(
        items: tabs,
        selectedIndex: 2,
        onTap: (_) {},
      ),
      throwsRangeError,
    );
  });
  testWidgets('forwards taps and follows external selected index', (
    tester,
  ) async {
    int? tapped;
    Widget app(int index) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PlatformGlassNavigationBar(
          items: tabs,
          selectedIndex: index,
          onTap: (value) => tapped = value,
        ),
      ),
    );
    await tester.pumpWidget(app(0));
    await tester.tap(find.text('Chats'));
    expect(tapped, 1);
    // A declined tab change must not move the controlled selection.
    await tester.pumpAndSettle();
    final selector = find.byKey(const ValueKey('android-glass-selector'));
    expect(
      tester.getCenter(selector).dx,
      tester.getCenter(find.text('Home')).dx,
    );
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNWidgets(2));
    expect(find.byType(ImageFiltered), findsNothing);
    expect(
      tester.getCenter(selector).dx,
      tester.getCenter(find.text('Chats')).dx,
    );
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
  testWidgets('Android glass supports badges, insets, RTL and large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: 24),
            textScaler: TextScaler.linear(3),
            disableAnimations: true,
            highContrast: true,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              extendBody: true,
              bottomNavigationBar: PlatformGlassNavigationBar(
                items: const [
                  ...tabs,
                  GlassNavigationItem(
                    label: 'Collections',
                    icon: Icons.museum,
                    badge: '8',
                  ),
                  GlassNavigationItem(label: 'Tours', icon: Icons.route),
                  GlassNavigationItem(label: 'Profile', icon: Icons.person),
                ],
                selectedIndex: 2,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('8'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(find.byKey(const ValueKey('android-glass-selector'))).dx,
      tester.getCenter(find.text('Collections')).dx,
    );
    expect(
      tester.getSize(find.byType(PlatformGlassNavigationBar)).height,
      PlatformGlassNavigationBar.androidHeight + 24,
    );
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
  testWidgets(
    'held drag enlarges lens, previews continuously and commits once',
    (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: PlatformGlassNavigationBar(
              items: tabs,
              selectedIndex: 0,
              onTap: taps.add,
            ),
          ),
        ),
      );
      final selector = find.byKey(const ValueKey('android-glass-selector'));
      final restingSize = tester.getSize(selector);
      final home = tester.getCenter(find.text('Home'));
      final chats = tester.getCenter(find.text('Chats'));
      final gesture = await tester.startGesture(home);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      expect(tester.getSize(selector).height, greaterThan(restingSize.height));
      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('android-glass-surface')),
      );
      final heldRect = tester.getRect(selector);
      expect(heldRect.top, lessThan(surfaceRect.top));
      expect(heldRect.bottom, greaterThan(surfaceRect.bottom));
      expect(heldRect.width, greaterThan(restingSize.width * 1.2));
      await gesture.moveTo(Offset((home.dx + chats.dx) / 2, home.dy));
      await tester.pump();
      expect(taps, isEmpty);
      expect(tester.getCenter(selector).dx, greaterThan(home.dx));
      expect(tester.getCenter(selector).dx, lessThan(chats.dx));
      await gesture.moveTo(chats);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, [1]);
      // This host declines the selection, so the pill returns to Home.
      expect(tester.getCenter(selector).dx, closeTo(home.dx, 0.1));
      expect(tester.getSize(selector).height, closeTo(restingSize.height, 0.1));
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
  testWidgets('cancelled RTL drag restores selection without navigation', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            bottomNavigationBar: PlatformGlassNavigationBar(
              items: tabs,
              selectedIndex: 0,
              onTap: taps.add,
            ),
          ),
        ),
      ),
    );
    final home = tester.getCenter(find.text('Home'));
    final chats = tester.getCenter(find.text('Chats'));
    expect(home.dx, greaterThan(chats.dx));
    final gesture = await tester.startGesture(home);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(chats);
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(taps, isEmpty);
    expect(
      tester.getCenter(find.byKey(const ValueKey('android-glass-selector'))).dx,
      closeTo(home.dx, 0.1),
    );
  }, variant: TargetPlatformVariant({TargetPlatform.android}));
  testWidgets('optical renderer shaders compile and can be instantiated', (
    tester,
  ) async {
    await LiquidGlassShaders.ensureLoaded(false);
    expect(LiquidGlassShaders.isLoadedFor(false), isTrue);
    LiquidGlassShaders.createMainShader(false).dispose();
    LiquidGlassShaders.createBorderShader(false).dispose();
  });
  testWidgets('custom Android builder receives items and callback', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: PlatformGlassNavigationBar(
            items: tabs,
            selectedIndex: 0,
            onTap: (value) => tapped = value,
            androidBuilder: (context, items, index, onTap) => TextButton(
              onPressed: () => onTap(1),
              child: Text(items[1].label),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Chats'));
    expect(tapped, 1);
  });
  testWidgets('native view receives external selection and dynamic tabs', (
    tester,
  ) async {
    const symbols = [
      GlassNavigationItem(label: 'Home', icon: Icons.home, iosSymbol: 'house'),
      GlassNavigationItem(
        label: 'Chats',
        icon: Icons.chat,
        iosSymbol: 'message',
      ),
    ];
    int? id;
    int? nativeTap;
    final updates = <Map<dynamic, dynamic>>[];
    const platform = MethodChannel('platform_glass_navigation');
    const views = MethodChannel('flutter/platform_views');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(platform, (call) async => true);
    messenger.setMockMethodCallHandler(views, (call) async {
      if (call.method == 'create') {
        id = (call.arguments as Map)['id'] as int;
        messenger.setMockMethodCallHandler(
          MethodChannel('platform_glass_navigation/bar/$id'),
          (call) async {
            updates.add(call.arguments as Map);
            return null;
          },
        );
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(platform, null);
      messenger.setMockMethodCallHandler(views, null);
      if (id != null) {
        messenger.setMockMethodCallHandler(
          MethodChannel('platform_glass_navigation/bar/$id'),
          null,
        );
      }
    });
    Widget app(int index, List<GlassNavigationItem> items) => MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PlatformGlassNavigationBar(
          items: items,
          selectedIndex: index,
          onTap: (index) => nativeTap = index,
        ),
      ),
    );
    await tester.pumpWidget(app(0, symbols));
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsOneWidget);
    await tester.pumpWidget(
      app(1, [
        ...symbols,
        const GlassNavigationItem(
          label: 'Profile',
          icon: Icons.person,
          iosSymbol: 'person',
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(updates.last['selected'], 1);
    expect((updates.last['items'] as List).length, 3);
    ui.channelBuffers.push(
      'platform_glass_navigation/bar/$id',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('selected', 0),
      ),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(nativeTap, 0);
    expect(updates.last['selected'], 1);
    final themedBar = PlatformGlassNavigationBar(
      items: symbols,
      selectedIndex: 0,
      onTap: (_) {},
    );
    Widget themedApp(ThemeData theme) => MaterialApp(
      theme: theme,
      home: Scaffold(bottomNavigationBar: themedBar),
    );
    await tester.pumpWidget(
      themedApp(
        ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange)),
      ),
    );
    await tester.pumpAndSettle();
    final originalViewId = id;
    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpWidget(themedApp(darkTheme));
    await tester.pumpAndSettle();
    expect(id, originalViewId);
    expect(updates.last['tint'], darkTheme.colorScheme.primary.toARGB32());
    expect(
      updates.last['unselectedTint'],
      darkTheme.colorScheme.onSurfaceVariant.toARGB32(),
    );
    expect(updates.last['brightness'], 'dark');
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));
}
