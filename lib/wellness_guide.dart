import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

class WellnessGuideController {
  _WellnessGuideState? _state;

  void _attach(_WellnessGuideState state) => _state = state;
  void _detach(_WellnessGuideState state) {
    if (identical(_state, state)) _state = null;
  }

  void wave() => _state?._wave();
  void celebrate() => _state?._celebrate();
}

class WellnessGuide extends StatefulWidget {
  const WellnessGuide({
    required this.screen,
    required this.isCheckedIn,
    required this.reduceMotion,
    this.controller,
    super.key,
  });

  final int screen;
  final bool isCheckedIn;
  final bool reduceMotion;
  final WellnessGuideController? controller;

  @override
  State<WellnessGuide> createState() => _WellnessGuideState();
}

class _WellnessGuideState extends State<WellnessGuide> {
  static Future<bool>? _assetAvailability;
  rive.File? _file;
  rive.RiveWidgetController? _riveController;
  rive.NumberInput? _screenInput;
  rive.BooleanInput? _checkedInInput;
  rive.TriggerInput? _waveInput;
  rive.TriggerInput? _celebrateInput;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _load();
  }

  @override
  void didUpdateWidget(covariant WellnessGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    _syncInputs();
  }

  Future<void> _load() async {
    try {
      const assetPath = 'assets/rive/mahila_guide.riv';
      final available = await (_assetAvailability ??=
          AssetManifest.loadFromAssetBundle(rootBundle).then(
        (manifest) => manifest.listAssets().contains(assetPath),
      ));
      if (!available) {
        // A licensed guide is optional. Avoid asking the Rive runtime to load
        // an absent file, which would otherwise create noisy startup errors.
        return;
      }
      final file = await rive.File.asset(
        assetPath,
        riveFactory: rive.Factory.rive,
      );
      if (!mounted) {
        file?.dispose();
        return;
      }
      if (file == null) return;
      final controller = rive.RiveWidgetController(
        file,
        artboardSelector: const rive.ArtboardNamed('Guide'),
        stateMachineSelector: const rive.StateMachineNamed('GuideState'),
      );
      final machine = controller.stateMachine;
      // The licensed asset contract intentionally uses Rive state-machine
      // inputs so designers can replace the character without code changes.
      // ignore: deprecated_member_use
      _screenInput = machine.number('screen');
      // ignore: deprecated_member_use
      _checkedInInput = machine.boolean('isCheckedIn');
      // ignore: deprecated_member_use
      _waveInput = machine.trigger('wave');
      // ignore: deprecated_member_use
      _celebrateInput = machine.trigger('celebrate');
      if (_screenInput == null ||
          _checkedInInput == null ||
          _waveInput == null ||
          _celebrateInput == null) {
        throw StateError('The Mahila guide Rive input contract is incomplete.');
      }
      _file = file;
      _riveController = controller;
      _syncInputs();
      if (mounted) setState(() => _available = true);
      if (widget.screen == 0 && !widget.reduceMotion) _wave();
    } catch (error, stackTrace) {
      debugPrint('Wellness guide unavailable: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
      _disposeRive();
      if (mounted) setState(() => _available = false);
    }
  }

  void _syncInputs() {
    _screenInput?.value = widget.screen.toDouble();
    _checkedInInput?.value = widget.isCheckedIn;
    if (_riveController != null) {
      _riveController!.active = !widget.reduceMotion;
    }
  }

  void _wave() {
    if (!widget.reduceMotion) _waveInput?.fire();
  }

  void _celebrate() {
    if (!widget.reduceMotion) _celebrateInput?.fire();
  }

  void _disposeRive() {
    _screenInput?.dispose();
    _checkedInInput?.dispose();
    _waveInput?.dispose();
    _celebrateInput?.dispose();
    _riveController?.dispose();
    _file?.dispose();
    _screenInput = null;
    _checkedInInput = null;
    _waveInput = null;
    _celebrateInput = null;
    _riveController = null;
    _file = null;
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _disposeRive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_available || _riveController == null) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: 'Mahila Mitr wellness guide',
      image: true,
      child: SizedBox(
        height: 154,
        child: rive.RiveWidget(
          controller: _riveController!,
          fit: rive.Fit.contain,
          alignment: Alignment.bottomRight,
        ),
      ),
    );
  }
}
