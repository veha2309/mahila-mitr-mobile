import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

String messageLifetimeLabel(Map<String, dynamic> message, DateTime now,
    {required bool outgoing}) {
  final expiry = DateTime.tryParse(message['expires_at'] as String? ?? '');
  if (expiry == null) {
    return outgoing ? 'Sent · waiting to be read' : 'Unread · timer paused';
  }
  final seconds = expiry.difference(now).inSeconds;
  if (seconds <= 0) return 'Expired';
  final remaining = seconds < 60
      ? '${seconds}s'
      : seconds < 3600
          ? '${(seconds / 60).ceil()}m'
          : '${seconds ~/ 3600}h ${((seconds % 3600) / 60).ceil()}m';
  return '${outgoing ? 'Read' : 'Seen'} · $remaining left';
}

/// A receipt requires a readable part of the bubble inside the chat viewport.
/// Prefetch, list caching, covered routes and background activity never count.
class ReadAwareMessage extends StatefulWidget {
  const ReadAwareMessage(
      {super.key,
      required this.viewportKey,
      required this.unread,
      required this.onRead,
      required this.child});
  final GlobalKey viewportKey;
  final bool unread;
  final Future<void> Function() onRead;
  final Widget child;
  @override
  State<ReadAwareMessage> createState() => _ReadAwareMessageState();
}

class _ReadAwareMessageState extends State<ReadAwareMessage>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _visibleTicks = 0;
  bool _pending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visibleTicks = 0;
  }

  void _check() {
    if (!mounted || !widget.unread || _pending) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final bubble = context.findRenderObject();
    final viewport = widget.viewportKey.currentContext?.findRenderObject();
    if (lifecycle != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent != true ||
        bubble is! RenderBox ||
        viewport is! RenderBox ||
        !bubble.attached ||
        !viewport.attached ||
        !bubble.hasSize ||
        !viewport.hasSize) {
      _visibleTicks = 0;
      return;
    }
    final bounds = bubble.localToGlobal(Offset.zero) & bubble.size;
    final view = viewport.localToGlobal(Offset.zero) & viewport.size;
    final visible = bounds.intersect(view);
    if (visible.isEmpty ||
        visible.height < math.min(bounds.height, view.height) * .6) {
      _visibleTicks = 0;
      return;
    }
    if (++_visibleTicks < 3) return;
    _visibleTicks = 0;
    _pending = true;
    widget.onRead().catchError((Object error) {
      // Keep the message unread on failure; retry while it remains visible.
      debugPrint('Read receipt failed: $error');
    }).whenComplete(() => _pending = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
