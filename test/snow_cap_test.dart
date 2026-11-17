import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winter_theme/src/snow_cap.dart';

const _childKey = ValueKey('child');
const _tick = Duration(milliseconds: 50);

Widget _app(Widget cap, {bool reducedMotion = false}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: Center(child: cap),
    ),
  );
}

SnowCap _cap({
  double width = 320,
  int seed = 3,
  bool enabled = true,
  bool startSettled = false,
  bool accumulating = true,
  bool shedding = true,
  Duration settleTime = const Duration(seconds: 30),
  BorderRadius borderRadius = BorderRadius.zero,
  double shedRate = 1,
  ImageProvider? texture,
  CustomPainter? backgroundPainter,
  CustomPainter? foregroundPainter,
  Widget? overlay,
  Widget? child,
}) {
  return SnowCap(
    seed: seed,
    enabled: enabled,
    startSettled: startSettled,
    accumulating: accumulating,
    shedding: shedding,
    settleTime: settleTime,
    borderRadius: borderRadius,
    shedRate: shedRate,
    texture: texture,
    backgroundPainter: backgroundPainter,
    foregroundPainter: foregroundPainter,
    overlay: overlay,
    child:
        child ??
        SizedBox(
          key: _childKey,
          width: width,
          height: 120,
          child: const ColoredBox(color: Color(0xFF2B4C7E)),
        ),
  );
}

SnowCapState _state(WidgetTester t) =>
    t.state<SnowCapState>(find.byType(SnowCap));

Future<void> _run(WidgetTester t, double seconds) async {
  final frames = (seconds / 0.05).round();
  for (var i = 0; i < frames; i++) {
    await t.pump(_tick);
  }
}

