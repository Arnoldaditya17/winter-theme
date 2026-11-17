import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Draws snow that settles on the top edge of [child], the way real snow does.
///
/// The edge starts bare. Random patches form, grow and join into one heap
/// over about [settleTime]. Once the corners fill up, pieces break off, tip
/// over the corner and fall down the sides, and the broken spots fill in
/// again.
///
/// ```dart
/// SnowCap(
///   borderRadius: BorderRadius.circular(16),
///   child: Card(child: MyContent()),
/// )
/// ```
///
/// To get "snow falls, then settles", put a [Snowfall] over a header and a
/// [SnowCap] on the card below it.
///
/// **Clipping.** The snow is drawn above and beside [child], outside its
/// box, so a clipping ancestor (a `ClipRRect`, a `Card` with a clip, a
/// `ListView`'s viewport edge, ...) cuts it off. Wrap the outermost widget
/// that shares the top edge, and make sure nothing above it clips.
///
/// The snow never takes pointer events and [child] lays out exactly as it
/// would without [SnowCap].
///
/// Screens that rebuild often, and golden tests, should set [startSettled] so
/// the heap is full on the first frame. Set [seed] to make the heap, the
/// flakes and the breaks repeat exactly.
///
/// Beyond the built-in look you can pass a [texture] image (any
/// [ImageProvider], including a `NetworkImage`, which Flutter caches in its
/// image cache), draw your own decoration with [backgroundPainter] and
/// [foregroundPainter], or place any widget, for example a Lottie animation,
/// over the child with [overlay].
class SnowCap extends StatefulWidget {
  /// Creates snow that settles on top of [child].
  const SnowCap({
    super.key,
    required this.child,
    this.enabled = true,
    this.thickness = 12,
    this.overlap = 2,
    this.borderRadius = BorderRadius.zero,
    this.settleTime = const Duration(seconds: 30),
    this.startSettled = false,
    this.accumulating = true,
    this.shedding = true,
    this.chunkSize = 24,
    this.shedRate = 1.0,
    this.fallSpeed = 1.0,
    this.fallDistance,
    this.color = const Color(0xFFFFFFFF),
    this.shadeColor = const Color(0xFFD5E2EE),
    this.seed,
    this.texture,
    this.backgroundPainter,
    this.foregroundPainter,
    this.overlay,
  }) : assert(thickness > 0),
       assert(overlap >= 0),
       assert(chunkSize > 0),
       assert(shedRate >= 0),
       assert(fallSpeed > 0),
       assert(fallDistance == null || fallDistance > 0);

  /// The widget the snow settles on.
  final Widget child;

  /// Whether the snow is shown. When false only [child] is rendered and no
  /// frames are scheduled. The heap is kept, so turning it back on carries on.
  final bool enabled;

  /// Height of the heap above the edge when it is full, in logical pixels.
  /// The actual height varies gently along the edge and is thinner over the
  /// rounded corners.
  final double thickness;

  /// How far the snow lips over the front edge of [child], in logical pixels.
  /// The lip is uneven and grows with the amount of snow.
  final double overlap;

  /// The corner radii of [child]. Only the top corners are used. With
  /// [BorderRadius.zero] the snow falls to zero just before the corners, so
  /// nothing drapes over them.
  final BorderRadius borderRadius;

  /// How long a bare edge takes to build up into one full heap. Must be
  /// longer than zero.
  final Duration settleTime;

  /// When true the heap is full on the first frame and the build-up is
  /// skipped. Use it for screens that rebuild often and for golden tests.
  final bool startSettled;

  /// When false no new flakes land, so the heap stays as it is.
  final bool accumulating;

  /// When false the corners never break off and nothing trickles.
  final bool shedding;

  /// The typical length of a broken piece, in logical pixels. Nothing is
  /// drawn if the child is narrower than four chunk sizes.
  final double chunkSize;

  /// Multiplier on how often breaks and trickles happen. `0` stops them.
  final double shedRate;

  /// Multiplier on how fast pieces tip and fall.
  final double fallSpeed;

  /// How far a piece falls before it fades out. When null this is the full
  /// height of [child].
  final double? fallDistance;

  /// The colour of the snow's top surface.
  final Color color;

  /// The tone of the base and underside of the snow.
  final Color shadeColor;

  /// Fixes the shape of the heap and where patches form. When set it also
  /// fixes how flakes land and the sequence of breaks, so golden and widget
  /// tests repeat exactly. When null every instance is different.
  final int? seed;

  /// An image used to fill the snow instead of the plain gradient, for
  /// example a soft snow texture. It is tiled at its natural size. Any
  /// [ImageProvider] works, so a `NetworkImage` (or a caching provider from a
  /// package) is loaded once and cached. The snow shows its normal gradient
  /// until the image arrives, and keeps it if the image fails to load.
  final ImageProvider? texture;

  /// Painted over [child] but under the snow. It gets the child's size and
  /// its origin is the child's top-left corner, so it can draw above the edge
  /// at negative coordinates. Repaints whenever its own `repaint` fires.
  final CustomPainter? backgroundPainter;

