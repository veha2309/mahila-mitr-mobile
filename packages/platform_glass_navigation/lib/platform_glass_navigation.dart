import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/physics.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

part 'src/android_glass_bar.dart';

/// A native SF Symbol, Flutter icon font, or custom PNG for an iOS tab.
@immutable
class GlassNavigationItem {
  const GlassNavigationItem({
    required this.label,
    required this.icon,
    this.iosSymbol,
    this.iosImage,
    this.badge,
  });
  final String label;
  final IconData icon;
  final String? iosSymbol;

  /// PNG bytes, drawn as a template (tinted by UIKit). Takes priority over symbol.
  final Uint8List? iosImage;
  final String? badge;
}

typedef AndroidNavigationBuilder =
    Widget Function(
      BuildContext context,
      List<GlassNavigationItem> items,
      int selectedIndex,
      ValueChanged<int> onTap,
    );

/// Controlled bottom bar: the caller owns routing and selectedIndex.
/// Use Scaffold(extendBody: true) to put content behind the glass on both platforms.
class PlatformGlassNavigationBar extends StatefulWidget {
  /// Default Android bar height, excluding the device's bottom safe area.
  static const double androidHeight = 96;

  PlatformGlassNavigationBar({
    super.key,
    required List<GlassNavigationItem> items,
    required this.selectedIndex,
    required this.onTap,
    this.androidBuilder,
    this.onScrubChanged,
    this.tintColor,
    this.unselectedColor,
    this.surfaceColor,
  }) : items = List.unmodifiable(items) {
    if (items.length < 2 || items.length > 5) {
      throw ArgumentError('Use 2–5 tabs for a native bottom tab bar.');
    }
    if (selectedIndex < 0 || selectedIndex >= items.length) {
      throw RangeError.index(selectedIndex, items, 'selectedIndex');
    }
  }
  final List<GlassNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final AndroidNavigationBuilder? androidBuilder;

  /// Android hold/drag preview in logical tab coordinates; null ends/cancels it.
  /// Preview never commits navigation: the host still owns [onTap].
  final ValueChanged<double?>? onScrubChanged;

  /// Active destination and selector tint. Defaults to ColorScheme.primary.
  final Color? tintColor;

  /// Inactive icons and labels. Defaults to ColorScheme.onSurfaceVariant.
  final Color? unselectedColor;

  /// Glass surface tint. Defaults to ColorScheme.surface.
  /// Native iOS keeps UIKit's material; its appearance follows theme brightness.
  final Color? surfaceColor;
  @override
  State<PlatformGlassNavigationBar> createState() => _BarState();
}

