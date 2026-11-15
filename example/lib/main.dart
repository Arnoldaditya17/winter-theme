import 'package:material_ui/material_ui.dart';
import 'package:winter_theme/winter_theme.dart';

void main() => runApp(const WinterThemeExampleApp());

class WinterThemeExampleApp extends StatelessWidget {
  const WinterThemeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'winter_theme',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7FB8E6),
          brightness: Brightness.dark,
        ),
      ),
      home: const SnowTestScreen(),
    );
  }
}

const _background = Color(0xFF0B1626);

const _palettes = <String, List<Color>>{
  'Snow': [Color(0xFFFFFFFF)],
  'Ice': [Color(0xFFFFFFFF), Color(0xFFBFE3FF), Color(0xFF8FC7FF)],
  'Festive': [
    Color(0xFFFFFFFF),
    Color(0xFFFF6B6B),
    Color(0xFFFFD166),
    Color(0xFF7BD389),
  ],
  'Sakura': [Color(0xFFFFFFFF), Color(0xFFFFE3EE), Color(0xFFFFB3D1)],
};

enum _Area { full, top, bottom }

/// Test screen for the [Snowfall] widget: full-screen snow with live
/// controls for every option, plus a second snowfall confined to one card.
class SnowTestScreen extends StatefulWidget {
  const SnowTestScreen({super.key});

  @override
  State<SnowTestScreen> createState() => _SnowTestScreenState();
}

class _SnowTestScreenState extends State<SnowTestScreen> {
  bool _showControls = true;
  bool _enabled = true;
  bool _behind = false;
  String _palette = 'Snow';
  _Area _area = _Area.full;
  double _flakes = 150;
  double _crystals = 0.35;
  double _size = 10;
  double _speed = 70;
  double _wind = 0;
  double _gusts = 45;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: _background,
      child: Snowfall(
        enabled: _enabled,
        layer: _behind ? SnowfallLayer.background : SnowfallLayer.foreground,
        colors: _palettes[_palette],
        numberOfSnowflakes: _flakes.round(),
        crystalFraction: _crystals,
        maxSize: _size,
        minSpeed: _speed * 0.4,
        maxSpeed: _speed,
        wind: _wind,
        gustiness: _gusts,
        heightFactor: _area == _Area.full ? 1 : 0.5,
        alignment: _area == _Area.bottom
            ? Alignment.bottomCenter
            : Alignment.topCenter,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Snowfall test'),
            backgroundColor: Colors.transparent,
            actions: [
              IconButton(
                tooltip: _showControls ? 'Hide controls' : 'Show controls',
                icon: Icon(_showControls ? Icons.tune : Icons.tune_outlined),
                onPressed: () => setState(() => _showControls = !_showControls),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _HeroCard(),
                const SizedBox(height: 16),
                if (_showControls)
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Full-screen snow'),
                          subtitle: const Text(
                            'Snowfall wraps the whole screen',
                          ),
                          value: _enabled,
                          onChanged: (value) =>
                              setState(() => _enabled = value),
                        ),
                        SwitchListTile(
                          title: const Text('Snow behind content'),
                          subtitle: const Text('Falls behind the cards'),
                          value: _behind,
                          onChanged: (value) => setState(() => _behind = value),
                        ),
                        _Labeled(
                          label: 'Colours',
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (final name in _palettes.keys)
                                ChoiceChip(
                                  label: Text(name),
                                  selected: _palette == name,
                                  onSelected: (_) =>
                                      setState(() => _palette = name),
                                ),
                            ],
                          ),
                        ),
                        _Labeled(
                          label: 'Position',
                          child: SegmentedButton<_Area>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: _Area.full,
                                label: Text('Full'),
                              ),
                              ButtonSegment(
                                value: _Area.top,
                                label: Text('Top half'),
                              ),
                              ButtonSegment(
                                value: _Area.bottom,
                                label: Text('Bottom half'),
                              ),
                            ],
                            selected: {_area},
                            onSelectionChanged: (value) =>
                                setState(() => _area = value.first),
                          ),
                        ),
                        _LabeledSlider(
                          label: 'Snowflakes',
                          valueLabel: '${_flakes.round()}',
                          value: _flakes,
                          min: 0,
                          max: 500,
                          onChanged: (value) => setState(() => _flakes = value),
                        ),
                        _LabeledSlider(
                          label: 'Crystals',
                          valueLabel: '${(_crystals * 100).round()}%',
                          value: _crystals,
                          min: 0,
                          max: 1,
                          onChanged: (value) =>
                              setState(() => _crystals = value),
                        ),
                        _LabeledSlider(
                          label: 'Largest flake',
                          valueLabel: '${_size.round()} px',
                          value: _size,
                          min: 3,
                          max: 24,
                          onChanged: (value) => setState(() => _size = value),
                        ),
                        _LabeledSlider(
                          label: 'Speed',
                          valueLabel: '${_speed.round()} px/s',
                          value: _speed,
                          min: 10,
                          max: 300,
                          onChanged: (value) => setState(() => _speed = value),
                        ),
                        _LabeledSlider(
                          label: 'Wind',
                          valueLabel: '${_wind.round()} px/s',
                          value: _wind,
                          min: -150,
                          max: 150,
                          onChanged: (value) => setState(() => _wind = value),
                        ),
                        _LabeledSlider(
                          label: 'Gusts',
                          valueLabel: '${_gusts.round()} px/s',
                          value: _gusts,
                          min: 0,
                          max: 200,
                          onChanged: (value) => setState(() => _gusts = value),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Snow in one card only',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  color: const Color(0xFF1C3A5E),
                  child: Snowfall(
                    numberOfSnowflakes: 60,
                    maxSize: 8,
                    child: SizedBox(
                      height: 180,
                      child: Center(
                        child: FilledButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                                const SnackBar(
                                  content: Text('Taps pass through the snow'),
                                ),
                              ),
                          icon: const Icon(Icons.ac_unit),
                          label: const Text('Tap me through the snow'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A night-sky banner with its own, denser snowfall.
class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Snowfall(
        numberOfSnowflakes: 70,
        maxSize: 12,
        crystalFraction: 0.5,
        colors: const [Color(0xFFFFFFFF), Color(0xFFCFE8FF)],
        child: Container(
          height: 190,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF14315A), Color(0xFF2B5C8F), Color(0xFF6FA3CF)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Let it snow',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'winter_theme',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(label), const SizedBox(height: 8), child],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(valueLabel)],
          ),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}
