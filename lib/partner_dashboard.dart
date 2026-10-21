import 'package:flutter/material.dart';

import 'app_design.dart';
import 'home_widgets.dart';

/// Partner Home only presents shared timing and existing partner actions.
/// Pairing, account access, and mutations remain in the application controller.
class PartnerDashboard extends StatelessWidget {
  const PartnerDashboard({
    required this.today,
    required this.name,
    required this.partnerName,
    required this.connected,
    required this.onProfile,
    required this.onConnect,
    required this.onMessages,
    required this.onNote,
    required this.onInsights,
    required this.onReflections,
    required this.onConnection,
    required this.onNickname,
    this.periodStart,
    this.periodEnd,
    this.nextPeriod,
    this.reflectionCount = 0,
    super.key,
  });

  final DateTime today;
  final String name;
  final String partnerName;
  final bool connected;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime? nextPeriod;
  final int reflectionCount;
  final VoidCallback onProfile;
  final VoidCallback onConnect;
  final VoidCallback onMessages;
  final VoidCallback onNote;
  final VoidCallback onInsights;
  final VoidCallback onReflections;
  final VoidCallback onConnection;
  final VoidCallback onNickname;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHeading(date: today, name: name, onProfile: onProfile),
          if (!connected) ...[
            _WelcomeCard(onConnect: onConnect),
            const SizedBox(height: 24),
            const _CarePrompt(connected: false),
          ] else ...[
            _ConnectionHero(
              name: name,
              partnerName: partnerName,
              onConnection: onConnection,
              onNickname: onNickname,
            ),
            const SizedBox(height: 24),
            _SectionHeading(
              title: 'Shared cycle',
              action: 'View calendar',
              onPressed: onInsights,
            ),
            const SizedBox(height: 12),
            _SharedCycleCard(
              today: today,
              start: periodStart,
              end: periodEnd,
              next: nextPeriod,
            ),
            const SizedBox(height: 24),
            const Text('Little ways to be there',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            AppActionPair(
              first: AppActionTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Messages',
                subtitle: 'Make a little time to talk',
                color: AppPalette.sage,
                onTap: onMessages,
              ),
              second: AppActionTile(
                icon: Icons.mail_outline_rounded,
                title: 'Write a note',
                subtitle: 'A small thought, just for them',
                onTap: onNote,
              ),
            ),
            const SizedBox(height: 20),
            const _CarePrompt(connected: true),
            const SizedBox(height: 20),
            _ReflectionsCard(count: reflectionCount, onOpen: onReflections),
          ],
          const SizedBox(height: 24),
          const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline_rounded, size: 15, color: AppPalette.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'A private space for two. Either person can end the connection in Settings.',
                style: TextStyle(
                    color: AppPalette.muted, fontSize: 12, height: 1.5),
              ),
            ),
          ]),
        ],
      );
}

class _ConnectionHero extends StatelessWidget {
  const _ConnectionHero(
      {required this.name,
      required this.partnerName,
      required this.onConnection,
      required this.onNickname});
  final String name;
  final String partnerName;
  final VoidCallback onConnection;
  final VoidCallback onNickname;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xfff5dde6), Color(0xfff9ece3)],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xffecd3dc)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.favorite_border_rounded,
                size: 17, color: AppPalette.plum),
            const SizedBox(width: 7),
            const Expanded(
                child: Text('YOUR SHARED SPACE',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: AppPalette.plum,
                        fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: 'Connection settings',
              onPressed: onConnection,
              icon: const Icon(Icons.tune_rounded, size: 20),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _InitialAvatar(name: name, color: AppPalette.plum),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.favorite_rounded,
                    size: 16, color: AppPalette.plum)),
            _InitialAvatar(name: partnerName, color: AppPalette.forest),
          ]),
          const SizedBox(height: 20),
          Text('Here for $partnerName.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          const Text(
              'A little presence can mean a lot. Make room for a conversation, a kind note, or simply being there.',
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: AppPalette.muted)),
          const SizedBox(height: 14),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(30)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_rounded, size: 15, color: AppPalette.plum),
                    SizedBox(width: 5),
                    Flexible(
                        child: Text('Connected privately',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppPalette.plum,
                                fontWeight: FontWeight.w600))),
                  ]),
                ),
                TextButton.icon(
                    onPressed: onNickname,
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit nickname',
                        style: TextStyle(fontSize: 12))),
              ]),
        ]),
      );
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) => CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white.withValues(alpha: .8),
      child: Text(
          name.trim().isEmpty
              ? '?'
              : name.trim().characters.first.toUpperCase(),
          style: TextStyle(
              fontSize: 23, fontWeight: FontWeight.w600, color: color)));
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(
      {required this.title, required this.action, required this.onPressed});
  final String title;
  final String action;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final heading = Text(title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600));
        final button = TextButton(onPressed: onPressed, child: Text(action));
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, button]);
        }
        return Row(children: [Expanded(child: heading), button]);
      });
}

