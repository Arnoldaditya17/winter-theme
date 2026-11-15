import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:winter_theme/winter_theme.dart';
import 'package:winter_theme_example/main.dart';

void main() {
  testWidgets('test screen toggles the full-screen snow', (tester) async {
    // Tall enough that the lazily built list shows every card at once.
    tester.view
      ..physicalSize = const Size(800, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const WinterThemeExampleApp());
    Snowfall screenSnow() =>
        tester.widget<Snowfall>(find.byType(Snowfall).first);
    expect(screenSnow().enabled, isTrue);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(screenSnow().enabled, isFalse);

    await tester.tap(find.text('Festive'));
    await tester.pump();
    expect(screenSnow().colors, hasLength(4));
    expect(
      find.textContaining(
        'colors: const [Color(0xFFFFFFFF), Color(0xFFFF6B6B)',
      ),
      findsOneWidget,
    );
  });
}
