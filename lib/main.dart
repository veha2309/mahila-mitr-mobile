import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

const plum = Color(0xff70415f);
const ink = Color(0xff382638);
const cream = Color(0xfffff8f4);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
  }
  runApp(const MahilaMitr());
}

class MahilaMitr extends StatelessWidget {
  const MahilaMitr({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mahila Mitr',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: plum),
          scaffoldBackgroundColor: cream,
          useMaterial3: true,
          textTheme: const TextTheme(bodyMedium: TextStyle(color: ink)),
        ),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final email = TextEditingController();
  final otp = TextEditingController();
  final pairingCode = TextEditingController();
  final noteDraft = TextEditingController();
  final reflection = TextEditingController();
  final notifications = FlutterLocalNotificationsPlugin();
  static const nearby = MethodChannel('mahila_mitr/nearby');
  Timer? nearbyTimer;
  Timer? nearbyPoll;
  bool nearbyAdvertising = false;
  bool nearbyScanning = false;
  bool nearbyScanTimedOut = false;
  int nearbyScanSeen = 0;
  final Set<String> nearbyCodes = {};
  StreamSubscription<AuthState>? authSubscription;
  SupabaseClient? get client => supabaseUrl.isEmpty || supabaseKey.isEmpty ? null : Supabase.instance.client;
  String? role;
  Session? session;
  bool codeSent = false;
  String? pendingEmail;
  bool busy = false;
  bool notificationsReady = false;
  String? invite;
  Map<String, dynamic>? link;
  List<Map<String, dynamic>> cycles = [];
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> ratings = [];
  String noteStyle = 'letter';
  int stars = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = client?.auth.currentSession;
    authSubscription = client?.auth.onAuthStateChange.listen((event) {
      if (!mounted) return;
      setState(() => session = event.session);
      refresh();
    });
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => role = prefs.getString('role'));
      refresh();
    });
    _initializeNotifications();
    nearby.setMethodCallHandler((call) async {
      if (!mounted) return;
      if (call.method == 'found' && call.arguments is String && role == 'partner' && link == null) {
        setState(() => nearbyCodes.add(call.arguments as String));
      } else if (call.method == 'scanProgress' && call.arguments is int) {
        setState(() => nearbyScanSeen = call.arguments as int);
      } else if (call.method == 'error') {
        setState(() { nearbyAdvertising = false; nearbyScanning = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(call.arguments.toString())));
      }
    });
  }

  Future<void> _initializeNotifications() async {
    try {
      await notifications.initialize(settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ));
      notificationsReady = true;
    } catch (_) {
      notificationsReady = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(notify: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    authSubscription?.cancel();
    nearbyTimer?.cancel();
    nearbyPoll?.cancel();
    nearby.setMethodCallHandler(null);
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(nearby.invokeMethod<void>('stopAdvertising').catchError((Object _) {}));
      unawaited(nearby.invokeMethod<void>('stopScan').catchError((Object _) {}));
    }
    for (final controller in [email, otp, pairingCode, noteDraft, reflection]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> action(Future<void> Function() work) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await work();
    } catch (error, stackTrace) {
      debugPrint('Mahila Mitr action failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      final message = error is AuthException && error.code == 'email_address_not_authorized'
              ? 'Email sign-in is not available for this address yet.'
              : error is AuthRetryableFetchException && error.message.contains('Error sending confirmation email')
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> refresh({bool notify = false}) async {
    final api = client;
    if (api == null || session == null || role == null) return;
    try {
      final linkRows = await api.from('links').select('id,owner_id,partner_id').limit(1);
      final nextLink = linkRows.isEmpty ? null : Map<String, dynamic>.from(linkRows.first);
      if (nextLink != null && nearbyAdvertising) {
        nearbyTimer?.cancel();
        nearbyPoll?.cancel();
        await nearby.invokeMethod<void>('stopAdvertising');
        if (mounted) setState(() => nearbyAdvertising = false);
      }
      final cycleRows = role == 'owner' || nextLink != null
          ? await api.from('cycles').select('id,start_date,end_date').order('start_date', ascending: false)
          : <Map<String, dynamic>>[];
      final ratingRows = nextLink != null
          ? await api.from('date_ratings').select('id,author_id,date_on,stars,reflection').eq('link_id', nextLink['id']).order('date_on', ascending: false)
          : <Map<String, dynamic>>[];
      final noteRows = role == 'owner'
          ? await api.from('notes').select('id,body,style,created_at,opened_at').order('created_at', ascending: false)
          : <Map<String, dynamic>>[];
      final incoming = noteRows.any((item) => item['opened_at'] == null && !notes.any((old) => old['id'] == item['id']));
      if (mounted) {
        setState(() {
          link = nextLink;
          cycles = List<Map<String, dynamic>>.from(cycleRows);
          ratings = List<Map<String, dynamic>>.from(ratingRows);
          notes = List<Map<String, dynamic>>.from(noteRows);
        });
      }
      if (notify && incoming && notificationsReady) {
        await notifications.show(
          id: 1,
          title: 'Mahila Mitr',
          body: 'You have a notification',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails('notes', 'Private notes'),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    } catch (_) {
      // Retain the current view and retry when the app is back online.
    }
  }

  String get _normalizedEmail => email.text.trim().toLowerCase();

  Future<void> sendCode() => action(() async {
        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(_normalizedEmail)) {
          throw const FormatException('Enter a valid email address.');
        }
        await client!.auth.signInWithOtp(email: _normalizedEmail);
        setState(() { codeSent = true; pendingEmail = _normalizedEmail; });
      });
  Future<void> verifyCode() => action(() async {
        await client!.auth.verifyOTP(email: pendingEmail, token: otp.text.trim(), type: OtpType.email);
      });
  Future<void> logPeriod() => action(() async {
        final today = DateUtils.dateOnly(DateTime.now()).toIso8601String().substring(0, 10);
        await client!.from('cycles').insert({'owner_id': session!.user.id, 'start_date': today});
        await refresh();
      });
  Future<void> createInvite() => action(() async {
        final value = await client!.rpc('create_invite');
        setState(() => invite = value.toString());
      });
  Future<void> shareNearby() => action(() async {
        if (defaultTargetPlatform != TargetPlatform.android) {
          throw const FormatException('Nearby Bluetooth pairing is currently available on Android phones.');
        }
        final value = await client!.rpc('create_invite');
        final code = value.toString();
        await nearby.invokeMethod<void>('startAdvertising', {'code': code});
        nearbyTimer?.cancel();
        nearbyTimer = Timer(const Duration(minutes: 10), () {
          nearby.invokeMethod<void>('stopAdvertising');
          nearbyPoll?.cancel();
          if (mounted) setState(() => nearbyAdvertising = false);
        });
        nearbyPoll?.cancel();
        nearbyPoll = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
        setState(() { invite = code; nearbyAdvertising = true; });
      });
  Future<void> scanNearby() => action(() async {
        if (defaultTargetPlatform != TargetPlatform.android) {
          throw const FormatException('Nearby Bluetooth pairing is currently available on Android phones.');
        }
        await nearby.invokeMethod<void>('startScan');
        nearbyTimer?.cancel();
        nearbyTimer = Timer(const Duration(seconds: 30), () {
          nearby.invokeMethod<void>('stopScan');
          if (mounted) setState(() { nearbyScanning = false; nearbyScanTimedOut = true; });
        });
        setState(() { nearbyCodes.clear(); nearbyScanning = true; nearbyScanTimedOut = false; nearbyScanSeen = 0; });
      });
  Future<void> stopNearby() async {
    nearbyTimer?.cancel();
    nearbyPoll?.cancel();
    await nearby.invokeMethod<void>(nearbyAdvertising ? 'stopAdvertising' : 'stopScan');
    if (mounted) setState(() { nearbyAdvertising = false; nearbyScanning = false; });
  }
  Future<void> connectNearby(String code) async {
    pairingCode.text = code;
    await acceptInvite();
  }
  Future<void> acceptInvite() => action(() async {
        await client!.rpc('accept_invite', params: {'invite_code': pairingCode.text.trim().toUpperCase()});
        if (nearbyScanning) await nearby.invokeMethod<void>('stopScan');
        nearbyTimer?.cancel();
        if (mounted) setState(() { nearbyScanning = false; nearbyCodes.clear(); });
        await refresh();
      });
  Future<void> unlink() => action(() async {
        await client!.rpc('unlink_partner');
        setState(() { link = null; notes = []; ratings = []; });
        await refresh();
      });
  Future<void> sendNote() => action(() async {
        if (link == null || noteDraft.text.trim().isEmpty) return;
        await client!.from('notes').insert({
          'link_id': link!['id'], 'sender_id': session!.user.id,
          'recipient_id': link!['owner_id'], 'body': noteDraft.text.trim(), 'style': noteStyle,
        });
        noteDraft.clear();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your note was sent.')));
      });
  Future<void> rateDate() => action(() async {
        if (link == null) return;
        final today = DateUtils.dateOnly(DateTime.now()).toIso8601String().substring(0, 10);
        await client!.from('date_ratings').insert({
          'link_id': link!['id'], 'author_id': session!.user.id, 'date_on': today,
          'stars': stars, 'reflection': reflection.text.trim().isEmpty ? null : reflection.text.trim(),
        });
        reflection.clear();
        await refresh();
      });
  Future<void> openNote(Map<String, dynamic> note) async {
    final style = note['style'] as String? ?? 'letter';
    final design = noteDesign[style] ?? noteDesign['letter']!;
    if (mounted) {
      await showDialog<void>(context: context, builder: (context) => AlertDialog(
            backgroundColor: design.color,
            title: Column(children: [Text(design.icon, style: const TextStyle(fontSize: 52)), Text(design.title)]),
            content: Text(note['body'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ));
    }
    if (note['opened_at'] == null) {
      await action(() async {
        await client!.rpc('open_note', params: {'note_id': note['id']});
        await refresh();
      });
    }
  }

  Widget card(String title, List<Widget> children, {Color? color}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: ink)),
          const SizedBox(height: 10), ...children,
        ]),
      );
  Widget button(String label, VoidCallback onPressed) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : onPressed, child: Text(label))),
      );
  Widget input(TextEditingController controller, String label, {TextInputType? keyboard, int lines = 1, int? maxLength}) =>
      TextField(controller: controller, keyboardType: keyboard, maxLines: lines, maxLength: maxLength,
          decoration: InputDecoration(labelText: label, filled: true, fillColor: cream, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))));

  @override
  Widget build(BuildContext context) {
    final owner = role == 'owner';
    return Scaffold(body: SafeArea(child: ListView(padding: const EdgeInsets.all(22), children: [
      const Text('✿  Mahila Mitr', style: TextStyle(fontSize: 25, color: plum, fontWeight: FontWeight.bold)),
      const Padding(padding: EdgeInsets.only(top: 8, bottom: 24), child: Text('A gentle space for your cycle and the people you choose.')),
      if (client == null) card('Setup needed', [const Text('Add your Supabase URL and publishable key with --dart-define to enable sign in and syncing.')]),
      if (role == null) card('How will you use the app?', [
        button('Track my cycle', () => chooseRole('owner')),
        button('Support my partner', () => chooseRole('partner')),
      ]) else if (session == null) card('Private sign in', [
        const Text('Enter your email address. We’ll send a one-time code.'),
        const SizedBox(height: 12),
        input(email, 'Email address', keyboard: TextInputType.emailAddress),
        if (codeSent) ...[
          Text('Code sent to $pendingEmail'),
          input(otp, 'Email code', keyboard: TextInputType.number),
          TextButton(onPressed: () => setState(() { codeSent = false; pendingEmail = null; otp.clear(); }), child: const Text('Use a different email')),
        ],
        button(codeSent ? 'Verify code' : 'Send code', codeSent ? verifyCode : sendCode),
      ]) else ...[
        if (owner) card('Your cycle', [
          Text(nextPeriodLabel(), style: const TextStyle(fontSize: 29, fontWeight: FontWeight.bold, color: ink)),
          const Text('Estimated next period · dates can vary'),
          button('My period started today', logPeriod),
          const Text('Estimates are approximate and are not contraception guidance.', style: TextStyle(fontSize: 12)),
        ], color: const Color(0xfff9e4e8)),
        card(link == null ? 'Connect privately' : 'Partner connected', [
          Text(link == null
              ? owner ? 'Pairing shares your period start logs. Create a one-time code for someone you trust.' : 'Enter the code your partner shared with you.'
              : owner ? 'Your partner can see your period start logs and send creative notes.' : 'You can see period start logs and send thoughtful notes.'),
          if (link == null && owner) ...[
            button('Create pairing code', createInvite),
            if (invite != null) Center(child: Text(invite!, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.bold, letterSpacing: 3, color: plum))),
            button(nearbyAdvertising ? 'Stop nearby sharing' : 'Share nearby for 10 minutes', nearbyAdvertising ? stopNearby : shareNearby),
          ],
          if (link == null && !owner) ...[
            input(pairingCode, 'Pairing code'), button('Connect', acceptInvite),
            button(nearbyScanning ? 'Stop nearby scan' : 'Find nearby partner', nearbyScanning ? stopNearby : scanNearby),
            if (nearbyScanning) Text('Scanning · $nearbyScanSeen Bluetooth signals seen'),
            if (nearbyScanTimedOut && nearbyCodes.isEmpty) Text('No Mahila Mitr invitation found. $nearbyScanSeen Bluetooth signals were seen. Keep both apps open and try again.'),
            for (final code in nearbyCodes) ListTile(
              title: const Text('Mahila Mitr invitation nearby'),
              subtitle: const Text('Tap to connect with this person'),
              trailing: const Icon(Icons.bluetooth),
              onTap: busy ? null : () => connectNearby(code),
            ),
          ],
          if (link != null) TextButton(onPressed: unlink, child: const Text('Disconnect partner')),
        ]),
        if (!owner && link != null) card('Send a little moment', [
          const Text('Choose the feeling your partner will see when opening your note.'),
          Wrap(spacing: 6, children: noteDesign.entries.map((entry) => ChoiceChip(
            label: Text('${entry.value.icon} ${entry.value.title}'), selected: noteStyle == entry.key,
            onSelected: (_) => setState(() => noteStyle = entry.key),
          )).toList()),
          input(noteDraft, 'Write something kind', lines: 4, maxLength: 500),
          button('Send note', sendNote),
        ]),
        if (link != null) card('How was your date?', [
          const Text('Each of you can rate today once. Ratings and reflections are shared.'),
          Wrap(children: [for (var n = 1; n <= 5; n++) IconButton(
            onPressed: () => setState(() => stars = n),
            icon: Icon(n <= stars ? Icons.star : Icons.star_border, color: const Color(0xffd78c48)),
          )]),
          input(reflection, 'A favorite moment (optional)', maxLength: 300),
          button("Save today's rating", rateDate),
          for (final rating in ratings.take(6)) ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("${rating['author_id'] == session!.user.id ? 'You' : 'Partner'} · ${rating['date_on']} · ${'★' * (rating['stars'] as int)}"),
            subtitle: rating['reflection'] == null ? null : Text(rating['reflection'] as String),
          ),
        ]),
        if (owner) card('Your notes', [
          TextButton(onPressed: () async {
            await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
            await notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: false, sound: false);
          }, child: const Text('Enable discreet notifications')),
          if (notes.isEmpty) const Text('When your partner writes, you’ll find it here.'),
          for (final note in notes) ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(noteDesign[note['style']]?.icon ?? '✉', style: const TextStyle(fontSize: 27)),
            title: Text(note['opened_at'] == null ? 'A new little surprise' : 'A note from your partner'),
            subtitle: Text((note['created_at'] as String).substring(0, 10)),
            onTap: () => openNote(note),
          ),
        ]),
        if ((owner || link != null) && cycles.isNotEmpty) card('Period starts', [
          for (final cycle in cycles) ListTile(contentPadding: EdgeInsets.zero, title: Text(cycle['start_date'] as String)),
        ]),
        TextButton(onPressed: () => action(() async {
          await client!.auth.signOut();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('role');
          setState(() { role = null; link = null; notes = []; ratings = []; cycles = []; });
        }), child: const Text('Sign out')),
      ],
    ])));
  }

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

class NoteDesign {
  const NoteDesign(this.title, this.icon, this.color);
  final String title;
  final String icon;
  final Color color;
}

const noteDesign = <String, NoteDesign>{
  'letter': NoteDesign('A little letter', '✉', Color(0xfffff1ec)),
  'bloom': NoteDesign('A flower for you', '✿', Color(0xfff8edf5)),
  'star': NoteDesign('A bright thought', '✦', Color(0xfff3f0ff)),
};
