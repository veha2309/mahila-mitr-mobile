import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'navigation_card_stack.dart';
import 'app_design.dart';

const premiumPlum = AppPalette.plum;
const premiumInk = AppPalette.ink;
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
            borderRadius: BorderRadius.circular(12),
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
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppPalette.border),
        ),
        child: Column(children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppPalette.lilac, shape: BoxShape.circle),
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
  const AnimatedTabStack(
      {required this.index,
      required this.children,
      required this.reduceMotion,
      this.previewPosition,
      this.navigationAction = 0,
      super.key});
  final int index;
  final List<Widget> children;
  final bool reduceMotion;
  final double? previewPosition;
  final int navigationAction;
  @override
  Widget build(BuildContext context) => NavigationCardStack(
      index: index,
      reduceMotion: reduceMotion,
      previewPosition: previewPosition,
      navigationAction: navigationAction,
      children: children);
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
    this.cycleLength = 28,
    this.onViewCalendar,
    this.periodInProgress = false,
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
  final int cycleLength;
  final VoidCallback? onViewCalendar;
  final bool periodInProgress;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfff5dde6), Color(0xfff9ece3)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xffecd3dc)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1088445e), blurRadius: 24, offset: Offset(0, 10))
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.water_drop_outlined,
                size: 18, color: AppPalette.plum),
            const SizedBox(width: 8),
            const Expanded(
                child: Text('Cycle overview',
                    style: TextStyle(
                        color: AppPalette.plum,
                        fontSize: 13,
                        fontWeight: FontWeight.w600))),
            if (onViewCalendar != null)
              IconButton(
                  onPressed: onViewCalendar,
                  tooltip: 'Open calendar',
                  icon: const Icon(Icons.calendar_month_outlined, size: 20))
            else if (isCheckedIn)
              const Icon(Icons.check_circle, size: 18, color: AppPalette.plum),
          ]),
          const SizedBox(height: 22),
          LayoutBuilder(builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
            final stacked = constraints.maxWidth < 275 || largeText;
            final wheelSize = largeText ? 210.0 : 152.0;
            final wheel = Semantics(
              label: cycleDay == null
                  ? 'No cycle data'
                  : 'Cycle day $cycleDay. Estimated cycle length $cycleLength days.',
              child: ExcludeSemantics(
                  child: CustomPaint(
                painter: _CycleDayDial(day: cycleDay, length: cycleLength),
                child: SizedBox(
                  width: wheelSize,
                  height: wheelSize,
                  child: Center(
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('DAY',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2,
                              color: AppPalette.plum,
                              fontWeight: FontWeight.w600)),
                      Text(cycleDay?.toString() ?? '—',
                          style: const TextStyle(
                              fontSize: 52,
                              height: 1.1,
                              letterSpacing: -2,
                              color: AppPalette.ink,
                              fontWeight: FontWeight.w500)),
                      if (cycleDay != null)
                        Text('of ~$cycleLength',
                            style: const TextStyle(
                                fontSize: 11, color: AppPalette.muted)),
                    ],
                  )),
                ),
              )),
            );
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    periodInProgress ? 'Period ongoing' : daysToGo == null
                        ? 'Get started'
                        : daysToGo! < 0
                            ? 'Update due'
                            : daysToGo == 0
                                ? 'Today'
                                : 'In $daysToGo days',
                    style: const TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        letterSpacing: -.7,
                        fontWeight: FontWeight.w500,
                        color: AppPalette.ink)),
                const SizedBox(height: 6),
                Text(
                    periodInProgress ? 'Until you mark it ended' : daysToGo == null
                        ? 'Add your last period'
                        : 'Next period estimate',
                    style:
                        const TextStyle(color: AppPalette.muted, fontSize: 12)),
                const SizedBox(height: 14),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .65),
                        borderRadius: BorderRadius.circular(9)),
                    child: Text(phase,
                        style: const TextStyle(
                            color: AppPalette.plum,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
              ],
            );
            if (stacked) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: wheel),
                    const SizedBox(height: 18),
                    summary
                  ]);
            }
            return Row(children: [
              wheel,
              const SizedBox(width: 20),
              Expanded(child: summary)
            ]);
          }),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.event_outlined,
                  color: AppPalette.plum, size: 19),
              const SizedBox(width: 9),
              Expanded(
                  child: Text(
                      periodInProgress ? 'Record an end date when your period ends.' : daysToGo == null
                          ? 'Log your first period to see an estimate.'
                          : 'Next period · $nextPeriodLabel',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w500))),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCheckIn,
                icon: Icon(isCheckedIn ? Icons.check_rounded : Icons.add,
                    size: 19),
                label: Text(isCheckedIn
                    ? 'Update today’s check-in'
                    : 'Check in for today'),
              )),
        ]),
      );
}

