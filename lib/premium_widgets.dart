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

/// Creative Animated Pop-up Dialog tailored for each couple status
class CreativeStatusDialog extends StatefulWidget {
  const CreativeStatusDialog({
    required this.status,
    required this.partnerName,
    this.onAction,
    super.key,
  });

  final String status;
  final String partnerName;
  final VoidCallback? onAction;

  @override
  State<CreativeStatusDialog> createState() => _CreativeStatusDialogState();
}

class _CreativeStatusDialogState extends State<CreativeStatusDialog>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.disposeWidget();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final isSleepy = status.contains('Resting') || status.contains('🌙') || status.contains('Sleep');
    final isMissingYou = status.contains('Missing') || status.contains('💗') || status.contains('Love');
    final isFeelingGood = status.contains('Feeling good') || status.contains('🌷') || status.contains('Happy');
    final isNeedCare = status.contains('Need some care') || status.contains('🫶') || status.contains('Care');
    final isTalkToMe = status.contains('Talk to me') || status.contains('☕') || status.contains('Chat');

    final emoji = status.isNotEmpty ? status.characters.first : '✨';
    final words = status.length > emoji.length ? status.substring(emoji.length).trim() : status;

    // Theme and styling based on status
    final List<Color> bgGradient;
    final Color accentColor;
    final Color textColor;
    final String subtitle;
    final String actionText;
    final Widget animatedScene;

    if (isSleepy) {
      bgGradient = const [Color(0xff120e24), Color(0xff221b3a), Color(0xff141029)];
      accentColor = const Color(0xffb8a9e5);
      textColor = const Color(0xfff3efff);
      subtitle = '${widget.partnerName} is tucked in & resting softly';
      actionText = 'Send sweet dreams 💤';
      animatedScene = _SleepyNightScene(
        pulse: _pulseController,
        particles: _particleController,
        emoji: emoji,
      );
    } else if (isMissingYou) {
      bgGradient = const [Color(0xffffeef3), Color(0xffffdbe5), Color(0xfffff5f8)];
      accentColor = const Color(0xffe64980);
      textColor = const Color(0xff2f233a);
      subtitle = '${widget.partnerName} is missing you warmly';
      actionText = 'Send love back 💖';
      animatedScene = _MissingYouScene(
        pulse: _pulseController,
        particles: _particleController,
        emoji: emoji,
      );
    } else if (isFeelingGood) {
      bgGradient = const [Color(0xfff3fced), Color(0xffe2f7d8), Color(0xfffffcf2)];
      accentColor = const Color(0xff38b000);
      textColor = const Color(0xff223a1a);
      subtitle = '${widget.partnerName} is radiant and full of joy';
      actionText = 'Celebrate her joy ✨';
      animatedScene = _FeelingGoodScene(
        pulse: _pulseController,
        particles: _particleController,
        emoji: emoji,
      );
    } else if (isNeedCare) {
      bgGradient = const [Color(0xfffff4f0), Color(0xffffe6de), Color(0xfffff9f6)];
      accentColor = const Color(0xfff76707);
      textColor = const Color(0xff3a2620);
      subtitle = '${widget.partnerName} could use some gentle care & warmth';
      actionText = 'Send a warm hug 🫂';
      animatedScene = _NeedCareScene(
        pulse: _pulseController,
        particles: _particleController,
        emoji: emoji,
      );
    } else if (isTalkToMe) {
      bgGradient = const [Color(0xff2a1f18), Color(0xff3d2d23), Color(0xff1f1712)];
      accentColor = const Color(0xffd4a373);
      textColor = const Color(0xfffbf5ed);
      subtitle = '${widget.partnerName} is free and wants to chat';
      actionText = 'Let\'s talk ☕';
      animatedScene = _TalkToMeScene(
        pulse: _pulseController,
        particles: _particleController,
        emoji: emoji,
      );
    } else {
      bgGradient = [Colors.white, const Color(0xfff8f4fa)];
      accentColor = premiumPlum;
      textColor = premiumInk;
      subtitle = '${widget.partnerName} updated their feeling';
      actionText = 'Send a reply 💌';
      animatedScene = _DefaultStatusScene(
        pulse: _pulseController,
        emoji: emoji,
        accent: accentColor,
      );
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: bgGradient,
            ),
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isSleepy || isTalkToMe ? 0.35 : 0.22),
                blurRadius: 40,
                spreadRadius: 6,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(
              color: accentColor.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Interactive animated scene
                      SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: animatedScene,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        words,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textColor.withValues(alpha: 0.8),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: isSleepy || isTalkToMe ? Colors.white : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).pop();
                          widget.onAction?.call();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button top right
                Positioned(
                  top: 14,
                  right: 14,
                  child: IconButton(
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor: textColor.withValues(alpha: 0.08),
                    ),
                    icon: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.7)),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on AnimationController {
  void disposeWidget() => dispose();
}