class _BarState extends State<PlatformGlassNavigationBar> {
  bool glass = false;
  Map<String, Object?>? configuration;
  MethodChannel? channel;
  int revision = 0;
  ThemeData? hostTheme;
  final Map<IconData, Future<Uint8List>> iconImages = {};

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) _initialize();
  }

  Future<void> _initialize() async {
    try {
      final supported =
          await const MethodChannel(
            'platform_glass_navigation',
          ).invokeMethod<bool>('supportsGlass') ??
          false;
      if (!mounted || !supported) return;
      glass = true;
      await _update();
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  @override
  void didUpdateWidget(covariant PlatformGlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (glass) _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    hostTheme = Theme.of(context);
    // Inherited theme changes must also reach an already-created native view.
    if (glass) _update();
  }

  Future<Uint8List> _iconPng(IconData icon) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 25,
          color: Colors.white,
        ),
      ),
    );
    painter.layout();
    canvas.scale(3);
    painter.paint(
      canvas,
      Offset((30 - painter.width) / 2, (30 - painter.height) / 2),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(90, 90);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('Could not render tab icon');
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    } finally {
      image.dispose();
      picture.dispose();
      painter.dispose();
    }
  }

  Future<void> _update() async {
    final current = ++revision;
    final snapshot = widget;
    final theme = hostTheme;
    if (theme == null) return;
    final tint = snapshot.tintColor ?? theme.colorScheme.primary;
    final unselected =
        snapshot.unselectedColor ?? theme.colorScheme.onSurfaceVariant;
    try {
      final items = await Future.wait(
        snapshot.items.map(
          (item) async => {
            'label': item.label,
            'symbol': item.iosSymbol,
            'badge': item.badge,
            'image':
                item.iosImage ??
                (item.iosSymbol == null
                    ? await iconImages.putIfAbsent(
                        item.icon,
                        () => _iconPng(item.icon),
                      )
                    : null),
          },
        ),
      );
      if (!mounted || current != revision) return;
      final next = <String, Object?>{
        'items': items,
        'selected': snapshot.selectedIndex,
        'tint': tint.toARGB32(),
        'unselectedTint': unselected.toARGB32(),
        'brightness': theme.brightness.name,
      };
      if (channel != null) await channel!.invokeMethod<void>('update', next);
      if (mounted && current == revision) setState(() => configuration = next);
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'platform_glass_navigation',
      ),
    );
  }

  void _tap(int index) {
    if (index >= 0 && index < widget.items.length) {
      widget.onTap(index);
      // Restore the controlled selection when the app declines a tab change.
      if (glass) _update();
    }
  }

  @override
  void dispose() {
    revision++;
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = widget.tintColor ?? theme.colorScheme.primary;
    final unselected =
        widget.unselectedColor ?? theme.colorScheme.onSurfaceVariant;
    final surface = widget.surfaceColor ?? theme.colorScheme.surface;
    if (glass && configuration != null) {
      return SizedBox(
        height: 90 + MediaQuery.paddingOf(context).bottom,
        child: UiKitView(
          viewType: 'platform_glass_navigation/bar',
          creationParams: configuration,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: (id) async {
            channel = MethodChannel('platform_glass_navigation/bar/$id');
            channel!.setMethodCallHandler((call) async {
              if (mounted &&
                  call.method == 'selected' &&
                  call.arguments is int) {
                _tap(call.arguments as int);
              }
            });
            await _update();
          },
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return CupertinoTabBar(
        currentIndex: widget.selectedIndex,
        onTap: _tap,
        activeColor: tint,
        inactiveColor: unselected,
        backgroundColor: surface.withValues(alpha: 0.85),
        items: widget.items
            .map(
              (item) => BottomNavigationBarItem(
                label: item.label,
                icon: Icon(item.icon),
              ),
            )
            .toList(),
      );
    }
    if (widget.androidBuilder != null) {
      return widget.androidBuilder!(
        context,
        widget.items,
        widget.selectedIndex,
        _tap,
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _AndroidGlassBar(
        items: widget.items,
        selectedIndex: widget.selectedIndex,
        onTap: _tap,
        tintColor: tint,
        unselectedColor: unselected,
        surfaceColor: surface,
        onScrubChanged: widget.onScrubChanged,
      );
    }
    return NavigationBar(
      backgroundColor: surface,
      indicatorColor: tint.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final style =
            NavigationBarTheme.of(context).labelTextStyle?.resolve(states) ??
            theme.textTheme.labelMedium ??
            const TextStyle();
        return style.copyWith(
          color: states.contains(WidgetState.selected) ? tint : unselected,
        );
      }),
      selectedIndex: widget.selectedIndex,
      onDestinationSelected: _tap,
      destinations: widget.items
          .asMap()
          .entries
          .map(
            (entry) => NavigationDestination(
              label: entry.value.label,
              icon: entry.value.badge == null
                  ? Icon(
                      entry.value.icon,
                      color: entry.key == widget.selectedIndex
                          ? tint
                          : unselected,
                    )
                  : Badge(
                      label: Text(entry.value.badge!),
                      child: Icon(
                        entry.value.icon,
                        color: entry.key == widget.selectedIndex
                            ? tint
                            : unselected,
                      ),
                    ),
            ),
          )
          .toList(),
    );
  }
}

/// Native iOS 26 segmented tabs, with the caller's existing UI elsewhere.
class PlatformGlassSegmentedControl extends StatefulWidget {
  PlatformGlassSegmentedControl({
    super.key,
    required List<String> labels,
    required this.selectedIndex,
    required this.onTap,
    required this.fallbackBuilder,
  }) : labels = List.unmodifiable(labels) {
    if (labels.length < 2) throw ArgumentError('Use at least two segments.');
    if (selectedIndex < 0 || selectedIndex >= labels.length) {
      throw RangeError.index(selectedIndex, labels, 'selectedIndex');
    }
  }

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final WidgetBuilder fallbackBuilder;

  @override
  State<PlatformGlassSegmentedControl> createState() => _SegmentedState();
}

class _SegmentedState extends State<PlatformGlassSegmentedControl> {
  bool glass = false;
  MethodChannel? channel;
  Map<String, Object> get configuration => {
    'labels': widget.labels,
    'selected': widget.selectedIndex,
  };

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) _initialize();
  }

  Future<void> _initialize() async {
    try {
      final supported =
          await const MethodChannel(
            'platform_glass_navigation',
          ).invokeMethod<bool>('supportsGlass') ??
          false;
      if (mounted && supported) setState(() => glass = true);
    } catch (error, stack) {
      _report(error, stack);
    }
  }

  Future<void> _update() async {
    try {
      await channel?.invokeMethod<void>('update', configuration);
    } catch (error, stack) {
      if (mounted) _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'platform_glass_navigation',
      ),
    );
  }

  @override
  void didUpdateWidget(covariant PlatformGlassSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void dispose() {
    channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!glass) return widget.fallbackBuilder(context);
    return SizedBox(
      height: 48,
      child: UiKitView(
        viewType: 'platform_glass_navigation/segments',
        gestureRecognizers: {
          Factory<HorizontalDragGestureRecognizer>(
            HorizontalDragGestureRecognizer.new,
          ),
        },
        creationParams: configuration,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) async {
          if (!mounted) return;
          channel = MethodChannel('platform_glass_navigation/segments/$id');
          channel!.setMethodCallHandler((call) async {
            if (mounted && call.method == 'selected' && call.arguments is int) {
              final index = call.arguments as int;
              if (index >= 0 && index < widget.labels.length) {
                widget.onTap(index);
              }
              await _update();
            }
          });
          await _update();
        },
      ),
    );
  }
}