  /// Painted over the snow, in the same coordinate space as
  /// [backgroundPainter]. Use it for sparkle, frost or icicles.
  final CustomPainter? foregroundPainter;

  /// A widget laid out over the child's box, above the snow. It ignores
  /// pointer events and may overflow the box. Use it to add, for example, a
  /// Lottie animation:
  ///
  /// ```dart
  /// SnowCap(
  ///   overlay: Align(
  ///     alignment: Alignment.topCenter,
  ///     child: FractionalTranslation(
  ///       translation: const Offset(0, -0.8),
  ///       child: Lottie.asset('assets/sparkle.json', width: 80),
  ///     ),
  ///   ),
  ///   child: card,
  /// )
  /// ```
  final Widget? overlay;

  @override
  State<SnowCap> createState() => SnowCapState();
}

/// The state of a [SnowCap]. Public only so tests can inspect the heap; do
/// not use it in app code.
@visibleForTesting
class SnowCapState extends State<SnowCap> with SingleTickerProviderStateMixin {
  final _SnowCapSim _sim = _SnowCapSim();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _reduced = false;

  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _imageInfo;

  /// A copy of the current heap heights, one per sample.
  @visibleForTesting
  List<double> get debugHeights => List<double>.of(_sim.heights);

  /// The cap (maximum height) of every sample.
  @visibleForTesting
  List<double> get debugCaps => List<double>.of(_sim.cap);

  /// The number of separate patches currently drawn.
  @visibleForTesting
  int get debugPatchCount => _sim.patchCount();

  /// The number of pieces that have broken off so far.
  @visibleForTesting
  int get debugBreakCount => _sim.breakCount;

  /// The number of pieces currently falling.
  @visibleForTesting
  int get debugPieceCount => _sim.pieces.length;

  /// The snow height divided by the cap, over the whole edge, from 0 to 1.
  @visibleForTesting
  double get debugFill => _sim.totalFill();

  /// The distance between samples, in logical pixels.
  @visibleForTesting
  double get debugStep => _SnowCapSim.step;

  /// Whether the ticker is currently running.
  @visibleForTesting
  bool get debugTickerActive => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    assert(widget.settleTime > Duration.zero, 'settleTime must be positive');
    // Created once. Never create another ticker: that is what throws
    // "multiple tickers were created" after a hot reload.
    _ticker = createTicker(_onTick);
    _sim.reseed(widget.seed);
    _sim.configure(widget);
    _sim.initSettled = widget.startSettled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced != _reduced) {
      _reduced = reduced;
      if (reduced) _sim.settle();
    }
    _sim.initSettled = widget.startSettled || _reduced;
    _resolveTexture();
    _syncTicker();
  }

  @override
  void didUpdateWidget(SnowCap oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(widget.settleTime > Duration.zero, 'settleTime must be positive');
    final seedChanged = widget.seed != oldWidget.seed;
    final terrainChanged =
        seedChanged ||
        widget.thickness != oldWidget.thickness ||
        widget.borderRadius != oldWidget.borderRadius;
    if (seedChanged) _sim.reseed(widget.seed);
    _sim.configure(widget);
    if (terrainChanged) {
      _sim.rebuildTerrain();
      if (_reduced) _sim.settle();
    }
    if (widget.texture != oldWidget.texture) _resolveTexture();
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopListening();
    _imageInfo?.dispose();
    _imageInfo = null;
    _sim.dispose();
    super.dispose();
  }

  bool get _shouldRun =>
      widget.enabled &&
      !_reduced &&
      (widget.accumulating || widget.shedding || _sim.airborne);

  void _syncTicker() {
    final run = _shouldRun;
    if (run && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _sim.update(dt.toDouble());
    if (!_shouldRun) _ticker.stop();
  }

  void _resolveTexture() {
    final provider = widget.texture;
    if (provider == null) {
      _stopListening();
      _stream = null;
      _imageInfo?.dispose();
      _imageInfo = null;
      _sim.setTexture(null, 1);
      return;
    }
    final stream = provider.resolve(createLocalImageConfiguration(context));
    if (_stream != null && stream.key == _stream!.key) return;
    _stopListening();
    _stream = stream;
    _listener ??= ImageStreamListener(_onImage, onError: (_, _) {});
    stream.addListener(_listener!);
  }

  void _stopListening() {
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
  }

  void _onImage(ImageInfo info, bool synchronousCall) {
    final old = _imageInfo;
    _imageInfo = info;
    _sim.setTexture(
      info.image,
      createLocalImageConfiguration(context).devicePixelRatio ?? 1,
    );
    old?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        w.child,
        if (w.enabled) ...[
          if (w.backgroundPainter != null)
            Positioned.fill(
              key: const ValueKey('background'),
              child: IgnorePointer(
                child: CustomPaint(painter: w.backgroundPainter),
              ),
            ),
          Positioned.fill(
            key: const ValueKey('snow'),
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _SnowCapPainter(_sim)),
              ),
            ),
          ),
          if (w.foregroundPainter != null)
            Positioned.fill(
              key: const ValueKey('foreground'),
              child: IgnorePointer(
                child: CustomPaint(painter: w.foregroundPainter),
              ),
            ),
          if (w.overlay != null)
            Positioned.fill(
              key: const ValueKey('overlay'),
              child: IgnorePointer(child: w.overlay),
            ),
        ],
      ],
    );
  }
}

