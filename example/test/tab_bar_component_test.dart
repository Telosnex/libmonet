import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:monet_studio/tab_bar_component.dart';

void main() {
  testWidgets('tabs use the standalone controller and retain selection', (
    tester,
  ) async {
    Widget buildApp() => const MaterialApp(
          home: Scaffold(body: TabBarComponent()),
        );

    await tester.pumpWidget(buildApp());
    final context = tester.element(find.byType(TabBar));
    final controller = DefaultTabController.of(context);
    expect(controller.length, 3);
    expect(controller.index, 0);

    await tester.tap(find.byIcon(Icons.directions_bike));
    await tester.pumpAndSettle();
    expect(controller.index, 2);

    await tester.pumpWidget(buildApp());
    expect(DefaultTabController.of(tester.element(find.byType(TabBar))),
        same(controller));
    expect(controller.index, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
