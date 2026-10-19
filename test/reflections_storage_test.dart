import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahila_mitr/app_design.dart';

void main() {
  testWidgets('reflection expansion and text scroll use separate stored state',
      (tester) async {
    final controller = TextEditingController();
    final bucket = PageStorageBucket();
    Widget screen() => MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: PageStorage(
              bucket: bucket,
              child: ListView(children: [
                ExpansionTile(
                    key: const PageStorageKey('moments-reflections'),
                    title: const Text('Shared reflections'),
                    children: [
                      AppTextInput(
                          controller: controller,
                          label: 'Add a note (optional)',
                          lines: 3,
                          maxLength: 300),
                    ]),
              ])),
        ));
    await tester.pumpWidget(screen());
    await tester.tap(find.text('Shared reflections'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Keep my reflection draft');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('Shared reflections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shared reflections'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Keep my reflection draft'), findsOneWidget);
    // Recreate the page with the same stored expansion state.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Keep my reflection draft'), findsOneWidget);
    final reload = tester.binding.reassembleApplication();
    await tester.pump();
    await reload;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Keep my reflection draft'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
