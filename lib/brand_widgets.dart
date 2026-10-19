import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_design.dart';

class BrandFlower extends StatelessWidget {
  const BrandFlower({this.size = 88, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: 'Mahila Mitr',
      child: SizedBox.square(
          dimension: size, child: CustomPaint(painter: BrandFlowerPainter())));
}

class FloralProgressIndicator extends StatefulWidget {
  const FloralProgressIndicator({this.size = 88, super.key});
  final double size;
  @override
  State<FloralProgressIndicator> createState() =>
      _FloralProgressIndicatorState();
}

class _FloralProgressIndicatorState extends State<FloralProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _petals = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  bool _reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _petals.stop();
    } else if (!_petals.isAnimating) {
      _petals.repeat();
    }
  }

  @override
  void dispose() {
    _petals.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Loading',
      child: SizedBox.square(
          dimension: widget.size,
          child: AnimatedBuilder(
              animation: _petals,
              builder: (context, _) => CustomPaint(
                  painter: BrandFlowerPainter(
                      phase: _reduced ? null : _petals.value)))));
}

/// Shared geometry for the loading flower and exported native app icons.
class BrandFlowerPainter extends CustomPainter {
  BrandFlowerPainter({this.phase});
  final double? phase;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 256, size.height / 256);
    final petal = Path()
      ..moveTo(128, 116)
      ..cubicTo(104, 98, 100, 56, 128, 44)
      ..cubicTo(156, 56, 152, 98, 128, 116)
      ..close();
    for (var i = 0; i < 6; i++) {
      final light = phase == null
          ? 1.0
          : .3 +
              .7 * (1 + math.cos(phase! * math.pi * 2 - i * math.pi / 3)) / 2;
      canvas.save();
      canvas.translate(128, 128);
      canvas.rotate(i * math.pi / 3);
      canvas.translate(-128, -128);
      canvas.drawPath(petal,
          Paint()..color = AppPalette.plum.withValues(alpha: light * .08));
      canvas.drawPath(
          petal,
          Paint()
            ..color = AppPalette.plum.withValues(alpha: light)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.5
            ..strokeJoin = StrokeJoin.round);
      canvas.restore();
    }
    final leaf = Path()
      ..moveTo(171, 175)
      ..quadraticBezierTo(191, 173, 190, 190)
      ..quadraticBezierTo(173, 192, 171, 175)
      ..close();
    canvas.drawPath(
        leaf,
        Paint()
          ..color = const Color(0xff8a9b7c)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5);
    canvas.drawCircle(
        const Offset(128, 128), 10, Paint()..color = AppPalette.plum);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BrandFlowerPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
