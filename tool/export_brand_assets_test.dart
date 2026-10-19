// Run explicitly: flutter test tool/export_brand_assets_test.dart
// Renders native icons from the same vector painter used by the app loader.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/brand_widgets.dart';

void main() {
  testWidgets('export floral launcher and splash assets', (tester) async {
    await tester.runAsync(() async {
      Future<void> render(String path, int size, {bool opaque = true}) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        if (opaque) {
          canvas.drawColor(const ui.Color(0xfff8f5f6), ui.BlendMode.src);
        }
        BrandFlowerPainter().paint(canvas, ui.Size.square(size.toDouble()));
        final picture = recorder.endRecording();
        final image = await picture.toImage(size, size);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      }

      await render('branding/app-icon.png', 1024);
      for (final entry in {
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192
      }.entries) {
        await render(
            'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png',
            entry.value);
      }
      final icons = Directory('ios/Runner/Assets.xcassets/AppIcon.appiconset');
      final contents =
          jsonDecode(await File('${icons.path}/Contents.json').readAsString())
              as Map<String, dynamic>;
      for (final item in contents['images'] as List) {
        if (item['filename'] == null) continue;
        final points = double.parse((item['size'] as String).split('x').first);
        final scale =
            double.parse((item['scale'] as String).replaceAll('x', ''));
        await render(
            '${icons.path}/${item['filename']}', (points * scale).round());
      }
      for (var scale = 1; scale <= 3; scale++) {
        await render(
            'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage${scale == 1 ? '' : '@${scale}x'}.png',
            192 * scale,
            opaque: false);
      }
      await render('web/favicon.png', 32);
      for (final size in [192, 512]) {
        await render('web/icons/Icon-$size.png', size);
        await render('web/icons/Icon-maskable-$size.png', size);
      }
    });
  });
}
