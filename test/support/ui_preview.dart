import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';

Future<void> loadPreviewFonts() async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final font = File(
      '${Platform.environment['WINDIR'] ?? 'C:/Windows'}/Fonts/segoeui.ttf');
  final loader = FontLoader('PreviewSans')
    ..addFont(font.readAsBytes().then(ByteData.sublistView));
  await loader.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(File.fromUri(File(Platform.resolvedExecutable)
            .parent
            .parent
            .parent
            .uri
            .resolve('material_fonts/MaterialIcons-Regular.otf'))
        .readAsBytes()
        .then(ByteData.sublistView));
  await icons.load();
}

ThemeData previewTheme() {
  final theme = buildAppTheme();
  if (!const bool.fromEnvironment('CAPTURE_UI')) return theme;
  return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'PreviewSans'),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          hintStyle: const TextStyle(
              fontFamily: 'PreviewSans', color: AppPalette.muted),
          labelStyle: const TextStyle(
              fontFamily: 'PreviewSans', color: AppPalette.muted)),
      filledButtonTheme: FilledButtonThemeData(
          style: theme.filledButtonTheme.style!.copyWith(
              textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge!
                  .copyWith(fontFamily: 'PreviewSans')))));
}

Future<void> capturePreview(
    WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final render =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final originalShadows = debugDisableShadows;
  try {
    debugDisableShadows = false;
    void repaint(RenderObject object) {
      object.markNeedsPaint();
      object.visitChildren(repaint);
    }
    repaint(render);
    await tester.pump();
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/ui-previews/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  } finally {
    debugDisableShadows = originalShadows;
  }
}