class _SharedCycleCard extends StatelessWidget {
  const _SharedCycleCard(
      {required this.today, this.start, this.end, this.next});
  final DateTime today;
  final DateTime? start;
  final DateTime? end;
  final DateTime? next;
  static String date(DateTime value) => '${value.day} ${const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ][value.month - 1]} ${value.year}';

  @override
  Widget build(BuildContext context) {
    final day = DateUtils.dateOnly(today);
    final started = start != null && !DateUtils.dateOnly(start!).isAfter(day);
    final ongoing = started && end == null;
    final usableEstimate =
        next != null && !DateUtils.dateOnly(next!).isBefore(day);
    final title = start == null
        ? 'No shared cycle entries yet'
        : !started
            ? 'A future entry is saved'
            : ongoing
                ? 'Period in progress'
                : 'Next period estimate';
    final detail = start == null
        ? 'Shared timing will appear here when your partner adds a period.'
        : !started
            ? 'Starts ${date(start!)}'
            : ongoing
                ? 'Started ${date(start!)}'
                : usableEstimate
                    ? date(next!)
                    : 'Waiting for updated cycle timing';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppPalette.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: AppPalette.lilac,
                  borderRadius: BorderRadius.circular(13)),
              child: const Icon(Icons.water_drop_outlined,
                  color: AppPalette.plum, size: 22)),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(detail,
                    style: const TextStyle(
                        fontSize: 13, height: 1.5, color: AppPalette.muted)),
              ])),
        ]),
        if (ongoing) ...[
          const SizedBox(height: 16),
          Text(
              'Day ${day.difference(DateUtils.dateOnly(start!)).inDays + 1} of this period',
              style: const TextStyle(
                  color: AppPalette.plum,
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Text(
            ongoing
                ? 'Your partner updates their own period dates. Ask how you can help today.'
                : 'Cycle timing is an estimate. Let your partner tell you what they need.',
            style: const TextStyle(
                color: AppPalette.muted, fontSize: 12, height: 1.5)),
      ]),
    );
  }
}

class _CarePrompt extends StatelessWidget {
  const _CarePrompt({required this.connected});
  final bool connected;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppPalette.sage, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.spa_outlined, color: AppPalette.forest, size: 20),
            SizedBox(width: 8),
            Expanded(
                child: Text('A SMALL WAY TO CARE',
                    style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        color: AppPalette.forest,
                        fontWeight: FontWeight.w700)))
          ]),
          const SizedBox(height: 13),
          Text(
              connected
                  ? '“What would feel helpful today?”'
                  : 'Start with a conversation.',
              style: const TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.forest)),
          const SizedBox(height: 9),
          Text(
              connected
                  ? 'Listen first. A little practical help or a quiet moment together can be enough.'
                  : 'Talk about what you both feel comfortable sharing before you connect.',
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppPalette.forest)),
        ]),
      );
}

class _ReflectionsCard extends StatelessWidget {
  const _ReflectionsCard({required this.count, required this.onOpen});
  final int count;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Material(
        color: AppPalette.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppPalette.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onOpen,
            child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome_outlined,
                          color: AppPalette.plum, size: 24),
                      const SizedBox(width: 13),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('Shared reflections',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 7),
                            Text(
                                count == 0
                                    ? 'Remember a day together. Add your first reflection.'
                                    : '$count ${count == 1 ? 'reflection' : 'reflections'} together. Make room for another memory.',
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: AppPalette.muted)),
                          ])),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppPalette.muted, size: 20),
                    ]))),
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onConnect});
  final VoidCallback onConnect;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: AppPalette.lilac, borderRadius: BorderRadius.circular(26)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.favorite_border_rounded,
              color: AppPalette.plum, size: 35),
          const SizedBox(height: 22),
          Text('Be there, together.',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
              'Connect with your partner to see shared cycle timing, send thoughtful notes, and keep little memories together.',
              style: TextStyle(
                  fontSize: 14, color: AppPalette.muted, height: 1.6)),
          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: onConnect,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Connect with your partner'))),
          const SizedBox(height: 12),
          const Text(
              'Use their single-use invite code or find their invitation nearby.',
              style: TextStyle(
                  fontSize: 12, height: 1.5, color: AppPalette.muted)),
        ]),
      );
}
