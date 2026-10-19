import 'package:flutter/material.dart';
import 'package:platform_glass_navigation/platform_glass_navigation.dart';
import 'app_design.dart';
import 'appearance_settings.dart';

class AppNavigation extends StatelessWidget {
  const AppNavigation(
      {required this.index,
      required this.onSelected,
      this.onScrubChanged,
      super.key});
  final int index;
  final ValueChanged<int> onSelected;
  final ValueChanged<double?>? onScrubChanged;
  @override
  Widget build(BuildContext context) {
    final effects = AppearanceScope.effectsOf(context);
    const items = [
      GlassNavigationItem(
          label: 'Home', icon: Icons.home_outlined, iosSymbol: 'house'),
      GlassNavigationItem(
          label: 'Insights',
          icon: Icons.insights_outlined,
          iosSymbol: 'chart.xyaxis.line'),
      GlassNavigationItem(
          label: 'Moments',
          icon: Icons.favorite_border_rounded,
          iosSymbol: 'heart'),
      GlassNavigationItem(
          label: 'Settings',
          icon: Icons.tune_rounded,
          iosSymbol: 'slider.horizontal.3'),
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (effects == VisualEffects.off || largeText) {
      return NavigationBar(
          height: 72 +
              (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2) * 48,
          selectedIndex: index,
          onDestinationSelected: onSelected,
          destinations: items
              .map((item) => NavigationDestination(
                  icon: Icon(item.icon), label: item.label))
              .toList());
    }
    // Reduced mode stays a capsule but skips shaders and animations on every platform.
    if (effects == VisualEffects.reduced) {
      return SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Material(
                  color: AppPalette.surface,
                  elevation: 0,
                  shape: const StadiumBorder(
                      side: BorderSide(color: AppPalette.border)),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                      children: items
                          .asMap()
                          .entries
                          .map((entry) => Expanded(
                              child: Semantics(
                                  selected: index == entry.key,
                                  button: true,
                                  child: InkWell(
                                      onTap: () => onSelected(entry.key),
                                      child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(entry.value.icon,
                                                    color: index == entry.key
                                                        ? AppPalette.plum
                                                        : AppPalette.muted,
                                                    size: 22),
                                                const SizedBox(height: 3),
                                                Text(entry.value.label,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: index ==
                                                                entry.key
                                                            ? FontWeight.w800
                                                            : FontWeight.w500)),
                                              ]))))))
                          .toList()))));
    }
    return PlatformGlassNavigationBar(
      items: items,
      selectedIndex: index,
      onTap: onSelected,
      onScrubChanged: onScrubChanged,
      tintColor: const Color(0xff563d60),
      unselectedColor: const Color(0xff4f5753),
      surfaceColor: AppPalette.surface,
    );
  }
}
