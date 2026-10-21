import 'app_version.dart';
import 'brand_widgets.dart';
import 'app_activity.dart';
import 'year_calendar.dart';
import 'home_widgets.dart';
import 'app_navigation.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dashboard_store.dart';
import 'cycle_calendar.dart';
import 'partner_dashboard.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'private_room_page.dart';
import 'notes_widgets.dart';
import 'appearance_settings.dart';
import 'app_design.dart';
import 'premium_widgets.dart';
import 'wellness_guide.dart';
import 'logging_reminders.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handled automatically by system notification payload
}

const plum = AppPalette.plum;
const ink = AppPalette.ink;
const cream = AppPalette.canvas;
const rose = Color(0xffe9c7d1);
const sage = Color(0xffb7c9b3);
const coral = Color(0xfff28c8c);
const line = AppPalette.border;
const blush = Color(0xfffff0f3);
const softLilac = Color(0xfff3eef8);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  }
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const MahilaMitr());
}

final _navigatorKey = GlobalKey<NavigatorState>();

class MahilaMitr extends StatefulWidget {
  const MahilaMitr({super.key});

  @override
  State<MahilaMitr> createState() => _MahilaMitrState();
}

class _MahilaMitrState extends State<MahilaMitr> {
  final appearance = AppearanceController();
  final activity = AppActivityController();
  @override
  void initState() { super.initState(); appearance.load(); appearance.startMonitoring(); }
  @override
  void dispose() { activity.dispose(); appearance.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Mahila Mitr',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => AppActivityScope(controller: activity,
          child: AppearanceScope(controller: appearance,
            child: AnimatedBuilder(animation: appearance, builder: (context, _) {
              final media = MediaQuery.of(context);
              return MediaQuery(data: media.copyWith(disableAnimations: media.disableAnimations ||
                appearance.effective == VisualEffects.reduced || appearance.effective == VisualEffects.off),
                child: AppActivityOverlay(controller: activity, child: child!));
            }))),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final guideController = WellnessGuideController();
  final email = TextEditingController();
  final otp = TextEditingController();
  final pairingCode = TextEditingController();
  final noteDraft = TextEditingController();
  final reflection = TextEditingController();
  final displayNameInput = TextEditingController();
  final notifications = FlutterLocalNotificationsPlugin();
  late final loggingReminders = LoggingReminders(notifications);
  bool _pendingLogReminder = false;
  bool _loggingDataReady = false;
  static const nearby = MethodChannel('mahila_mitr/nearby');
  Timer? nearbyTimer;
  Timer? nearbyPoll;
  bool nearbyAdvertising = false;
  bool nearbyScanning = false;
  bool nearbyScanTimedOut = false;
  int nearbyScanSeen = 0;
  int nearbyScanSeconds = 0;
  Timer? nearbySecondsTimer;
  final Set<String> nearbyCodes = {};
  final Map<String, String> nearbyInvitationNames = {};
  bool refreshing = false;
  StreamSubscription<AuthState>? authSubscription;
  RealtimeChannel? _linkChannel;
  String? _watchedLinkId;
  final ValueNotifier<int> _stateRevision = ValueNotifier<int>(0);
  DashboardStore? _store;
  Future<void>? _storeReady;
  String? _loadedAccount;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _syncRetry;
  String? _syncingAccount;
  bool _refreshAgain = false;
  String? _syncNotice;

  String? get _accountKey => session == null || role == null
      ? null : DashboardStore.accountKey(session!.user.id, role!);

  Future<void> _restoreDashboard() async {
    final key = _accountKey;
    if (key == null) return;
    _storeReady ??= () async { _store = await DashboardStore.open(); }();
    await _storeReady;
    if (!mounted || key != _accountKey || _loadedAccount == key) return;
    _loadedAccount = key;
    final cached = _store!.snapshot(key);
    if (cached != null) {
      _applyDashboard(cached);
      _loggingDataReady = true;
      unawaited(_syncLoggingReminders());
      _openPendingLogReminder();
    }
  }

