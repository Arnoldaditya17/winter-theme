import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// How a [Snowfall] draws each snowflake.
enum SnowflakeShape {
  /// A mix of six-armed ice crystals that slowly spin as they fall and soft
  /// round flakes. [Snowfall.crystalFraction] sets the mix. Flakes too small
  /// to show a crystal's detail are always drawn round, which reads as
  /// distance.
  crystal,

  /// Plain soft round dots.
  dot,
}

/// Whether a [Snowfall] draws its snow in front of or behind its child.
enum SnowfallLayer {
  /// Snow falls in front of the child. Taps still reach the child.
  foreground,

  /// Snow falls behind the child, so it only shows through the child's
  /// transparent parts. Useful behind text, cards, or a transparent scaffold.
  background,
}

/// Draws falling snow over [child].
///
/// The snow fills whatever box this widget is given, so the same widget can
/// cover a whole screen, a single card, or an app bar:
///
/// ```dart
/// Snowfall(child: MyScreen())
/// ```
///
/// To make it snow over the entire app, wrap the navigator in
/// `MaterialApp.builder`:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => Snowfall(child: child!),
/// )
/// ```
///
/// Almost everything can be customised: the look of the flakes ([shape],
/// [colors], [crystalPath], [minSize], [maxSize], [opacity]), how they move
/// ([minSpeed], [maxSpeed], [wind], [gustiness], [sway], [spin]), and where
/// they appear ([layer], [padding], [alignment], [widthFactor],
/// [heightFactor], [fadeExtent]).
///
/// The snow never intercepts pointer events, so [child] stays fully
/// interactive.
class Snowfall extends StatefulWidget {
  /// Creates a snowfall over [child].
  const Snowfall({
    super.key,
    required this.child,
    this.enabled = true,
    this.numberOfSnowflakes = 120,
    this.color = const Color(0xFFFFFFFF),
    this.colors,
    this.crystalPath,
    this.layer = SnowfallLayer.foreground,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
    this.widthFactor = 1,
    this.heightFactor = 1,
    this.sway = 1,
    this.spin = 1,
    this.seed,
    this.shape = SnowflakeShape.crystal,
    this.crystalFraction = 0.35,
    this.fadeExtent = 56,
    this.minSize = 1.5,
    this.maxSize = 10,
    this.minSpeed = 30,
    this.maxSpeed = 90,
    this.wind = 0,
    this.gustiness = 45,
    this.opacity = 0.9,
  }) : assert(numberOfSnowflakes >= 0),
       assert(minSize > 0 && maxSize >= minSize),
       assert(minSpeed >= 0 && maxSpeed >= minSpeed),
       assert(colors == null || colors.length > 0),
       assert(widthFactor > 0 && widthFactor <= 1),
       assert(heightFactor > 0 && heightFactor <= 1),
       assert(sway >= 0),
       assert(spin >= 0),
       assert(crystalFraction >= 0 && crystalFraction <= 1),
       assert(fadeExtent >= 0),
       assert(opacity >= 0 && opacity <= 1);

  /// The widget the snow falls over.
  final Widget child;

  /// Whether it is snowing. When false nothing is drawn and no frames are
  /// scheduled.
  final bool enabled;

  /// How many snowflakes are on screen at once.
  final int numberOfSnowflakes;

  /// Colour of the snowflakes. Ignored when [colors] is given.
  final Color color;

  /// A palette to pick each snowflake's colour from at random, for example
  /// white mixed with pale blue, or festive reds and golds. When null every
  /// flake uses [color].
  final List<Color>? colors;

  /// A custom outline drawn in place of the built-in six-armed crystal.
  ///
  /// Define it for a flake of radius 1 centred on the origin (so it fits in
  /// the square from -1 to 1); it is scaled, rotated and stroked per flake.
  /// Use it for stars, hearts, leaves or any other falling shape.
  final Path? crystalPath;

  /// Whether the snow is drawn in front of or behind [child].
  final SnowfallLayer layer;

  /// Insets the snowing area from the edges of [child], for example to keep
  /// snow out from under a navigation bar.
  final EdgeInsetsGeometry padding;

  /// Where the snowing area sits inside [child] when [widthFactor] or
  /// [heightFactor] make it smaller than the child.
  final AlignmentGeometry alignment;

  /// Width of the snowing area as a fraction of the child's width, from just
  /// above 0 to 1.
  final double widthFactor;

  /// Height of the snowing area as a fraction of the child's height, from
  /// just above 0 to 1. For snow in only the top third use `heightFactor: 1 /
  /// 3` with `alignment: Alignment.topCenter`.
  final double heightFactor;

  /// Multiplier for how far flakes swing from side to side as they fall.
  /// 0 makes them fall in straight lines.
  final double sway;

  /// Multiplier for how fast crystals rotate. 0 stops them rotating.
  final double spin;

  /// Seed for the random layout of flakes. Give one to get the same snowfall
  /// every run, which is useful in golden tests and screenshots.
  final int? seed;

  /// Whether flakes are drawn as ice crystals or plain dots.
  final SnowflakeShape shape;

