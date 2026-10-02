import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/models/polaroid_model.dart';

/// Asserts that [transform] keeps the whole square viewport covered by the
/// photo.
///
/// It mirrors exactly how `PolaroidFrame` renders: translate by the pan, then
/// rotate, then scale. Every viewport corner therefore has to land inside the
/// scaled picture once the pan and the tilt are undone.
void expectPhotoCoversViewport(ImageTransform transform) {
  final double half = transform.zoom / 2;
  final double cos = math.cos(transform.rotation);
  final double sin = math.sin(transform.rotation);

  for (final double sx in const <double>[-0.5, 0.5]) {
    for (final double sy in const <double>[-0.5, 0.5]) {
      final double x = sx - transform.pan.dx;
      final double y = sy - transform.pan.dy;
      final double photoX = x * cos + y * sin;
      final double photoY = -x * sin + y * cos;

      expect(
        photoX.abs(),
        lessThanOrEqualTo(half + 1e-9),
        reason: 'corner ($sx, $sy) falls off the photo horizontally',
      );
      expect(
        photoY.abs(),
        lessThanOrEqualTo(half + 1e-9),
        reason: 'corner ($sx, $sy) falls off the photo vertically',
      );
    }
  }
}
