import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/models/filter_model.dart';
import 'package:polaroid_studio/services/filter_service.dart';

/// Multiplies the 4x5 colour matrix with `[r, g, b, 1]`.
List<double> _apply(List<double> matrix, double r, double g, double b) {
  final input = <double>[r, g, b, 1];
  final output = <double>[];
  for (var row = 0; row < 4; row++) {
    var value = matrix[row * 5 + 4];
    for (var col = 0; col < 4; col++) {
      value += matrix[row * 5 + col] * input[col];
    }
    output.add(value);
  }
  return output;
}

void main() {
  group('FilterParams', () {
    test('the original filter is neutral', () {
      expect(FilterParams.none.isNeutral, isTrue);
      expect(FilterType.original.params.isNeutral, isTrue);
      expect(FilterType.original.params, FilterParams.none);
    });

    test('every preset describes a real look', () {
      for (final type in FilterType.values) {
        expect(type.label, isNotEmpty);
        expect(type.params.hashCode, type.params.hashCode);
      }

      expect(FilterType.blackWhite.params.saturation, 0);
      expect(FilterType.sepia.params.sepia, 1);
      expect(FilterType.cool.params.temperature, lessThan(0));
      expect(FilterType.warm.params.temperature, greaterThan(0));
      expect(FilterType.vintage.params.vignette, greaterThan(0));
    });

    test('lerp returns the endpoints at 0 and 1', () {
      const a = FilterParams(saturation: 0.2, contrast: 1.5, fade: 0.4);
      const b = FilterParams(saturation: 1.4, contrast: 0.8, fade: 0);

      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);

      final middle = a.lerp(b, 0.5);
      expect(middle.saturation, closeTo(0.8, 1e-9));
      expect(middle.contrast, closeTo(1.15, 1e-9));
      expect(middle.fade, closeTo(0.2, 1e-9));
    });

    test('equality covers every parameter', () {
      const params = FilterParams(saturation: 0.5);
      expect(params, const FilterParams(saturation: 0.5));
      expect(params, isNot(const FilterParams(saturation: 0.6)));
      expect(params.hashCode, const FilterParams(saturation: 0.5).hashCode);
    });
  });

  group('FilterService', () {
    test('produces 4x5 matrices with an untouched alpha row', () {
      for (final type in FilterType.values) {
        final matrix = FilterService.matrixFor(type);

        expect(matrix, hasLength(20));
        expect(matrix.every((value) => value.isFinite), isTrue);
        expect(matrix.sublist(15), <double>[0, 0, 0, 1, 0]);
      }
    });

    test('the original filter keeps the identity matrix', () {
      expect(
        FilterService.isIdentity(FilterService.matrixFor(FilterType.original)),
        isTrue,
      );
      expect(
        FilterService.isIdentity(
          FilterService.matrixForParams(FilterParams.none),
        ),
        isTrue,
      );
      expect(
        FilterService.isIdentity(FilterService.matrixFor(FilterType.warm)),
        isFalse,
      );
    });

    test('black and white collapses every colour to the same grey', () {
      final matrix = FilterService.matrixFor(FilterType.blackWhite);
      final red = _apply(matrix, 1, 0, 0);
      final green = _apply(matrix, 0, 1, 0);
      final blue = _apply(matrix, 0, 0, 1);

      for (final pixel in <List<double>>[red, green, blue]) {
        expect(pixel[0], closeTo(pixel[1], 1e-9));
        expect(pixel[1], closeTo(pixel[2], 1e-9));
        expect(pixel[3], 1);
      }

      // Different luminosities still produce different greys.
      expect(red[0], isNot(closeTo(green[0], 1e-3)));
      expect(green[0], isNot(closeTo(blue[0], 1e-3)));
    });

    test('white stays white in the identity case', () {
      final white = _apply(
        FilterService.matrixFor(FilterType.original),
        1,
        1,
        1,
      );

      expect(white[0], closeTo(1, 1e-9));
      expect(white[1], closeTo(1, 1e-9));
      expect(white[2], closeTo(1, 1e-9));
      expect(white[3], 1);
    });

    test('sepia warms the image and preserves alpha', () {
      final matrix = FilterService.matrixFor(FilterType.sepia);
      final white = _apply(matrix, 1, 1, 1);

      expect(white[0], greaterThan(white[2]));
      expect(white[3], 1);

      final black = _apply(matrix, 0, 0, 0);
      expect(black[0], closeTo(0, 0.05));
      expect(black[3], 1);
    });

    test('warm and cool presets push the channels in opposite directions', () {
      final warm = _apply(FilterService.matrixFor(FilterType.warm), 1, 1, 1);
      final cool = _apply(FilterService.matrixFor(FilterType.cool), 1, 1, 1);

      expect(warm[0], greaterThan(warm[2]));
      expect(cool[2], greaterThan(cool[0]));
    });

    test('fade lifts the blacks instead of crushing them', () {
      final matrix = FilterService.matrixFor(FilterType.faded);
      final black = _apply(matrix, 0, 0, 0);

      expect(black[0], greaterThan(0));
      expect(black[3], 1);
    });

    test('composing twice keeps the alpha channel intact', () {
      for (final type in FilterType.values) {
        final matrix = FilterService.matrixFor(type);
        expect(matrix[18], 1);
        expect(matrix[19], 0);
      }
    });
  });
}
