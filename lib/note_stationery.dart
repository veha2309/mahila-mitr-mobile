import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_design.dart';
import 'note_design.dart';

class NoteStationery extends StatelessWidget {
  const NoteStationery(
      {required this.design,
      required this.child,
      this.padding = const EdgeInsets.all(22),
      super.key});
  final NoteDesign design;
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(22), boxShadow: [
          BoxShadow(
              color: design.accent.withValues(alpha: .06),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ]),
        child: Material(
            color: design.color,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: design.accent.withValues(alpha: .2))),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
                painter: _PaperBorder(design),
                child: Padding(padding: padding, child: child))),
      );
}

class NoteMotif extends StatelessWidget {
  const NoteMotif({required this.design, this.height = 72, super.key});
  final NoteDesign design;
  final double height;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
          child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _MotifPainter(design)),
      ));
}

class NoteStylePicker extends StatelessWidget {
  const NoteStylePicker(
      {required this.selected,
      required this.onSelected,
      this.enabled = true,
      super.key});
  final String selected;
  final ValueChanged<String> onSelected;
  final bool enabled;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
            constraints.maxWidth < 250;
        final width =
            stacked ? constraints.maxWidth : (constraints.maxWidth - 16) / 3;
        return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: noteDesign.entries.map((entry) {
              final design = entry.value;
              final active = selected == entry.key;
              final label = Row(children: [
                Expanded(
                    child: Text(design.title,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: active ? design.accent : AppPalette.muted))),
                if (active)
                  Icon(Icons.check_circle, size: 14, color: design.accent),
              ]);
              return SizedBox(
                  width: width,
                  child: Semantics(
                    selected: active,
                    button: true,
                    child: Material(
                      color: design.color,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: active ? design.accent : AppPalette.border,
                              width: active ? 1.4 : 1)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('note-style-${entry.key}'),
                        onTap: enabled ? () => onSelected(entry.key) : null,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: stacked
                              ? Row(children: [
                                  SizedBox(
                                      width: 64,
                                      child: NoteMotif(
                                          design: design, height: 46)),
                                  const SizedBox(width: 12),
                                  Expanded(child: label),
                                ])
                              : Column(children: [
                                  NoteMotif(design: design, height: 46),
                                  const SizedBox(height: 8),
                                  label
                                ]),
                        ),
                      ),
                    ),
                  ));
            }).toList());
      });
}

class _PaperBorder extends CustomPainter {
  const _PaperBorder(this.design);
  final NoteDesign design;
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = design.accent.withValues(alpha: .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(7), const Radius.circular(16)),
        ink);
    if (design.kind == 'letter') {
      // A folded paper corner, kept in the margin rather than behind the text.
      final fold = Path()
        ..moveTo(size.width - 27, 7)
        ..lineTo(size.width - 27, 25)
        ..lineTo(size.width - 9, 25);
      canvas.drawPath(fold, ink);
    } else if (design.kind == 'star') {
      for (final x in [19.0, size.width - 19]) {
        canvas.drawCircle(Offset(x, size.height - 19), 1.5,
            Paint()..color = design.accent.withValues(alpha: .3));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PaperBorder old) => old.design != design;
}

