import 'package:flutter/material.dart';
import 'app_design.dart';
import 'floral_widgets.dart';

import 'note_design.dart';
import 'note_stationery.dart';
export 'note_design.dart';

String momentDate(BuildContext context, String? timestamp) {
  final date = DateTime.tryParse(timestamp ?? '')?.toLocal();
  return date == null
      ? ''
      : MaterialLocalizations.of(context).formatMediumDate(date);
}

class MomentsConnectionCard extends StatelessWidget {
  const MomentsConnectionCard(
      {required this.name, required this.onOpen, super.key});
  final String name;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xff66384e),
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                        name.trim().isEmpty
                            ? 'P'
                            : name.trim().characters.first.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      const Text('Open your private chat',
                          style: TextStyle(
                              color: Color(0xffead6df), fontSize: 12)),
                    ])),
                const SizedBox(width: 10),
                const Icon(Icons.chat_bubble_outline_rounded,
                    color: Colors.white, size: 21),
              ]),
            )),
      );
}

class MomentCard extends StatelessWidget {
  const MomentCard(
      {required this.note,
      required this.onOpen,
      this.fromName = 'Your partner',
      super.key});
  final Map<String, dynamic> note;
  final VoidCallback onOpen;
  final String fromName;
  @override
  Widget build(BuildContext context) {
    final design = noteDesign[note['style']] ?? noteDesign['letter']!;
    final unread = note['opened_at'] == null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: NoteStationery(
        design: design,
        padding: EdgeInsets.zero,
        child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(design.symbol, color: design.accent, size: 20),
                      const SizedBox(width: 9),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(design.title,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: design.accent)),
                            const SizedBox(height: 4),
                            Text(
                                momentDate(
                                    context, note['created_at'] as String?),
                                style: const TextStyle(
                                    fontSize: 11, color: AppPalette.muted)),
                          ])),
                      if (unread)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: design.accent.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('Unread',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: design.accent,
                                    fontWeight: FontWeight.w600))),
                    ]),
                    if (unread) ...[
                      const SizedBox(height: 8),
                      NoteMotif(design: design, height: 64),
                      const SizedBox(height: 8),
                      Text('From $fromName',
                          style: const TextStyle(
                              fontSize: 15, color: AppPalette.ink)),
                    ] else ...[
                      const SizedBox(height: 18),
                      Text(note['body'] as String? ?? '',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              height: 1.65,
                              color: AppPalette.ink)),
                    ],
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: Text(unread ? 'Open your note' : 'Read again',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: design.accent,
                                  fontWeight: FontWeight.w600))),
                      Icon(Icons.arrow_forward_rounded,
                          size: 17, color: design.accent),
                    ]),
                  ]),
            )),
      ),
    );
  }
}

Future<void> showMomentReader(BuildContext context,
        {required NoteDesign design,
        required String message,
        required String fromName,
        String? createdAt,
        bool preview = false}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppPalette.canvas,
        showDragHandle: true,
        builder: (_) => NoteReadingSheet(
            design: design,
            message: message,
            fromName: fromName,
            createdAt: createdAt,
            preview: preview));

class NoteReadingSheet extends StatelessWidget {
  const NoteReadingSheet(
      {required this.design,
      required this.message,
      required this.fromName,
      this.createdAt,
      this.preview = false,
      super.key});
  final NoteDesign design;
  final String message;
  final String fromName;
  final String? createdAt;
  final bool preview;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: FloralBackdrop(
          color: AppPalette.canvas,
          child: SafeArea(
              top: false,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
                    child: Row(children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: AppPalette.plum, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              preview ? 'Preview · not sent' : 'Private note',
                              style: const TextStyle(
                                  fontSize: 12, color: AppPalette.plum))),
                      IconButton(
                          tooltip: 'Close note',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded)),
                    ])),
                Expanded(
                    child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: NoteStationery(
                      design: design,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(design.symbol,
                                  size: 16, color: design.accent),
                              const SizedBox(width: 7),
                              Expanded(
                                  child: Text(design.title,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: design.accent))),
                            ]),
                            NoteMotif(design: design, height: 100),
                            const SizedBox(height: 12),
                            SelectableText(message,
                                style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.75,
                                    letterSpacing: .1,
                                    color: AppPalette.ink)),
                            const SizedBox(height: 26),
                            Divider(
                                color: design.accent.withValues(alpha: .2),
                                height: 1),
                            const SizedBox(height: 16),
                            Text('From $fromName',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: design.accent)),
                            if (createdAt != null) ...[
                              const SizedBox(height: 5),
                              Text(momentDate(context, createdAt),
                                  style: const TextStyle(
                                      fontSize: 11, color: AppPalette.muted)),
                            ],
                          ])),
                )),
              ])),
        ),
      );
}

class MomentComposer extends StatelessWidget {
  const MomentComposer(
      {required this.controller,
      required this.style,
      required this.onStyleChanged,
      required this.onSend,
      required this.busy,
      required this.senderName,
      super.key});
  final TextEditingController controller;
  final String style;
  final ValueChanged<String> onStyleChanged;
  final VoidCallback onSend;
  final bool busy;
  final String senderName;
  @override
  Widget build(BuildContext context) {
    final design = noteDesign[style] ?? noteDesign['letter']!;
    return AppSurface(title: 'New note', children: [
      NoteStylePicker(
          selected: style, enabled: !busy, onSelected: onStyleChanged),
      const SizedBox(height: 14),
      TextField(
        controller: controller,
        maxLength: 500,
        minLines: 4,
        maxLines: 7,
        textCapitalization: TextCapitalization.sentences,
        enabled: !busy,
        style:
            const TextStyle(fontSize: 16, height: 1.6, color: AppPalette.ink),
        decoration: InputDecoration(
            hintText: 'Write your note…',
            labelText: 'Your note',
            alignLabelWithHint: true,
            fillColor: design.color),
      ),
      const SizedBox(height: 14),
      ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final canSend = !busy && value.text.trim().isNotEmpty;
            final send = FilledButton.icon(
                onPressed: canSend ? onSend : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_outlined, size: 18),
                label: Text(busy ? 'Sending…' : 'Send note'));
            final preview = TextButton.icon(
                onPressed: canSend
                    ? () => showMomentReader(context,
                        design: design,
                        message: value.text.trim(),
                        fromName: senderName,
                        preview: true)
                    : null,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview note'));
            return LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 300 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
                return Row(children: [
                  Expanded(child: send),
                  const SizedBox(width: 8),
                  preview
                ]);
              }
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [send, preview]);
            });
          }),
    ]);
  }
}
