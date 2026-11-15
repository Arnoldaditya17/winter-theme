import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winter_theme/winter_theme.dart';

Widget _host(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: SizedBox(width: 300, height: 300, child: child)),
);

Finder get _snow => find.descendant(
  of: find.byType(Snowfall),
  matching: find.byType(CustomPaint),
);

void main() {
  testWidgets('paints snow over its child and keeps animating', (tester) async {
    await tester.pumpWidget(_host(const Snowfall(child: Text('hello'))));
    expect(find.text('hello'), findsOneWidget);
    expect(_snow, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stops drawing and ticking when disabled', (tester) async {
    await tester.pumpWidget(
      _host(const Snowfall(enabled: false, child: Text('hello'))),
    );
    expect(find.text('hello'), findsOneWidget);
    expect(_snow, findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('child stays tappable under the snow', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Snowfall(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector));
    expect(taps, 1);
  });

  testWidgets('survives a zero-sized box and a flake count change', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox.shrink(child: Snowfall(child: SizedBox())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(
      _host(const Snowfall(numberOfSnowflakes: 5, child: SizedBox())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('background layer puts the snow behind the child', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Snowfall(layer: SnowfallLayer.background, child: Text('hello')),
      ),
    );
    final stack = tester.widget<Stack>(
      find.descendant(of: find.byType(Snowfall), matching: find.byType(Stack)),
    );
    expect(stack.children.first, isA<Positioned>());
    expect(stack.children.last, isA<Text>());
  });

  testWidgets('snow area follows padding, alignment and size factors', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Snowfall(
          padding: EdgeInsets.only(left: 20),
          alignment: Alignment.topLeft,
          widthFactor: 0.5,
          heightFactor: 0.25,
          child: SizedBox.expand(),
        ),
      ),
    );
    final host = tester.getTopLeft(find.byType(Snowfall));
    final snow = tester.getRect(_snow);
    expect(snow.topLeft, host + const Offset(20, 0));
    expect(snow.size, const Size(140, 75));
  });

  testWidgets('paints with a colour palette and a custom path', (tester) async {
    await tester.pumpWidget(
      _host(
        Snowfall(
          seed: 7,
          colors: const [Color(0xFFFFFFFF), Color(0xFF9AD0FF)],
          crystalFraction: 1,
          crystalPath: Path()..addOval(const Rect.fromLTRB(-1, -1, 1, 1)),
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}
