import 'package:flutter/material.dart';
import 'app_design.dart';
import 'brand_widgets.dart';
import 'floral_widgets.dart';

class AppActivityController extends ChangeNotifier {
  final _operations = <Object, String>{};
  bool _disposed = false;
  bool get active => _operations.isNotEmpty;
  String get label => active ? _operations.values.last : '';

  Future<T> run<T>(String label, Future<T> Function() work) async {
    final token = Object();
    if (!_disposed) {
      _operations[token] = label;
      notifyListeners();
    }
    try {
      return await work();
    } finally {
      if (!_disposed) {
        _operations.remove(token);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _operations.clear();
    super.dispose();
  }
}

class AppActivityScope extends InheritedWidget {
  const AppActivityScope(
      {required this.controller, required super.child, super.key});
  final AppActivityController controller;
  @override
  bool updateShouldNotify(AppActivityScope oldWidget) =>
      oldWidget.controller != controller;
}

Future<T> runWithAppActivity<T>(
    BuildContext context, String label, Future<T> Function() work) {
  final controller =
      context.getInheritedWidgetOfExactType<AppActivityScope>()?.controller;
  return controller == null ? work() : controller.run(label, work);
}

/// Lives above the Navigator, so completing a request never pops a newer route.
class AppActivityOverlay extends StatelessWidget {
  const AppActivityOverlay(
      {required this.controller, required this.child, super.key});
  final AppActivityController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => Stack(fit: StackFit.expand, children: [
          AbsorbPointer(
              absorbing: controller.active,
              child:
                  ExcludeSemantics(excluding: controller.active, child: child)),
          if (controller.active) ...[
            const Positioned.fill(
                child:
                    ModalBarrier(dismissible: false, color: Color(0x33000000))),
            Center(
                child: Semantics(
              container: true,
              liveRegion: true,
              label: controller.label,
              child: ExcludeSemantics(
                  child: Material(
                color: AppPalette.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                    side: const BorderSide(color: Color(0xffe4ced8))),
                clipBehavior: Clip.antiAlias,
                elevation: 4,
                shadowColor: AppPalette.plum.withValues(alpha: .15),
                child: FloralBackdrop(
                    color: AppPalette.surface,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            decoration: const BoxDecoration(
                                color: AppPalette.lilac,
                                shape: BoxShape.circle),
                            child: const FloralProgressIndicator()),
                        const SizedBox(height: 16),
                        Text(controller.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: AppPalette.ink)),
                      ]),
                    )),
              )),
            )),
          ],
        ]),
      );
}
