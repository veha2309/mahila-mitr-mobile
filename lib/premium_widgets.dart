import 'dart:math' as math;

import 'package:flutter/material.dart';

const premiumPlum = Color(0xff6e4d73);
const premiumInk = Color(0xff2f233a);
const premiumRose = Color(0xffe9c7d1);
const premiumSage = Color(0xffb7c9b3);
const premiumCoral = Color(0xfff28c8c);

class PrivacyBanner extends StatelessWidget {
  const PrivacyBanner({
    required this.title,
    required this.body,
    this.icon = Icons.lock_outline_rounded,
    this.tone = const Color(0xfff4edf4),
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: '$title. $body',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: tone,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: premiumPlum.withValues(alpha: .10)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
              child: Icon(icon, color: premiumPlum, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(body,
                        style: TextStyle(
                            color: premiumInk.withValues(alpha: .68),
                            height: 1.35,
                            fontSize: 12)),
                  ]),
            ),
          ]),
        ),
      );
}

class ExpressiveEmptyState extends StatelessWidget {
  const ExpressiveEmptyState({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfffffbfc), Color(0xfff8edf3)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffeadde4)),
        ),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: premiumPlum, size: 30),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: premiumInk.withValues(alpha: .64), height: 1.4)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

class AnimatedTabStack extends StatelessWidget {
  const AnimatedTabStack({
    required this.index,
    required this.children,
    required this.reduceMotion,
    super.key,
  });

  final int index;
  final List<Widget> children;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => IndexedStack(
        index: index,
        sizing: StackFit.expand,
        children: children,
      );
}

class CycleTodayHero extends StatelessWidget {
  const CycleTodayHero({
    required this.cycleDay,
    required this.phase,
    required this.nextPeriodLabel,
    required this.daysToGo,
    required this.confidence,
    required this.isCheckedIn,
    required this.reduceMotion,
    required this.onCheckIn,
    this.guide = const SizedBox.shrink(),
    super.key,
  });

  final int? cycleDay;
  final String phase;
  final String nextPeriodLabel;
  final int? daysToGo;
  final String confidence;
  final bool isCheckedIn;
  final bool reduceMotion;
  final VoidCallback onCheckIn;
  final Widget guide;

  @override
  Widget build(BuildContext context) {
    final progress = cycleDay == null ? 0.0 : (cycleDay! / 28).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff76547b), Color(0xff5d3e67)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x296e4d73),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        const Positioned(
          right: -54,
          top: -70,
          child: _GlowOrb(size: 190, color: Color(0x22ffffff)),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Semantics(
                label: cycleDay == null
                    ? 'No cycle data yet'
                    : 'Cycle day $cycleDay, $phase phase',
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => CustomPaint(
                    painter: _CycleRingPainter(progress: value),
                    child: SizedBox(
                      width: 112,
                      height: 112,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(cycleDay?.toString() ?? '—',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    height: 1,
                                    fontWeight: FontWeight.w800)),
                            Text(cycleDay == null ? 'cycle day' : 'DAY',
                                style: const TextStyle(
                                    color: Color(0xffeadde8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(phase,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        daysToGo == null
                            ? 'Log your first period to begin your story.'
                            : '$daysToGo days until $nextPeriodLabel',
                        style: const TextStyle(
                            color: Color(0xffeee4ed), height: 1.35),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text('$confidence confidence',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ]),
              ),
            ]),
            guide,
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: premiumPlum,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: onCheckIn,
                icon: Icon(isCheckedIn
                    ? Icons.check_circle_rounded
                    : Icons.favorite_outline_rounded),
                label: Text(isCheckedIn
                    ? 'Update today’s check-in'
                    : 'Check in for today'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class WellnessHistoryStrip extends StatelessWidget {
  const WellnessHistoryStrip({
    required this.days,
    required this.hasLog,
    required this.onSelected,
    super.key,
  });

  final List<DateTime> days;
  final bool Function(DateTime) hasLog;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your week',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Small check-ins reveal meaningful patterns.',
              style: TextStyle(
                  color: premiumInk.withValues(alpha: .58), fontSize: 12)),
          const SizedBox(height: 14),
          Row(
            children: days.map((date) {
              final logged = hasLog(date);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              final weekday =
                  const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];
              return Expanded(
                child: Semantics(
                  button: true,
                  label:
                      '$weekday ${date.day}${logged ? ', wellness logged' : ', not logged'}',
                  child: InkWell(
                    onTap: () => onSelected(date),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: logged
                            ? premiumSage.withValues(alpha: .42)
                            : isToday
                                ? premiumRose.withValues(alpha: .32)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: isToday
                                ? premiumPlum
                                : const Color(0xffeee5e9)),
                      ),
                      child: Column(children: [
                        Text(weekday,
                            style: TextStyle(
                                fontSize: 10,
                                color: premiumInk.withValues(alpha: .55))),
                        const SizedBox(height: 6),
                        Text('${date.day}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Icon(
                          logged ? Icons.check_rounded : Icons.circle_outlined,
                          size: 14,
                          color: logged ? premiumPlum : const Color(0xffd8cbd1),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
}

class WellnessInsight extends StatelessWidget {
  const WellnessInsight({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xffeef4ec),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: premiumPlum, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body,
                  style: TextStyle(
                      color: premiumInk.withValues(alpha: .68),
                      height: 1.35,
                      fontSize: 12)),
            ]),
          ),
        ]),
      );
}

class AnimatedEnvelopeDialog extends StatelessWidget {
  const AnimatedEnvelopeDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.reduceMotion,
    super.key,
  });

  final String icon;
  final String title;
  final String message;
  final Color color;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
          duration:
              reduceMotion ? Duration.zero : const Duration(milliseconds: 520),
          curve: Curves.easeOutBack,
          builder: (context, value, child) => Transform.translate(
            offset: Offset(0, (1 - value) * 34),
            child: Transform.scale(
              scale: .86 + (.14 * value),
              child: Opacity(opacity: value.clamp(0, 1), child: child),
            ),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 54, 24, 20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x29000000),
                      blurRadius: 30,
                      offset: Offset(0, 16)),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .86),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, height: 1.45)),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.favorite_outline_rounded),
                  label: const Text('Keep this moment'),
                ),
              ]),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: -34,
              child: Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 6),
                  ),
                  child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 38))),
                ),
              ),
            ),
          ]),
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _CycleRingPainter extends CustomPainter {
  const _CycleRingPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9;
    final active = Paint()
      ..shader = const SweepGradient(
        colors: [Color(0xffffd6d6), Color(0xffb7c9b3), Colors.white],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;
    final bounds = rect.deflate(8);
    canvas.drawArc(bounds, 0, math.pi * 2, false, track);
    canvas.drawArc(bounds, -math.pi / 2, math.pi * 2 * progress, false, active);
  }

  @override
  bool shouldRepaint(covariant _CycleRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