  /// With [SnowflakeShape.crystal], the share of flakes drawn as crystals,
  /// from 0 to 1. The rest are soft round flakes.
  final double crystalFraction;

  /// Height in logical pixels of the bands at the top and bottom edges over
  /// which flakes fade in and out, so they don't pop into view or vanish
  /// abruptly. Set to 0 for hard edges.
  final double fadeExtent;

  /// Radius of the smallest snowflake, in logical pixels.
  final double minSize;

  /// Radius of the largest snowflake, in logical pixels.
  final double maxSize;

  /// Fall speed of the slowest snowflake, in logical pixels per second.
  final double minSpeed;

  /// Fall speed of the fastest snowflake, in logical pixels per second.
  final double maxSpeed;

  /// Horizontal drift in logical pixels per second. Positive blows to the
  /// right, negative to the left.
  final double wind;

  /// Strength of the blowing-wind effect, in logical pixels per second.
  ///
  /// Gusts roll across the snow in waves on top of the steady [wind], pushing
  /// flakes sideways and then letting them settle. Set to 0 for still air.
  final double gustiness;

  /// Opacity of the most opaque snowflakes, from 0 to 1. Smaller flakes are
  /// drawn fainter to suggest depth.
  final double opacity;

  @override
  State<Snowfall> createState() => _SnowfallState();
}

