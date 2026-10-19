import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_design.dart';

enum VisualEffects { automatic, full, reduced, off }

/// Preferences belong to the device, never to a partner's shared account data.
class AppearanceController extends ChangeNotifier with WidgetsBindingObserver {
  static const preferenceKey = 'appearance.visual_effects';
  VisualEffects _choice = VisualEffects.automatic;
  VisualEffects _automaticLevel = VisualEffects.full;
  VisualEffects get choice => _choice;
  VisualEffects get effective =>
      _choice == VisualEffects.automatic ? _automaticLevel : _choice;
  int _samples = 0;
  int _slow = 0;
  int _warmup = 30;
  bool _foreground = true;
  bool _started = false;
  bool _disposed = false;
  SharedPreferences? _prefs;
  int _selectionRevision = 0;
  Future<void> _saving = Future.value();

  Future<void> load() async {
    final revision = _selectionRevision;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    _prefs = prefs;
    final saved = prefs.getString(preferenceKey);
    // A setting changed during loading takes precedence over the saved value.
    if (revision == _selectionRevision) {
      _choice = VisualEffects.values.firstWhere((v) => v.name == saved,
          orElse: () => VisualEffects.automatic);
    }
    notifyListeners();
  }

  void startMonitoring() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  Future<void> select(VisualEffects value) async {
    _selectionRevision++;
    _choice = value;
    _automaticLevel = VisualEffects.full;
    _samples = 0;
    _slow = 0;
    _warmup = 30;
    notifyListeners();
    final save = _saving.catchError((Object _) {}).then((_) async {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setString(preferenceKey, value.name);
    });
    _saving = save;
    await save;
  }

  void _onTimings(List<FrameTiming> frames) {
    if (!_foreground || _choice != VisualEffects.automatic) return;
    for (final frame in frames) {
      // Use actual UI/raster work, excluding idle gaps between frames.
      recordFrame(frame.buildDuration > frame.rasterDuration
          ? frame.buildDuration
          : frame.rasterDuration);
    }
  }

  @visibleForTesting
  void recordFrame(Duration work) {
    if (_choice != VisualEffects.automatic || !_foreground) return;
    if (_warmup-- > 0) return;
    _samples++;
    if (work > const Duration(milliseconds: 32)) _slow++;
    if (_samples < 60) return;
    if (_slow >= 18 && _automaticLevel != VisualEffects.off) {
      _automaticLevel = _automaticLevel == VisualEffects.full
          ? VisualEffects.reduced
          : VisualEffects.off;
      // Never oscillate back to expensive effects during the same session.
      notifyListeners();
    }
    _samples = 0;
    _slow = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _samples = 0;
    _slow = 0;
    _warmup = 30;
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope(
      {required AppearanceController controller,
      required super.child,
      super.key})
      : super(notifier: controller);
  static AppearanceController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier;
  static VisualEffects effectsOf(BuildContext context) {
    final value = maybeOf(context)?.effective ?? VisualEffects.full;
    if (MediaQuery.highContrastOf(context)) return VisualEffects.off;
    if (MediaQuery.disableAnimationsOf(context) &&
        value == VisualEffects.full) {
      return VisualEffects.reduced;
    }
    return value;
  }
}

class AppearanceSettingsPanel extends StatelessWidget {
  const AppearanceSettingsPanel({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = AppearanceScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    const descriptions = {
      VisualEffects.automatic: (
        'Automatic',
        'Reduce effects when rendering stays slow.'
      ),
      VisualEffects.full: (
        'Full effects',
        'Liquid glass, refraction, and interactive screen cards.'
      ),
      VisualEffects.reduced: (
        'Reduced effects',
        'Solid capsule, no refraction or movement.'
      ),
      VisualEffects.off: (
        'Off',
        'Simple navigation for the lightest experience.'
      ),
    };
    return AppSurface(title: 'Display & performance', children: [
      const Text('Choose how much visual detail feels right for your device.',
          style: TextStyle(color: AppPalette.muted)),
      const SizedBox(height: 12),
      for (final entry in descriptions.entries)
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
                controller.choice == entry.key
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: AppPalette.plum),
            title: Text(entry.value.$1,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle:
                Text(entry.value.$2, style: const TextStyle(fontSize: 12)),
            selected: controller.choice == entry.key,
            onTap: () async {
              try {
                await controller.select(entry.key);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Applied for now. Could not save this preference.')));
                }
              }
            }),
      const SizedBox(height: 8),
      Text(
          controller.choice == VisualEffects.automatic
              ? 'Currently using ${descriptions[controller.effective]!.$1.toLowerCase()}. Automatic adjustments reset when you reopen the app.'
              : 'Saved on this device. System Reduce Motion and high contrast take priority.',
          style: const TextStyle(fontSize: 12, color: AppPalette.muted)),
    ]);
  }
}
