import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:winter_theme/winter_theme.dart';

/// Demo for [SnowCap]: snow falls over the header (Snowfall), then settles on
/// the card below it (SnowCap). Toggles show `startSettled`, `accumulating`
/// and `shedding`, and a custom painter shows the extra customization hooks.
class SnowCapDemoScreen extends StatefulWidget {
  const SnowCapDemoScreen({super.key});

  @override
  State<SnowCapDemoScreen> createState() => _SnowCapDemoScreenState();
}

class _SnowCapDemoScreenState extends State<SnowCapDemoScreen> {
  bool _startSettled = false;
  bool _accumulating = true;
  bool _shedding = true;
  bool _rounded = true;
  bool _sparkle = false;
  double _settleSeconds = 30;
  int _restart = 0;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(_rounded ? 24 : 0);
    return Scaffold(
      backgroundColor: const Color(0xFF0B1626),
      appBar: AppBar(
        title: const Text('SnowCap'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Start over',
            icon: const Icon(Icons.restart_alt),
            onPressed: () => setState(() => _restart++),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Snow falls over the header...
          SizedBox(
            height: 150,
            child: Snowfall(
              numberOfSnowflakes: 70,
              child: const Center(
                child: Text(
                  'Snow falls,\nthen settles',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ...and settles on the card below it.
          SnowCap(
            key: ValueKey(_restart),
            seed: 7,
            thickness: 14,
            borderRadius: radius,
            settleTime: Duration(seconds: _settleSeconds.round()),
            startSettled: _startSettled,
            accumulating: _accumulating,
            shedding: _shedding,
            foregroundPainter: _sparkle ? const _SparklePainter() : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF2B4C7E),
                borderRadius: radius,
              ),
              child: const SizedBox(
                height: 130,
                child: Center(
                  child: Text(
                    'A card with a snowy roof',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('startSettled'),
                  subtitle: const Text('Full heap on the first frame'),
                  value: _startSettled,
                  onChanged: (v) => setState(() {
                    _startSettled = v;
                    _restart++;
                  }),
                ),
                SwitchListTile(
                  title: const Text('accumulating'),
                  subtitle: const Text('Off: no new flakes land'),
                  value: _accumulating,
                  onChanged: (v) => setState(() => _accumulating = v),
                ),
                SwitchListTile(
                  title: const Text('shedding'),
                  subtitle: const Text('Off: corners never break off'),
                  value: _shedding,
                  onChanged: (v) => setState(() => _shedding = v),
                ),
                SwitchListTile(
                  title: const Text('Rounded corners'),
                  subtitle: const Text('borderRadius: 24'),
                  value: _rounded,
                  onChanged: (v) => setState(() => _rounded = v),
                ),
                SwitchListTile(
                  title: const Text('Custom painter'),
                  subtitle: const Text('foregroundPainter draws sparkles'),
                  value: _sparkle,
                  onChanged: (v) => setState(() => _sparkle = v),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('settleTime'),
                      Text('${_settleSeconds.round()} s'),
                    ],
                  ),
                ),
                Slider(
                  value: _settleSeconds,
                  min: 5,
                  max: 60,
                  onChanged: (v) => setState(() => _settleSeconds = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A few glints along the top edge, as an example of `foregroundPainter`.
class _SparklePainter extends CustomPainter {
  const _SparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final rng = math.Random(5);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (0.1 + 0.8 * rng.nextDouble());
      final y = -4 - rng.nextDouble() * 6;
      final r = 2.5 + rng.nextDouble() * 2.5;
      canvas.drawLine(Offset(x - r, y), Offset(x + r, y), paint);
      canvas.drawLine(Offset(x, y - r), Offset(x, y + r), paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}