  void _applyDashboard(Map<String, dynamic> data) {
    List<Map<String, dynamic>> rows(String field) =>
        (data[field] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    setState(() {
      link = data['link'] == null ? null : Map<String, dynamic>.from(data['link'] as Map);
      cycles = rows('cycles'); dayLogs = rows('dayLogs');
      ratings = rows('ratings'); notes = rows('notes');
      displayName = data['displayName'] as String?;
      partnerDisplayName = data['partnerDisplayName'] as String?;
      partnerNickname = data['partnerNickname'] as String?;
      myNickname = data['myNickname'] as String?;
      ownerName = data['ownerName'] as String?;
      profileChecked = true;
      syncError = null;
    });
  }

  Future<void> _saveLocal(String table, Map<String, dynamic> values,
      {Map<String, dynamic>? existing, bool delete = false, String? conflict,
      String? rpc}) async {
    final key = _accountKey;
    if (key == null) return;
    await _restoreDashboard();
    if (!mounted || key != _accountKey) return;
    final row = <String, dynamic>{
      ...?existing, ...values,
      'id': existing?['id'] ?? values['id'] ?? const Uuid().v4(),
    };
    await _store!.enqueue(key, table, row, delete: delete, conflict: conflict, rpc: rpc);
    if (!mounted || key != _accountKey) return;
    _applyDashboard(_store!.snapshot(key)!);
    setState(() => _syncNotice = 'Saved on this device · waiting to sync');
    _loggingDataReady = true;
    unawaited(_syncLoggingReminders());
    unawaited(refresh());
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    if (mounted) {
      _stateRevision.value++;
    }
  }

  // Whether our own PrivateRoomPage is currently open (so we skip popups for
  // status messages that the logged-in user themselves triggered).
  bool _isOnChatScreen = false;
  bool _isAppInForeground = true;
  SupabaseClient? get client => supabaseUrl.isEmpty || supabaseKey.isEmpty
      ? null
      : Supabase.instance.client;
  String? role;
  Session? session;
  bool codeSent = false;
  String? pendingEmail;
  bool busy = false;
  bool notificationsReady = false;
  bool profileChecked = false;
  String? syncError;
  String? displayName;
  String? ownerName;
  String? partnerDisplayName;
  String? partnerNickname;
  String? myNickname;
  final Set<String> _resolvingCodes = {};
  String get effectivePartnerName {
    if (partnerNickname != null && partnerNickname!.trim().isNotEmpty) {
      return partnerNickname!.trim();
    }
    if (partnerDisplayName != null && partnerDisplayName!.trim().isNotEmpty) {
      return partnerDisplayName!.trim();
    }
    if (ownerName != null && ownerName!.trim().isNotEmpty) {
      return ownerName!.trim();
    }
    return 'Partner';
  }

  String? invite;
  Map<String, dynamic>? link;
  List<Map<String, dynamic>> cycles = [];

  /// The most-recent cycle that has no end date — i.e. the period is ongoing.
  Map<String, dynamic>? get _activePeriod {
    if (cycles.isEmpty) return null;
    final latest = cycles.first;
    return latest['end_date'] == null ? latest : null;
  }
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> ratings = [];
  List<Map<String, dynamic>> dayLogs = [];

  static const moodMeta = <String, ({String label, String emoji, Color color})>{
    'happy': (label: 'Happy', emoji: '😊', color: Color(0xfffbe3e8)),
    'calm': (label: 'Calm', emoji: '🌿', color: Color(0xffe8f2e6)),
    'energetic': (label: 'Energetic', emoji: '⚡', color: Color(0xfffff3d6)),
    'sad': (label: 'Low', emoji: '😢', color: Color(0xffe9e5f5)),
    'irritable': (label: 'Irritable', emoji: '😤', color: Color(0xfffde8e4)),
    'anxious': (label: 'Anxious', emoji: '😰', color: Color(0xffe2e9f0)),
  };

  static const flowMeta = <String, ({String label, String icon})>{
    'none': (label: 'No flow', icon: '○'),
    'spotting': (label: 'Spotting', icon: '💧'),
    'light': (label: 'Light', icon: '🩸'),
    'medium': (label: 'Medium', icon: '🩸🩸'),
    'heavy': (label: 'Heavy', icon: '🩸🩸🩸'),
  };

  static const energyMeta = <String, ({String label, String icon})>{
    'high': (label: 'High', icon: '⚡'),
    'normal': (label: 'Balanced', icon: '🌱'),
    'low': (label: 'Low', icon: '🌙'),
  };

  Map<String, dynamic>? dayLogFor(DateTime date) {
    final key = sqlDate(date);
    for (final log in dayLogs) {
      if (log['date_on'] == key) return log;
    }
    return null;
  }

  bool hasDayLog(DateTime date) => dayLogFor(date) != null;
  String noteStyle = 'letter';
  int stars = 5;
  int tab = 0;
  int _navigatorAction = 0;
  final _navigationPreview = ValueNotifier<double?>(null);
  int calendarMode = 0;
  DateTime selectedDay = DateUtils.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = client?.auth.currentSession;
    authSubscription = client?.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      if (session?.user.id != event.session?.user.id) {
        _loggingDataReady = false;
        _loadedAccount = null;
        _stopLinkRealtime();
        _stopUnlinkedRealtime();
        profileChecked = false;
        link = null; cycles = []; dayLogs = []; ratings = []; notes = [];
        displayName = null; ownerName = null; partnerDisplayName = null;
        partnerNickname = null; myNickname = null;
        _syncNotice = null; syncError = null;
      }
      setState(() => session = event.session);
      if (event.session == null) _syncLoggingReminders();
      if (event.event != AuthChangeEvent.tokenRefreshed || _syncNotice != null) {
        refresh();
      }
      _initFirebaseMessaging();
    }, onError: (Object error, StackTrace stack) {
      // A refresh-token request may fail offline without invalidating the
      // restored session or hiding this account's saved dashboard.
      if (mounted) {
        setState(() => _syncNotice = 'Connection unavailable · showing saved data');
      }
    });
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => role = prefs.getString('role'));
      refresh();
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      if (results.any((value) => value != ConnectivityResult.none)) {
        refresh(notify: true);
      } else {
        setState(() => _syncNotice = 'Offline · changes are saved on this device');
      }
    });
    _syncRetry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isAppInForeground && session != null &&
          (_syncNotice != null || link == null)) {
        refresh();
      }
    });
    _initializeNotifications();
    _initFirebaseMessaging();
    nearby.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'found' && call.arguments is String && link == null) {
        unawaited(resolveNearbyInvitation(call.arguments as String));
      } else if (call.method == 'scanProgress' && call.arguments is int) {
        setState(() => nearbyScanSeen = call.arguments as int);
      } else if (call.method == 'error') {
        setState(() {
          nearbyAdvertising = false;
          nearbyScanning = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(call.arguments.toString())));
      }
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      await notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload == LoggingReminders.payload) {
            _pendingLogReminder = true;
            refresh();
          } else {
            openPrivateRoom();
          }
        },
      );
      final androidPlugin = notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      const channel = AndroidNotificationChannel(
        'private_room',
        'Private notifications',
        description: 'Discreet notifications from your partner',
        importance: Importance.max,
        showBadge: true,
      );
      await androidPlugin?.createNotificationChannel(channel);

      notificationsReady = true;
      final launch = await notifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true &&
          launch?.notificationResponse?.payload == LoggingReminders.payload) {
        _pendingLogReminder = true;
      }
      if (session == null || _loggingDataReady) _syncLoggingReminders();
      _openPendingLogReminder();
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
      notificationsReady = false;
    }
  }

  Future<void> _syncLoggingReminders() async {
    if (!notificationsReady) return;
    await loggingReminders.sync(
      enabled: session != null && role == 'owner',
      cycles: List.of(cycles),
      logs: List.of(dayLogs),
    );
  }

  void _openPendingLogReminder() {
    if (!_pendingLogReminder || !mounted || !profileChecked ||
        syncError != null || session == null || role != 'owner') {
      return;
    }
    _pendingLogReminder = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && session != null && role == 'owner') {
        showDayLogger(DateUtils.dateOnly(DateTime.now()));
      }
    });
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await messaging.getToken();
      if (token != null) {
        _registerPushToken(token);
      }
      messaging.onTokenRefresh.listen((token) {
        _registerPushToken(token);
      });
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final isViewingChat = _isOnChatScreen && _isAppInForeground;
        if (!isViewingChat) {
          _showDiscreetNotification(
            title: message.notification?.title,
            body: message.notification?.body,
          );
        }
      });
    } catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  Future<void> _registerPushToken(String token) async {
    final api = client;
    if (api == null || session == null) return;
    try {
      final platform = defaultTargetPlatform == TargetPlatform.android
          ? 'android'
          : defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : null;
      if (platform == null) return;
      await api.rpc('register_push_token', params: {
        'device_token': token,
        'device_platform': platform,
      });
      debugPrint('FCM token registered with Supabase');
    } catch (e) {
      debugPrint('Push token registration skipped or failed: $e');
    }
  }

  Future<void> _showDiscreetNotification({String? title, String? body}) async {
    if (!notificationsReady) return;
    try {
      await notifications.show(
        id: (DateTime.now().millisecondsSinceEpoch % 100000),
        title: title ?? 'Mahila Mitr',
        body: body ?? 'You have a notification',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'private_room',
            'Private notifications',
            channelDescription: 'Discreet notifications from your partner',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) refresh(notify: true);
  }

  @override
  void dispose() {
    _navigationPreview.dispose();
    WidgetsBinding.instance.removeObserver(this);
    authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncRetry?.cancel();
    _stopLinkRealtime();
    _stopUnlinkedRealtime();
    _stateRevision.dispose();
    nearbyTimer?.cancel();
    nearbyPoll?.cancel();
    nearbySecondsTimer?.cancel();
    nearby.setMethodCallHandler(null);
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(nearby
          .invokeMethod<void>('stopAdvertising')
          .catchError((Object _) {}));
      unawaited(
          nearby.invokeMethod<void>('stopScan').catchError((Object _) {}));
    }
    for (final controller in [
      email,
      otp,
      pairingCode,
      noteDraft,
      reflection,
      displayNameInput
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> action(Future<void> Function() work, {String label = 'Saving changes…'}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await runWithAppActivity(context, label, work);
    } catch (error, stackTrace) {
      debugPrint('Mahila Mitr action failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final message = error is AuthException &&
              error.code == 'email_address_not_authorized'
          ? 'Email sign-in is not available for this address yet.'
          : error is AuthRetryableFetchException &&
                  error.message.contains('Error sending confirmation email')
              ? 'We could not send the email code right now. Please try again later.'
              : error is AuthRetryableFetchException
                  ? 'Could not reach the sign-in service. Check your connection and try again.'
                  : error is AuthException
                      ? error.message
                      : error is FormatException
                          ? error.message
                          : error is PlatformException
                              ? error.message ?? 'Bluetooth is unavailable.'
                              : kDebugMode
                                  ? 'Sign-in failed: $error'
                                  : 'Could not complete this. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseRole(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', value);
    setState(() => role = value);
    refresh();
  }

  // ─── Realtime helpers ──────────────────────────────────────────────────────

  void _startLinkRealtime(String linkId) {
    if (_watchedLinkId == linkId) return; // already subscribed
    _stopLinkRealtime();
    _watchedLinkId = linkId;
    final api = client;
    if (api == null) return;

    _linkChannel = api
        .channel('private-room-$linkId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ephemeral_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'link_id',
            value: linkId,
          ),
          callback: _onRealtimeMessage,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'link_id',
            value: linkId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final senderId = row['sender_id'] as String?;
            if (senderId != null && senderId != session?.user.id) {
              refresh();
              final isViewingChat = _isOnChatScreen && _isAppInForeground;
              if (!isViewingChat) {
                _showDiscreetNotification(body: 'You have a new private note');
              }
            }
          },
        )
        .subscribe();
  }

  void _stopLinkRealtime() {
    final ch = _linkChannel;
    if (ch != null) {
      client?.removeChannel(ch);
      _linkChannel = null;
      _watchedLinkId = null;
    }
  }

  RealtimeChannel? _unlinkedWatchChannel;

  void _startUnlinkedRealtime() {
    if (_unlinkedWatchChannel != null) return;
    final api = client;
    final uid = session?.user.id;
    if (api == null || uid == null || link != null) return;

    _unlinkedWatchChannel = api
        .channel('unlinked-watch-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'links',
          callback: (_) {
            refresh();
          },
        )
        .subscribe();
  }

  void _stopUnlinkedRealtime() {
    final ch = _unlinkedWatchChannel;
    if (ch != null) {
      client?.removeChannel(ch);
      _unlinkedWatchChannel = null;
    }
  }

  void _onRealtimeMessage(PostgresChangePayload payload) {
    if (!mounted) return;
    final row = payload.newRecord;
    final kind = row['kind'] as String? ?? 'message';
    final senderId = row['sender_id'] as String?;
    final myId = session?.user.id;

    // Check if the message is from the partner (not from ourselves)
    if (senderId != null && senderId != myId) {
      final isViewingChat = _isOnChatScreen && _isAppInForeground;
      if (!isViewingChat) {
        _showDiscreetNotification();
      }

      if (kind == 'status' && !isViewingChat) {
        final conversationId = row['conversation_id'] as String?;
        if (conversationId != null) {
          _fetchAndShowStatus(conversationId);
        } else {
          _showStatusPopup();
        }
      }
    }
  }

  Future<void> _fetchAndShowStatus(String conversationId) async {
    try {
      final rows = await client!.rpc('get_ephemeral_messages',
          params: {'target_conversation_id': conversationId});
      final messages = List<Map<String, dynamic>>.from(
          (rows as List).map((e) => Map<String, dynamic>.from(e as Map)));
      // Find the latest status message from partner
      final myId = session?.user.id;
      final statusMsg = messages.lastWhere(
          (m) => m['kind'] == 'status' && m['sender_id'] != myId,
          orElse: () => {});
      if (statusMsg.isNotEmpty) {
        _partnerLatestStatus = statusMsg['body'] as String?;
      }
    } catch (e) {
      debugPrint('Failed to fetch status body: $e');
    }
    if (mounted) _showStatusPopup();
  }

  void _showStatusPopup() {
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (_) => CreativeStatusDialog(
        status: _partnerLatestStatus ?? '💗 Missing you',
        partnerName: effectivePartnerName,
        onAction: openPrivateRoom,
      ),
    );
  }

  String? _partnerLatestStatus;

  Future<void> openPrivateRoom() async {
    if (link == null || client == null) return;
    // Load conversations for this link
    final rows = await client!.rpc('get_ephemeral_conversations');
    final convos = List<Map<String, dynamic>>.from(
        (rows as List).map((e) => Map<String, dynamic>.from(e as Map)));
    if (!mounted) return;
    setState(() => _isOnChatScreen = true);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PrivateRoomPage(
        client: client!,
        linkId: link!['id'] as String,
        myUserId: session!.user.id,
        myName: displayName ?? 'You',
        partnerName: effectivePartnerName,
        partnerNickname: partnerNickname ?? '',
        partnerDisplayName: partnerDisplayName ?? "",
        myNickname: myNickname ?? '',
        initialConversations: convos,
        onStatusSent: (status) {
          _partnerLatestStatus = status;
        },
        onNicknameChanged: (newNick) {
          setState(() {
            partnerNickname = newNick.isEmpty ? null : newNick;
            ownerName = effectivePartnerName;
          });
        },
      ),
    ));
    if (mounted) setState(() => _isOnChatScreen = false);
  }

  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> refresh({bool notify = false}) async {
    final api = client;
    final key = _accountKey;
    final userId = session?.user.id;
    final currentRole = role;
    if (api == null || key == null || userId == null || currentRole == null) return;
    try {
      await _restoreDashboard();
    } catch (error) {
      _storeReady = null;
      if (mounted && key == _accountKey) {
        setState(() => syncError = 'Could not open saved data. Please retry.');
      }
      return;
    }
    if (!mounted || key != _accountKey) return;
    if (_syncingAccount != null) {
      _refreshAgain = true;
      return;
    }
    _syncingAccount = key;
    refreshing = true;
    try {
      await _store!.flush(key, (mutation) async {
        if (key != _accountKey) throw StateError('Account changed');
        final table = mutation['table'] as String;
        final row = Map<String, dynamic>.from(mutation['row'] as Map);
        if (mutation['rpc'] == 'open_note') {
          await api.rpc('open_note', params: {'note_id': row['id']})
              .timeout(const Duration(seconds: 15));
        } else if (mutation['delete'] == true) {
          await api.from(table).delete().eq('id', row['id']).timeout(const Duration(seconds: 15));
        } else {
          await api.from(table).upsert(row, onConflict: mutation['conflict'] as String,
              ignoreDuplicates: table == 'notes')
              .timeout(const Duration(seconds: 15));
        }
      }, isCurrentAccount: () => mounted && key == _accountKey);
      if (!mounted || key != _accountKey) return;
      final profileRows = await api
          .from('profiles')
          .select('display_name')
          .eq('id', userId)
          .limit(1).timeout(const Duration(seconds: 15));
      final linkRows = await api
          .from('links')
          .select('id,owner_id,partner_id,owner_nickname,partner_nickname')
          .limit(1).timeout(const Duration(seconds: 15));
      final nextLink =
          linkRows.isEmpty ? null : Map<String, dynamic>.from(linkRows.first);
      if (nextLink != null && nearbyAdvertising) {
        nearbyTimer?.cancel();
        await nearby.invokeMethod<void>('stopAdvertising');
        if (mounted) setState(() => nearbyAdvertising = false);
      }
      if (nextLink != null && nearbyScanning) {
        nearbyTimer?.cancel();
        nearbySecondsTimer?.cancel();
        await nearby.invokeMethod<void>('stopScan');
        if (mounted) setState(() => nearbyScanning = false);
      }
      final cycleRows = currentRole == 'owner' || nextLink != null
          ? await api
              .from('cycles')
              .select('id,start_date,end_date,flow,symptoms,notes')
              .order('start_date', ascending: false).timeout(const Duration(seconds: 15))
          : <Map<String, dynamic>>[];
      final ratingRows = nextLink != null
          ? await api
              .from('date_ratings')
              .select('id,link_id,author_id,date_on,stars,reflection')
              .eq('link_id', nextLink['id'])
              .order('date_on', ascending: false).timeout(const Duration(seconds: 15))
          : <Map<String, dynamic>>[];
      final noteRows = currentRole == 'owner'
          ? await api
              .from('notes')
              .select('id,body,style,created_at,opened_at')
              .order('created_at', ascending: false).timeout(const Duration(seconds: 15))
          : <Map<String, dynamic>>[];
      List<Map<String, dynamic>> dayLogRows = [];
      var dayLogsLoaded = true;
      try {
        if (currentRole == 'owner' || nextLink != null) {
          final rows = await api
              .from('day_logs')
              .select('id,owner_id,date_on,mood,flow,energy,symptoms,note')
              .order('date_on', ascending: false).timeout(const Duration(seconds: 15));
          dayLogRows = List<Map<String, dynamic>>.from(rows);
        }
      } catch (e) {
        dayLogsLoaded = false;
        debugPrint('day_logs query skipped or table not created yet: $e');
      }
      String? nextPartnerDisplayName;
      String? nextPartnerNickname;
      String? nextMyNickname;
      if (nextLink != null) {
        final partnerUserId =
            currentRole == 'owner' ? nextLink['partner_id'] : nextLink['owner_id'];
        if (partnerUserId != null) {
          final pRows = await api
              .from('profiles')
              .select('display_name')
              .eq('id', partnerUserId)
              .limit(1).timeout(const Duration(seconds: 15));
          if (pRows.isNotEmpty) {
            nextPartnerDisplayName = pRows.first['display_name'] as String?;
          }
        }
        if (currentRole == 'owner') {
          nextPartnerNickname = nextLink['partner_nickname'] as String?;
          nextMyNickname = nextLink['owner_nickname'] as String?;
        } else {
          nextPartnerNickname = nextLink['owner_nickname'] as String?;
          nextMyNickname = nextLink['partner_nickname'] as String?;
        }
      }
      final incoming = noteRows.any((item) =>
          item['opened_at'] == null &&
          !notes.any((old) => old['id'] == item['id']));
      if (mounted && key == _accountKey) {
        await _store!.acceptRemote(key, {
          'link': nextLink, 'cycles': cycleRows, 'ratings': ratingRows,
          'notes': noteRows, 'dayLogs': dayLogsLoaded ? dayLogRows : dayLogs,
          'displayName': profileRows.isEmpty ? null : profileRows.first['display_name'],
          'partnerDisplayName': nextPartnerDisplayName,
          'partnerNickname': nextPartnerNickname, 'myNickname': nextMyNickname,
          'ownerName': nextPartnerNickname?.trim().isNotEmpty == true
              ? nextPartnerNickname!.trim()
              : (nextPartnerDisplayName?.trim().isNotEmpty == true
                  ? nextPartnerDisplayName!.trim()
                  : 'Partner'),
        });
        if (!mounted || key != _accountKey) return;
        _applyDashboard(_store!.snapshot(key)!);
        setState(() => _syncNotice = _store!.pendingCount(key) > 0
            ? 'Saved on this device · waiting to sync'
            : dayLogsLoaded ? null : 'Daily logs could not refresh · showing saved data');
        // Start realtime subscription once we know the link id
        if (nextLink != null) {
          _stopUnlinkedRealtime();
          _startLinkRealtime(nextLink['id'] as String);
        } else {
          _stopLinkRealtime();
          _startUnlinkedRealtime();
        }
      }
      if (mounted && key == _accountKey && notify && incoming && notificationsReady) {
        await _showDiscreetNotification();
      }
      if (mounted && key == _accountKey && dayLogsLoaded) {
        _loggingDataReady = true;
        await _syncLoggingReminders();
        _openPendingLogReminder();
      }
    } catch (error) {
      if (mounted && key == _accountKey) {
        setState(() {
          _syncNotice = error is PostgrestException
              ? 'Sync needs attention: ${error.message}. Your changes are saved on this device.'
              : 'Offline or service unavailable · changes are saved on this device';
          if (!profileChecked) {
            syncError = 'Connect to the internet to load this account for the first time.';
          }
        });
      }
      debugPrint('Mahila Mitr refresh failed: $error');
    } finally {
      refreshing = false;
      _syncingAccount = null;
      if (_refreshAgain && mounted) {
        _refreshAgain = false;
        unawaited(refresh());
      }
    }
  }

  Future<void> updatePartnerNickname(String newNickname) => action(() async {
        await client!.rpc('set_partner_nickname', params: {
          'new_nickname': newNickname.trim(),
        });
        await refresh();
      }, label: 'Saving nickname…');

  void showEditNicknameDialog() {
    final controller = TextEditingController(text: partnerNickname ?? '');
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
              partnerDisplayName != null
                  ? 'Choose a sweet nickname for $partnerDisplayName'
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
            onPressed: () {
              Navigator.pop(ctx);
              updatePartnerNickname(controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> resolveNearbyInvitation(String code) async {
    if (link != null) return;
    if (_resolvingCodes.contains(code) || nearbyInvitationNames[code] != null) {
      return;
    }
    _resolvingCodes.add(code);
    if (mounted && !nearbyCodes.contains(code)) {
      setState(() => nearbyCodes.add(code));
    }
    try {
      final result =
          await client!.rpc('preview_invite', params: {'invite_code': code});
      final name = result?.toString().trim();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => nearbyInvitationNames[code] = name);
      }
    } catch (error) {
      debugPrint('Invitation preview failed: $error');
    } finally {
      _resolvingCodes.remove(code);
    }
  }

  String get _normalizedEmail => email.text.trim().toLowerCase();

  Future<void> sendCode() => action(() async {
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_normalizedEmail)) {
          throw const FormatException('Enter a valid email address.');
        }
        await client!.auth.signInWithOtp(email: _normalizedEmail);
        setState(() {
          codeSent = true;
          pendingEmail = _normalizedEmail;
        });
      }, label: 'Sending verification code…');
  Future<void> verifyCode() => action(() async {
        await client!.auth.verifyOTP(
            email: pendingEmail, token: otp.text.trim(), type: OtpType.email);
      }, label: 'Verifying code…');
  Future<void> saveProfile() => action(() async {
        final value = displayNameInput.text.trim();
        if (value.length < 2 || value.length > 50) {
          throw const FormatException(
              'Enter a name between 2 and 50 characters.');
        }
        await _saveLocal('profiles', {
          'id': session!.user.id,
          'display_name': value,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        if (mounted) setState(() => displayName = value);
      }, label: 'Saving profile…');

  // ── Period flow: STEP 1 – Start a new period ────────────────────────────
  Future<void> showStartPeriodConfirm() async {
    DateTime selectedStart = DateUtils.dateOnly(DateTime.now());
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSS) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: line, borderRadius: BorderRadius.circular(4)),
            ),
            const Text('🩸', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            const Text('Start your period',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              "When did it start? We'll track it and remind you to mark the end.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: ink.withValues(alpha: .6)),
            ),
            const SizedBox(height: 24),
            // Quick chips
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _StartChip(
                label: 'Today',
                selected: selectedStart == DateUtils.dateOnly(DateTime.now()),
                onTap: () => setSS(() =>
                    selectedStart = DateUtils.dateOnly(DateTime.now())),
              ),
              const SizedBox(width: 10),
              _StartChip(
                label: 'Yesterday',
                selected: selectedStart ==
                    DateUtils.dateOnly(DateTime.now())
                        .subtract(const Duration(days: 1)),
                onTap: () => setSS(() => selectedStart =
                    DateUtils.dateOnly(DateTime.now())
                        .subtract(const Duration(days: 1))),
              ),
              const SizedBox(width: 10),
              _StartChip(
                label: 'Pick date',
                selected: false,
                onTap: () async {
                  final v = await showDatePicker(
                    context: context,
                    initialDate: selectedStart,
                    firstDate: DateTime(2010),
                    lastDate: DateUtils.dateOnly(DateTime.now()),
                  );
                  if (v != null) setSS(() => selectedStart = v);
                },
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'Selected: ${_fmtDate(selectedStart)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: plum),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: coral,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Start period',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: TextStyle(color: ink.withValues(alpha: .45))),
            ),
          ]),
        ),
      ),
    );
    if (confirmed != true) return;
    await action(() async {
      await _saveLocal('cycles', {
        'owner_id': session!.user.id,
        'start_date': sqlDate(selectedStart),
        'end_date': null,
        'flow': 'medium',
        'symptoms': <String>[],
      });
    });
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ── Period flow: STEP 2 – End the active period ──────────────────────────
  Future<void> showEndPeriodSheet(Map<String, dynamic> active) async {
    final start = DateTime.parse(active['start_date'] as String);
    DateTime endDate = DateUtils.dateOnly(DateTime.now());
    // Clamp: end cannot be before start
    if (endDate.isBefore(start)) endDate = start;
    var flow = active['flow'] as String? ?? 'medium';
    final symptoms = <String>{
      ...((active['symptoms'] as List?)?.whereType<String>() ?? const [])
    };
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSS) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 20, 24, MediaQuery.viewInsetsOf(context).bottom + 28),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: line, borderRadius: BorderRadius.circular(4)),
              ),
              const Text('✅', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text('End your period',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Started ${_fmtDate(start)}. When did it end?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14, color: ink.withValues(alpha: .6)),
              ),
              const SizedBox(height: 24),
              // Quick end chips
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _StartChip(
                  label: 'Today',
                  selected: endDate ==
                      DateUtils.dateOnly(DateTime.now()),
                  onTap: () => setSS(() =>
                      endDate = DateUtils.dateOnly(DateTime.now())),
                ),
                const SizedBox(width: 10),
                _StartChip(
                  label: 'Yesterday',
                  selected: endDate ==
                      DateUtils.dateOnly(DateTime.now())
                          .subtract(const Duration(days: 1)),
                  onTap: () => setSS(() => endDate =
                      DateUtils.dateOnly(DateTime.now())
                          .subtract(const Duration(days: 1))),
                ),
                const SizedBox(width: 10),
                _StartChip(
                  label: 'Pick date',
                  selected: false,
                  onTap: () async {
                    final v = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: start,
                      lastDate: DateUtils.dateOnly(DateTime.now()),
                    );
                    if (v != null) setSS(() => endDate = v);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                'End date: ${_fmtDate(endDate)}  ·  ${endDate.difference(start).inDays + 1} day(s)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: plum),
              ),
              const SizedBox(height: 20),
              // Flow
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Overall flow',
                    style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'light', label: Text('Light')),
                  ButtonSegment(value: 'medium', label: Text('Medium')),
                  ButtonSegment(value: 'heavy', label: Text('Heavy')),
                ],
                selected: {flow},
                onSelectionChanged: (v) =>
                    setSS(() => flow = v.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              // Symptoms
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Symptoms (optional)',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 7,
                  children: [
                    'Cramps', 'Low energy', 'Headache',
                    'Mood changes', 'Bloating',
                  ]
                      .map((item) => FilterChip(
                            label: Text(item),
                            selected: symptoms.contains(item),
                            onSelected: (selected) => setSS(() => selected
                                ? symptoms.add(item)
                                : symptoms.remove(item))))
                      .toList(),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: plum,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save & end period',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel',
                    style: TextStyle(color: ink.withValues(alpha: .45))),
              ),
            ]),
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    await action(() async {
      if (endDate.isBefore(start)) {
        throw const FormatException('The end date cannot be before the start date.');
      }
      await _saveLocal('cycles', {
        'owner_id': session!.user.id,
        'end_date': sqlDate(endDate),
        'flow': flow,
        'symptoms': symptoms.toList(),
      }, existing: active);
    });
  }

  Future<void> showPeriodLogger({Map<String, dynamic>? existing}) async {
    DateTime? start = existing == null
        ? null
        : DateTime.parse(existing['start_date'] as String);
    DateTime? end = existing?['end_date'] == null
        ? null
        : DateTime.parse(existing!['end_date'] as String);
    var flow = existing?['flow'] as String? ?? 'medium';
    String? dateError;
    final symptoms = <String>{
      ...((existing?['symptoms'] as List?)?.whereType<String>() ?? const [])
    };
    final notesController =
        TextEditingController(text: existing?['notes'] as String? ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cream,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              22, 18, 22, MediaQuery.viewInsetsOf(context).bottom + 22),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: line, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 18),
              Align(
                  alignment: Alignment.centerLeft,
                  child: heading(
                      'Cycle log',
                      existing == null ? 'Log your period' : 'Edit period',
                      existing == null
                          ? 'Choose the real start date. Nothing is preselected.'
                          : 'Update any date or detail below.')),
              if (existing == null)
                Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(spacing: 8, children: [
                      ActionChip(
                          label: const Text('Started today'),
                          onPressed: () => setSheetState(() {
                                start = DateUtils.dateOnly(DateTime.now());
                                dateError = null;
                              })),
                      ActionChip(
                          label: const Text('Started yesterday'),
                          onPressed: () => setSheetState(() {
                                start = DateUtils.dateOnly(DateTime.now())
                                    .subtract(const Duration(days: 1));
                                dateError = null;
                              })),
                    ])),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: dateField('Started', start, () async {
                  final value = await showDatePicker(
                      context: context,
                      initialDate: start ?? DateUtils.dateOnly(DateTime.now()),
                      firstDate: DateTime(2010),
                      lastDate: DateUtils.dateOnly(DateTime.now()));
                  if (value != null) {
                    setSheetState(() {
                      start = value;
                      if (end != null && end!.isBefore(value)) end = null;
                      dateError = null;
                    });
                  }
                })),
                const SizedBox(width: 10),
                Expanded(
                    child: dateField('Ended', end, () async {
                  final value = await showDatePicker(
                      context: context,
                      initialDate:
                          end ?? start ?? DateUtils.dateOnly(DateTime.now()),
                      firstDate: start ?? DateTime(2010),
                      lastDate: DateUtils.dateOnly(DateTime.now()));
                  if (value != null) setSheetState(() => end = value);
                },
                        clear: end == null
                            ? null
                            : () => setSheetState(() => end = null))),
              ]),
              if (dateError != null)
                Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(dateError!,
                            style: const TextStyle(color: coral)))),
              const SizedBox(height: 18),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Flow',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'light', label: Text('Light')),
                    ButtonSegment(value: 'medium', label: Text('Medium')),
                    ButtonSegment(value: 'heavy', label: Text('Heavy')),
                  ],
                  selected: {
                    flow
                  },
                  onSelectionChanged: (value) =>
                      setSheetState(() => flow = value.first),
                  showSelectedIcon: false),
              const SizedBox(height: 18),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Symptoms',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                      spacing: 7,
                      children: [
                        'Cramps',
                        'Low energy',
                        'Headache',
                        'Mood changes',
                        'Bloating'
                      ]
                          .map((item) => FilterChip(
                              label: Text(item),
                              selected: symptoms.contains(item),
                              onSelected: (selected) => setSheetState(() =>
                                  selected
                                      ? symptoms.add(item)
                                      : symptoms.remove(item))))
                          .toList())),
              const SizedBox(height: 12),
              input(notesController, 'Private notes', lines: 3, maxLength: 500),
              button('Save period', () {
                if (start == null) {
                  setSheetState(
                      () => dateError = 'Choose when the period started.');
                  return;
                }
                Navigator.pop(sheetContext, true);
              }),
              if (existing != null)
                TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Delete this entry',
                        style: TextStyle(color: coral))),
            ]),
          ),
        ),
      ),
    );
    final notes = notesController.text.trim();
    // Modal futures complete as dismissal begins. Keep controllers alive until
    // the reverse transition has removed the TextField from the tree.
    Timer(const Duration(milliseconds: 400), notesController.dispose);
    if (saved == null) return;
    if (saved == false && existing != null) {
      await action(() async {
        await _saveLocal('cycles', {}, existing: existing, delete: true);
      });
      return;
    }
    await action(() async {
      final values = {
        'owner_id': session!.user.id,
        'start_date': sqlDate(start!),
        'end_date': end == null ? null : sqlDate(end!),
        'flow': flow,
        'symptoms': symptoms.toList(),
        'notes': notes.isEmpty ? null : notes,
      };
      await _saveLocal('cycles', values, existing: existing);
    });
  }

  Future<void> showDayLogger(DateTime date) async {
    final existing = dayLogFor(date);
    var selectedMood = existing?['mood'] as String?;
    var selectedFlow = existing?['flow'] as String? ?? 'none';
    var selectedEnergy = existing?['energy'] as String?;
    final symptoms = <String>{
      ...((existing?['symptoms'] as List?)?.whereType<String>() ?? const [])
    };
    final noteController =
        TextEditingController(text: existing?['note'] as String? ?? '');
    var showDetails = existing != null;

    const availableSymptoms = [
      'Cramps',
      'Headache',
      'Bloating',
      'Tender breasts',
      'Backache',
      'Fatigue',
      'Mood swings',
      'Cravings',
      'Acne',
      'Nausea',
    ];

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              22, 18, 22, MediaQuery.viewInsetsOf(context).bottom + 22),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                      color: line, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: heading(
                  'A moment for you',
                  DateUtils.isSameDay(date, DateTime.now())
                      ? 'How are you today?'
                      : formatDate(date),
                  'Start with what feels easy. More detail is always optional.',
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('How are you feeling today?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: moodMeta.entries.map((e) {
                    final key = e.key;
                    final item = e.value;
                    final isSelected = selectedMood == key;
                    return ChoiceChip(
                      label: Text('${item.emoji} ${item.label}'),
                      selected: isSelected,
                      selectedColor: item.color,
                      onSelected: (val) =>
                          setSheetState(() => selectedMood = val ? key : null),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Period flow',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: flowMeta.entries.map((e) {
                    final key = e.key;
                    final item = e.value;
                    final isSelected = selectedFlow == key;
                    return ChoiceChip(
                      label: Text('${item.icon} ${item.label}'),
                      selected: isSelected,
                      selectedColor: rose,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedFlow = key);
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setSheetState(() => showDetails = !showDetails),
                  icon: Icon(showDetails
                      ? Icons.expand_less_rounded
                      : Icons.add_circle_outline_rounded),
                  label: Text(showDetails
                      ? 'Hide optional details'
                      : 'Add energy, symptoms or a private note'),
                ),
              ),
              AnimatedCrossFade(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                crossFadeState: showDetails
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Column(children: [
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Energy level',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: energyMeta.entries.map((e) {
                        final key = e.key;
                        final item = e.value;
                        return ChoiceChip(
                          label: Text('${item.icon} ${item.label}'),
                          selected: selectedEnergy == key,
                          selectedColor: sage.withValues(alpha: .4),
                          onSelected: (val) => setSheetState(
                              () => selectedEnergy = val ? key : null),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Body & symptoms',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: availableSymptoms
                          .map((sym) => FilterChip(
                                label: Text(sym),
                                selected: symptoms.contains(sym),
                                onSelected: (selected) => setSheetState(() =>
                                    selected
                                        ? symptoms.add(sym)
                                        : symptoms.remove(sym)),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  input(noteController, 'Private note (optional)',
                      lines: 3, maxLength: 500),
                ]),
              ),
              button(existing == null ? 'Save daily log' : 'Update daily log',
                  () => Navigator.pop(sheetContext, true)),
              if (existing != null)
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Delete this day’s log',
                      style: TextStyle(color: coral)),
                ),
            ]),
          ),
        ),
      ),
    );

    final noteText = noteController.text.trim();
    Timer(const Duration(milliseconds: 400), noteController.dispose);

    if (saved == null) return;
    if (saved == false && existing != null) {
      await action(() async {
        await _saveLocal('day_logs', {}, existing: existing, delete: true);
      });
      return;
    }

    var saveCompleted = false;
    await action(() async {
      final values = {
        'owner_id': session!.user.id,
        'date_on': sqlDate(date),
        'mood': selectedMood,
        'flow': selectedFlow,
        'energy': selectedEnergy,
        'symptoms': symptoms.toList(),
        'note': noteText.isEmpty ? null : noteText,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await _saveLocal('day_logs', values, existing: existing,
          conflict: 'owner_id,date_on');
      saveCompleted = true;
    });
    if (saveCompleted &&
        existing == null &&
        DateUtils.isSameDay(date, DateTime.now())) {
      guideController.celebrate();
    }
    if (saveCompleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(existing == null
            ? 'Today’s check-in is saved privately.'
            : 'Your check-in has been updated.'),
      ));
    }
  }

  Widget dateField(String label, DateTime? value, VoidCallback onTap,
          {VoidCallback? clear}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: line)),
          child: Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 18, color: plum),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: ink.withValues(alpha: .55))),
                  Text(value == null ? 'Choose date' : formatDate(value),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ])),
            if (clear != null)
              IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: clear,
                  icon: const Icon(Icons.close, size: 17)),
          ]),
        ),
      );

  String sqlDate(DateTime value) =>
      DateUtils.dateOnly(value).toIso8601String().substring(0, 10);
  Future<void> createInvite() => action(() async {
        final value = await client!.rpc('create_invite');
        setState(() => invite = value.toString());
      }, label: 'Creating invite…');
  Future<void> shareNearby() => action(() async {
        if (defaultTargetPlatform != TargetPlatform.android) {
          throw const FormatException(
              'Nearby Bluetooth pairing is currently available on Android phones.');
        }
        final value = await client!.rpc('create_invite');
        final code = value.toString().trim().replaceAll('"', '').toUpperCase();
        setState(() {
          invite = code;
          nearbyAdvertising = true;
        });
        try {
          await nearby.invokeMethod<void>('startAdvertising', {'code': code});
        } catch (_) {
          if (mounted) setState(() => nearbyAdvertising = false);
          rethrow;
        }
        nearbyTimer?.cancel();
        nearbyTimer = Timer(const Duration(minutes: 10), () {
          nearby.invokeMethod<void>('stopAdvertising');
          if (mounted) setState(() => nearbyAdvertising = false);
        });
      }, label: 'Starting nearby sharing…');
  Future<void> scanNearby() => action(() async {
        if (defaultTargetPlatform != TargetPlatform.android) {
          throw const FormatException(
              'Nearby Bluetooth pairing is currently available on Android phones.');
        }
        nearbySecondsTimer?.cancel();
        setState(() {
          nearbyCodes.clear();
          nearbyInvitationNames.clear();
          nearbyScanning = true;
          nearbyScanTimedOut = false;
          nearbyScanSeen = 0;
          nearbyScanSeconds = 0;
        });
        nearbySecondsTimer =
            Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!mounted || !nearbyScanning) {
            timer.cancel();
            return;
          }
          setState(() => nearbyScanSeconds++);
        });
        try {
          await nearby.invokeMethod<void>('startScan');
        } catch (_) {
          nearbySecondsTimer?.cancel();
          if (mounted) setState(() => nearbyScanning = false);
          rethrow;
        }
        nearbyTimer?.cancel();
        nearbyTimer = Timer(const Duration(seconds: 30), () {
          nearby.invokeMethod<void>('stopScan');
          nearbySecondsTimer?.cancel();
          if (mounted) {
            setState(() {
              nearbyScanning = false;
              nearbyScanTimedOut = true;
            });
          }
        });
      }, label: 'Starting scan…');
  Future<void> stopNearby() async {
    nearbyTimer?.cancel();
    nearbySecondsTimer?.cancel();
    final wasAdvertising = nearbyAdvertising;
    setState(() {
      nearbyAdvertising = false;
      nearbyScanning = false;
    });
    await nearby
        .invokeMethod<void>(wasAdvertising ? 'stopAdvertising' : 'stopScan')
        .catchError((_) {});
  }

  Future<void> connectNearby(String code) async {
    pairingCode.text = code;
    await acceptInvite();
  }

  Future<void> acceptInvite() => action(() async {
        await client!.rpc('accept_invite',
            params: {'invite_code': pairingCode.text.trim().toUpperCase()});
        if (nearbyScanning) await nearby.invokeMethod<void>('stopScan');
        nearbyTimer?.cancel();
        nearbySecondsTimer?.cancel();
        if (mounted) {
          setState(() {
            nearbyScanning = false;
            nearbyCodes.clear();
            nearbyInvitationNames.clear();
          });
        }
        for (var attempt = 0; refreshing && attempt < 40; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        await refresh();
      }, label: 'Connecting partner…');
  Future<void> unlink() => action(() async {
        await client!.rpc('unlink_partner');
        setState(() {
          link = null;
          notes = [];
          ratings = [];
        });
        await refresh();
      }, label: 'Disconnecting partner…');
  Future<void> confirmUnlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.link_off_rounded, color: plum),
        title: const Text('Disconnect this pairing?'),
        content: const Text(
            'Both people will lose access to shared moments and reflections. Your private cycle history stays in your account.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep connection')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true) await unlink();
  }

  Future<void> sendNote() => action(() async {
        if (link == null || noteDraft.text.trim().isEmpty) return;
        await _saveLocal('notes', {
          'link_id': link!['id'],
          'sender_id': session!.user.id,
          'recipient_id': link!['owner_id'],
          'body': noteDraft.text.trim(),
          'style': noteStyle,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        noteDraft.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Note saved. It will send when connected.')));
        }
      }, label: 'Sending note…');
  Future<void> rateDate() => action(() async {
        if (link == null) return;
        final today = DateUtils.dateOnly(DateTime.now())
            .toIso8601String()
            .substring(0, 10);
        final previous = ratings.where((row) => row['link_id'] == link!['id'] &&
            row['author_id'] == session!.user.id && row['date_on'] == today).firstOrNull;
        await _saveLocal('date_ratings', {
          'link_id': link!['id'],
          'author_id': session!.user.id,
          'date_on': today,
          'stars': stars,
          'reflection':
              reflection.text.trim().isEmpty ? null : reflection.text.trim(),
        }, existing: previous, conflict: 'link_id,author_id,date_on');
        reflection.clear();
      }, label: 'Saving reflection…');
  Future<void> openNote(Map<String, dynamic> note) async {
    final style = note['style'] as String? ?? 'letter';
    final design = noteDesign[style] ?? noteDesign['letter']!;
    if (mounted) {
      await showMomentReader(context, design: design,
        message: note['body'] as String, fromName: effectivePartnerName,
        createdAt: note['created_at'] as String?);
    }
    if (note['opened_at'] == null) {
      await action(() async {
        await _saveLocal('notes', {
          'opened_at': DateTime.now().toUtc().toIso8601String(),
        }, existing: note, rpc: 'open_note');
      });
    }
  }

  Widget card(String title, List<Widget> children,
          {Color color = Colors.white}) =>
      AppSurface(title: title, color: color, children: children);

  Widget button(String label, VoidCallback onPressed,
          {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: secondary
              ? OutlinedButton(
                  onPressed: busy ? null : onPressed, child: Text(label))
              : FilledButton(
                  onPressed: busy ? null : onPressed, child: Text(label)),
        ),
      );

  Widget input(TextEditingController controller, String label,
          {TextInputType? keyboard, int lines = 1, int? maxLength}) =>
      AppTextInput(controller: controller, label: label, keyboard: keyboard,
          lines: lines, maxLength: maxLength);

  Widget heading(String eyebrow, String title, [String? subtitle]) =>
      AppPageHeading(eyebrow: eyebrow, title: title, subtitle: subtitle);

  @override
  Widget build(BuildContext context) {
    if (role == null) return roleScreen();
    if (session == null) return signInScreen();
    if (syncError != null) return configurationErrorScreen();
    if (!profileChecked) {
      return const Scaffold(
          body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            FloralProgressIndicator(), SizedBox(height: 12),
            Text('Loading your account…', style: TextStyle(color: AppPalette.muted)),
          ])));
    }
    if (displayName == null) return profileSetupScreen();
    final pages = role == 'owner'
        ? [homeScreen(), insightsScreen(), momentsScreen(), moreScreen()]
        : [partnerHomeScreen(), insightsScreen(), momentsScreen(), moreScreen()];
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<double?>(valueListenable: _navigationPreview,
          builder: (context, preview, _) => AnimatedTabStack(
            index: tab, previewPosition: preview, navigationAction: _navigatorAction,
            reduceMotion: AppearanceScope.effectsOf(context) != VisualEffects.full,
            children: pages,
          )),
      ),
      bottomNavigationBar: AppNavigation(index: tab,
        onScrubChanged: (position) {
          if (!mounted) return;
          if (_navigationPreview.value == null && position != null) FocusManager.instance.primaryFocus?.unfocus();
          _navigationPreview.value = position;
        },
        onSelected: (value) {
          FocusManager.instance.primaryFocus?.unfocus();
          if (value != tab) {
            setState(() { _navigatorAction++; tab = value; });
          }
        }),
    );
  }

  Widget page(List<Widget> children) => AppPage(children: [
    if (session != null && profileChecked && _syncNotice != null)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          const Icon(Icons.cloud_outlined, size: 18, color: plum),
          const SizedBox(width: 8),
          Expanded(child: Text(_syncNotice!, style: const TextStyle(fontSize: 12))),
          TextButton(onPressed: () => refresh(), child: const Text('Retry')),
        ]),
      ),
    ...children,
  ]);

  Widget roleScreen() => Scaffold(
        body: SafeArea(
          child: page([
            const SizedBox(height: 24),
            Align(
                alignment: Alignment.centerLeft,
                child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: AppPalette.lilac,
                        borderRadius: BorderRadius.circular(24)),
                    child:
                        const Icon(Icons.spa_outlined, color: plum, size: 36))),
            const SizedBox(height: 28),
            const AppPageHeading(
                eyebrow: 'Welcome to Mahila Mitr',
                title: 'Track your cycle.',
                subtitle:
                    'Log periods and symptoms, view your history, and choose what to share with a partner.'),
            const Text('How would you like to begin?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            roleChoice(
                Icons.circle_outlined,
                'I track my cycle',
                'Log periods, understand patterns, and stay in control.',
                () => chooseRole('owner')),
            roleChoice(
                Icons.favorite,
                'I’m a support partner',
                'Be present, send little moments, and support with empathy.',
                () => chooseRole('partner'),
                iconColor: coral),
            const PrivacyBanner(
              title: 'Private from the very first step',
              body:
                  'Your cycle details stay yours. A partner sees only the information explained before you connect.',
              icon: Icons.shield_outlined,
              tone: Color(0xfffaf0ed),
            ),
          ]),
        ),
      );

  Widget roleChoice(
          IconData icon, String title, String subtitle, VoidCallback onTap,
          {Color iconColor = plum}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: line)),
          child: Row(children: [
            CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: .14),
                child: Icon(icon, color: iconColor)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(color: ink.withValues(alpha: .62)))
                ])),
            const Icon(Icons.chevron_right, color: plum),
          ]),
        ),
      );

  Widget signInScreen() => Scaffold(
        body: SafeArea(
          child: page([
            const SizedBox(height: 26),
            heading('Mahila Mitr', 'Sign in',
                'We’ll email you a verification code.'),
            const PrivacyBanner(
              title: 'Password-free and discreet',
              body:
                  'We use a one-time email code. Sensitive details never appear in notification previews.',
            ),
            const SizedBox(height: 22),
            input(email, 'Email address', keyboard: TextInputType.emailAddress),
            button('Send verification code', sendCode),
            if (codeSent) ...[
              const SizedBox(height: 24),
              const Center(
                  child: Text('ENTER 8-DIGIT CODE',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700))),
              const SizedBox(height: 10),
              input(otp, 'Verification code',
                  keyboard: TextInputType.number, maxLength: 8),
              button('Verify & continue', verifyCode),
              TextButton(
                  onPressed: () => setState(() {
                        codeSent = false;
                        pendingEmail = null;
                        otp.clear();
                      }),
                  child: const Text('Use a different email')),
            ],
            const SizedBox(height: 36),
            TextButton.icon(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('role');
                if (mounted) setState(() => role = null);
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Choose a different role'),
            ),
          ]),
        ),
      );

  Widget profileSetupScreen() => Scaffold(
        body: SafeArea(
          child: page([
            const SizedBox(height: 42),
            heading('Your profile', 'What should we call you?',
                'Your first name is shown only to the person you pair with.'),
            input(displayNameInput, 'First name', maxLength: 50),
            button('Save and continue', saveProfile),
            const PrivacyBanner(
              title: 'Only your paired person can see this',
              body:
                  'Your name is never public. You can disconnect your private pairing whenever you choose.',
              icon: Icons.person_outline_rounded,
              tone: Color(0xffeef4ec),
            ),
          ]),
        ),
      );

  Widget configurationErrorScreen() => Scaffold(
        body: SafeArea(
          child: page([
            const SizedBox(height: 42),
            heading('Your account', 'Saved data is unavailable.',
                syncError),
            card('Try again', [
              button('Retry', () => action(refresh, label: 'Loading your account…')),
            ]),
          ]),
        ),
      );

  Widget homeScreen() {
    final today = DateUtils.dateOnly(DateTime.now());
    final next = predictedNext;
    final latestStart = cycles.isEmpty
        ? null
        : DateTime.parse(cycles.first['start_date'] as String);
    final cycleDay = latestStart == null || today.isBefore(latestStart)
        ? null
        : today.difference(DateUtils.dateOnly(latestStart)).inDays + 1;
    final phase = cycleDay == null
        ? 'No periods logged'
        : _activePeriod != null
            ? 'Period in progress'
            : isPeriodDay(today)
                ? 'Menstrual phase'
            : cycleDay <= 13
                ? 'Follicular phase'
                : cycleDay <= 16
                    ? 'Ovulation window'
                    : 'Luteal phase';
    final daysToGo = next?.difference(today).inDays;
    final confidence = cycles.length >= 3
        ? 'High'
        : cycles.isNotEmpty
            ? 'Building'
            : 'Starting';
    final checkedIn = hasDayLog(today);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final week = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );
    return page([
      HomeHeading(date: today, name: displayName ?? 'Profile',
          onProfile: () => setState(() => tab = 3)),
      CycleTodayHero(
        cycleDay: cycleDay,
        cycleLength: averageCycleLength,
        onViewCalendar: () => setState(() => tab = 1),
        phase: phase,
        periodInProgress: _activePeriod != null,
        nextPeriodLabel: next == null ? 'your next period' : formatDate(next),
        daysToGo: daysToGo,
        confidence: confidence,
        isCheckedIn: checkedIn,
        reduceMotion: reduceMotion,
        onCheckIn: () => showDayLogger(today),
        guide: WellnessGuide(
          controller: guideController,
          screen: 0,
          isCheckedIn: checkedIn,
          reduceMotion: reduceMotion,
        ),
      ),
      const SizedBox(height: 16),
      AppActionPair(
        first: AppActionTile(
            icon: _activePeriod == null
                ? Icons.water_drop_outlined
                : Icons.check_circle_outline_rounded,
            title:
                _activePeriod == null ? 'Log your period' : 'End this period',
            subtitle: _activePeriod == null
                ? 'Add a start date'
                : 'Add an end date',
            onTap: _activePeriod == null
                ? showStartPeriodConfirm
                : () => showEndPeriodSheet(_activePeriod!)),
        second: AppActionTile(
            icon: link == null
                ? Icons.favorite_border_rounded
                : Icons.chat_bubble_outline_rounded,
            title: link == null ? 'Add a partner' : 'Messages',
            subtitle: link == null
                ? 'Create or enter an invite code'
                : 'Open your conversation',
            color: AppPalette.sage,
            onTap:
                link == null ? () => setState(() => tab = 3) : openPrivateRoom),
      ),
      const SizedBox(height: 26),
      WellnessHistoryStrip(
        days: week,
        hasLog: hasDayLog,
        onSelected: showDayLogger,
      ),
      const SizedBox(height: 24),
      if (checkedIn) todayWellnessCard(),
      if (cycles.length >= 2) ...[
        AppSurface(title: 'Cycle averages', children: [
          Row(children: [
            metric('$averageCycleLength', 'Cycle days'),
            metric('$averagePeriodLength', 'Period days'),
            metric('${cycles.length}', 'Periods logged'),
          ]),
        ]),
      ],
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Your recent cycles',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
        TextButton(
            onPressed: () => setState(() => tab = 1),
            child: const Text('See insights'))
      ]),
      // ── Active period banner ──
      if (_activePeriod != null)
        _ActivePeriodBanner(
          startDate: DateTime.parse(_activePeriod!['start_date'] as String),
          onEnd: () => showEndPeriodSheet(_activePeriod!),
          onEdit: () => showPeriodLogger(existing: _activePeriod),
        )
      else if (cycles.isEmpty)
        card('No period history', [
          const Text(
              'Add your last period to start tracking.'),
          button('Start a period', showStartPeriodConfirm),
        ]),
      // ── Recent cycles ──
      if (cycles.isNotEmpty)
        for (var i = 0; i < cycles.take(3).length; i++) periodRow(cycles[i], i),
      TextButton.icon(
        onPressed: showPeriodLogger,
        icon: const Icon(Icons.edit_calendar_outlined, size: 18),
        label: const Text('View or edit period entries'),
      ),
    ]);
  }

  Widget _privateChatButton() => Material(
    color: AppPalette.surface, clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppPalette.border)),
    child: InkWell(onTap: openPrivateRoom,
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        const CircleAvatar(backgroundColor: AppPalette.sage,
          child: Icon(Icons.chat_bubble_outline_rounded, color: AppPalette.forest, size: 20)),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your private room', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppPalette.ink)),
          SizedBox(height: 4),
          Text('A conversation for the two of you', style: TextStyle(fontSize: 12, color: AppPalette.muted)),
        ])),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward_rounded, size: 18, color: AppPalette.muted),
      ]))));

  Widget todayWellnessCard() {
    final today = DateUtils.dateOnly(DateTime.now());
    final log = dayLogFor(today);
    final moodKey = log?['mood'] as String?;
    final moodInfo = moodKey != null ? moodMeta[moodKey] : null;
    final flowKey = log?['flow'] as String?;
    final flowInfo = flowKey != null ? flowMeta[flowKey] : null;
    final energyKey = log?['energy'] as String?;
    final energyInfo = energyKey != null ? energyMeta[energyKey] : null;
    final symptoms =
        (log?['symptoms'] as List?)?.whereType<String>().toList() ?? [];
    final note = log?['note'] as String?;

    return DailyCheckInCard(
      mood: moodInfo?.label,
      flow: flowInfo?.label,
      energy: energyInfo?.label,
      symptoms: symptoms,
      note: note,
      onEdit: () => showDayLogger(today),
    );
  }

  List<Widget> dayLogSection(DateTime date) {
    final log = dayLogFor(date);
    if (log == null) {
      if (role != 'owner') return const [];
      return [
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showDayLogger(date),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Log mood & flow for this day'),
          style: OutlinedButton.styleFrom(
            foregroundColor: plum,
            side: const BorderSide(color: line),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ];
    }

    final moodKey = log['mood'] as String?;
    final moodInfo = moodKey != null ? moodMeta[moodKey] : null;
    final flowKey = log['flow'] as String?;
    final flowInfo = flowKey != null ? flowMeta[flowKey] : null;
    final energyKey = log['energy'] as String?;
    final energyInfo = energyKey != null ? energyMeta[energyKey] : null;
    final symptoms =
        (log['symptoms'] as List?)?.whereType<String>().toList() ?? [];
    final note = log['note'] as String?;

    return [
      const SizedBox(height: 12),
      const Divider(color: line, height: 1),
      const SizedBox(height: 12),
      Row(
        children: [
          const Text('Daily Wellness',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          if (role == 'owner')
            GestureDetector(
              onTap: () => showDayLogger(date),
              child: const Text('Edit ›',
                  style: TextStyle(
                      color: plum, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (moodInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: moodInfo.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${moodInfo.emoji} ${moodInfo.label}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: ink),
              ),
            ),
          if (flowInfo != null && flowKey != 'none')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: rose.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${flowInfo.icon} ${flowInfo.label}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: ink),
              ),
            ),
          if (energyInfo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: sage.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${energyInfo.icon} ${energyInfo.label} energy',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: ink),
              ),
            ),
        ],
      ),
      if (symptoms.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final s in symptoms)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: line),
                ),
                child: Text(s,
                    style: TextStyle(
                        fontSize: 11,
                        color: ink.withValues(alpha: .75),
                        fontWeight: FontWeight.w500)),
              ),
          ],
        ),
      ],
      if (note != null && note.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xfffaf6f2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: line),
          ),
          child: Text(
            '“$note”',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: ink.withValues(alpha: .75),
            ),
          ),
        ),
      ],
    ];
  }

  Widget metric(String value, String label) => Expanded(
          child: Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        Text(label,
            style: TextStyle(fontSize: 12, color: ink.withValues(alpha: .6)))
      ]));

  Widget periodRow(Map<String, dynamic> cycle, int index) {
    final start = DateTime.parse(cycle['start_date'] as String);
    final end = cycle['end_date'] == null
        ? null
        : DateTime.parse(cycle['end_date'] as String);
    final isActive = end == null && index == 0;
    return PeriodHistoryTile(start: start, end: end, isActive: isActive,
      onTap: role == 'owner'
          ? () => isActive ? showEndPeriodSheet(cycle) : showPeriodLogger(existing: cycle)
          : null);
  }

  Widget shortcut(
          IconData icon, String title, String subtitle, VoidCallback onTap,
          {Color color = rose}) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
              height: 112,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(icon, color: plum),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(subtitle, style: const TextStyle(fontSize: 11))
                        ])
                  ])));

  Widget insightsScreen() => page([
        Row(children: [
          IconButton(
              onPressed: () => setState(() => tab = 0),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child: heading(
                  '',
                  calendarMode == 3 ? 'Statistics' : 'Calendar'))
        ]),
        SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Month')),
              ButtonSegment(value: 1, label: Text('Week')),
              ButtonSegment(value: 2, label: Text('Year')),
              ButtonSegment(value: 3, label: Text('Stats'))
            ],
            selected: {
              calendarMode
            },
            onSelectionChanged: (value) =>
                setState(() => calendarMode = value.first),
            showSelectedIcon: false),
        const SizedBox(height: 22),
        if (calendarMode == 0)
          monthlyCalendar()
        else if (calendarMode == 1)
          weeklyCalendar()
        else if (calendarMode == 2)
          yearlyCalendar()
        else
          statistics(),
      ]);

  Widget monthlyCalendar() {
    final month = DateTime(selectedDay.year, selectedDay.month);
    final leading = month.weekday - 1;
    final total = DateUtils.getDaysInMonth(month.year, month.month);
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            onPressed: () => setState(
                () => selectedDay = DateTime(month.year, month.month - 1, 1)),
            icon: const Icon(Icons.chevron_left)),
        Text('${monthName(month.month)} ${month.year}',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        IconButton(
            onPressed: () => setState(
                () => selectedDay = DateTime(month.year, month.month + 1, 1)),
            icon: const Icon(Icons.chevron_right))
      ]),
      Row(children: [
        for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(
              child: Center(child: Text(day, style: TextStyle(fontSize: 11))))
      ]),
      GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leading + total,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7),
          itemBuilder: (_, index) {
            if (index < leading) return const SizedBox();
            final date = DateTime(month.year, month.month, index - leading + 1);
            final logged = isPeriodDay(date);
            final predicted = isPredictedDay(date);
            final selected = DateUtils.isSameDay(date, selectedDay);
            final hasDayLogEntry = hasDayLog(date);
            return InkWell(
                onTap: () => setState(() => selectedDay = date),
                child: Container(
                    margin: const EdgeInsets.all(3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: selected
                            ? plum
                            : logged
                                ? coral
                                : predicted
                                    ? rose
                                    : isFertileWindowDay(date)
                                        ? const Color(0xffdfc4e4)
                                        : isIntimateWindowDay(date)
                                            ? const Color(0xffe8f2e6)
                                            : null,
                        borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${date.day}',
                            style: TextStyle(
                                color: selected || logged ? Colors.white : ink,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        if (hasDayLogEntry)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: selected || logged ? Colors.white : plum,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    )));
          }),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        legend(coral, 'Logged'),
        const SizedBox(width: 8),
        legend(rose, 'Predicted'),
        const SizedBox(width: 8),
        legend(const Color(0xffdfc4e4), 'Fertile'),
        const SizedBox(width: 8),
        legend(const Color(0xffe8f2e6), 'Intimate'),
      ]),
      const SizedBox(height: 20),
      card(formatLongDate(selectedDay), [
        Text(isPeriodDay(selectedDay)
            ? 'Logged period day'
            : isPredictedDay(selectedDay)
                ? 'Predicted period window'
                : isFertileWindowDay(selectedDay)
                    ? 'Approximate fertile window'
                    : isIntimateWindowDay(selectedDay)
                        ? 'Intimate window (low fertility)'
                        : 'No cycle event logged'),
        ...dayLogSection(selectedDay),
      ]),
    ]);
  }

  Widget weeklyCalendar() {
    final monday =
        selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
            '${monday.day}–${monday.add(const Duration(days: 6)).day} ${monthName(monday.month)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Row(children: [
          IconButton(
              onPressed: () => setState(() =>
                  selectedDay = selectedDay.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left)),
          IconButton(
              onPressed: () => setState(
                  () => selectedDay = selectedDay.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right))
        ])
      ]),
      for (var i = 0; i < 7; i++)
        Builder(builder: (_) {
          final date = monday.add(Duration(days: i));
          final active = DateUtils.isSameDay(date, selectedDay);
          final dayLog = dayLogFor(date);
          String? moodEmoji;
          String? flowText;
          if (dayLog != null) {
            final moodKey = dayLog['mood'] as String?;
            if (moodKey != null) moodEmoji = moodMeta[moodKey]?.emoji;
            final flowKey = dayLog['flow'] as String?;
            if (flowKey != null && flowKey != 'none') {
              flowText = flowMeta[flowKey]?.label;
            }
          }
          final parts = [
            if (isPeriodDay(date))
              'Logged cycle day'
            else if (isPredictedDay(date))
              'Upcoming'
            else if (isFertileWindowDay(date))
              'Approx fertile window'
            else if (isIntimateWindowDay(date))
              'Intimate window'
            else
              'Plan gently',
            if (moodEmoji != null) 'Mood: $moodEmoji',
            if (flowText != null) 'Flow: $flowText',
          ];
          return ListTile(
              onTap: () => setState(() => selectedDay = date),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              tileColor: active ? rose.withValues(alpha: .5) : null,
              leading: CircleAvatar(
                  backgroundColor: active ? plum : Colors.white,
                  foregroundColor: active ? Colors.white : ink,
                  child: Text(weekdayLetter(date.weekday))),
              title: Text(
                  '${date.day}   ${isPeriodDay(date) ? 'Period' : isPredictedDay(date) ? 'Predicted' : isFertileWindowDay(date) ? 'Fertile Window' : isIntimateWindowDay(date) ? 'Intimate Window' : 'Regular day'}',
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(parts.join(' • ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (moodEmoji != null)
                    Text(moodEmoji, style: const TextStyle(fontSize: 16)),
                  if (isPeriodDay(date)) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.circle, color: coral, size: 10),
                  ],
                ],
              ));
        }),
      card(
          'A gentle reminder',
          [
            const Text(
                'Cycle predictions are estimates and support awareness—not diagnosis.')
          ],
          color: sage.withValues(alpha: .25)),
    ]);
  }

  Widget yearlyCalendar() => YearCalendar(
    selectedDay: selectedDay,
    isPeriodDay: isPeriodDay,
    isPredictedDay: isPredictedDay,
    onYearChanged: (year) => setState(() => selectedDay = DateTime(year, selectedDay.month)),
    onMonthSelected: (month) => setState(() {
      selectedDay = month;
      calendarMode = 0;
    }),
  );

  // ─── computed helpers for stats ────────────────────────────────────────────

  /// Cycle lengths for the last [n] cycles (oldest→newest).
  List<int> _recentLengths(int n) =>
      cycleLengths.take(n).toList().reversed.toList();

  /// Trend delta: latest cycle length vs previous one.
  int? get _cycleLengthTrend {
    final l = cycleLengths;
    return l.length >= 2 ? l[0] - l[1] : null;
  }

  /// Period duration trend (last 6, oldest→newest).
  List<int> get _periodDurations {
    return cycles
        .where((c) => c['end_date'] != null)
        .take(6)
        .toList()
        .reversed
        .map((c) =>
            DateTime.parse(c['end_date'] as String)
                .difference(DateTime.parse(c['start_date'] as String))
                .inDays +
            1)
        .toList();
  }

  /// Symptom counts across all logged cycles and day logs.
  Map<String, int> get _symptomCounts {
    final counts = <String, int>{};
    for (final c in cycles) {
      final syms = (c['symptoms'] as List?)?.whereType<String>() ?? [];
      for (final s in syms) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    for (final dl in dayLogs) {
      final syms = (dl['symptoms'] as List?)?.whereType<String>() ?? [];
      for (final s in syms) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Flow counts across all logged cycles and day logs.
  Map<String, int> get _flowCounts {
    final counts = <String, int>{'light': 0, 'medium': 0, 'heavy': 0};
    for (final c in cycles) {
      final f = c['flow'] as String?;
      if (f != null && counts.containsKey(f)) counts[f] = counts[f]! + 1;
    }
    for (final dl in dayLogs) {
      final f = dl['flow'] as String?;
      if (f != null && counts.containsKey(f)) counts[f] = counts[f]! + 1;
    }
    return counts;
  }

  // ─── stats screen ───────────────────────────────────────────────────────────

  Widget statistics() {
    final lengths = _recentLengths(8);
    final trend = _cycleLengthTrend;
    final periodDurs = _periodDurations;
    final symptomCounts = _symptomCounts;
    final flowCounts = _flowCounts;
    final totalWithSymptoms = cycles
            .where((c) => (c['symptoms'] as List?)?.isNotEmpty == true)
            .length +
        dayLogs
            .where((dl) => (dl['symptoms'] as List?)?.isNotEmpty == true)
            .length;
    final totalFlowed = cycles.length +
        dayLogs
            .where((dl) => dl['flow'] != null && dl['flow'] != 'none')
            .length;

    // fertile window estimate
    final nextPeriod = predictedNext;
    DateTime? ovulation;
    DateTime? fertileStart;
    DateTime? fertileEnd;
    if (nextPeriod != null) {
      ovulation = nextPeriod.subtract(const Duration(days: 14));
      fertileStart = ovulation.subtract(const Duration(days: 5));
      fertileEnd = ovulation.add(const Duration(days: 1));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── top metric row ──────────────────────────────────────────────────────
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _statBadge(
            value: '$averageCycleLength',
            label: 'Avg cycle',
            footer: 'days',
            trend: trend,
            color: rose,
          ),
          const SizedBox(width: 8),
          _statBadge(
            value: '$averagePeriodLength',
            label: 'Period length',
            footer: 'days avg',
            color: const Color(0xfff0e6fb),
          ),
          const SizedBox(width: 8),
          _statBadge(
            value: '${regularity.round()}%',
            label: 'Regularity',
            footer: cycles.length < 2 ? 'need more data' : 'stable',
            color: sage,
          ),
        ]),
      ),
      const SizedBox(height: 14),

      // ── cycle length bar chart ───────────────────────────────────────────────
      if (lengths.isNotEmpty)
        _statsCard(
          title: 'Cycle length trend',
          subtitle: 'Last ${lengths.length} cycles · in days',
          child: _cycleLengthChart(lengths),
        ),

      // ── period duration trend ────────────────────────────────────────────────
      if (periodDurs.length >= 2)
        _statsCard(
          title: 'Period duration trend',
          subtitle: 'Last ${periodDurs.length} periods · in days',
          child: _durationChart(periodDurs),
        ),

      // ── flow distribution ────────────────────────────────────────────────────
      if (totalFlowed > 0)
        _statsCard(
          title: 'Flow distribution',
          subtitle: '$totalFlowed cycles logged',
          child: _flowChart(flowCounts, totalFlowed),
        ),

      // ── symptom breakdown ────────────────────────────────────────────────────
      if (symptomCounts.isNotEmpty)
        _statsCard(
          title: 'Symptom frequency',
          subtitle: 'Across $totalWithSymptoms cycles with symptoms',
          child: _symptomBreakdown(symptomCounts, totalWithSymptoms),
        ),

      // ── fertile & intimate window card ─────────────────────────────────────────
      if (ovulation != null && cycles.isNotEmpty && nextPeriod != null)
        _statsCard(
          title: 'Fertile & Intimate windows',
          subtitle: 'Based on your average cycle',
          child: _windowsCard(fertileStart!, ovulation, fertileEnd!, nextPeriod),
        ),

      // ── prediction confidence ─────────────────────────────────────────────────
      Row(children: [
        Expanded(
          child: _miniCard(
            icon: Icons.auto_graph_rounded,
            label: 'Prediction',
            value: cycles.length >= 3
                ? 'High'
                : cycles.length == 2
                    ? 'Medium'
                    : 'Low',
            valueColor: cycles.length >= 3
                ? const Color(0xff6d8b70)
                : cycles.length == 2
                    ? coral
                    : ink.withValues(alpha: .45),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniCard(
            icon: Icons.history_rounded,
            label: 'Logged cycles',
            value: '${cycles.length}',
            valueColor: plum,
          ),
        ),
      ]),
      const SizedBox(height: 8),

      // ── disclaimer ────────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xfffaf0ed),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded,
                color: plum.withValues(alpha: .6), size: 18),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Insights support awareness—not medical diagnosis. Predictions improve as you log more cycles.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
    ]);
  }

  // ── stat badge (top row) ────────────────────────────────────────────────────
  Widget _statBadge(
          {required String value,
          required String label,
          required String footer,
          int? trend,
          required Color color}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (trend != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        trend > 0
                            ? Icons.arrow_upward_rounded
                            : trend < 0
                                ? Icons.arrow_downward_rounded
                                : Icons.remove_rounded,
                        size: 12,
                        color: trend > 0
                            ? coral
                            : trend < 0
                                ? const Color(0xff6d8b70)
                                : ink.withValues(alpha: .4),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        trend == 0 ? 'same' : '${trend > 0 ? '+' : ''}$trend d',
                        style: TextStyle(
                          fontSize: 9,
                          color: trend > 0
                              ? coral
                              : trend < 0
                                  ? const Color(0xff6d8b70)
                                  : ink.withValues(alpha: .4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  const SizedBox(height: 0),
              ]),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              Text(footer,
                  style: TextStyle(
                      fontSize: 10, color: ink.withValues(alpha: .5))),
            ],
          ),
        ),
      );

  // ── generic stats card wrapper ───────────────────────────────────────────────
  Widget _statsCard(
          {required String title,
          required String subtitle,
          required Widget child}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(fontSize: 12, color: ink.withValues(alpha: .5))),
            const SizedBox(height: 20),
            child,
          ],
        ),
      );



  Widget _cycleLengthChart(List<int> lengths) {
    if (lengths.isEmpty) return const SizedBox();
    final minL = lengths.reduce((a, b) => a < b ? a : b).clamp(21, 45);
    final maxL = lengths.reduce((a, b) => a > b ? a : b).clamp(21, 45);
    final range = (maxL - minL).clamp(1, 45).toDouble();
    const double chartH = 120;
    const double minBarH = 20;
    return Column(children: [
      SizedBox(
        height: chartH + 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // y-axis
            Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$maxL',
                    style: TextStyle(
                        fontSize: 9, color: ink.withValues(alpha: .4))),
                Text('$minL',
                    style: TextStyle(
                        fontSize: 9, color: ink.withValues(alpha: .4))),
              ],
            ),
          ),
          ...lengths.asMap().entries.map((e) {
              final i = e.key;
              final l = e.value;
              final isLast = i == lengths.length - 1;
              final fraction = range == 0 ? 1.0 : (l - minL) / range;
              final barH = minBarH + fraction * (chartH - minBarH);
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$l',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isLast ? FontWeight.w700 : FontWeight.normal,
                          color: isLast ? plum : ink.withValues(alpha: .6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        height: barH,
                        decoration: BoxDecoration(
                          color: isLast ? plum : rose.withValues(alpha: .8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _dot(rose, 'Previous cycles'),
          const SizedBox(width: 14),
          _dot(plum, 'Most recent'),
        ],
      ),
    ]);
  }

  // ── period duration chart ────────────────────────────────────────────────────
  Widget _durationChart(List<int> durs) {
    final maxD = durs.reduce((a, b) => a > b ? a : b).clamp(1, 14);
    const chartH = 88.0;
    const minBarH = 16.0;
    return SizedBox(
      height: chartH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ...durs.asMap().entries.map((e) {
            final i = e.key;
            final d = e.value;
            final isLast = i == durs.length - 1;
            final barH = minBarH + (d / maxD) * (chartH - minBarH);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('$d d',
                        style: TextStyle(
                            fontSize: 9,
                            color: isLast ? plum : ink.withValues(alpha: .5),
                            fontWeight:
                                isLast ? FontWeight.w700 : FontWeight.normal)),
                    const SizedBox(height: 2),
                    Container(
                      height: barH,
                      decoration: BoxDecoration(
                        color: isLast
                            ? const Color(0xffb097c8)
                            : const Color(0xffe9d8f4),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── flow distribution bars ───────────────────────────────────────────────────
  Widget _flowChart(Map<String, int> counts, int total) {
    final items = [
      _FlowItem('Light', counts['light'] ?? 0, sage),
      _FlowItem('Medium', counts['medium'] ?? 0, coral),
      _FlowItem('Heavy', counts['heavy'] ?? 0, const Color(0xffc44a6a)),
    ];
    return Column(
      children: items.map((item) {
        final pct = total == 0 ? 0.0 : item.count / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(
              width: 52,
              child: Text(item.label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 12,
                  backgroundColor: item.color.withValues(alpha: .18),
                  valueColor: AlwaysStoppedAnimation(item.color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              child: Text('${(pct * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      color: ink.withValues(alpha: .6),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ── symptom breakdown ────────────────────────────────────────────────────────
  Widget _symptomBreakdown(Map<String, int> counts, int total) {
    if (total == 0) {
      return Text('No symptoms logged yet.',
          style: TextStyle(color: ink.withValues(alpha: .5)));
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: sorted.map((entry) {
        final pct = entry.value / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: Text(entry.key,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 10,
                  backgroundColor: rose.withValues(alpha: .25),
                  valueColor: const AlwaysStoppedAnimation(coral),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text('${(pct * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 11,
                      color: ink.withValues(alpha: .6),
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      }).toList(),
    );
  }

  // ── fertile & intimate windows card ──────────────────────────────────────────
  Widget _windowsCard(
          DateTime fertileStart, DateTime ovulation, DateTime fertileEnd, DateTime nextPeriod) {
    final intimateStart = fertileEnd.add(const Duration(days: 1));
    final intimateEnd = nextPeriod.subtract(const Duration(days: 1));
    return Column(children: [
      Row(children: [
        _fertileChip(Icons.local_florist_rounded, 'Approx fertile',
            formatDate(fertileStart), const Color(0xffdfc4e4)),
        const SizedBox(width: 8),
        _fertileChip(Icons.favorite_border_rounded, 'Intimate window',
            '${intimateStart.day} - ${formatDate(intimateEnd)}', const Color(0xffe8f2e6)),
      ]),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: rose.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: plum),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'These are estimates based on your logs. The intimate window represents days with lower chance of fertility. Track consistently for better accuracy.',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _fertileChip(IconData icon, String title, String date, Color bg) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: plum),
            const SizedBox(height: 6),
            Text(title,
                style:
                    TextStyle(fontSize: 10, color: ink.withValues(alpha: .55))),
            const SizedBox(height: 2),
            Text(date,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  // ── mini summary card ────────────────────────────────────────────────────────
  Widget _miniCard(
          {required IconData icon,
          required String label,
          required String value,
          required Color valueColor}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: rose.withValues(alpha: .4),
            child: Icon(icon, color: plum, size: 18),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: valueColor)),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: ink.withValues(alpha: .55))),
          ]),
        ]),
      );

  static Widget _dot(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ]);

  Widget partnerHomeScreen() {
    final latest = cycles.isEmpty ? null : cycles.first;
    return page([
      PartnerDashboard(
        today: DateTime.now(),
        name: displayName ?? 'Profile',
        partnerName: effectivePartnerName,
        connected: link != null,
        periodStart: latest == null
            ? null : DateTime.parse(latest['start_date'] as String),
        periodEnd: latest?['end_date'] == null
            ? null : DateTime.parse(latest!['end_date'] as String),
        nextPeriod: predictedNext,
        reflectionCount: ratings.length,
        onProfile: () => setState(() => tab = 3),
        onConnection: () => setState(() => tab = 3),
        onConnect: _openPairing,
        onMessages: openPrivateRoom,
        onNote: _openPartnerNote,
        onInsights: () => setState(() => tab = 1),
        onReflections: _openPartnerReflections,
        onNickname: showEditNicknameDialog,
      ),
    ]);
  }

  Future<void> _openPartnerNote() async {
    if (role != 'partner' || link == null) return;
    await _showPartnerSheet(() => MomentComposer(
      controller: noteDraft, style: noteStyle,
      onStyleChanged: (value) => setState(() => noteStyle = value),
      onSend: sendNote, busy: busy, senderName: displayName ?? 'Your partner',
    ));
  }

  Future<void> _openPartnerReflections() async {
    if (link == null) return;
    await _showPartnerSheet(() => reflectionsCard(initiallyExpanded: true));
  }

  Future<void> _showPartnerSheet(Widget Function() content) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ListenableBuilder(
      listenable: _stateRevision,
      builder: (context, child) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: SafeArea(top: false, child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: link == null
            ? const Text('This connection has ended. Close this sheet to return home.')
            : content(),
        )),
      ),
    ),
  );

  Widget momentsScreen() => page([
    AppPageHeading(eyebrow: '', title: 'Moments',
      subtitle: role == 'partner' && link != null ? 'For $effectivePartnerName' : null,
      trailing: role == 'owner' ? IconButton(tooltip: 'Enable note notifications',
          onPressed: requestNotificationPermission,
          icon: const Icon(Icons.notifications_none_rounded)) : null),
    if (link == null)
      card('Connect a partner', [
        const Text('Pair with a partner to share notes and reflections.'),
        button('Go to pairing', () => setState(() => tab = 3)),
      ])
    else ...[
      MomentsConnectionCard(name: effectivePartnerName, onOpen: openPrivateRoom),
      const SizedBox(height: 22),
      if (role == 'partner')
        MomentComposer(controller: noteDraft, style: noteStyle,
          onStyleChanged: (value) => setState(() => noteStyle = value),
          onSend: sendNote, busy: busy, senderName: displayName ?? 'Your partner')
      else ...[
        Row(children: [
          const Expanded(child: Text('Notes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          Text('${notes.where((note) => note['opened_at'] == null).length} unread',
              style: const TextStyle(fontSize: 12, color: AppPalette.muted)),
        ]),
        const SizedBox(height: 14),
        if (notes.isEmpty) const ExpressiveEmptyState(
          icon: Icons.mail_outline,
          title: 'No notes yet',
          body: 'Notes from your partner will appear here.'),
        for (final note in notes)
          MomentCard(note: note, fromName: effectivePartnerName, onOpen: () => openNote(note)),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      reflectionsCard(),
    ],
  ]);

  Widget reflectionsCard({bool initiallyExpanded = false}) => Material(
    color: AppPalette.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppPalette.border)),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey(initiallyExpanded ? 'partner-reflections-sheet' : 'moments-reflections'),
      initiallyExpanded: initiallyExpanded,
      leading: const Icon(Icons.star_border_rounded, color: plum),
      title: const Text('Shared reflections', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      subtitle: const Text('Rate a day or add a note', style: TextStyle(fontSize: 12, color: AppPalette.muted)),
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: const Border(), collapsedShape: const Border(),
      children: [
        Row(children: [
          for (var n = 1; n <= 5; n++)
            Expanded(
                child: IconButton(
                    onPressed: () => setState(() => stars = n),
                    icon: Icon(n <= stars ? Icons.star : Icons.star_border,
                        color: coral)))
        ]),
        input(reflection, 'Add a note (optional)', lines: 3, maxLength: 300),
        button('Save reflection', rateDate),
        if (ratings.isNotEmpty)
          const Padding(
              padding: EdgeInsets.only(top: 18, bottom: 4),
              child: Text('Recent reflections',
                  style: TextStyle(fontWeight: FontWeight.w700))),
        for (final rating in ratings.take(5))
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                  child: Text(
                      rating['author_id'] == session!.user.id ? 'Y' : 'P')),
              title: Text(
                  rating['author_id'] == session!.user.id ? 'You' : 'Partner'),
              subtitle: Text(rating['reflection'] as String? ??
                  'Shared ${rating['stars']} stars')),
      ]));

  Widget pairingScreen() => page([
        heading(
            'Private pairing',
            link == null
                ? 'Connect with your\npartner'
                : 'Connected with $effectivePartnerName',
            'Connect one partner. You can disconnect at any time.'),
        if (link == null)
          PrivacyBanner(
            title: role == 'owner'
                ? 'You control what gets shared'
                : 'Know what you are accepting',
            body: role == 'owner'
                ? 'Your partner can see shared cycle timing, send private moments, and add reflections. Private notes remain yours.'
                : 'Connecting lets you see shared cycle timing and send moments. The owner can disconnect at any time.',
            icon: Icons.visibility_outlined,
          ),
        if (link == null) const SizedBox(height: 16),
        if (link == null && role == 'owner') ...[
          card('Your invite code', [
            if (invite == null)
              const Text(
                  'Create a single-use code. Only share it with the person you trust.')
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: softLilac, borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Text(invite!,
                      style: const TextStyle(
                          fontSize: 24,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Expires in 10 minutes · one use only',
                      style: TextStyle(fontSize: 11, color: plum)),
                ]),
              ),
            button(invite == null ? 'Create invite code' : 'Create a new code',
                createInvite),
            Row(children: [
              Expanded(
                  child: button(
                      nearbyAdvertising ? 'Stop sharing' : 'Share nearby',
                      nearbyAdvertising ? stopNearby : shareNearby,
                      secondary: true))
            ]),
            if (nearbyAdvertising)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xfff5ecf8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xffdfc4e4)),
                ),
                child: Row(
                  children: [
                    const _PulsingIcon(
                        icon: Icons.bluetooth_searching, color: plum),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Broadcasting invitation',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: plum,
                            ),
                          ),
                          Text(
                            'Keep this screen open so your partner can find you.',
                            style: TextStyle(
                              fontSize: 11,
                              color: ink.withValues(alpha: .7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]),
        ] else if (link == null) ...[
          card('Use a shared code', [
            input(pairingCode, '12-character invite code'),
            button('Connect securely', acceptInvite),
          ]),
          card('Or find her nearby', [
            const Text(
                'Nearby pairing uses Bluetooth and never broadcasts cycle information.'),
            button(nearbyScanning ? 'Stop nearby scan' : 'Scan nearby',
                nearbyScanning ? stopNearby : scanNearby,
                secondary: true),
            if (nearbyScanning) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xfff6edf8), Color(0xfffaeef7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffdfc4e4)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const _PulsingIcon(
                          icon: Icons.bluetooth_searching_rounded,
                          color: plum,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Scanning for nearby invite (${nearbyScanSeconds}s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: plum,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                nearbyScanSeen > 0
                                    ? '$nearbyScanSeen Bluetooth signal${nearbyScanSeen == 1 ? '' : 's'} detected'
                                    : 'Listening for partner phone signals…',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ink.withValues(alpha: .7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: plum,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: const LinearProgressIndicator(
                        minHeight: 3,
                        color: plum,
                        backgroundColor: Color(0x226e4d73),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (nearbyScanTimedOut && nearbyCodes.isEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xfffcf5f3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xfff4cfc5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Color(0xffb84a39), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Scan timed out. Make sure her phone is currently sharing nearby and tap scan again.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ink.withValues(alpha: .8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (nearbyCodes.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final code in nearbyCodes)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: plum, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: plum.withValues(alpha: .12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Color(0xfff3e7f5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite, color: plum, size: 22),
                    ),
                    title: Text(
                      nearbyInvitationNames[code] == null
                          ? 'Finding her name…'
                          : '${nearbyInvitationNames[code]} is nearby',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: plum,
                      ),
                    ),
                    subtitle: const Text(
                      'Tap to connect securely and establish private link',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: FilledButton.tonal(
                      onPressed: busy ? null : () => connectNearby(code),
                      style: FilledButton.styleFrom(
                        backgroundColor: plum,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Connect',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    onTap: busy ? null : () => connectNearby(code),
                  ),
                ),
            ],
          ]),
        ] else
          card('Connected privately with $effectivePartnerName', [
            if (partnerNickname != null && partnerDisplayName != null)
              Text('Account name: $partnerDisplayName',
                  style: TextStyle(
                      fontSize: 12,
                      color: ink.withValues(alpha: .6),
                      fontWeight: FontWeight.w500)),
            Text(role == 'owner'
                ? 'Your partner can support you with notes and shared reflections.'
                : 'You can view shared cycle timing and send thoughtful moments.'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: showEditNicknameDialog,
                    icon: const Icon(Icons.favorite_border,
                        size: 16, color: plum),
                    label: Text(
                      partnerNickname == null
                          ? 'Set nickname'
                          : 'Nickname: $partnerNickname',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: plum,
                      side: const BorderSide(color: Color(0xffd5c4dc)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const PrivacyBanner(
              title: 'Connection active',
              body:
                  'Only this paired account has access. Disconnecting ends shared access for both people.',
              icon: Icons.lock_person_outlined,
              tone: Color(0xffeef4ec),
            ),
            const SizedBox(height: 4),
            _privateChatButton(),
            button('Disconnect partner', confirmUnlink, secondary: true)
          ]),
        card(
            'Private by design',
            [
              const Text(
                  'Codes are hashed, expire in 10 minutes, and can only be used once.')
            ],
            color: sage.withValues(alpha: .25)),
      ]);

  Widget moreScreen() => page([
        heading('', 'Settings'),
        pairingScreenContent(),
        const AppearanceSettingsPanel(),
        AppSurface(title: 'Your account', children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                  backgroundColor: AppPalette.lilac,
                  child: Text(
                      (displayName ?? 'M').characters.first.toUpperCase(),
                      style: const TextStyle(
                          color: plum, fontWeight: FontWeight.w800))),
              title: Text(displayName ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(session?.user.email ?? '',
                  style: const TextStyle(fontSize: 12))),
          const Divider(),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline_rounded, color: plum),
              title: const Text('Edit profile name'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                displayNameInput.text = displayName ?? '';
                setState(() => displayName = null);
              }),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.notifications_none_rounded, color: plum),
              title: const Text('Discreet notifications'),
              subtitle: const Text('Keep message previews private'),
              onTap: requestNotificationPermission),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded, color: plum),
              title: const Text('Sign out'),
              onTap: busy ? null : signOut),
        ]),
        const AppSurface(title: 'About', children: [
          ListTile(contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.info_outline_rounded),
            title: Text(AppVersion.name), subtitle: Text(AppVersion.display)),
        ]),
        const PrivacyBanner(
            title: 'Partner access',
            body:
                'Choose who you connect with. You can disconnect your partner at any time.',
            icon: Icons.shield_outlined,
            tone: AppPalette.sage),
      ]);

  Future<void> _openPairing() => Navigator.of(context).push<void>(MaterialPageRoute(
    builder: (_) => ListenableBuilder(
      listenable: _stateRevision,
      builder: (context, _) => Scaffold(
        appBar: AppBar(backgroundColor: cream),
        body: SafeArea(child: pairingScreen()),
      ),
    ),
  ));

  Widget pairingScreenContent() => Column(children: [
        if (link == null)
          button(
              'Open secure pairing',
              _openPairing)
        else
          card('Connected with ${ownerName ?? 'your partner'}', [
            const Text('Your private connection is active.'),
            button('Disconnect partner', confirmUnlink, secondary: true)
          ])
      ]);

  Future<void> requestNotificationPermission() => action(
      _requestNotificationPermission, label: 'Enabling notifications…');

  Future<void> _requestNotificationPermission() async {
    final androidPlugin = notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _initFirebaseMessaging();
    if (_loggingDataReady) await _syncLoggingReminders();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications enabled')),
      );
    }
  }

  Future<void> signOut() => action(() async {
        await client!.auth.signOut();
        await _syncLoggingReminders();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('role');
        setState(() {
          role = null;
          link = null;
          notes = [];
          ratings = [];
          cycles = [];
          dayLogs = [];
          tab = 0;
          displayName = null;
          ownerName = null;
          profileChecked = false;
          syncError = null;
        });
      }, label: 'Signing out…');

  int get averageCycleLength {
    final lengths = cycleLengths;
    return lengths.isEmpty
        ? 28
        : (lengths.reduce((a, b) => a + b) / lengths.length)
            .round()
            .clamp(21, 45);
  }

  List<int> get cycleLengths {
    final values = <int>[];
    for (var i = 0; i + 1 < cycles.length; i++) {
      final recent = DateTime.parse(cycles[i]['start_date'] as String);
      final older = DateTime.parse(cycles[i + 1]['start_date'] as String);
      final days = recent.difference(older).inDays;
      if (days >= 15 && days <= 60) values.add(days);
    }
    return values;
  }

  int get averagePeriodLength {
    final values = cycles
        .where((cycle) => cycle['end_date'] != null)
        .map((cycle) =>
            DateTime.parse(cycle['end_date'] as String)
                .difference(DateTime.parse(cycle['start_date'] as String))
                .inDays +
            1)
        .toList();
    return values.isEmpty
        ? 5
        : (values.reduce((a, b) => a + b) / values.length).round();
  }

  double get regularity {
    final lengths = cycleLengths;
    if (lengths.length < 2) return lengths.isEmpty ? 0 : 100;
    final spread = lengths.reduce((a, b) => a > b ? a : b) -
        lengths.reduce((a, b) => a < b ? a : b);
    return (100 - spread * 4).clamp(0, 100).toDouble();
  }

  DateTime? get predictedNext => cycles.isEmpty || _activePeriod != null
      ? null
      : DateTime.parse(cycles.first['start_date'] as String)
          .add(Duration(days: averageCycleLength));

  bool isPeriodDay(DateTime date) =>
      isRecordedPeriodDay(cycles, date, today: DateTime.now());

  bool isPredictedDay(DateTime date) {
    if (isPeriodDay(date)) return false;
    final next = predictedNext;
    return next != null &&
        !date.isBefore(next) &&
        date.isBefore(next.add(Duration(days: averagePeriodLength)));
  }

  bool isFertileWindowDay(DateTime date) {
    if (isPeriodDay(date)) return false;
    if (cycles.isEmpty) return false;
    final next = predictedNext;
    if (next == null) return false;
    final ovulation = next.subtract(const Duration(days: 14));
    final fertileStart = DateUtils.dateOnly(ovulation.subtract(const Duration(days: 5)));
    final fertileEnd = DateUtils.dateOnly(ovulation.add(const Duration(days: 1)));
    final d = DateUtils.dateOnly(date);
    return !d.isBefore(fertileStart) && !d.isAfter(fertileEnd);
  }

  bool isIntimateWindowDay(DateTime date) {
    if (cycles.isEmpty) return false;
    final next = predictedNext;
    if (next == null) return false;
    if (isPeriodDay(date) || isPredictedDay(date) || isFertileWindowDay(date)) return false;
    
    final latestStart = DateUtils.dateOnly(DateTime.parse(cycles.first['start_date'] as String));
    final nextEnd = next.add(Duration(days: averagePeriodLength));
    final d = DateUtils.dateOnly(date);
    return !d.isBefore(latestStart) && !d.isAfter(nextEnd);
  }

  static Widget legend(Color color, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAvatar(radius: 4, backgroundColor: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10))
      ]);
  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  String monthName(int month) => months[month - 1];
  String weekdayLetter(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];
  String formatDate(DateTime date) =>
      '${date.day} ${monthName(date.month)} ${date.year}';
  String formatLongDate(DateTime date) => '${const [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][date.weekday - 1]}, ${formatDate(date)}';

  String nextPeriodLabel() {
    if (cycles.isEmpty) return 'Add your first period';
    final latest = DateTime.parse(cycles.first['start_date'] as String);
    var length = 28;
    if (cycles.length > 1) {
      final previous = DateTime.parse(cycles[1]['start_date'] as String);
      length = latest.difference(previous).inDays.clamp(21, 45);
    }
    final next = latest.add(Duration(days: length));
    return '${next.day}/${next.month}/${next.year}';
  }
}