class _SnowCapPainter extends CustomPainter {
  _SnowCapPainter(this.sim) : version = sim.version, super(repaint: sim);

  final _SnowCapSim sim;
  final int version;

  @override
  void paint(Canvas canvas, Size size) => sim.paint(canvas, size);

  @override
  bool shouldRepaint(_SnowCapPainter old) =>
      old.sim != sim || old.version != version;

  @override
  bool? hitTest(Offset position) => false;
}

// ---------------------------------------------------------------------------
// Noise
// ---------------------------------------------------------------------------

/// A hash to [0, 1) that stays exact on the web (no product exceeds 2^53).
double _hash(int i, int s) {
  var x = (i * 73856 + s * 19349) & 0xFFFFFF;
  x = ((x ^ (x >> 11)) * 40503) & 0xFFFFFF;
  x = ((x ^ (x >> 7)) * 31337) & 0xFFFFFF;
  x = ((x ^ (x >> 9)) * 52711) & 0xFFFFFF;
  return x / 0x1000000;
}

/// Smooth 1D value noise in [0, 1].
double _noise(double x, int s) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3 - 2 * f);
  final a = _hash(i, s);
  final b = _hash(i + 1, s);
  return a + (b - a) * u;
}

double _smoothstep(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

// ---------------------------------------------------------------------------
// Simulation
// ---------------------------------------------------------------------------

class _Side {
  double cooldown = 0;
  double threshold = 0.85;
  double trickle = 8;
}

class _Piece {
  _Piece({
    required this.path,
    required this.px,
    required this.py,
    required this.sign,
    required this.xLo,
    required this.xHi,
    required this.yMid,
    required this.crumbleAt,
  });

  final Path path;
  final double px;
  final double py;

  /// -1 for the left corner, 1 for the right: the outward direction.
  final int sign;
  final double xLo;
  final double xHi;
  final double yMid;
  final double crumbleAt;

  double ox = 0;
  double oy = 0;
  double angle = 0;
  double omega = 0.25;
  double spin = 0;
  double vx = 0;
  double vy = 0;
  double age = 0;
  bool released = false;
}

class _SnowCapSim extends ChangeNotifier {
  static const double step = 1.5;
  static const double bare = 0.35;
  static const double _gravity = 650;
  static const double _bumpRadius = 6;
  static const double _bumpHeight = 0.9;
  static const int _maxPieces = 4;
  static const int _maxCrumbs = 90;
  static const double _repaintEpsilon = 0.05;

  // Configuration (copied from the widget).
  double thickness = 12;
  double overlap = 2;
  double chunkSize = 24;
  double shedRate = 1;
  double fallSpeed = 1;
  double? fallDistance;
  double settleSeconds = 30;
  bool accumulating = true;
  bool shedding = true;
  Color color = const Color(0xFFFFFFFF);
  Color shade = const Color(0xFFD5E2EE);
  BorderRadius radius = BorderRadius.zero;
  bool initSettled = false;
  int version = 0;

  int _noiseSeed = 0;
  math.Random _rng = math.Random();

  // Geometry.
  double width = 0;
  double height = 0;
  int n = 0;
  Float64List heights = Float64List(0);
  Float64List cap = Float64List(0);
  Float64List _edge = Float64List(0);
  Float64List _lipNoise = Float64List(0);
  Float64List _grain = Float64List(0);
  Float64List _stickCum = Float64List(0);
  Float64List _scratch = Float64List(0);
  Float64List _painted = Float64List(0);
  Float32List _grainPoints = Float32List(0);
  final Float64List _bump = Float64List((2 * (_bumpRadius / step).ceil()) + 1);

  // Simulation state.
  double _time = 0;
  int breakCount = 0;
  final List<_Side> _sides = [_Side(), _Side()];
  final List<_Piece> pieces = [];

  // Crumbs: a fixed pool, no allocation while running.
  final Float64List _cx = Float64List(_maxCrumbs);
  final Float64List _cy = Float64List(_maxCrumbs);
  final Float64List _cvx = Float64List(_maxCrumbs);
  final Float64List _cvy = Float64List(_maxCrumbs);
  final Float64List _cr = Float64List(_maxCrumbs);
  final Float64List _cage = Float64List(_maxCrumbs);
  final Float64List _clife = Float64List(_maxCrumbs);
  final Float64List _cgs = Float64List(_maxCrumbs);
  int _liveCrumbs = 0;

  // Drawing.
  final Path _fillPath = Path();
  final Path _basePath = Path();
  final Path _topPath = Path();
  final Paint _fillPaint = Paint();
  final Paint _shadePaint = Paint();
  final Paint _basePaintP = Paint();
  final Paint _highlightPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Paint _grainPaint = Paint()
    ..strokeWidth = 1.1
    ..strokeCap = StrokeCap.round;
  final Paint _crumbPaint = Paint();
  ui.Shader? _gradient;
  ui.Shader? _shadeOverlay;
  int _shaderVersion = -1;
  ui.ImageShader? _texture;

  bool get airborne => pieces.isNotEmpty || _liveCrumbs > 0;

  _SnowCapSim() {
    final r = (_bumpRadius / step).ceil();
    for (var k = -r; k <= r; k++) {
      final d = k.abs() * step;
      _bump[k + r] = d >= _bumpRadius
          ? 0
          : 0.5 * (1 + math.cos(math.pi * d / _bumpRadius));
    }
  }

  void reseed(int? seed) {
    if (seed == null) {
      _noiseSeed = math.Random().nextInt(1 << 24);
      _rng = math.Random();
    } else {
      _noiseSeed = seed & 0xFFFFFF;
      _rng = math.Random(seed ^ 0x5bd1e995);
    }
    for (final s in _sides) {
      s.cooldown = 3 + _rng.nextDouble() * 6;
      s.threshold = 0.7 + _rng.nextDouble() * 0.27;
      s.trickle = 4 + _rng.nextDouble() * 8;
    }
    if (n > 0) rebuildTerrain();
  }

  void configure(SnowCap w) {
    thickness = w.thickness;
    overlap = w.overlap;
    chunkSize = w.chunkSize;
    shedRate = w.shedRate;
    fallSpeed = w.fallSpeed;
    fallDistance = w.fallDistance;
    settleSeconds = w.settleTime.inMicroseconds / 1e6;
    accumulating = w.accumulating;
    shedding = w.shedding;
    color = w.color;
    shade = w.shadeColor;
    radius = w.borderRadius;
    version++;
  }

  void setTexture(ui.Image? image, double dpr) {
    final old = _texture;
    _texture = image == null
        ? null
        : ui.ImageShader(
            image,
            TileMode.repeated,
            TileMode.repeated,
            Float64List.fromList([
              1 / dpr, 0, 0, 0, //
              0, 1 / dpr, 0, 0,
              0, 0, 1, 0,
              0, 0, 0, 1,
            ]),
          );
    version++;
    notifyListeners();
    old?.dispose();
  }

  @override
  void dispose() {
    _texture?.dispose();
    _texture = null;
    super.dispose();
  }

  // -- Terrain --------------------------------------------------------------

  /// Fits the heap to a new size. Existing heights are resampled onto the new
  /// grid so a resize keeps the snow instead of resetting to bare.
  void resize(double w, double h) {
    height = h;
    if (n > 0 && w == width) return;
    final oldN = n;
    final oldHeights = heights;
    final oldWidth = width;
    width = w;
    n = (w / step).ceil() + 1;
    heights = Float64List(n);
    cap = Float64List(n);
    _edge = Float64List(n);
    _lipNoise = Float64List(n);
    _grain = Float64List(n);
    _stickCum = Float64List(n);
    _scratch = Float64List(n);
    _painted = Float64List(n);
    _grainPoints = Float32List(((n + 1) ~/ 2) * 2);
    rebuildTerrain(keepHeights: true);
    if (oldN == 0) {
      if (initSettled) heights.setAll(0, cap);
    } else {
      for (var i = 0; i < n; i++) {
        final pos = (i * step / w) * (oldWidth / step);
        final a = pos.floor().clamp(0, oldN - 1);
        final b = (a + 1).clamp(0, oldN - 1);
        final f = pos - pos.floor();
        heights[i] = oldHeights[a] + (oldHeights[b] - oldHeights[a]) * f;
      }
    }
    for (var i = 0; i < n; i++) {
      heights[i] = math.min(heights[i], cap[i]);
    }
    _painted.setAll(0, heights);
  }

  /// Recomputes the cached per-sample cap, edge, lip and stickiness. Only
  /// called when the size, thickness, corner radii or seed change.
  void rebuildTerrain({bool keepHeights = false}) {
    if (n == 0) return;
    final rl = radius.topLeft;
    final rr = radius.topRight;
    final rxl = math.min(rl.x, width / 2);
    final rxr = math.min(rr.x, width / 2);
    final double ryl = rxl > 0 ? rl.y : 0.0;
    final double ryr = rxr > 0 ? rr.y : 0.0;
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      final x = math.min(i * step, width);
      final xr = width - x;
      var c =
          thickness *
          (1 +
              0.2 * (_noise(x / 70, _noiseSeed) * 2 - 1) +
              0.1 * (_noise(x / 19, _noiseSeed + 1) * 2 - 1));
      c *= _taper(x, rxl) * _taper(xr, rxr);
      cap[i] = math.max(0, c);
      _edge[i] = math.max(_edgeY(x, rxl, ryl), _edgeY(xr, rxr, ryr));
      _lipNoise[i] = _noise(x / 9, _noiseSeed + 2);
      _grain[i] = _hash(i, _noiseSeed + 3);
      final raw =
          0.65 * _noise(x / 26, _noiseSeed + 7) +
          0.35 * _noise(x / 11, _noiseSeed + 8);
      total += 0.01 + _smoothstep(0.45, 0.6, raw);
      _stickCum[i] = total;
    }
    if (!keepHeights) {
      for (var i = 0; i < n; i++) {
        heights[i] = math.min(heights[i], cap[i]);
      }
    }
    version++;
  }

  double _taper(double d, double r) {
    if (r > 0.5) {
      final t = (d / r).clamp(0.0, 1.0);
      return math.sqrt(1 - (1 - t) * (1 - t)) * (0.5 + 0.5 * t);
    }
    return _smoothstep(2, 8, d);
  }

  double _edgeY(double d, double rx, double ry) {
    if (rx <= 0.5 || d >= rx) return 0;
    final u = (rx - d) / rx;
    return ry * (1 - math.sqrt(math.max(0, 1 - u * u)));
  }

  /// Snaps the heap to full and clears anything in the air.
  void settle() {
    if (n > 0) {
      heights.setAll(0, cap);
      _painted.setAll(0, heights);
    }
    pieces.clear();
    _liveCrumbs = 0;
    for (var i = 0; i < _maxCrumbs; i++) {
      _cage[i] = 1;
      _clife[i] = 0;
    }
    notifyListeners();
  }

  // -- Queries (tests and shedding) ------------------------------------------

  int patchCount() {
    var count = 0;
    var inside = false;
    for (var i = 0; i < n; i++) {
      final on = heights[i] > bare;
      if (on && !inside) count++;
      inside = on;
    }
    return count;
  }

  double totalFill() {
    var h = 0.0;
    var c = 0.0;
    for (var i = 0; i < n; i++) {
      h += heights[i];
      c += cap[i];
    }
    return c <= 0 ? 0 : h / c;
  }

  int get _zoneSamples {
    final r = math.min(radius.topLeft.x, radius.topRight.x);
    final rMax = math.max(radius.topLeft.x, radius.topRight.x);
    final w = (math.max(r, rMax) + 0.6 * chunkSize) / step;
    return math.min(n ~/ 2, w.ceil());
  }

  double _zoneFill(int side) {
    final zn = _zoneSamples;
    final from = side == 0 ? 0 : n - zn;
    var h = 0.0;
    var c = 0.0;
    for (var i = from; i < from + zn; i++) {
      h += heights[i];
      c += cap[i];
    }
    return c <= 0 ? 0 : h / c;
  }

  /// Index of the outermost sample holding snow, or -1.
  int _outermost(int side) {
    if (side == 0) {
      for (var i = 0; i < n ~/ 2; i++) {
        if (heights[i] > bare) return i;
      }
    } else {
      for (var i = n - 1; i >= n ~/ 2; i--) {
        if (heights[i] > bare) return i;
      }
    }
    return -1;
  }

  // -- Update ----------------------------------------------------------------

  void update(double dt) {
    if (n == 0 || dt <= 0) return;
    _time += dt;
    if (accumulating) {
      _addFlakes(dt);
      _slump(dt);
    }
    if (shedding) _updateShedding(dt);
    _updatePieces(dt);
    _updateCrumbs(dt);
    if (airborne || _heapChanged()) {
      _painted.setAll(0, heights);
      notifyListeners();
    }
  }

  bool _heapChanged() {
    for (var i = 0; i < n; i++) {
      if ((heights[i] - _painted[i]).abs() > _repaintEpsilon) return true;
    }
    return false;
  }

  void _addFlakes(double dt) {
    // Average rate that fills a bare edge in about settleTime. Growth slows
    // near the cap, so aim a little faster than a straight fill.
    final v = thickness / (0.75 * settleSeconds);
    final rate = v * width / (_bumpHeight * _bumpRadius);
    final expected = rate * dt;
    var count = expected.floor();
    if (_rng.nextDouble() < expected - count) count++;
    // Stickiness fades out as the heap builds, so the rest catches up later
    // and broken stretches refill evenly.
    final uniform = 0.9 * _smoothstep(0.35, 0.95, _time / settleSeconds);
    final r = (_bumpRadius / step).ceil();
    for (var f = 0; f < count; f++) {
      final idx = _rng.nextDouble() < uniform ? _rng.nextInt(n) : _pickSticky();
      final amp = _bumpHeight * (0.7 + 0.6 * _rng.nextDouble());
      for (var k = -r; k <= r; k++) {
        final j = idx + k;
        if (j < 0 || j >= n) continue;
        final c = cap[j];
        if (c <= 0.01) continue;
        final ratio = heights[j] / c;
        final slow = ratio < 0.75 ? 1.0 : math.max(0.0, (1 - ratio) / 0.25);
        heights[j] = math.min(c, heights[j] + amp * _bump[k + r] * slow);
      }
    }
  }

  int _pickSticky() {
    final target = _rng.nextDouble() * _stickCum[n - 1];
    var lo = 0;
    var hi = n - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_stickCum[mid] < target) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _slump(double dt) {
    final k = math.min(0.35, 0.02 * dt * 60);
    for (var i = 0; i < n; i++) {
      final h = heights[i];
      final l = i > 0 ? heights[i - 1] : h;
      final r = i < n - 1 ? heights[i + 1] : h;
      _scratch[i] = math.max(0, math.min(cap[i], h + k * (l + r - 2 * h)));
    }
    final t = heights;
    heights = _scratch;
    _scratch = t;
  }

  void _updateShedding(double dt) {
    final scaled = dt * shedRate;
    for (var side = 0; side < 2; side++) {
      final s = _sides[side];
      s.cooldown -= scaled;
      s.trickle -= scaled;
      final fill = _zoneFill(side);
      if (s.cooldown <= 0 && fill >= s.threshold) {
        if (pieces.length < _maxPieces) {
          _breakOff(side);
          s.cooldown = 3 + _rng.nextDouble() * 6;
          s.threshold = 0.7 + _rng.nextDouble() * 0.27;
        }
      } else if (s.trickle <= 0) {
        if (fill >= 0.33) _trickle(side);
        s.trickle = 4 + _rng.nextDouble() * 8;
      }
    }
  }

  double _lipAt(int i, double h) =>
      overlap *
      (0.55 + 0.9 * _lipNoise[i]) *
      math.min(1.0, h / (0.6 * thickness));

  void _trickle(int side) {
    final i0 = _outermost(side);
    if (i0 < 0) return;
    final dir = side == 0 ? 1 : -1;
    final x = i0 * step;
    final y = _edge[i0] - heights[i0];
    for (var k = 0; k < 4; k++) {
      final j = i0 + dir * k;
      if (j >= 0 && j < n) heights[j] *= 0.7;
    }
    final out = side == 0 ? -1.0 : 1.0;
    final crumbs = 2 + _rng.nextInt(3);
    final life = math.sqrt(2 * _fallTotal / _gravity) + 0.2;
    for (var c = 0; c < crumbs; c++) {
      _spawnCrumb(
        x,
        y,
        out * (10 + _rng.nextDouble() * 35),
        -_rng.nextDouble() * 20,
        1.0 + _rng.nextDouble() * 1.2,
        life,
        1,
      );
    }
  }

  double get _fallTotal => fallDistance ?? math.max(1.0, height);

  void _breakOff(int side) {
    final i0 = _outermost(side);
    breakCount++;
    if (i0 < 0) return;
    final tip = _rng.nextDouble() < 0.25;
    final len = tip
        ? chunkSize * (0.2 + 0.2 * _rng.nextDouble())
        : chunkSize * (0.6 + 0.9 * _rng.nextDouble());
    final m = math.max(2, (len / step).round());
    final int a;
    final int b; // [a, b)
    if (side == 0) {
      a = i0;
      b = math.min(n ~/ 2, i0 + m);
    } else {
      b = i0 + 1;
      a = math.max(n ~/ 2, b - m);
    }
    if (b - a < 1) return;
    final out = side == 0 ? -1 : 1;
    final crackIdx = side == 0 ? b - 1 : a;
    final crackX = crackIdx * step;
    final crackY = _edge[crackIdx] - heights[crackIdx] * 0.5;

    if (tip) {
      // A small crumble off the tip: powder only.
      final life = math.sqrt(2 * _fallTotal / _gravity) + 0.2;
      final x = (side == 0 ? a : b - 1) * step;
      for (var c = 0; c < 10; c++) {
        _spawnCrumb(
          x + (_rng.nextDouble() - 0.5) * len,
          _edge[a] - heights[a],
          out * (10 + _rng.nextDouble() * 50),
          -_rng.nextDouble() * 40,
          1.0 + _rng.nextDouble() * 1.5,
          life,
          1,
        );
      }
    } else {
      pieces.add(_buildPiece(side, a, b));
    }
    _puff(crackX, crackY);
    for (var i = a; i < b; i++) {
      heights[i] = math.min(cap[i], heights[i] * _rng.nextDouble() * 0.12);
    }
  }

  _Piece _buildPiece(int side, int a, int b) {
    final inward = side == 0 ? 1 : -1;
    final first = side == 0 ? a : b - 1; // outermost
    final last = side == 0 ? b - 1 : a; // innermost (the crack)
    final path = Path();
    double bottomAt(int i) => _edge[i] + _lipAt(i, heights[i]);
    path.moveTo(first * step, bottomAt(first));
    var yMid = 0.0;
    for (var i = first; i != last + inward; i += inward) {
      path.lineTo(i * step, _edge[i] - heights[i]);
      yMid += _edge[i] - heights[i] * 0.5;
    }
    yMid /= (b - a);
    // A rough crack down the inner side.
    final topY = _edge[last] - heights[last];
    final botY = bottomAt(last);
    final cx = last * step;
    for (var j = 1; j <= 3; j++) {
      final f = j / 4;
      path.lineTo(
        cx + inward * (0.5 + _rng.nextDouble() * 2.5),
        topY + (botY - topY) * f,
      );
    }
    path.lineTo(cx, botY);
    for (var i = last; i != first - inward; i -= inward) {
      path.lineTo(i * step, bottomAt(i));
    }
    path.close();
    return _Piece(
      path: path,
      px: side == 0 ? 0 : width,
      py: side == 0
          ? (radius.topLeft.x > 0.5 ? radius.topLeft.y : 0.0)
          : (radius.topRight.x > 0.5 ? radius.topRight.y : 0.0),
      sign: side == 0 ? -1 : 1,
      xLo: math.min(a, b - 1) * step,
      xHi: math.max(a, b - 1) * step,
      yMid: yMid,
      crumbleAt: _rng.nextDouble() < 0.4 ? 0.25 + _rng.nextDouble() * 0.35 : -1,
    );
  }

  void _puff(double x, double y) {
    final count = 8 + _rng.nextInt(5);
    for (var c = 0; c < count; c++) {
      _spawnCrumb(
        x + (_rng.nextDouble() - 0.5) * 6,
        y + (_rng.nextDouble() - 0.5) * 6,
        (_rng.nextDouble() - 0.5) * 50,
        -10 - _rng.nextDouble() * 35,
        1.5 + _rng.nextDouble() * 2,
        0.5 + _rng.nextDouble() * 0.6,
        0.2,
      );
    }
  }

  void _spawnCrumb(
    double x,
    double y,
    double vx,
    double vy,
    double r,
    double life,
    double gravityScale,
  ) {
    for (var i = 0; i < _maxCrumbs; i++) {
      if (_cage[i] >= _clife[i]) {
        _cx[i] = x;
        _cy[i] = y;
        _cvx[i] = vx;
        _cvy[i] = vy;
        _cr[i] = r;
        _cage[i] = 0;
        _clife[i] = life;
        _cgs[i] = gravityScale;
        _liveCrumbs++;
        return;
      }
    }
  }

  void _updatePieces(double dt) {
    final pdt = dt * fallSpeed;
    for (var i = pieces.length - 1; i >= 0; i--) {
      final p = pieces[i];
      p.age += pdt;
      if (!p.released) {
        p.omega += 2.0 * pdt;
        p.angle += p.sign * p.omega * pdt;
        if (p.angle.abs() >= 1.1) {
          p.released = true;
          p.vx = p.sign * (55 + _rng.nextDouble() * 60);
          p.vy = -(10 + _rng.nextDouble() * 30);
          p.spin = p.sign * (p.omega * 0.6 + _rng.nextDouble() * 0.8);
        }
      } else {
        p.vy += _gravity * pdt;
        p.vx += (_rng.nextDouble() - 0.5) * 120 * pdt;
        p.ox += p.vx * pdt;
        p.oy += p.vy * pdt;
        p.angle += p.spin * pdt;
      }
      // Powder.
      if (_rng.nextDouble() < 20 * pdt) {
        final lx = p.xLo + _rng.nextDouble() * (p.xHi - p.xLo);
        final w = _world(p, lx, p.yMid);
        _spawnCrumb(
          w.dx,
          w.dy,
          (_rng.nextDouble() - 0.5) * 30,
          -_rng.nextDouble() * 15,
          0.8 + _rng.nextDouble(),
          0.5 + _rng.nextDouble() * 0.5,
          0.6,
        );
      }
      final progress = p.oy / _fallTotal;
      if (p.crumbleAt > 0 && progress >= p.crumbleAt) {
        final mid = _world(p, (p.xLo + p.xHi) / 2, p.yMid);
        for (var c = 0; c < 14; c++) {
          _spawnCrumb(
            mid.dx + (_rng.nextDouble() - 0.5) * (p.xHi - p.xLo),
            mid.dy + (_rng.nextDouble() - 0.5) * 6,
            p.vx * 0.5 + (_rng.nextDouble() - 0.5) * 90,
            p.vy * 0.5 - _rng.nextDouble() * 40,
            1.2 + _rng.nextDouble() * 2.2,
            0.6 + _rng.nextDouble() * 0.7,
            1,
          );
        }
        pieces.removeAt(i);
      } else if (progress >= 1 || p.age > 10) {
        pieces.removeAt(i);
      }
    }
  }

  Offset _world(_Piece p, double x, double y) {
    final rx = x - p.px;
    final ry = y - p.py;
    final c = math.cos(p.angle);
    final s = math.sin(p.angle);
    return Offset(p.px + p.ox + rx * c - ry * s, p.py + p.oy + rx * s + ry * c);
  }

  void _updateCrumbs(double dt) {
    if (_liveCrumbs == 0) return;
    final cdt = dt * fallSpeed;
    for (var i = 0; i < _maxCrumbs; i++) {
      if (_cage[i] >= _clife[i]) continue;
      _cage[i] += cdt;
      if (_cage[i] >= _clife[i]) {
        _liveCrumbs--;
        continue;
      }
      _cvy[i] += _gravity * _cgs[i] * cdt;
      _cx[i] += _cvx[i] * cdt;
      _cy[i] += _cvy[i] * cdt;
    }
  }

  // -- Painting --------------------------------------------------------------

  void _ensureShaders() {
    if (_shaderVersion == version && _gradient != null) return;
    _shaderVersion = version;
    final dark = Color.lerp(shade, const Color(0xFF000000), 0.1)!;
    final from = Offset(0, -thickness * 1.1);
    final to = Offset(0, overlap + 3);
    _gradient = ui.Gradient.linear(
      from,
      to,
      [color, color, shade, dark],
      [0, 0.3, 0.82, 1],
    );
    final clear = shade.withValues(alpha: 0);
    _shadeOverlay = ui.Gradient.linear(
      from,
      to,
      [
        clear,
        clear,
        shade.withValues(alpha: 0.55),
        dark.withValues(alpha: 0.7),
      ],
      [0, 0.3, 0.82, 1],
    );
    _basePaintP.color = dark.withValues(alpha: 0.3);
    _highlightPaint.color = const Color(0xFFFFFFFF).withValues(alpha: 0.8);
    _grainPaint.color = shade.withValues(alpha: 0.55);
  }

  void paint(Canvas canvas, Size size) {
    if (size.width < chunkSize * 4 || size.height <= 0) return;
    resize(size.width, size.height);
    _ensureShaders();
    _paintHeap(canvas);
    for (final p in pieces) {
      _paintPiece(canvas, p);
    }
    if (_liveCrumbs > 0) {
      for (var i = 0; i < _maxCrumbs; i++) {
        if (_cage[i] >= _clife[i]) continue;
        final t = 1 - _cage[i] / _clife[i];
        _crumbPaint.color = color.withValues(alpha: color.a * t);
        canvas.drawCircle(Offset(_cx[i], _cy[i]), _cr[i], _crumbPaint);
      }
    }
  }

  void _fillWith(Canvas canvas, Path path, double alpha) {
    _fillPaint
      ..shader = _texture ?? _gradient
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    canvas.drawPath(path, _fillPaint);
    if (_texture != null) {
      _shadePaint
        ..shader = _shadeOverlay
        ..color = Color.fromRGBO(255, 255, 255, alpha);
      canvas.drawPath(path, _shadePaint);
    }
  }

  void _paintHeap(Canvas canvas) {
    _fillPath.reset();
    _basePath.reset();
    _topPath.reset();
    var gp = 0;
    var i = 0;
    while (i < n) {
      if (heights[i] <= bare) {
        i++;
        continue;
      }
      final s = i;
      while (i < n && heights[i] > bare) {
        i++;
      }
      final s0 = math.max(0, s - 1);
      final e0 = math.min(n - 1, i); // include one tapering sample
      _fillPath.moveTo(s0 * step, _edge[s0] + _lipAt(s0, heights[s0]));
      for (var j = s0; j <= e0; j++) {
        _fillPath.lineTo(j * step, _edge[j] - heights[j]);
      }
      for (var j = e0; j >= s0; j--) {
        _fillPath.lineTo(j * step, _edge[j] + _lipAt(j, heights[j]));
      }
      _fillPath.close();

      // Darker base where the snow meets the surface.
      _basePath.moveTo(s0 * step, _edge[s0] - math.min(heights[s0], 3.0));
      for (var j = s0; j <= e0; j++) {
        _basePath.lineTo(j * step, _edge[j] - math.min(heights[j], 3.0));
      }
      for (var j = e0; j >= s0; j--) {
        _basePath.lineTo(j * step, _edge[j] + _lipAt(j, heights[j]));
      }
      _basePath.close();

      // Soft highlight just under the top surface.
      _topPath.moveTo(s * step, _edge[s] - heights[s] + 1.2);
      for (var j = s + 1; j < i; j++) {
        _topPath.lineTo(j * step, _edge[j] - heights[j] + 1.2);
      }
    }
    _fillWith(canvas, _fillPath, 1);
    canvas.drawPath(_basePath, _basePaintP);
    canvas.drawPath(_topPath, _highlightPaint);
    // Grain, fixed in x so it never shimmers as the heap builds.
    for (var j = 0; j < n; j += 2) {
      final h = heights[j];
      if (h <= 2.5) continue;
      _grainPoints[gp++] = j * step;
      _grainPoints[gp++] = _edge[j] - h * (0.15 + 0.8 * _grain[j]);
    }
    if (gp > 0) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        gp == _grainPoints.length
            ? _grainPoints
            : Float32List.sublistView(_grainPoints, 0, gp),
        _grainPaint,
      );
    }
  }

  void _paintPiece(Canvas canvas, _Piece p) {
    final progress = p.oy / _fallTotal;
    final alpha = progress < 0.7 ? 1.0 : ((1 - progress) / 0.3).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(p.px + p.ox, p.py + p.oy);
    canvas.rotate(p.angle);
    canvas.translate(-p.px, -p.py);
    _fillWith(canvas, p.path, alpha);
    canvas.restore();
  }
}