class _MotifPainter extends CustomPainter {
  const _MotifPainter(this.design);
  final NoteDesign design;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 180, size.height / 80);
    canvas.save();
    canvas.translate(
        (size.width - 180 * scale) / 2, (size.height - 80 * scale) / 2);
    canvas.scale(scale);
    final ink = Paint()
      ..color = design.accent.withValues(alpha: .65)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (design.kind == 'letter') {
      final envelope = RRect.fromRectAndRadius(
          const Rect.fromLTWH(42, 15, 96, 56), const Radius.circular(5));
      canvas.drawRRect(
          envelope, Paint()..color = Colors.white.withValues(alpha: .6));
      canvas.drawRRect(envelope, ink);
      canvas.drawPath(
          Path()
            ..moveTo(43, 18)
            ..lineTo(90, 49)
            ..lineTo(137, 18),
          ink);
      canvas.drawPath(
          Path()
            ..moveTo(43, 69)
            ..lineTo(74, 43)
            ..moveTo(137, 69)
            ..lineTo(106, 43),
          ink);
      canvas.drawCircle(
          const Offset(90, 48), 10, Paint()..color = design.accent);
      canvas.drawCircle(
          const Offset(90, 48),
          6.5,
          Paint()
            ..color = const Color(0xfffff8ed)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .8);
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3;
        canvas.drawCircle(
            Offset(90 + math.cos(angle) * 2.5, 48 + math.sin(angle) * 2.5),
            1.4,
            Paint()..color = const Color(0xfffff8ed));
      }
    } else if (design.kind == 'bloom') {
      final stem = Paint()
        ..color = const Color(0xff8c9b7d)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
          Path()
            ..moveTo(90, 73)
            ..quadraticBezierTo(70, 42, 44, 45)
            ..moveTo(90, 73)
            ..quadraticBezierTo(110, 42, 136, 45)
            ..moveTo(90, 73)
            ..lineTo(90, 38),
          stem);
      for (final leaf in [const Offset(65, 55), const Offset(115, 55)]) {
        canvas.save();
        canvas.translate(leaf.dx, leaf.dy);
        canvas.rotate(leaf.dx < 90 ? -.6 : .6);
        canvas.drawOval(const Rect.fromLTWH(-10, -4, 20, 8),
            Paint()..color = const Color(0xffbdc9af).withValues(alpha: .65));
        canvas.restore();
      }
      flower(canvas, const Offset(90, 26), 19);
      flower(canvas, const Offset(44, 43), 12);
      flower(canvas, const Offset(136, 43), 12);
    } else {
      final points = [
        const Offset(37, 49),
        const Offset(69, 26),
        const Offset(105, 45),
        const Offset(140, 21)
      ];
      final line = Paint()
        ..color = design.accent.withValues(alpha: .24)
        ..strokeWidth = 1;
      for (var i = 1; i < points.length; i++) {
        canvas.drawLine(points[i - 1], points[i], line);
      }
      for (var i = 0; i < points.length; i++) {
        spark(canvas, points[i], i.isEven ? 9 : 6);
      }
      spark(canvas, const Offset(70, 64), 3);
      spark(canvas, const Offset(127, 65), 4);
      canvas.drawCircle(const Offset(23, 23), 1.4,
          Paint()..color = design.accent.withValues(alpha: .5));
      canvas.drawCircle(const Offset(155, 51), 1.4,
          Paint()..color = design.accent.withValues(alpha: .5));
    }
    canvas.restore();
  }

  void flower(Canvas canvas, Offset center, double radius) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 3);
      final oval = Rect.fromCenter(
          center: Offset(0, -radius * .47),
          width: radius * .55,
          height: radius * .9);
      canvas.drawOval(
          oval, Paint()..color = design.accent.withValues(alpha: .1));
      canvas.drawOval(
          oval,
          Paint()
            ..color = design.accent.withValues(alpha: .65)
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke);
      canvas.restore();
    }
    canvas.drawCircle(
        Offset.zero, radius * .16, Paint()..color = design.accent);
    canvas.restore();
  }

  void spark(Canvas canvas, Offset center, double radius) {
    final shape = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx + radius * .2, center.dy - radius * .2,
          center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx + radius * .2, center.dy + radius * .2,
          center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx - radius * .2, center.dy + radius * .2,
          center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx - radius * .2, center.dy - radius * .2,
          center.dx, center.dy - radius)
      ..close();
    canvas.drawPath(
        shape, Paint()..color = design.accent.withValues(alpha: .7));
  }

  @override
  bool shouldRepaint(covariant _MotifPainter old) => old.design != design;
}