class _SnowfallState extends State<Snowfall>
    with SingleTickerProviderStateMixin {
  late final _SnowField _field = _SnowField(widget.seed);
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _field.resize(widget.numberOfSnowflakes);
    _syncTicker();
  }

  @override
  void didUpdateWidget(Snowfall oldWidget) {
    super.didUpdateWidget(oldWidget);
    _field.resize(widget.numberOfSnowflakes);
    _syncTicker();
  }

  void _syncTicker() {
    if (widget.enabled && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!widget.enabled && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    // Clamp so a paused app or a dropped frame doesn't teleport the snow.
    final dt = math.min(
      (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond,
      0.1,
    );
    _lastTick = elapsed;
    _field.advance(
      dt,
      minSpeed: widget.minSpeed,
      maxSpeed: widget.maxSpeed,
      wind: widget.wind,
      gustiness: widget.gustiness,
      sway: widget.sway,
      spin: widget.spin,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snow = Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: widget.padding,
          child: FractionallySizedBox(
            alignment: widget.alignment,
            widthFactor: widget.widthFactor,
            heightFactor: widget.heightFactor,
            child: ClipRect(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SnowPainter(
                    field: _field,
                    colors: widget.colors ?? [widget.color],
                    shape: widget.shape,
                    crystalPath: widget.crystalPath ?? _crystalPath,
                    crystalFraction: widget.crystalFraction,
                    fadeExtent: widget.fadeExtent,
                    minSize: widget.minSize,
                    maxSize: widget.maxSize,
                    opacity: widget.opacity,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final behind = widget.layer == SnowfallLayer.background;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (widget.enabled && behind) snow,
        widget.child,
        if (widget.enabled && !behind) snow,
      ],
    );
  }
}

/// One snowflake. Everything is stored as a 0..1 fraction so the field
/// survives resizes and live changes to size and speed.
class _Flake {
  _Flake(math.Random random)
    : x = random.nextDouble(),
      y = random.nextDouble(),
      depth = _randomDepth(random),
      variety = random.nextDouble(),
      tint = random.nextDouble(),
      rotation = random.nextDouble() * math.pi * 2,
      spin = (random.nextDouble() - 0.5) * 1.6,
      swayPhase = random.nextDouble() * math.pi * 2,
      swayRate = 0.6 + random.nextDouble() * 1.2,
      swayAmount = 6 + random.nextDouble() * 14;

  /// Horizontal position as a fraction of the width.
  double x;

  /// Vertical position as a fraction of the height.
  double y;

  /// 0 is far (small, slow, faint); 1 is near (large, fast, bright).
  double depth;

  /// Fixed 0..1 roll deciding whether this flake is a crystal or round.
  final double variety;

  /// Fixed 0..1 roll picking this flake's colour from the palette.
  final double tint;

  /// Current angle in radians, and how fast it turns in radians per second.
  double rotation;
  final double spin;

  double swayPhase;
  final double swayRate;
  final double swayAmount;
}

/// Skews towards 0 so most flakes are small and far, with a few large
/// crystals up close, as in real snowfall.
double _randomDepth(math.Random random) {
  final value = random.nextDouble();
  return value * value;
}

class _SnowField extends ChangeNotifier {
  _SnowField(int? seed) : _random = math.Random(seed);

  final math.Random _random;
  final List<_Flake> flakes = [];

  /// Seconds of snowfall so far; drives the gust waves.
  double _time = 0;

  /// Set by the painter; the field cannot move flakes until it is known.
  Size size = Size.zero;

  void resize(int count) {
    if (count < flakes.length) {
      flakes.removeRange(count, flakes.length);
    } else {
      while (flakes.length < count) {
        flakes.add(_Flake(_random));
      }
    }
  }

  void advance(
    double dt, {
    required double minSpeed,
    required double maxSpeed,
    required double wind,
    required double gustiness,
    required double sway,
    required double spin,
  }) {
    if (size.isEmpty || dt <= 0) {
      notifyListeners();
      return;
    }
    _time += dt;
    for (final flake in flakes) {
      // Two overlapping waves that travel down the box, so a gust sweeps
      // through the snow rather than shoving every flake at once. Squaring
      // the slow wave leaves calm spells between gusts.
      final slow = math.sin(_time * 0.45 - flake.y * 2.2);
      final gust =
          gustiness *
          (slow * slow.abs() * 0.75 +
              math.sin(_time * 1.3 - flake.y * 5 + flake.x * 3) * 0.25);
      final speed = minSpeed + (maxSpeed - minSpeed) * flake.depth;
      flake.swayPhase += flake.swayRate * dt;
      // Flakes tumble faster while a gust has hold of them.
      flake.rotation += flake.spin * spin * dt * (1 + gust.abs() / 40);
      final dx =
          (wind + gust) * (0.5 + flake.depth * 0.5) +
          math.cos(flake.swayPhase) * flake.swayAmount * sway;
      flake.y += speed * dt / size.height;
      flake.x += dx * dt / size.width;

      if (flake.y > 1.05) {
        flake
          ..y = -0.05
          ..x = _random.nextDouble()
          ..depth = _randomDepth(_random);
      }
      if (flake.x > 1.05) {
        flake.x -= 1.1;
      } else if (flake.x < -0.05) {
        flake.x += 1.1;
      }
    }
    notifyListeners();
  }
}

/// A six-armed crystal of radius 1 centred on the origin: each arm is a
/// spine with two pairs of side branches.
final Path _crystalPath = () {
  final path = Path();
  void branch(double angle, double at, double length) {
    final base = Offset(math.sin(angle), -math.cos(angle)) * at;
    for (final side in const [-1, 1]) {
      final a = angle + side * math.pi / 3;
      path
        ..moveTo(base.dx, base.dy)
        ..lineTo(
          base.dx + math.sin(a) * length,
          base.dy - math.cos(a) * length,
        );
    }
  }

  for (var arm = 0; arm < 6; arm++) {
    final angle = arm * math.pi / 3;
    path
      ..moveTo(0, 0)
      ..lineTo(math.sin(angle), -math.cos(angle));
    branch(angle, 0.42, 0.3);
    branch(angle, 0.7, 0.2);
  }
  return path;
}();

class _SnowPainter extends CustomPainter {
  _SnowPainter({
    required this.field,
    required this.colors,
    required this.shape,
    required this.crystalPath,
    required this.crystalFraction,
    required this.fadeExtent,
    required this.minSize,
    required this.maxSize,
    required this.opacity,
  }) : super(repaint: field);

  /// Below this radius a crystal's arms blur together, so draw a dot.
  static const double _crystalMinRadius = 4;

  final _SnowField field;
  final List<Color> colors;
  final SnowflakeShape shape;
  final Path crystalPath;
  final double crystalFraction;
  final double fadeExtent;
  final double minSize;
  final double maxSize;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    field.size = size;
    if (size.isEmpty) return;
    final smallDotPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
    final largeDotPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);
    final crystalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fade = math.min(fadeExtent, size.height / 2);

    for (final flake in field.flakes) {
      final radius = minSize + (maxSize - minSize) * flake.depth;
      final center = Offset(flake.x * size.width, flake.y * size.height);

      final color =
          colors[math.min(
            (flake.tint * colors.length).floor(),
            colors.length - 1,
          )];
      var alpha = color.a * opacity * (0.4 + 0.6 * flake.depth);
      if (fade > 0) {
        final edge = math.min(center.dy, size.height - center.dy) / fade;
        if (edge <= 0) continue;
        // Smoothstep, so the fade eases at both ends of the band.
        if (edge < 1) alpha *= edge * edge * (3 - 2 * edge);
      }
      final flakeColor = color.withValues(alpha: alpha);

      final isCrystal =
          shape == SnowflakeShape.crystal &&
          radius >= _crystalMinRadius &&
          flake.variety < crystalFraction;
      if (!isCrystal) {
        final large = radius >= _crystalMinRadius;
        canvas.drawCircle(
          center,
          radius * 0.6,
          (large ? largeDotPaint : smallDotPaint)..color = flakeColor,
        );
        continue;
      }
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(flake.rotation)
        ..scale(radius);
      // The canvas is scaled, so divide to keep a constant on-screen width.
      crystalPaint
        ..color = flakeColor
        ..strokeWidth = (0.9 + radius * 0.06) / radius;
      canvas
        ..drawPath(crystalPath, crystalPaint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_SnowPainter oldDelegate) =>
      oldDelegate.field != field ||
      !listEquals(oldDelegate.colors, colors) ||
      oldDelegate.crystalPath != crystalPath ||
      oldDelegate.shape != shape ||
      oldDelegate.crystalFraction != crystalFraction ||
      oldDelegate.fadeExtent != fadeExtent ||
      oldDelegate.minSize != minSize ||
      oldDelegate.maxSize != maxSize ||
      oldDelegate.opacity != opacity;
}