class _FlowItem {
  const _FlowItem(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
}

// ═══════════════════════════════════════════════════════════════════════════
// Private Room Page
// ═══════════════════════════════════════════════════════════════════════════

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  final double size = 24;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}

class _StartChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StartChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : ink,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal)),
      backgroundColor: selected ? plum : Colors.white,
      side: BorderSide(color: selected ? plum : line),
      onPressed: onTap,
    );
  }
}

class _ActivePeriodBanner extends StatelessWidget {
  final DateTime startDate;
  final VoidCallback onEnd;
  final VoidCallback onEdit;
  const _ActivePeriodBanner(
      {required this.startDate, required this.onEnd, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.dateOnly(DateTime.now()).difference(startDate).inDays + 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffff0f3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: coral.withValues(alpha: .45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: coral.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: coral,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: coral.withValues(alpha: .5),
                              blurRadius: 4,
                              spreadRadius: 1)
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Period in progress',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: coral)),
                  ],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('Edit',
                    style: TextStyle(fontSize: 12, color: ink.withValues(alpha: .6))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Day $days',
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: plum)),
          const SizedBox(height: 4),
          Text('Started ${_HomePageState._fmtDate(startDate)}',
              style: TextStyle(fontSize: 13, color: ink.withValues(alpha: .7))),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: plum,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onEnd,
              child: const Text('End period'),
            ),
          ),
        ],
      ),
    );
  }
}