class _CountingPainter extends CustomPainter {
  int paints = 0;
  @override
  void paint(Canvas canvas, Size size) => paints++;
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void main() {
  group('rendering and layout', () {
    testWidgets('renders the child', (t) async {
      await t.pumpWidget(_app(_cap()));
      expect(find.byKey(_childKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnowCap),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets('enabled: false renders only the child', (t) async {
      await t.pumpWidget(_app(_cap(enabled: false)));
      expect(find.byKey(_childKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnowCap),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(_state(t).debugTickerActive, isFalse);
    });

    testWidgets('does not change the size of the child', (t) async {
      await t.pumpWidget(_app(_cap()));
      expect(t.getSize(find.byType(SnowCap)), t.getSize(find.byKey(_childKey)));
      expect(t.getSize(find.byKey(_childKey)), const Size(320, 120));
    });

    testWidgets('lets taps through to the child', (t) async {
      var taps = 0;
      await t.pumpWidget(
        _app(
          _cap(
            child: GestureDetector(
              key: _childKey,
              onTap: () => taps++,
              child: const SizedBox(
                width: 320,
                height: 120,
                child: ColoredBox(color: Color(0xFF2B4C7E)),
              ),
            ),
          ),
        ),
      );
      await _run(t, 5);
      await t.tap(find.byKey(_childKey));
      expect(taps, 1);
    });

    testWidgets('draws nothing when narrower than four chunks', (t) async {
      await t.pumpWidget(_app(_cap(width: 60)));
      await _run(t, 5);
      expect(_state(t).debugHeights, isEmpty);
    });

    testWidgets('draws nothing when the child has no height', (t) async {
      await t.pumpWidget(
        _app(_cap(child: const SizedBox(width: 320, height: 0))),
      );
      await _run(t, 2);
      expect(_state(t).debugHeights, isEmpty);
    });
  });

  group('build-up', () {
    testWidgets('starts bare, forms patches, ends as one heap', (t) async {
      await t.pumpWidget(_app(_cap()));
      final s = _state(t);
      expect(s.debugHeights.every((h) => h == 0), isTrue);
      expect(s.debugPatchCount, 0);

      await _run(t, 10);
      expect(s.debugPatchCount, greaterThan(1));
      expect(s.debugFill, inInclusiveRange(0.1, 0.6));

      await _run(t, 20); // 30 s = settleTime
      expect(s.debugPatchCount, 1);
      expect(s.debugFill, greaterThan(0.75));
    });

    testWidgets('startSettled is full on the first frame', (t) async {
      await t.pumpWidget(_app(_cap(startSettled: true)));
      final s = _state(t);
      expect(s.debugFill, closeTo(1, 1e-9));
      expect(s.debugPatchCount, 1);
    });

    testWidgets('the same seed gives the same heap', (t) async {
      await t.pumpWidget(_app(_cap()));
      await _run(t, 12);
      final a = _state(t).debugHeights;
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(_app(_cap()));
      await _run(t, 12);
      expect(_state(t).debugHeights, a);
    });

    testWidgets('a width change keeps the heap', (t) async {
      await t.pumpWidget(_app(_cap()));
      await _run(t, 20);
      final before = _state(t).debugFill;
      expect(before, greaterThan(0.3));
      await t.pumpWidget(_app(_cap(width: 240)));
      await t.pump();
      expect(_state(t).debugFill, closeTo(before, 0.15));
      expect(_state(t).debugPatchCount, greaterThan(0));
    });

    testWidgets('changing parameters keeps the heap', (t) async {
      await t.pumpWidget(_app(_cap()));
      await _run(t, 15);
      final before = _state(t).debugHeights;
      await t.pumpWidget(_app(_cap(shedRate: 2)));
      expect(_state(t).debugHeights, before);
    });
  });

  group('lifecycle', () {
    testWidgets('no ticker when nothing can move', (t) async {
      await t.pumpWidget(
        _app(_cap(accumulating: false, shedding: false, startSettled: true)),
      );
      expect(_state(t).debugTickerActive, isFalse);
      await t.pumpAndSettle();
    });

    testWidgets('no ticker with reduced motion, and the heap is full', (
      t,
    ) async {
      await t.pumpWidget(_app(_cap(), reducedMotion: true));
      expect(_state(t).debugTickerActive, isFalse);
      await t.pumpAndSettle();
      expect(_state(t).debugFill, closeTo(1, 1e-9));
    });

    testWidgets('runs while accumulating and stops when turned off', (t) async {
      await t.pumpWidget(_app(_cap()));
      expect(_state(t).debugTickerActive, isTrue);
      await t.pumpWidget(_app(_cap(accumulating: false, shedding: false)));
      expect(_state(t).debugTickerActive, isFalse);
      await t.pumpWidget(_app(_cap()));
      expect(_state(t).debugTickerActive, isTrue);
    });

    testWidgets('keeps running while pieces are in the air', (t) async {
      await t.pumpWidget(_app(_cap(startSettled: true, settleTime: _s(10))));
      while (_state(t).debugPieceCount == 0) {
        await t.pump(_tick);
      }
      await t.pumpWidget(
        _app(
          _cap(
            startSettled: true,
            settleTime: _s(10),
            accumulating: false,
            shedding: false,
          ),
        ),
      );
      expect(_state(t).debugTickerActive, isTrue);
      await _run(t, 12);
      expect(_state(t).debugPieceCount, 0);
      expect(_state(t).debugTickerActive, isFalse);
    });

    testWidgets('parameter changes never create a second ticker', (t) async {
      for (var i = 0; i < 8; i++) {
        await t.pumpWidget(
          _app(_cap(seed: 3 + (i % 2), shedRate: 1.0 + i, enabled: i != 3)),
        );
        await t.pump(_tick);
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('disposes cleanly', (t) async {
      await t.pumpWidget(_app(_cap()));
      await _run(t, 3);
      await t.pumpWidget(const SizedBox());
      expect(t.binding.transientCallbackCount, 0);
    });

    testWidgets('a long pause does not make the heap jump', (t) async {
      await t.pumpWidget(_app(_cap()));
      await t.pump(_tick);
      await t.pump(const Duration(minutes: 5));
      expect(_state(t).debugFill, lessThan(0.05));
    });
  });

  group('shedding', () {
    testWidgets('a corner breaks, drops to near zero, then refills', (t) async {
      await t.pumpWidget(
        _app(
          _cap(
            startSettled: true,
            settleTime: _s(10),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      final s = _state(t);
      var prev = s.debugHeights;
      var index = -1;
      for (var i = 0; i < 600 && index < 0; i++) {
        await t.pump(_tick);
        final now = s.debugHeights;
        for (var j = 0; j < now.length; j++) {
          if (prev[j] > 3 && now[j] < prev[j] * 0.25) {
            index = j;
            break;
          }
        }
        prev = now;
      }
      expect(index, greaterThanOrEqualTo(0), reason: 'no break seen');
      expect(s.debugBreakCount, greaterThan(0));
      expect(s.debugHeights[index], lessThan(3));

      final cap = s.debugCaps[index];
      var best = 0.0;
      for (var i = 0; i < 800; i++) {
        await t.pump(_tick);
        best = best < s.debugHeights[index] ? s.debugHeights[index] : best;
      }
      expect(best, greaterThan(cap * 0.6));
    });

    testWidgets('shedding: false never breaks', (t) async {
      await t.pumpWidget(
        _app(_cap(startSettled: true, shedding: false, settleTime: _s(10))),
      );
      await _run(t, 60);
      expect(_state(t).debugBreakCount, 0);
      expect(_state(t).debugPieceCount, 0);
    });

    testWidgets('the middle never sheds', (t) async {
      await t.pumpWidget(
        _app(_cap(startSettled: true, settleTime: _s(10), shedRate: 3)),
      );
      final s = _state(t);
      final n = s.debugHeights.length;
      final mid = [for (var i = n ~/ 3; i < 2 * n ~/ 3; i++) i];
      var minRatio = 1.0;
      for (var i = 0; i < 800; i++) {
        await t.pump(_tick);
        final h = s.debugHeights;
        final c = s.debugCaps;
        for (final j in mid) {
          final r = h[j] / c[j];
          if (r < minRatio) minRatio = r;
        }
      }
      expect(s.debugBreakCount, greaterThan(2));
      expect(minRatio, greaterThan(0.7));
    });

    testWidgets('live pieces are capped at four', (t) async {
      await t.pumpWidget(
        _app(_cap(startSettled: true, settleTime: _s(5), shedRate: 20)),
      );
      var most = 0;
      for (var i = 0; i < 600; i++) {
        await t.pump(_tick);
        if (_state(t).debugPieceCount > most) most = _state(t).debugPieceCount;
      }
      expect(most, inInclusiveRange(1, 4));
    });
  });

  group('customization', () {
    testWidgets('custom painters and overlay are drawn', (t) async {
      final bg = _CountingPainter();
      final fg = _CountingPainter();
      await t.pumpWidget(
        _app(
          _cap(
            backgroundPainter: bg,
            foregroundPainter: fg,
            overlay: const SizedBox(key: ValueKey('overlay-content')),
          ),
        ),
      );
      await t.pump(_tick);
      expect(bg.paints, greaterThan(0));
      expect(fg.paints, greaterThan(0));
      expect(find.byKey(const ValueKey('overlay-content')), findsOneWidget);
      expect(t.getSize(find.byType(SnowCap)), const Size(320, 120));
    });

    testWidgets('a texture image fills the snow', (t) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      );
      await t.runAsync(() async {
        await t.pumpWidget(
          _app(_cap(startSettled: true, texture: MemoryImage(png))),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await t.pump(_tick);
      await t.pump(_tick);
      expect(t.takeException(), isNull);
      await t.pumpWidget(_app(_cap(startSettled: true)));
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  });

  group('asserts', () {
    const child = SizedBox();
    test('out-of-range values throw', () {
      expect(() => SnowCap(thickness: 0, child: child), throwsAssertionError);
      expect(() => SnowCap(overlap: -1, child: child), throwsAssertionError);
      expect(() => SnowCap(chunkSize: 0, child: child), throwsAssertionError);
      expect(() => SnowCap(shedRate: -1, child: child), throwsAssertionError);
      expect(() => SnowCap(fallSpeed: 0, child: child), throwsAssertionError);
      expect(
        () => SnowCap(fallDistance: 0, child: child),
        throwsAssertionError,
      );
    });

    testWidgets('a zero settleTime throws', (t) async {
      await t.pumpWidget(
        _app(SnowCap(settleTime: Duration.zero, child: const SizedBox())),
      );
      expect(t.takeException(), isAssertionError);
    });

    test('the constructor is const', () {
      const SnowCap(child: SizedBox());
    });
  });

  group('golden', () {
    Widget framed(SnowCap cap) => _app(
      RepaintBoundary(
        key: const ValueKey('golden'),
        child: ColoredBox(
          color: const Color(0xFF14223A),
          child: Padding(padding: const EdgeInsets.all(40), child: cap),
        ),
      ),
    );

    Future<void> expectGolden(WidgetTester t, String name) => expectLater(
      find.byKey(const ValueKey('golden')),
      matchesGoldenFile('goldens/$name.png'),
    );

    testWidgets('patches part-way through', (t) async {
      await t.pumpWidget(framed(_cap(shedding: false)));
      await _run(t, 10);
      await expectGolden(t, 'snow_cap_patches');
    });

    testWidgets('full heap, square corners', (t) async {
      await t.pumpWidget(
        framed(_cap(startSettled: true, accumulating: false, shedding: false)),
      );
      await expectGolden(t, 'snow_cap_square');
    });

    testWidgets('full heap, rounded corners', (t) async {
      await t.pumpWidget(
        framed(
          _cap(
            startSettled: true,
            accumulating: false,
            shedding: false,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: const SizedBox(
              key: _childKey,
              width: 320,
              height: 120,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF2B4C7E),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
            ),
          ),
        ),
      );
      await expectGolden(t, 'snow_cap_rounded');
    });

    testWidgets('one frame mid-break', (t) async {
      await t.pumpWidget(
        framed(
          _cap(
            startSettled: true,
            accumulating: false,
            settleTime: _s(10),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      for (var i = 0; i < 800 && _state(t).debugPieceCount == 0; i++) {
        await t.pump(_tick);
      }
      expect(_state(t).debugPieceCount, greaterThan(0));
      await _run(t, 0.7);
      await expectGolden(t, 'snow_cap_break');
    });
  });
}

Duration _s(int seconds) => Duration(seconds: seconds);
