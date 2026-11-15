# winter_theme

A fully customizable snowfall effect for Flutter. Wrap any widget in
`Snowfall` and it snows inside that widget's box: a whole screen, a single
card, an app bar, or the entire app. Taps pass straight through the snow.

<p>
  <img src="https://raw.githubusercontent.com/Arnoldaditya17/winter-theme/main/screenshots/snowfall.gif" width="260" alt="Snowfall with ice crystals and wind gusts">
  <img src="https://raw.githubusercontent.com/Arnoldaditya17/winter-theme/main/screenshots/snowfall.png" width="260" alt="Full-screen snow with live controls">
  <img src="https://raw.githubusercontent.com/Arnoldaditya17/winter-theme/main/screenshots/festive.png" width="260" alt="Festive color palette">
</p>

## Features

- Six-armed ice crystals that spin as they fall, mixed with soft round flakes
- Steady wind plus gusts that roll through the snow in waves
- Flakes fade in at the top and out at the bottom instead of popping
- Custom colors, color palettes, and your own flake outline
- Snow in front of or behind your content
- Snow over any region: padding, alignment, and width and height factors
- One `CustomPainter` and one ticker, with no per-frame rebuilds
- No dependencies beyond Flutter

## Install

```yaml
dependencies:
  winter_theme: ^1.0.0
```

## Usage

```dart
import 'package:winter_theme/winter_theme.dart';

// Over one screen, card, app bar, or any other widget:
Snowfall(child: MyScreen())

// Over the whole app:
MaterialApp(
  builder: (context, child) => Snowfall(child: child!),
  home: const HomeScreen(),
)
```

### Colors

```dart
Snowfall(
  colors: const [Colors.white, Color(0xFFBFE3FF), Color(0xFF8FC7FF)],
  child: child,
)
```

### Position

```dart
// Only in the top third, and behind the content:
Snowfall(
  layer: SnowfallLayer.background,
  alignment: Alignment.topCenter,
  heightFactor: 1 / 3,
  child: child,
)
```

With `SnowfallLayer.background` the snow shows only through the transparent
parts of the child, so give the child a transparent background.

### Motion

```dart
Snowfall(
  numberOfSnowflakes: 250,
  minSpeed: 60,
  maxSpeed: 180,
  wind: 40, // steady drift to the right
  gustiness: 120, // strong gusts
  child: child,
)
```

### Custom shapes

Draw your own outline for a flake of radius 1 centered on the origin. It is
scaled, rotated and stroked for each flake.

```dart
Snowfall(
  crystalFraction: 1,
  crystalPath: Path()
    ..moveTo(0, -1)
    ..lineTo(0.6, 0.8)
    ..lineTo(-0.95, -0.3)
    ..lineTo(0.95, -0.3)
    ..lineTo(-0.6, 0.8)
    ..close(), // a star
  child: child,
)
```

## Options

| Parameter | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Turns the snow on or off. Off schedules no frames. |
| `numberOfSnowflakes` | `120` | Flakes on screen at once. |
| `color` | white | Color of every flake. Ignored when `colors` is set. |
| `colors` | `null` | Palette each flake picks its color from at random. |
| `shape` | `crystal` | `SnowflakeShape.crystal` mixes ice crystals with round flakes; `dot` draws only round flakes. |
| `crystalFraction` | `0.35` | Share of the larger flakes drawn as crystals. |
| `crystalPath` | `null` | Custom outline drawn instead of the built-in crystal. |
| `minSize` / `maxSize` | `1.5` / `10` | Flake radius range in logical pixels. |
| `minSpeed` / `maxSpeed` | `30` / `90` | Fall speed range in pixels per second. |
| `wind` | `0` | Steady horizontal drift in pixels per second; negative blows left. |
| `gustiness` | `45` | Strength of the gusts in pixels per second; `0` is still air. |
| `sway` | `1` | Multiplier for the side-to-side swing; `0` falls straight. |
| `spin` | `1` | Multiplier for crystal rotation; `0` stops it. |
| `opacity` | `0.9` | Opacity of the nearest flakes. |
| `fadeExtent` | `56` | Height of the top and bottom bands where flakes fade in and out; `0` gives hard edges. |
| `layer` | `foreground` | `SnowfallLayer.foreground` or `background`. |
| `padding` | zero | Insets the snowing area from the child's edges. |
| `alignment` | center | Where the snowing area sits when it is smaller than the child. |
| `widthFactor` / `heightFactor` | `1` / `1` | Size of the snowing area as a fraction of the child. |
| `seed` | `null` | Fixes the random layout, for golden tests and screenshots. |

## Example

The app in [`example/`](example) is a playground with live controls for
these options. As you change them it shows the matching `Snowfall(...)` code
with a copy button, so you can tune the snow by eye and paste the result into
your app. The tune button in its app bar hides the controls.

The controls exist only in the example. The package itself draws nothing but
snow, so your users never see them.

## License

Apache 2.0. See [LICENSE](LICENSE).
