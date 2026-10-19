import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'app_design.dart';

/// Live tab cards: mounted once, transformed while the navigation lens is held.
class NavigationCardStack extends StatefulWidget {
  const NavigationCardStack(
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

  /// Increment only for navigation-bar selections. Other index changes snap.
  final int navigationAction;
  @override
  State<NavigationCardStack> createState() => _NavigationCardStackState();
}

class _NavigationCardStackState extends State<NavigationCardStack>
    with TickerProviderStateMixin {
  late final AnimationController _position = AnimationController.unbounded(
      vsync: this, value: widget.index.toDouble());
  late final AnimationController _lift = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 280));
  int _revision = 0;

  @override
  void didUpdateWidget(covariant NavigationCardStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion) {
      _revision++;
      _position.stop();
      _lift.stop();
      _position.value = widget.index.toDouble();
      _lift.value = 0;
      return;
    }
    if (oldWidget.index != widget.index &&
        oldWidget.navigationAction == widget.navigationAction) {
      // An in-screen shortcut, restoration, or app state update is not a gesture.
      _revision++;
      _position.stop();
      _lift.stop();
      _position.value = widget.index.toDouble();
      _lift.value = 0;
      return;
    }
    final preview = widget.previewPosition;
    if (preview != null) {
      _revision++;
      _position.stop();
      _position.value = preview.clamp(0, widget.children.length - 1).toDouble();
      if (oldWidget.previewPosition == null) _lift.forward();
    } else if (oldWidget.previewPosition != null) {
      final revision = ++_revision;
      _position
          .animateWith(SpringSimulation(
              const SpringDescription(mass: 1, stiffness: 400, damping: 36),
              _position.value,
              widget.index.toDouble(),
              0))
          .then((_) {
        if (mounted &&
            revision == _revision &&
            widget.previewPosition == null) {
          _lift.reverse();
        }
      });
    } else if (oldWidget.index != widget.index) {
      final revision = ++_revision;
      _position.animateTo(widget.index.toDouble(),
          duration: const Duration(milliseconds: 340),
          curve: Curves.easeInOutCubic);
      _lift
          .animateTo(.7,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic)
          .then((_) {
        if (mounted &&
            revision == _revision &&
            widget.previewPosition == null) {
          _lift.reverse();
        }
      });
    }
  }

  Widget _card(int i, double position, double lift, bool moving, double stride,
      double direction) {
    final distance = i - position;
    final depth = distance.abs().clamp(0.0, 1.0);
    final tilt = distance.clamp(-1.0, 1.0) * direction;
    final visible = moving ? distance.abs() < 1.4 : i == widget.index;
    final perspective = Matrix4.identity()
      ..setEntry(3, 2, .001)
      ..rotateY(-tilt * .09 * lift)
      ..rotateZ(tilt * .014 * lift);
    return Positioned.fill(
        key: ValueKey('navigation-card-$i'),
        child: Offstage(
            offstage: !visible,
            child: TickerMode(
                enabled: i == widget.index && !moving,
                child: ExcludeSemantics(
                    excluding: moving || i != widget.index,
                    child: IgnorePointer(
                        ignoring: moving || i != widget.index,
                        child: Transform.translate(
                            offset: Offset(distance * stride * direction,
                                (-8 + depth * 20) * lift),
                            child: Transform(
                                alignment: Alignment.center,
                                transform: perspective,
                                child: Transform.scale(
                                    scale: 1 - (.16 + depth * .025) * lift,
                                    child: Material(
                                        animationDuration: Duration.zero,
                                        color: AppPalette.canvas,
                                        elevation: lift * (18 - depth * 10),
                                        shadowColor: AppPalette.ink
                                            .withValues(alpha: .24),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                28 * lift),
                                            side: BorderSide(
                                                color: AppPalette.ink.withValues(
                                                    alpha: .08 * lift))),
                                        clipBehavior: Clip.antiAlias,
                                        child: RepaintBoundary(
                                            child: widget.children[i]))))))))));
  }

  @override
  void dispose() {
    _position.dispose();
    _lift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
          animation: Listenable.merge([_position, _lift]),
          builder: (context, _) {
            final lift = widget.reduceMotion
                ? 0.0
                : Curves.easeOutCubic.transform(_lift.value);
            final position = widget.reduceMotion
                ? widget.index.toDouble()
                : _position.value.clamp(0.0, widget.children.length - 1.0);
            final moving = !widget.reduceMotion &&
                (widget.previewPosition != null ||
                    _position.isAnimating ||
                    _lift.isAnimating ||
                    lift > .001);
            final stride = constraints.maxWidth * (1 - .14 * lift);
            final direction =
                Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
            final paintOrder = List.generate(widget.children.length, (i) => i)
              ..sort((a, b) =>
                  (b - position).abs().compareTo((a - position).abs()));
            return DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                      Color.lerp(
                          AppPalette.canvas, AppPalette.border, lift * .75)!,
                      Color.lerp(
                          AppPalette.canvas, AppPalette.lilac, lift * .6)!
                    ])),
                child: Stack(
                    clipBehavior: Clip.hardEdge,
                    fit: StackFit.expand,
                    children: paintOrder
                        .map((i) =>
                            _card(i, position, lift, moving, stride, direction))
                        .toList()));
          }));
}
