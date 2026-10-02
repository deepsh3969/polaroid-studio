import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Vintage filters available in the editor.
enum FilterType {
  original,
  vintage,
  warm,
  faded,
  classic,
  blackWhite,
  sepia,
  polaroid,
  cool,
}

extension FilterTypeX on FilterType {
  String get label => switch (this) {
    FilterType.original => 'Original',
    FilterType.vintage => 'Vintage',
    FilterType.warm => 'Warm',
    FilterType.faded => 'Faded',
    FilterType.classic => 'Classic',
    FilterType.blackWhite => 'Black & White',
    FilterType.sepia => 'Sepia',
    FilterType.polaroid => 'Polaroid',
    FilterType.cool => 'Cool',
  };

  /// Filter parameters used to build the colour matrix.
  FilterParams get params => FilterParams.forType(this);
}

/// Tone parameters of a filter.
///
/// Filters are applied through a colour matrix in the widget tree, so the
/// original photo file is never modified and the exact same look is captured
/// when the composition is exported.
@immutable
class FilterParams {
  const FilterParams({
    this.saturation = 1,
    this.brightness = 0,
    this.contrast = 1,
    this.temperature = 0,
    this.fade = 0,
    this.sepia = 0,
    this.vignette = 0,
  });

  /// Neutral parameters (identical to [FilterType.original]).
  static const FilterParams none = FilterParams();

  /// Colour saturation, `0` is greyscale.
  final double saturation;

  /// Additive brightness, `-0.5 .. 0.5`.
  final double brightness;

  /// Contrast around mid grey, `0.5 .. 1.6`.
  final double contrast;

  /// Warmth, `-1` cool .. `1` warm.
  final double temperature;

  /// Lifted blacks / washed out look, `0 .. 0.5`.
  final double fade;

  /// Blend towards the classic sepia tone, `0 .. 1`.
  final double sepia;

  /// Corner darkening strength, `0 .. 0.6`.
  final double vignette;

  static FilterParams forType(FilterType type) => switch (type) {
    FilterType.original => none,
    FilterType.vintage => const FilterParams(
      saturation: 0.82,
      contrast: 1.08,
      temperature: 0.35,
      fade: 0.1,
      vignette: 0.34,
    ),
    FilterType.warm => const FilterParams(
      saturation: 1.06,
      brightness: 0.03,
      temperature: 0.6,
      vignette: 0.1,
    ),
    FilterType.faded => const FilterParams(
      saturation: 0.74,
      contrast: 0.9,
      fade: 0.26,
      vignette: 0.12,
    ),
    FilterType.classic => const FilterParams(
      saturation: 0.9,
      contrast: 1.18,
      brightness: -0.02,
      vignette: 0.3,
    ),
    FilterType.blackWhite => const FilterParams(
      saturation: 0,
      contrast: 1.12,
      vignette: 0.18,
    ),
    FilterType.sepia => const FilterParams(
      sepia: 1,
      contrast: 1.05,
      fade: 0.08,
      vignette: 0.2,
    ),
    FilterType.polaroid => const FilterParams(
      saturation: 1.08,
      contrast: 1.04,
      brightness: 0.05,
      temperature: 0.18,
      fade: 0.14,
      vignette: 0.16,
    ),
    FilterType.cool => const FilterParams(
      saturation: 0.96,
      brightness: 0.01,
      temperature: -0.55,
      vignette: 0.1,
    ),
  };

  bool get isNeutral =>
      saturation == 1 &&
      brightness == 0 &&
      contrast == 1 &&
      temperature == 0 &&
      fade == 0 &&
      sepia == 0 &&
      vignette == 0;

  /// Linear interpolation used to animate filter changes smoothly.
  FilterParams lerp(FilterParams other, double t) => FilterParams(
    saturation: _mix(saturation, other.saturation, t),
    brightness: _mix(brightness, other.brightness, t),
    contrast: _mix(contrast, other.contrast, t),
    temperature: _mix(temperature, other.temperature, t),
    fade: _mix(fade, other.fade, t),
    sepia: _mix(sepia, other.sepia, t),
    vignette: _mix(vignette, other.vignette, t),
  );

  static double _mix(double a, double b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return a + (b - a) * t;
  }

  @override
  bool operator ==(Object other) =>
      other is FilterParams &&
      other.saturation == saturation &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.temperature == temperature &&
      other.fade == fade &&
      other.sepia == sepia &&
      other.vignette == vignette;

  @override
  int get hashCode => Object.hash(
    saturation,
    brightness,
    contrast,
    temperature,
    fade,
    sepia,
    vignette,
  );
}

/// Tween so filters can cross fade with a standard `TweenAnimationBuilder`.
class FilterParamsTween extends Tween<FilterParams> {
  FilterParamsTween({super.begin, super.end});

  @override
  FilterParams lerp(double t) => begin!.lerp(end!, t);
}
