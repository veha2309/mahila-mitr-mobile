import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const canvas = Color(0xfff8f5f6);
  static const surface = Color(0xffffffff);
  static const plum = Color(0xff88445e);
  static const ink = Color(0xff282329);
  static const muted = Color(0xff777177);
  static const border = Color(0xffeae5e8);
  static const lilac = Color(0xfff3e7e9);
  static const sage = Color(0xffeaf0e5);
  static const forest = Color(0xff294e43);
  static const peach = Color(0xfff3d7c8);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.plum,
      primary: AppPalette.plum,
      surface: AppPalette.surface,
      secondary: const Color(0xff8a9b7c),
      error: const Color(0xffa43d55));
  final rounded =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppPalette.canvas,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          color: AppPalette.ink,
          fontSize: 32,
          height: 1.12,
          letterSpacing: -1,
          fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(
          color: AppPalette.ink,
          fontSize: 25,
          height: 1.2,
          letterSpacing: -.6,
          fontWeight: FontWeight.w600),
      titleLarge: TextStyle(
          color: AppPalette.ink,
          fontSize: 19,
          height: 1.25,
          fontWeight: FontWeight.w600),
      titleMedium: TextStyle(
          color: AppPalette.ink, fontSize: 16, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: AppPalette.ink, fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(color: AppPalette.ink, fontSize: 14, height: 1.45),
      bodySmall: TextStyle(color: AppPalette.muted, fontSize: 12, height: 1.45),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    ),
    appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.canvas,
        foregroundColor: AppPalette.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: AppPalette.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppPalette.lilac,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? AppPalette.plum
              : AppPalette.muted)),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: rounded,
            backgroundColor: AppPalette.plum,
            foregroundColor: Colors.white,
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: rounded,
            side: const BorderSide(color: AppPalette.border),
            foregroundColor: AppPalette.plum,
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48), foregroundColor: AppPalette.plum)),
    iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
            minimumSize: const Size(48, 48), foregroundColor: AppPalette.plum)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppPalette.muted),
      hintStyle: const TextStyle(color: AppPalette.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.plum, width: 1.6)),
    ),
    chipTheme: ChipThemeData(
        backgroundColor: AppPalette.surface,
        selectedColor: AppPalette.lilac,
        side: const BorderSide(color: AppPalette.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7)),
    segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? AppPalette.plum
                    : AppPalette.surface),
            foregroundColor: WidgetStateProperty.resolveWith((states) =>
                states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppPalette.muted),
            side: const WidgetStatePropertyAll(
                BorderSide(color: AppPalette.border)),
            textStyle: const WidgetStatePropertyAll(
                TextStyle(fontSize: 12, fontWeight: FontWeight.w700)))),
    bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)))),
    dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppPalette.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    dividerTheme: const DividerThemeData(
        color: AppPalette.border, thickness: 1, space: 24),
    listTileTheme: const ListTileThemeData(
      iconColor: AppPalette.plum,
      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      titleTextStyle: TextStyle(
          color: AppPalette.ink, fontSize: 15, fontWeight: FontWeight.w600),
      subtitleTextStyle:
          TextStyle(color: AppPalette.muted, fontSize: 13, height: 1.45),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppPalette.plum),
  );
}

class AppTextInput extends StatelessWidget {
  const AppTextInput(
      {required this.controller,
      required this.label,
      this.keyboard,
      this.lines = 1,
      this.maxLength,
      super.key});
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final int lines;
  final int? maxLength;
  @override
  Widget build(BuildContext context) => TextField(
        // Keep the text scroll offset separate from an ancestor ExpansionTile's bool.
        key: PageStorageKey<TextEditingController>(controller),
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        maxLength: maxLength,
        decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppPalette.border))),
      );
}

class AppPage extends StatelessWidget {
  const AppPage({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final inset = constraints.maxWidth < 360 ? 16.0 : 20.0;
        final horizontal = constraints.maxWidth > 680
            ? (constraints.maxWidth - 632) / 2
            : inset;
        return ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal,
                40 + MediaQuery.paddingOf(context).bottom),
            children: children);
      });
}

class AppPageHeading extends StatelessWidget {
  const AppPageHeading(
      {required this.eyebrow,
      required this.title,
      this.subtitle,
      this.trailing,
      super.key});
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (eyebrow.isNotEmpty) ...[
            Text(eyebrow,
                style: const TextStyle(color: AppPalette.muted, fontSize: 13)),
            const SizedBox(height: 8),
          ],
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.headlineLarge)),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 10),
            Text(subtitle!,
                style: const TextStyle(
                    color: AppPalette.muted, fontSize: 14, height: 1.5))
          ],
        ]),
      );
}

class AppSurface extends StatelessWidget {
  const AppSurface(
      {required this.title,
      required this.children,
      this.color = AppPalette.surface,
      super.key});
  final String title;
  final List<Widget> children;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
          color: color,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppPalette.border)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              ...children,
            ]),
          )));
}

class AppActionTile extends StatelessWidget {
  const AppActionTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      this.color = AppPalette.lilac,
      super.key});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
        color: AppPalette.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppPalette.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: AppPalette.plum, size: 24)),
                const Spacer(),
                const Icon(Icons.arrow_forward,
                    size: 17, color: AppPalette.muted),
              ]),
              const SizedBox(height: 18),
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.ink)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, height: 1.4, color: AppPalette.muted)),
              ],
            ]),
          ),
        ),
      );
}

class AppActionPair extends StatelessWidget {
  const AppActionPair({required this.first, required this.second, super.key});
  final Widget first;
  final Widget second;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 12), second]);
        }
        return IntrinsicHeight(
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              Expanded(child: first),
              const SizedBox(width: 12),
              Expanded(child: second)
            ]));
      });
}

String greetingForHour(int hour) => hour < 12
    ? 'Good morning'
    : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