/// Sleepy Night Scene: Moon pulsing with animated rising Zzzs
class _SleepyNightScene extends StatelessWidget {
  const _SleepyNightScene({
    required this.pulse,
    required this.particles,
    required this.emoji,
  });

  final Animation<double> pulse;
  final Animation<double> particles;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, particles]),
      builder: (context, _) {
        final t = particles.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft glowing night halo
            Container(
              width: 110 + (pulse.value * 14),
              height: 110 + (pulse.value * 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff9d84e8).withValues(alpha: 0.35),
                    blurRadius: 36,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
            // Twinkling background stars
            Positioned(
              left: 35,
              top: 25,
              child: Opacity(
                opacity: 0.3 + (math.sin(t * math.pi * 2) * 0.4).abs(),
                child: const Text('✨', style: TextStyle(fontSize: 14)),
              ),
            ),
            Positioned(
              right: 40,
              bottom: 25,
              child: Opacity(
                opacity: 0.3 + (math.cos(t * math.pi * 2) * 0.4).abs(),
                child: const Text('⭐', style: TextStyle(fontSize: 12)),
              ),
            ),
            // Central Moon
            Transform.rotate(
              angle: -0.15 + (math.sin(t * math.pi * 2) * 0.08),
              child: Transform.scale(
                scale: 1.0 + (pulse.value * 0.08),
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 66),
                ),
              ),
            ),
            // Rising Zzz particle 1
            Positioned(
              right: 80 - (t * 22),
              top: 80 - (t * 65),
              child: Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: 0.2,
                  child: Text(
                    'z',
                    style: TextStyle(
                      fontSize: 14 + (t * 8),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xffe0d4ff),
                    ),
                  ),
                ),
              ),
            ),
            // Rising Zzz particle 2 (staggered)
            Positioned(
              right: 65 - (((t + 0.33) % 1.0) * 28),
              top: 80 - (((t + 0.33) % 1.0) * 70),
              child: Opacity(
                opacity: (1.0 - ((t + 0.33) % 1.0)).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: 0.15,
                  child: Text(
                    'Z',
                    style: TextStyle(
                      fontSize: 16 + (((t + 0.33) % 1.0) * 10),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xffcfbcff),
                    ),
                  ),
                ),
              ),
            ),
            // Rising Zzz particle 3 (staggered)
            Positioned(
              right: 50 - (((t + 0.66) % 1.0) * 32),
              top: 80 - (((t + 0.66) % 1.0) * 75),
              child: Opacity(
                opacity: (1.0 - ((t + 0.66) % 1.0)).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: 0.3,
                  child: Text(
                    'Zzz',
                    style: TextStyle(
                      fontSize: 18 + (((t + 0.66) % 1.0) * 12),
                      fontWeight: FontWeight.w900,
                      color: const Color(0xffe8dcff),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Missing You Scene: Beating heart with floating hearts
class _MissingYouScene extends StatelessWidget {
  const _MissingYouScene({
    required this.pulse,
    required this.particles,
    required this.emoji,
  });

  final Animation<double> pulse;
  final Animation<double> particles;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, particles]),
      builder: (context, _) {
        final t = particles.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Soft rosy halo
            Container(
              width: 100 + (pulse.value * 20),
              height: 100 + (pulse.value * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xfff06595).withValues(alpha: 0.30),
                    blurRadius: 32,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
            // Central beating heart
            Transform.scale(
              scale: 0.95 + (pulse.value * 0.18),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 66),
              ),
            ),
            // Floating mini heart 1
            Positioned(
              left: 65 + (math.sin(t * math.pi * 2) * 14),
              bottom: 25 + (t * 85),
              child: Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0),
                child: const Text('💕', style: TextStyle(fontSize: 18)),
              ),
            ),
            // Floating mini heart 2
            Positioned(
              right: 65 + (math.cos((t + 0.5) * math.pi * 2) * 16),
              bottom: 25 + (((t + 0.5) % 1.0) * 85),
              child: Opacity(
                opacity: (1.0 - ((t + 0.5) % 1.0)).clamp(0.0, 1.0),
                child: const Text('💖', style: TextStyle(fontSize: 16)),
              ),
            ),
            // Floating sparkle
            Positioned(
              left: 105,
              top: 15 + (((t + 0.25) % 1.0) * 30),
              child: Opacity(
                opacity: (1.0 - ((t + 0.25) % 1.0)).clamp(0.0, 1.0),
                child: const Text('✨', style: TextStyle(fontSize: 14)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Feeling Good Scene: Bouncing flower with radiant sparkles
class _FeelingGoodScene extends StatelessWidget {
  const _FeelingGoodScene({
    required this.pulse,
    required this.particles,
    required this.emoji,
  });

  final Animation<double> pulse;
  final Animation<double> particles;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, particles]),
      builder: (context, _) {
        final t = particles.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Sunshine glow
            Container(
              width: 105 + (pulse.value * 16),
              height: 105 + (pulse.value * 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xff51cf66).withValues(alpha: 0.28),
                    blurRadius: 36,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
            // Bouncing blossom
            Transform.translate(
              offset: Offset(0, -6 * math.sin(pulse.value * math.pi)),
              child: Transform.rotate(
                angle: math.sin(t * math.pi * 2) * 0.12,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 66),
                ),
              ),
            ),
            // Floating sparkles
            Positioned(
              left: 55 + (t * 20),
              top: 30 + (math.sin(t * math.pi * 2) * 15),
              child: Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0),
                child: const Text('✨', style: TextStyle(fontSize: 18)),
              ),
            ),
            Positioned(
              right: 55 + (((t + 0.4) % 1.0) * 20),
              top: 35 + (math.cos(t * math.pi * 2) * 15),
              child: Opacity(
                opacity: (1.0 - ((t + 0.4) % 1.0)).clamp(0.0, 1.0),
                child: const Text('🌸', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Need Care Scene: Warm hug ripples
class _NeedCareScene extends StatelessWidget {
  const _NeedCareScene({
    required this.pulse,
    required this.particles,
    required this.emoji,
  });

  final Animation<double> pulse;
  final Animation<double> particles;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, particles]),
      builder: (context, _) {
        final t = particles.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Expanding warm hug ripples
            Container(
              width: 80 + (t * 55),
              height: 80 + (t * 55),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xffff922b).withValues(alpha: (1.0 - t) * 0.4),
                  width: 2.5,
                ),
              ),
            ),
            // Warm center glow
            Container(
              width: 90 + (pulse.value * 12),
              height: 90 + (pulse.value * 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffff922b).withValues(alpha: 0.28),
                    blurRadius: 30,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
            // Heart-hands icon
            Transform.scale(
              scale: 0.94 + (pulse.value * 0.12),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 66),
              ),
            ),
            // Tender sparkles
            Positioned(
              left: 70,
              top: 25,
              child: Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0),
                child: const Text('🫂', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Talk To Me Scene: Rising steam particles from coffee cup
class _TalkToMeScene extends StatelessWidget {
  const _TalkToMeScene({
    required this.pulse,
    required this.particles,
    required this.emoji,
  });

  final Animation<double> pulse;
  final Animation<double> particles;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([pulse, particles]),
      builder: (context, _) {
        final t = particles.value;
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Warm cafe aroma glow
            Container(
              width: 100 + (pulse.value * 14),
              height: 100 + (pulse.value * 14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xffd4a373).withValues(alpha: 0.32),
                    blurRadius: 32,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
            // Coffee cup
            Transform.scale(
              scale: 0.96 + (pulse.value * 0.08),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 66),
              ),
            ),
            // Rising steam curl 1
            Positioned(
              left: 130 + (math.sin(t * math.pi * 2) * 8),
              top: 60 - (t * 45),
              child: Opacity(
                opacity: (1.0 - t).clamp(0.0, 1.0),
                child: const Text('~', style: TextStyle(fontSize: 22, color: Color(0xffe8d5c4), fontWeight: FontWeight.bold)),
              ),
            ),
            // Rising steam curl 2 (staggered)
            Positioned(
              right: 130 + (math.cos((t + 0.5) * math.pi * 2) * 8),
              top: 60 - (((t + 0.5) % 1.0) * 45),
              child: Opacity(
                opacity: (1.0 - ((t + 0.5) % 1.0)).clamp(0.0, 1.0),
                child: const Text('~', style: TextStyle(fontSize: 24, color: Color(0xffe8d5c4), fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Default Fallback Scene
class _DefaultStatusScene extends StatelessWidget {
  const _DefaultStatusScene({
    required this.pulse,
    required this.emoji,
    required this.accent,
  });

  final Animation<double> pulse;
  final String emoji;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 95 + (pulse.value * 15),
            height: 95 + (pulse.value * 15),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 6,
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.95 + (pulse.value * 0.12),
            child: Text(emoji, style: const TextStyle(fontSize: 66)),
          ),
        ],
      ),
    );
  }
}

