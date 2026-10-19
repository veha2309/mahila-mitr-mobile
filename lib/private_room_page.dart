import 'app_activity.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_design.dart';
import 'chat_widgets.dart';
import 'floral_widgets.dart';

const plum = AppPalette.plum;
const ink = AppPalette.ink;
const cream = AppPalette.canvas;
const line = AppPalette.border;
const coral = Color(0xfff28c8c);

class PrivateRoomPage extends StatefulWidget {
  const PrivateRoomPage({
    required this.client,
    required this.linkId,
    required this.myUserId,
    required this.myName,
    required this.partnerName,
    required this.initialConversations,
    required this.partnerNickname,
    required this.myNickname,
    required this.partnerDisplayName,
    required this.onNicknameChanged,
    this.onStatusSent,
    super.key,
  });

  final SupabaseClient client;
  final String linkId;
  final String myUserId;
  final String myName;
  final String partnerName;
  final String myNickname;
  final String partnerNickname;
  final String partnerDisplayName;
  final void Function(String)? onNicknameChanged;
  final List<Map<String, dynamic>> initialConversations;
  final void Function(String status)? onStatusSent;

  @override
  State<PrivateRoomPage> createState() => _PrivateRoomPageState();
}

class _PrivateRoomPageState extends State<PrivateRoomPage>
    with WidgetsBindingObserver {
  // ── state ──
  List<Map<String, dynamic>> _conversations = [];
  Map<String, dynamic>? _activeConvo;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _sending = false;
  bool _showStatuses = false;
  String? _error;
  RealtimeChannel? _channel;
  String? _currentPartnerNickname;
  Map<String, dynamic>? _replyingTo;
  final _msgController = TextEditingController();
  final _msgFocusNode = FocusNode();
  final _subjectController = TextEditingController(text: 'Private chat');
  final _scrollController = ScrollController();
  final _messageViewportKey = GlobalKey();
  Timer? _refreshTimer;
  bool _refreshing = false;
  int _refreshTicks = 0;

  static const _statuses = [
    '🌙 Resting',
    '💗 Missing you',
    '🌷 Feeling good',
    '🫶 Need some care',
    '☕ Talk to me',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      setState(() {});
      if (++_refreshTicks % 15 == 0) _refreshRoom();
    });
    _currentPartnerNickname =
        widget.partnerNickname.isNotEmpty ? widget.partnerNickname : null;
    _conversations = List.from(widget.initialConversations);
    if (_conversations.isNotEmpty) {
      _openConversation(_conversations.first);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _stopRealtime();
    _msgController.dispose();
    _msgFocusNode.dispose();
    _subjectController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshRoom();
  }

  Future<void> _refreshRoom() async {
    if (_refreshing || !mounted) return;
    _refreshing = true;
    try {
      final rows = await widget.client.rpc('get_ephemeral_conversations');
      if (!mounted) return;
      final conversations = List<Map<String, dynamic>>.from(rows as List);
      final activeId = _activeConvo?['id'];
      setState(() {
        _conversations = conversations;
        final matches = conversations.where((c) => c['id'] == activeId);
        _activeConvo = matches.isEmpty ? null : matches.first;
      });
      if (_activeConvo != null) {
        await _reloadMessages(_activeConvo!['id'] as String);
      } else if (conversations.isNotEmpty) {
        await _openConversation(conversations.first);
      } else {
        _stopRealtime();
        setState(() {
          _messages = [];
          _replyingTo = null;
        });
      }
    } catch (e) {
      debugPrint('Room refresh failed: $e');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _acknowledgeMessage(Map<String, dynamic> message) async {
    final conversationId = _activeConvo?['id'] as String?;
    if (conversationId == null) return;
    await widget.client.rpc('mark_ephemeral_messages_read', params: {
      'target_conversation_id': conversationId,
      'message_ids': [message['id']],
    });
    if (mounted && _activeConvo?['id'] == conversationId) {
      await _reloadMessages(conversationId);
    }
  }

  // ── name helpers ──

  String get _displayPartnerName {
    if (_currentPartnerNickname != null &&
        _currentPartnerNickname!.trim().isNotEmpty) {
      return _currentPartnerNickname!.trim();
    }
    if (widget.partnerDisplayName.trim().isNotEmpty) {
      return widget.partnerDisplayName.trim();
    }
    return widget.partnerName;
  }

  String get _partnerSubtitle {
    if (_activeConvo != null) {
      final minutes = _activeConvo?['ttl_minutes'] as int? ?? 60;
      final duration = minutes < 60 ? '$minutes min' : '${minutes ~/ 60} hr';
      return '$duration after reading · private';
    }
    if (_currentPartnerNickname != null &&
        widget.partnerDisplayName.trim().isNotEmpty) {
      return '${widget.partnerDisplayName} · tap to edit nickname';
    }
    return 'Private Room · tap to set nickname';
  }

  void _startReply(Map<String, dynamic> msg) {
    setState(() => _replyingTo = msg);
    _msgFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  void _showEditNicknameDialog() {
    final controller =
        TextEditingController(text: _currentPartnerNickname ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Partner nickname',
            style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 18, color: plum)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.partnerDisplayName.isNotEmpty
                  ? 'Choose a sweet nickname for ${widget.partnerDisplayName}'
                  : 'Choose a sweet nickname for your partner',
              style: TextStyle(fontSize: 13, color: ink.withValues(alpha: .7)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: 'e.g. My Angel, Love, Sunshine…',
                hintStyle: TextStyle(color: ink.withValues(alpha: .4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: plum, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: ink)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: plum),
            onPressed: () async {
              Navigator.pop(ctx);
              final newNick = controller.text.trim();
              try {
                await runWithAppActivity(context, 'Saving nickname…', () async {
                  await widget.client.rpc('set_partner_nickname', params: {
                    'new_nickname': newNick,
                  });
                });
                if (!mounted) return;
                setState(() =>
                    _currentPartnerNickname = newNick.isEmpty ? null : newNick);
                widget.onNicknameChanged?.call(newNick);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newNick.isEmpty
                          ? 'Nickname removed'
                          : 'Nickname updated to "$newNick" 💖'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update nickname: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── realtime ──

  void _startRealtime(String conversationId) {
    _stopRealtime();
    _channel = widget.client
        .channel('chat-$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ephemeral_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (_) => _reloadMessages(conversationId),
        )
        .subscribe();
  }

  void _stopRealtime() {
    final ch = _channel;
    if (ch != null) {
      widget.client.removeChannel(ch);
      _channel = null;
    }
  }

  // ── data ──

  Future<void> _openConversation(Map<String, dynamic> convo) async {
    if (!mounted) return;
    setState(() {
      _activeConvo = convo;
      _messages = [];
      _loading = true;
      _error = null;
      _replyingTo = null;
    });
    _startRealtime(convo['id'] as String);
    await _reloadMessages(convo['id'] as String);
  }

  Future<void> _reloadMessages(String conversationId) async {
    final scrollToEnd = _loading ||
        (_scrollController.hasClients &&
            _scrollController.position.extentAfter < 80);
    try {
      final rows = await widget.client.rpc('get_ephemeral_messages',
          params: {'target_conversation_id': conversationId});
      final msgs = List<Map<String, dynamic>>.from(
          (rows as List).map((e) => Map<String, dynamic>.from(e as Map)));
      if (mounted && _activeConvo?['id'] == conversationId) {
        setState(() {
          _error = null;
          _messages = msgs;
          _loading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              _activeConvo?['id'] == conversationId &&
              scrollToEnd &&
              _scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _createConversation() => runWithAppActivity(
      context, 'Creating conversation…', _createConversationRequest);

  Future<void> _createConversationRequest() async {
    final subject = _subjectController.text.trim();
    if (_sending || subject.isEmpty) return;
    setState(() => _sending = true);
    try {
      final id = await widget.client.rpc('create_ephemeral_conversation',
          params: {'conversation_subject': subject, 'ttl_minutes': 60});
      final convo = {
        'id': id.toString(),
        'subject': subject,
        'message_count': 0,
        'ttl_minutes': 60,
      };
      if (mounted) {
        setState(() {
          _conversations = [convo, ..._conversations];
          _sending = false;
        });
        await _openConversation(convo);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _triggerPushNotification() {
    if (_activeConvo == null) return;
    try {
      widget.client.functions.invoke('push-chat-notification', body: {
        'conversation_id': _activeConvo!['id'],
      }).catchError((e) {
        debugPrint('FCM push error: $e');
        return const FunctionResponse(data: null, status: 500);
      });
    } catch (e) {
      debugPrint('FCM push error: $e');
    }
  }

  Future<void> _sendMessage({String kind = 'message'}) async {
    final body = _msgController.text.trim();
    if (_sending || body.isEmpty || _activeConvo == null) return;
    final replyId = _replyingTo?['id'] as String?;
    setState(() => _sending = true);
    try {
      final params = <String, dynamic>{
        'target_conversation_id': _activeConvo!['id'],
        'message_body': body,
        'message_kind': kind,
      };
      if (replyId != null) {
        params['reply_message_id'] = replyId;
      }
      await widget.client.rpc('send_ephemeral_message', params: params);
      _triggerPushNotification();
      _msgController.clear();
      if (mounted) setState(() => _replyingTo = null);
      if (kind == 'status') widget.onStatusSent?.call(body);
      await _reloadMessages(_activeConvo!['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendStatus(String status) => runWithAppActivity(
      context, 'Sharing status…', () => _sendStatusRequest(status));

  Future<void> _sendStatusRequest(String status) async {
    if (_sending) return;
    if (_activeConvo == null) {
      // Create a default convo if none exists
      setState(() => _sending = true);
      try {
        final id = await widget.client.rpc('create_ephemeral_conversation',
            params: {
              'conversation_subject': 'Status updates',
              'ttl_minutes': 120
            });
        final convo = {
          'id': id.toString(),
          'subject': 'Status updates',
          'message_count': 0,
          'ttl_minutes': 120,
        };
        setState(() {
          _conversations = [convo, ..._conversations];
          _activeConvo = convo;
          _sending = false;
        });
        _startRealtime(convo['id'] as String);
      } catch (e) {
        if (mounted) {
          setState(() => _sending = false);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
          return;
        }
      }
    }
    if (_activeConvo == null) return;
    final replyId = _replyingTo?['id'] as String?;
    setState(() => _sending = true);
    try {
      final params = <String, dynamic>{
        'target_conversation_id': _activeConvo!['id'],
        'message_body': status,
        'message_kind': 'status',
      };
      if (replyId != null) {
        params['reply_message_id'] = replyId;
      }
      await widget.client.rpc('send_ephemeral_message', params: params);
      _triggerPushNotification();
      if (mounted) setState(() => _replyingTo = null);
      widget.onStatusSent?.call(status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Status "$status" sent 💌'),
          behavior: SnackBarBehavior.floating,
        ));
        await _reloadMessages(_activeConvo!['id'] as String);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showEditNicknameDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xffeadde8),
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: plum, size: 17),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            _displayPartnerName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.favorite,
                            size: 13, color: coral.withValues(alpha: .75)),
                      ],
                    ),
                    Text(
                      _partnerSubtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11, color: ink.withValues(alpha: .55)),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: plum),
            tooltip: 'Message timer',
            onPressed: _activeConvo == null ? null : _showTimerSettings,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: plum),
            tooltip: 'New conversation',
            onPressed: _showNewConvoSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Quiet, static backdrop.
          const Positioned.fill(
              child: FloralBackdrop(dense: true, child: SizedBox.expand())),
          // ── chat content ──
          Column(children: [
            if (_conversations.length > 1) _buildConvoTabs(),
            // Messages
            Expanded(child: _buildMessageList()),
            _buildStatusBar(),
            // Input
            if (_activeConvo != null) _buildInputBar(),
          ]),
        ],
      ),
    );
  }

  Future<void> _showTimerSettings() async {
    final conversationId = _activeConvo?['id'] as String?;
    if (conversationId == null) return;
    final minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: cream,
      builder: (ctx) => SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Message timer',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                  'Choose how long new messages stay after the recipient reads them. Existing messages keep their timer. The room disappears after its last message expires.'),
              const SizedBox(height: 16),
              for (final choice in <int, String>{
                10: '10 minutes',
                60: '1 hour',
                120: '2 hours',
                1440: '24 hours'
              }.entries)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined, color: plum),
                    title: Text(choice.value),
                    trailing: _activeConvo?['ttl_minutes'] == choice.key
                        ? const Icon(Icons.check_circle, color: plum)
                        : null,
                    onTap: () => Navigator.pop(ctx, choice.key)),
            ]),
      )),
    );
    if (minutes == null || !mounted) return;
    try {
      await runWithAppActivity(context, 'Updating message timer…', () async {
        await widget.client.rpc('update_conversation_expiry', params: {
          'target_conversation_id': conversationId,
          'new_ttl_minutes': minutes,
        });
        await _refreshRoom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not update timer: $e')));
      }
    }
  }

  Widget _buildStatusBar() => Column(mainAxisSize: MainAxisSize.min, children: [
        if (_activeConvo == null)
          Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _showStatuses = !_showStatuses),
                      icon: const Icon(Icons.local_florist_outlined, size: 18),
                      label: Text(_showStatuses
                          ? 'Close mood picker'
                          : 'Share how you feel')))),
        if (_showStatuses)
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                  children: _statuses
                      .map((status) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                              label: Text(status),
                              onPressed:
                                  _sending ? null : () => _sendStatus(status))))
                      .toList())),
      ]);

  Widget _buildConvoTabs() => SizedBox(
      height:
          54 + (MediaQuery.textScalerOf(context).scale(1) - 1).clamp(0, 2) * 24,
      child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: _conversations.length,
          separatorBuilder: (_, index) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final conversation = _conversations[i];
            return ChoiceChip(
                label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                        conversation['subject'] as String? ?? 'Conversation',
                        overflow: TextOverflow.ellipsis)),
                selected: _activeConvo?['id'] == conversation['id'],
                onSelected: (_) => _openConversation(conversation));
          }));

  Widget _buildMessageList() {
    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('💬', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text('Start a private conversation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Tap + to create a room, then send messages or statuses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ink.withValues(alpha: .6)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showNewConvoSheet,
              icon: const Icon(Icons.add),
              label: const Text('Create a room'),
            ),
          ]),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: plum));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: coral)));
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages yet.\nSend the first one! 💌',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xff9e8fa8))),
      );
    }
    final liveMessages = _messages.where((m) {
      final expiry = DateTime.tryParse(m['expires_at'] as String? ?? '');
      return expiry == null || expiry.isAfter(DateTime.now());
    }).toList();
    return ListView.builder(
      key: _messageViewportKey,
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      itemCount: liveMessages.length,
      itemBuilder: (_, i) {
        final message = liveMessages[i];
        return Column(
            key: ValueKey(message['id']),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (i == 0 ||
                  !DateUtils.isSameDay(
                      DateTime.parse(message['created_at'] as String).toLocal(),
                      DateTime.parse(
                              liveMessages[i - 1]['created_at'] as String)
                          .toLocal()))
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                        MaterialLocalizations.of(context).formatMediumDate(
                            DateTime.parse(message['created_at'] as String)
                                .toLocal()),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11, color: ink.withValues(alpha: .55)))),
              ReadAwareMessage(
                viewportKey: _messageViewportKey,
                unread: message['sender_id'] != widget.myUserId &&
                    message['read_at'] == null,
                onRead: () => _acknowledgeMessage(message),
                child: _buildMessage(message),
              ),
              Padding(
                  padding: const EdgeInsets.only(left: 6, right: 6, bottom: 12),
                  child: Text(
                      messageLifetimeLabel(message, DateTime.now(),
                          outgoing: message['sender_id'] == widget.myUserId),
                      textAlign: message['sender_id'] == widget.myUserId
                          ? TextAlign.right
                          : TextAlign.left,
                      style: TextStyle(
                          fontSize: 11, color: ink.withValues(alpha: .6)))),
            ]);
      },
    );
  }

  void _showMessageOptions(Map<String, dynamic> msg) {
    final body = msg['body'] as String? ?? '';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: plum),
                title: const Text('Reply to message',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startReply(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: plum),
                title: const Text('Copy message',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: body));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final outgoing = message['sender_id'] == widget.myUserId;
    final sent =
        DateTime.tryParse(message['created_at'] as String? ?? '')?.toLocal();
    return _SwipeToReply(
        key: ValueKey(message['id']),
        isMe: outgoing,
        onReply: () => _startReply(message),
        child: ChatMessageBubble(
            body: message['body'] as String? ?? '',
            outgoing: outgoing,
            status: message['kind'] == 'status',
            replyBody: message['reply_body'] as String?,
            time: sent == null
                ? ''
                : MaterialLocalizations.of(context)
                    .formatTimeOfDay(TimeOfDay.fromDateTime(sent)),
            onReply: () => _startReply(message),
            onOptions: () => _showMessageOptions(message)));
  }

  Widget _buildInputBar() => ChatComposer(
      controller: _msgController,
      focusNode: _msgFocusNode,
      sending: _sending,
      onSend: _sendMessage,
      onMood: () => setState(() => _showStatuses = !_showStatuses),
      moodPickerOpen: _showStatuses,
      reply: _replyingTo == null ? null : _buildReplyPreview());

  Widget _buildReplyPreview() => Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        color: const Color(0xfff5eef8),
        child: Row(
          children: [
            Container(
              width: 3.5,
              height: 34,
              decoration: BoxDecoration(
                color: plum,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _replyingTo!['sender_id'] == widget.myUserId
                        ? 'Replying to yourself'
                        : 'Replying to $_displayPartnerName',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: plum,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _replyingTo!['body'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: ink.withValues(alpha: .75),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: plum),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _cancelReply,
            ),
          ],
        ),
      );

  void _showNewConvoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cream,
      builder: (ctx) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: FloralEmblem(size: 50)),
                const SizedBox(height: 16),
                Text('A little space for you two',
                    style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text(
                    'Choose a topic. Messages stay unread until your partner sees them, then disappear after 1 hour.',
                    style: TextStyle(color: AppPalette.muted)),
                const SizedBox(height: 20),
                TextField(
                    controller: _subjectController,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Conversation topic',
                        hintText: 'Plans, little things, anything…')),
                const SizedBox(height: 12),
                ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _subjectController,
                    builder: (_, value, child) => FilledButton(
                        onPressed: value.text.trim().isEmpty || _sending
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _createConversation();
                              },
                        child: const Text('Create your conversation'))),
              ])),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({
    super.key,
    required this.child,
    required this.isMe,
    required this.onReply,
  });

  final Widget child;
  final bool isMe;
  final VoidCallback onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0;
  bool _hasTriggeredHaptic = false;
  static const double _maxDrag = 52.0;
  static const double _triggerThreshold = 30.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = const AlwaysStoppedAnimation(0);
    _controller.addListener(() {
      if (mounted) setState(() => _dragOffset = _animation.value);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _controller.stop();
    setState(() {
      final delta = details.primaryDelta ?? 0;
      if (widget.isMe) {
        // Own message: swipe LEFT (negative offset)
        _dragOffset = (_dragOffset + delta * 0.7).clamp(-_maxDrag, 0.0);
      } else {
        // Partner message: swipe RIGHT (positive offset)
        _dragOffset = (_dragOffset + delta * 0.7).clamp(0.0, _maxDrag);
      }

      if (_dragOffset.abs() >= _triggerThreshold && !_hasTriggeredHaptic) {
        HapticFeedback.lightImpact();
        _hasTriggeredHaptic = true;
      } else if (_dragOffset.abs() < _triggerThreshold) {
        _hasTriggeredHaptic = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() >= _triggerThreshold) {
      widget.onReply();
    }
    _animateBack();
  }

  void _onHorizontalDragCancel() {
    _animateBack();
  }

  void _animateBack() {
    _hasTriggeredHaptic = false;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      setState(() => _dragOffset = 0);
      return;
    }
    _animation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset.abs() / _maxDrag).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onHorizontalDragCancel: _onHorizontalDragCancel,
      child: Stack(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (progress > 0.05)
            Positioned(
              left: widget.isMe ? null : 16,
              right: widget.isMe ? 16 : null,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xffeedff2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.reply_rounded,
                      color: plum,
                      size: 17,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ── Girly chat wallpaper ──────────────────────────────────────────────────────