class _CycleDayDial extends CustomPainter {
  const _CycleDayDial({required this.day, required this.length});
  final int? day;
  final int length;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
        center, radius - 16, Paint()..color = const Color(0x88ffffff));
    canvas.drawCircle(
        center,
        radius - 22,
        Paint()
          ..color = const Color(0x35ffffff)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    // Each mark represents a day, positioned against the estimated cycle length.
    final marks = length.clamp(1, 120);
    final current = day == null ? -1 : (day! - 1).clamp(0, marks - 1);
    for (var i = 0; i < marks; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / marks;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = i == current ? 5 : 3
        ..color = i == current
            ? AppPalette.plum
            : i < current
                ? const Color(0xffba718f)
                : const Color(0xffdec4cf);
      if (i == current) {
        final marker = center + direction * (radius - 6);
        canvas.drawCircle(marker, 8, Paint()..color = const Color(0x2288445e));
      }
      canvas.drawLine(center + direction * (radius - 11),
          center + direction * (radius - (i == current ? 1 : 4)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CycleDayDial old) =>
      old.day != day || old.length != length;
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
  Widget build(BuildContext context) {
    final loggedCount = days.where(hasLog).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Daily log',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
          Text('$loggedCount/${days.length} logged',
              style: const TextStyle(color: AppPalette.muted, fontSize: 11)),
        ]),
        const SizedBox(height: 16),
        Row(
            children: days.map((date) {
          final logged = hasLog(date);
          final today = DateUtils.isSameDay(date, DateTime.now());
          final weekday =
              const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1];
          return Expanded(
              child: Semantics(
            button: true,
            label:
                '${date.day} ${date.month} ${date.year}, ${logged ? 'logged' : 'not logged'}',
            child: Material(
              color: today ? AppPalette.plum : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => onSelected(date),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Column(children: [
                    Text(weekday,
                        style: TextStyle(
                            fontSize: 10,
                            color: today ? Colors.white70 : AppPalette.muted)),
                    const SizedBox(height: 9),
                    Text('${date.day}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: today ? Colors.white : AppPalette.ink)),
                    const SizedBox(height: 9),
                    SizedBox(
                        height: 12,
                        child: Center(
                            child:
                                Icon(logged ? Icons.check_circle : Icons.circle,
                                    size: logged ? 12 : 5,
                                    color: today
                                        ? Colors.white
                                        : logged
                                            ? AppPalette.plum
                                            : AppPalette.border))),
                  ]),
                ),
              ),
            ),
          ));
        }).toList()),
      ]),
    );
  }
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
          color: AppPalette.sage,
          border: Border.all(color: AppPalette.border),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: AppPalette.plum, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: AppPalette.ink, fontWeight: FontWeight.w700)),
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
    );

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulseController.stop();
      _particleController.stop();
    } else {
      _pulseController.repeat(reverse: true);
      _particleController.repeat();
    }
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
    final isSleepy = status.contains('Resting') ||
        status.contains('🌙') ||
        status.contains('Sleep');
    final isMissingYou = status.contains('Missing') ||
        status.contains('💗') ||
        status.contains('Love');
    final isFeelingGood = status.contains('Feeling good') ||
        status.contains('🌷') ||
        status.contains('Happy');
    final isNeedCare = status.contains('Need some care') ||
        status.contains('🫶') ||
        status.contains('Care');
    final isTalkToMe = status.contains('Talk to me') ||
        status.contains('☕') ||
        status.contains('Chat');

    final emoji = status.isNotEmpty ? status.characters.first : '✨';
    final words = status.length > emoji.length
        ? status.substring(emoji.length).trim()
        : status;

    // Theme and styling based on status
    final List<Color> bgGradient;
    final Color accentColor;
    final Color textColor;
    final String subtitle;
    final String actionText;
    final Widget animatedScene;

    if (isSleepy) {
      bgGradient = const [
        Color(0xff120e24),
        Color(0xff221b3a),
        Color(0xff141029)
      ];
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
      bgGradient = const [
        Color(0xffffeef3),
        Color(0xffffdbe5),
        Color(0xfffff5f8)
      ];
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
      bgGradient = const [
        Color(0xfff3fced),
        Color(0xffe2f7d8),
        Color(0xfffffcf2)
      ];
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
      bgGradient = const [
        Color(0xfffff4f0),
        Color(0xffffe6de),
        Color(0xfffff9f6)
      ];
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
      bgGradient = const [
        Color(0xff2a1f18),
        Color(0xff3d2d23),
        Color(0xff1f1712)
      ];
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
                color: accentColor.withValues(
                    alpha: isSleepy || isTalkToMe ? 0.35 : 0.22),
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
                          foregroundColor: isSleepy || isTalkToMe
                              ? Colors.white
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
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
                    icon: Icon(Icons.close_rounded,
                        color: textColor.withValues(alpha: 0.7)),
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).pop(),
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
                  color: const Color(0xffff922b)
                      .withValues(alpha: (1.0 - t) * 0.4),
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
                child: const Text('~',
                    style: TextStyle(
                        fontSize: 22,
                        color: Color(0xffe8d5c4),
                        fontWeight: FontWeight.bold)),
              ),
            ),
            // Rising steam curl 2 (staggered)
            Positioned(
              right: 130 + (math.cos((t + 0.5) * math.pi * 2) * 8),
              top: 60 - (((t + 0.5) % 1.0) * 45),
              child: Opacity(
                opacity: (1.0 - ((t + 0.5) % 1.0)).clamp(0.0, 1.0),
                child: const Text('~',
                    style: TextStyle(
                        fontSize: 24,
                        color: Color(0xffe8d5c4),
                        fontWeight: FontWeight.bold)),
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
