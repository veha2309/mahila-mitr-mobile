# platform_glass_navigation

## Android package extraction

Android navigation now delegates to the standalone
[`liquid_retina_navigation`](https://github.com/veha2309/liquid_retina_navigation)
package, fetched from Git at `v0.1.0`. The app also declares this Git dependency
explicitly. The Android renderer no longer lives in this folder. The existing
`PlatformGlassNavigationBar` API adapts destination data and preview callbacks,
while the native iOS implementation remains here.

The copy/install instructions below describe the original bundled package;
the current dependency setup is defined by this folder's `pubspec.yaml`.

A reusable, host-themed Flutter navigation package with no dependencies on the
museum app's routes, assets, services, or backend.

| Platform | Appearance |
| --- | --- |
| iOS 26+ | Native UIKit Liquid Glass tab bar |
| iOS 15–25 | Cupertino tab bar |
| Android | Compact optical glass capsule with hold enlargement and drag selection |
| Web / desktop | Material NavigationBar |

The host owns `selectedIndex`, routing, and whether a requested tab change is
accepted. Use 2–5 destinations. Labels, icons, badges, colors, and items can
change at runtime.

## Install

Copy this entire folder into the consuming app as
`packages/platform_glass_navigation`. Keep its `lib`, `ios`, and `pubspec.yaml`
together. The supplied ZIP contains this folder and the standalone example.

```yaml
dependencies:
  flutter:
    sdk: flutter
  platform_glass_navigation:
    path: packages/platform_glass_navigation

flutter:
  uses-material-design: true
```

Run `flutter pub get`, then fully rebuild the app so Flutter registers the iOS
plugin and bundles the optical renderer's shaders. No manual native registration
or AppDelegate changes are needed. Android rendering uses the pinned
`liquid_glass_easy: 3.3.1` dependency; consumers do not need to declare it directly.

Requires Flutter 3.44+ and Dart 3.12.2+. iOS requires deployment target 15+;
native Liquid Glass requires iOS 26 and Xcode 26+. This is a local package,
version 0.2.0, and is not published on pub.dev.

## Use your app's theme

Configure the host `MaterialApp` as usual:

```dart
MaterialApp(
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system,
  home: const HomeScreen(),
);
```

Then add the bar inside your stateful screen:

```dart
import 'package:platform_glass_navigation/platform_glass_navigation.dart';

Scaffold(
  extendBody: true,
  body: IndexedStack(index: selectedIndex, children: pages),
  bottomNavigationBar: PlatformGlassNavigationBar(
    selectedIndex: selectedIndex,
    onTap: (index) => setState(() => selectedIndex = index),
    items: const [
      GlassNavigationItem(
        label: 'Home', icon: Icons.home_outlined, iosSymbol: 'house'),
      GlassNavigationItem(
        label: 'Search', icon: Icons.search, iosSymbol: 'magnifyingglass'),
      GlassNavigationItem(
        label: 'Profile', icon: Icons.person_outline, iosSymbol: 'person'),
    ],
  ),
);
```

No color arguments are necessary. Defaults are resolved from the nearest
Flutter theme, including a Cupertino theme when used in a `CupertinoApp`:

| Optional override | Host default | Applied to |
| --- | --- | --- |
| `tintColor` | `ColorScheme.primary` | Active icon, label, and selector tint |
| `unselectedColor` | `ColorScheme.onSurfaceVariant` | Inactive icons and labels |
| `surfaceColor` | `ColorScheme.surface` | Android glass tint and Flutter fallback surfaces |

The component follows inherited theme updates automatically, including changes
to the native iOS view.
UIKit owns its native glass surface; iOS receives active/inactive colors and
light/dark appearance rather than a Flutter-painted surface tint. Android and
Material label typography inherit the host text theme; UIKit owns native fonts.

For a one-off override, supply just the colors you want to replace:

```dart
PlatformGlassNavigationBar(
  items: tabs,
  selectedIndex: selectedIndex,
  onTap: selectTab,
  tintColor: Colors.orange,
);
```

## Android interaction and layout

The capsule is 54 logical pixels tall, with 40-pixel horizontal margins,
10 pixels above it, and a 24-pixel bottom gap above the device safe area.
`PlatformGlassNavigationBar.androidHeight` is 88 pixels, excluding that safe
area. Pad scrolling content by this height plus the device bottom inset so its
last controls can scroll clear of the bar.

Hold and drag to preview destinations continuously; release to request the
destination under the selector. Holding expands the selector 22% horizontally
and 42% vertically before movement stretch and lifts it 3 pixels beyond the
bar outline. Cancellation or a rejected selection restores the host's current
destination. Reduced motion disables expansion, spring motion, and refraction.

On Impeller, the outer surface and selector use live-backdrop optical refraction
and rim lighting. Navigation glyphs are painted before the selector so its lens
refracts them along with the background. Unsupported renderers use a frosted
fallback. High contrast uses a solid surface for readability. Android is an
approximation of UIKit's material; visual parity is not guaranteed.

## Icons and badges

`icon` accepts constant Flutter `IconData`, including the consuming app's custom
icon fonts. Native iOS renders it to a PNG when `iosSymbol` is omitted.
`iosSymbol` accepts an SF Symbol supported by the device OS. `iosImage` accepts
transparent monochrome PNG bytes and takes priority over `iosSymbol`.

`badge` is shown on native iOS, Android, and the Material fallback. The older-iOS
Cupertino fallback uses plain tab items. The consuming app owns its assets and
font declarations; no images or fonts are copied from the museum app.

## Routing and custom Android UI

For GoRouter, derive the selected index from your navigation shell and call
`navigationShell.goBranch(index)` in `onTap`. For Navigator or other routers,
use your existing routing callback. The package never creates routes itself.

To replace the Android UI, use `androidBuilder`:

```dart
androidBuilder: (context, items, index, onTap) => BottomNavigationBar(
  currentIndex: index,
  onTap: onTap,
  items: items.map((item) => BottomNavigationBarItem(
    label: item.label, icon: Icon(item.icon),
  )).toList(),
),
```

The builder is ignored on iOS. Custom builders own their colors and badge UI.

## Standalone example

```sh
cd example
flutter pub get
flutter run
```

The example has its own app, Android/iOS runners, three navigable tabs, palette
selection, and a light/dark switch. It passes no color overrides to the package.
For iOS, choose a signing team in Xcode as usual.

## Validation

Package tests cover host palette inheritance, runtime theme changes, explicit
overrides, Material fallback, native iOS channel updates, controlled selection,
held dragging, cancellation, RTL, safe-area insets, high contrast, large text,
and optical shader loading. The example separately tests theme switching and
tab navigation. Native iOS Swift changes require build verification on macOS.

Swift Package Manager and CocoaPods descriptors are included. Do not remove the
`ios` folder when copying the package.
Clean Flutter analysis, four package tests (including native channel updates), and one example widget test passed. Android debug APK and unsigned iOS device builds passed. Native visuals and routing integration in a consuming app have not been device-tested after extraction. The iOS example build used CocoaPods; the Swift Package Manager descriptor is included but has not been independently build-tested.

## Segmented tabs

`PlatformGlassSegmentedControl` accepts `labels`, `selectedIndex`, `onTap`,
and a `fallbackBuilder`. It uses UIKit's native segmented control on iOS 26+
and the supplied Flutter UI on older iOS and other platforms. Build with
Xcode 26 or newer to get Liquid Glass. The caller owns the selected tab,
so swipes and programmatic selection stay synchronized.

## Mahila Mitr integration adjustments

This vendored copy has a 96-pixel Android layout, 20-pixel horizontal margins,
12-pixel labels drawn above the liquid selector, a translucent ivory host surface,
and restrained border/shadow contrast. The optical renderer and controlled
hold/drag selection behavior are preserved. The consuming app supplies a static
capsule or Material fallback for reduced/off effects and large text. These local
changes do not modify the original Salarjung package checkout.

Full effects retain the original Salarjung surface opacity and optical refraction. Icons and the live backdrop are painted before the lens, while text labels are painted above it for readability.

## Host-controlled screen previews

`onScrubChanged` optionally reports a fractional Android tab position after a
180 ms hold and during horizontal dragging. `null` signals commit/cancellation.
It does not navigate. The host continues to own `onTap` and can use these events
to transform its own page cards. Deactivation/disposal cancels pending hold timers;
reduced motion suppresses preview callbacks. This hook is Android-specific.
