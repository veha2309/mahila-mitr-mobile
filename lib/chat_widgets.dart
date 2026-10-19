import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'app_design.dart';

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

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble(
      {required this.body,
      required this.outgoing,
      required this.time,
      required this.onReply,
      required this.onOptions,
      this.replyBody,
      this.status = false,
      super.key});
  final String body;
  final bool outgoing;
  final bool status;
  final String time;
  final String? replyBody;
  final VoidCallback onReply;
  final VoidCallback onOptions;
  @override
  Widget build(BuildContext context) {
    final foreground = outgoing ? Colors.white : AppPalette.ink;
    return Align(
        alignment: status
            ? Alignment.center
            : outgoing
                ? Alignment.centerRight
                : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          constraints: BoxConstraints(
              maxWidth: math.min(480, MediaQuery.sizeOf(context).width * .88)),
          child: Material(
              color: outgoing ? AppPalette.plum : AppPalette.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(outgoing || status ? 22 : 6),
                      bottomRight:
                          Radius.circular(!outgoing || status ? 22 : 6)),
                  side: BorderSide(
                      color: outgoing ? AppPalette.plum : AppPalette.border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                  onLongPress: onOptions,
                  onDoubleTap: onReply,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.local_florist_outlined,
                                            color: foreground.withValues(
                                                alpha: .75),
                                            size: 16),
                                        const SizedBox(width: 7),
                                        Flexible(
                                            child: Text(
                                                outgoing
                                                    ? 'Your status'
                                                    : 'Status',
                                                style: TextStyle(
                                                    color: foreground
                                                        .withValues(alpha: .75),
                                                    fontSize: 11))),
                                      ])),
                            if (replyBody != null && replyBody!.isNotEmpty)
                              Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(
                                      right: 6, bottom: 10),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: outgoing
                                          ? Colors.white.withValues(alpha: .12)
                                          : AppPalette.lilac,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border(
                                          left: BorderSide(
                                              color: outgoing
                                                  ? Colors.white60
                                                  : AppPalette.plum,
                                              width: 3))),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Replying to',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: foreground)),
                                        const SizedBox(height: 3),
                                        Text(replyBody!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: foreground.withValues(
                                                    alpha: .8),
                                                fontSize: 12)),
                                      ])),
                            Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(body,
                                    style: TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                        fontWeight: status
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: foreground))),
                            Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(time,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: foreground.withValues(
                                            alpha: .65)))),
                          ])))),
        ));
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer(
      {required this.controller,
      required this.focusNode,
      required this.sending,
      required this.onSend,
      this.reply,
      this.onMood,
      this.moodPickerOpen = false,
      super.key});
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final VoidCallback onSend;
  final Widget? reply;
  final VoidCallback? onMood;
  final bool moodPickerOpen;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
        child: Material(
            color: AppPalette.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: const BorderSide(color: Color(0xffd9bfd0))),
            clipBehavior: Clip.antiAlias,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (reply != null) reply!,
              Padding(
                  padding: const EdgeInsets.fromLTRB(2, 2, 4, 2),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (onMood != null)
                          IconButton(
                              tooltip: moodPickerOpen
                                  ? 'Close mood picker'
                                  : 'Share mood',
                              onPressed: sending ? null : onMood,
                              icon: Icon(moodPickerOpen
                                  ? Icons.close
                                  : Icons.sentiment_satisfied_alt_outlined)),
                        Expanded(
                            child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                minLines: 1,
                                maxLines: 4,
                                maxLength: 500,
                                enabled: !sending,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) {
                                  if (!sending) onSend();
                                },
                                decoration: const InputDecoration(
                                    hintText: 'Message',
                                    counterText: '',
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    fillColor: Colors.transparent,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10)))),
                        ValueListenableBuilder<TextEditingValue>(
                            valueListenable: controller,
                            builder: (context, value, _) => IconButton.filled(
                                tooltip: 'Send message',
                                onPressed: sending || value.text.trim().isEmpty
                                    ? null
                                    : onSend,
                                icon: sending
                                    ? const SizedBox.square(
                                        dimension: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.arrow_upward_rounded))),
                      ])),
            ])),
      ));
}
