import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_design.dart';

/// Static vector decoration: no images, shaders, timers, or animation controllers.
class FloralBackdrop extends StatelessWidget {
  const FloralBackdrop(
      {required this.child,
      this.color = AppPalette.canvas,
      this.dense = false,
      super.key});
  final Widget child;
  final Color color;
  final bool dense;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: Stack(children: [
          Positioned.fill(
              child: IgnorePointer(
                  child: RepaintBoundary(
                      child:
                          CustomPaint(painter: _FloralPainter(dense: dense))))),
          child,
        ]),
      );
}

class FloralEmblem extends StatelessWidget {
  const FloralEmblem({this.size = 48, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FloralPainter(emblem: true)));
}

class _FloralPainter extends CustomPainter {
  const _FloralPainter({this.dense = false, this.emblem = false});
  final bool dense;
  final bool emblem;
  void flower(Canvas canvas, Offset center, double radius, double opacity) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final leaf = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xff829878).withValues(alpha: opacity * .65);
    canvas.save();
    canvas.rotate(-.6);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(radius * .9, radius * .9),
            width: radius * .9,
            height: radius * .34),
        leaf);
    canvas.restore();
    final petal = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xffbd7e9c).withValues(alpha: opacity);
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(0, -radius * .48),
              width: radius * .57,
              height: radius * .95),
          petal);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, radius * .19,
        Paint()..color = AppPalette.plum.withValues(alpha: opacity * .8));
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (emblem) {
      flower(canvas, size.center(Offset.zero), size.shortestSide * .40, .65);
      return;
    }
    flower(canvas, Offset(size.width - 18, 30), 30, dense ? .18 : .13);
    if (dense) {
      flower(canvas, Offset(8, size.height - 30), 28, .16);
      flower(canvas, Offset(18, size.height * .34), 24, .16);
      flower(canvas, Offset(size.width - 8, size.height * .68), 34, .14);
      flower(canvas, Offset(size.width * .27, size.height * .16), 18, .12);
      flower(canvas, Offset(size.width * .72, size.height * .86), 22, .13);
    }
  }

  @override
  bool shouldRepaint(covariant _FloralPainter old) =>
      old.dense != dense || old.emblem != emblem;
}
