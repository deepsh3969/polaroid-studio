import '../models/filter_model.dart';

/// Builds the colour matrices used by the vintage filters.
///
/// Filters are pure functions of [FilterParams] and are applied with a
/// `ColorFilter` while painting, so:
///   * the source photo file is never modified,
///   * the very same transform is rasterised when the Polaroid is exported.
class FilterService {
  const FilterService._();

  /// Identity matrix (4x5, row major) accepted by `ColorFilter.matrix`.
  static const List<double> identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  /// Matrix for a named filter preset.
  static List<double> matrixFor(FilterType type) =>
      matrixForParams(type.params);

  /// Matrix for arbitrary [params].
  ///
  /// All matrices produced here keep an identity alpha row/column, which lets
  /// composition stay a simple RGB affine combination.
  static List<double> matrixForParams(FilterParams params) {
    if (params.isNeutral) return List<double>.from(identity);

    List<double> matrix = List<double>.from(identity);
    if (params.sepia > 0) {
      matrix = _compose(_sepia(params.sepia), matrix);
    }
    if (params.saturation != 1) {
      matrix = _compose(_saturation(params.saturation), matrix);
    }
    if (params.temperature != 0) {
      matrix = _compose(_temperature(params.temperature), matrix);
    }
    if (params.contrast != 1 || params.brightness != 0) {
      matrix = _compose(
        _contrastBrightness(params.contrast, params.brightness),
        matrix,
      );
    }
    if (params.fade > 0) {
      matrix = _compose(_fade(params.fade), matrix);
    }
    return matrix;
  }

  /// True when [matrix] is (numerically) the identity.
  static bool isIdentity(List<double> matrix) {
    if (matrix.length != identity.length) return false;
    for (var i = 0; i < identity.length; i++) {
      if ((matrix[i] - identity[i]).abs() > 0.0001) return false;
    }
    return true;
  }

  /// Applies [after] on top of [before] (`after(before(color))`).
  static List<double> _compose(List<double> after, List<double> before) {
    final result = List<double>.filled(20, 0);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        var sum = 0.0;
        for (var k = 0; k < 3; k++) {
          sum += after[row * 5 + k] * before[k * 5 + col];
        }
        result[row * 5 + col] = sum;
      }
      // Offset: translation of `before` pushed through `after`, then added.
      var offset = after[row * 5 + 4];
      for (var k = 0; k < 3; k++) {
        offset += after[row * 5 + k] * before[k * 5 + 4];
      }
      result[row * 5 + 4] = offset;
    }
    result[15] = 0;
    result[16] = 0;
    result[17] = 0;
    result[18] = 1;
    result[19] = 0;
    return result;
  }

  /// Luma weighted saturation, `0` produces true greyscale.
  static List<double> _saturation(double s) {
    const lr = 0.2126;
    const lg = 0.7152;
    const lb = 0.0722;
    return <double>[
      lr + (1 - lr) * s, lg - lg * s, lb - lb * s, 0, 0, //
      lr - lr * s, lg + (1 - lg) * s, lb - lb * s, 0, 0, //
      lr - lr * s, lg - lg * s, lb + (1 - lb) * s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

  /// Warm / cool white balance.
  static List<double> _temperature(double t) => <double>[
    1 + 0.18 * t, 0, 0, 0, 0, //
    0, 1 + 0.02 * t, 0, 0, 0, //
    0, 0, 1 - 0.18 * t, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  /// Contrast around mid grey plus additive brightness.
  static List<double> _contrastBrightness(double contrast, double brightness) {
    final pivot = 0.5 - 0.5 * contrast + brightness;
    return <double>[
      contrast, 0, 0, 0, pivot, //
      0, contrast, 0, 0, pivot, //
      0, 0, contrast, 0, pivot, //
      0, 0, 0, 1, 0,
    ];
  }

  /// Washed out print: compressed range with lifted blacks.
  static List<double> _fade(double f) {
    final scale = 1 - 0.45 * f;
    final lift = 0.24 * f;
    return <double>[
      scale, 0, 0, 0, lift, //
      0, scale, 0, 0, lift, //
      0, 0, scale, 0, lift, //
      0, 0, 0, 1, 0,
    ];
  }

  /// Classic sepia tone, blended towards identity by [amount].
  static List<double> _sepia(double amount) => <double>[
    1 + (0.393 - 1) * amount, 0.769 * amount, 0.189 * amount, 0, 0, //
    0.349 * amount, 1 + (0.686 - 1) * amount, 0.168 * amount, 0, 0, //
    0.272 * amount, 0.534 * amount, 1 + (0.131 - 1) * amount, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}
