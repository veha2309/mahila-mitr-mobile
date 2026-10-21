import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Guards Android's root route; pushed routes and modal sheets pop normally.
class DoubleBackToClose extends StatefulWidget {
  const DoubleBackToClose({required this.child, super.key});

  final Widget child;

  @override
  State<DoubleBackToClose> createState() => _DoubleBackToCloseState();
}

class _DoubleBackToCloseState extends State<DoubleBackToClose>
    with WidgetsBindingObserver {
  static const _window = Duration(seconds: 2);
  Timer? _resetTimer;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _reset() {
    _resetTimer?.cancel();
    _armed = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _reset();
  }

  void _onBack(bool didPop, Object? result) {
    if (didPop || ModalRoute.of(context)?.isCurrent != true) return;
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      _reset();
      return;
    }
    if (_armed) {
      _reset();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      unawaited(SystemNavigator.pop());
      return;
    }
    _armed = true;
    _resetTimer = Timer(_window, _reset);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Press back again to close'),
        duration: _window,
      ));
  }

  @override
  void dispose() {
    _reset();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return widget.child;
    }
    // Changing routes breaks the sequence, even if the user returns quickly.
    if (ModalRoute.isCurrentOf(context) != true) _reset();
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onBack,
      child: widget.child,
    );
  }
}
