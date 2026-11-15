## 1.0.1

* Much faster rendering: every flake is drawn from a cached sprite sheet in a
  single `drawRawAtlas` call, instead of one draw (and a blur filter) per
  flake. Smoother on low-end devices, with no per-frame allocations.
* Sprites are rendered at the screen's pixel density so crystals stay crisp.
* The example app shows the `Snowfall(...)` code for the current settings,
  with a copy button.

## 1.0.0

* Initial release.
* `Snowfall` widget: wrap any widget to make it snow over (or behind) it.
* Ice crystals mixed with soft round flakes, with a configurable mix.
* Steady wind plus rolling gusts.
* Flakes fade in and out at the top and bottom edges.
* Custom colors and palettes, custom flake outlines, size, speed, sway and
  spin controls.
* Position controls: padding, alignment, width and height factors, and a
  foreground or background layer.
