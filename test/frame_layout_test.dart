import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/models/frame_model.dart';
import 'package:polaroid_studio/models/polaroid_model.dart';
import 'package:polaroid_studio/utils/constants.dart';
import 'package:polaroid_studio/utils/helpers.dart';
import 'package:polaroid_studio/widgets/polaroid_frame.dart';

import 'support/photo_coverage.dart';

void main() {
  group('FrameLayout', () {
    test('keeps the photo square for every frame style', () {
      for (final style in FrameStyle.values) {
        final layout = FrameLayout.forStyle(style, 320);

        expect(layout.photoSize, 320 - 2 * layout.sidePadding);
        expect(
          layout.height,
          layout.topPadding + layout.photoSize + layout.bottomBarHeight,
        );
        expect(layout.aspectRatio, layout.height / 320);
        expect(layout.radius, greaterThan(0));
      }
    });

    test('the bottom caption border is always the widest one', () {
      for (final style in FrameStyle.values) {
        final layout = FrameLayout.forStyle(style, 320);

        expect(layout.bottomBarHeight, greaterThan(layout.sidePadding));
        expect(layout.bottomBarHeight, greaterThan(layout.topPadding));
      }
    });

    test('scales linearly with the card width', () {
      final small = FrameLayout.forStyle(FrameStyle.classic, 200);
      final large = FrameLayout.forStyle(FrameStyle.classic, 400);

      expect(large.height, closeTo(small.height * 2, 1e-9));
      expect(large.photoSize, closeTo(small.photoSize * 2, 1e-9));
      expect(
        large.shadow.blurRadius,
        closeTo(small.shadow.blurRadius * 2, 1e-9),
      );
    });

    test('exposes the export height used by the renderer', () {
      for (final style in FrameStyle.values) {
        final expected = FrameLayout.forStyle(
          style,
          AppMetrics.exportLogicalWidth,
        ).height;

        expect(exportFrameHeight(style), expected);
        expect(
          exportFrameHeight(style),
          greaterThan(AppMetrics.exportLogicalWidth),
        );
      }
    });
  });

  group('photo positioning maths', () {
    test('an upright photo only needs a 1x zoom', () {
      expect(minZoomForRotation(0), closeTo(1, 1e-9));
      expect(clampZoom(0.5, 0), AppMetrics.minZoom);
    });

    test('tilting forces a zoom in so no paper shows through', () {
      final required = minZoomForRotation(AppMetrics.maxRotation);

      expect(required, greaterThan(1));
      expect(clampZoom(1, AppMetrics.maxRotation), closeTo(required, 1e-9));
      expect(
        clampZoom(required * 1.2, AppMetrics.maxRotation),
        closeTo(required * 1.2, 1e-9),
      );
    });

    test('pan limit grows with zoom and never goes negative', () {
      expect(panLimitFor(1, 0), 0);
      expect(panLimitFor(2, 0), closeTo(0.5, 1e-9));
      expect(panLimitFor(0.5, 0), 0);
    });

    test('clampPan keeps the photo inside the viewport', () {
      final clamped = clampPan(const Offset(4, -4), 2, 0);

      expect(clamped.dx, closeTo(0.5, 1e-9));
      expect(clamped.dy, closeTo(-0.5, 1e-9));

      final inside = clampPan(const Offset(0.4, 0.4), 2, 0);
      expect(inside, const Offset(0.4, 0.4));

      final diagonal = clampPan(const Offset(0.9, -0.9), 2, 0);
      final limit = panLimitFor(2, 0);
      expect(diagonal.dx, closeTo(limit, 1e-9));
      expect(diagonal.dy, closeTo(-limit, 1e-9));
    });

    test('clampPan covers the viewport for every supported tilt', () {
      for (final rotation in const <double>[0, 0.2, 0.4, 0.52]) {
        final zoom = clampZoom(2, rotation);
        final pan = clampPan(const Offset(3, -3), zoom, rotation);

        expectPhotoCoversViewport(
          ImageTransform(pan: pan, zoom: zoom, rotation: rotation),
        );
      }
    });

    test('clamps are NaN safe', () {
      expect(clampZoom(double.nan, 0), AppMetrics.minZoom);
      expect(clampRotation(double.nan), 0);
      expect(
        clampPan(const Offset(double.nan, double.nan), 2, 0).dx.isFinite,
        isTrue,
      );
    });

    test('rotation stays inside the supported tilt range', () {
      expect(clampRotation(10), AppMetrics.maxRotation);
      expect(clampRotation(-10), -AppMetrics.maxRotation);
      expect(clampRotation(math.pi / 2), AppMetrics.maxRotation);
    });

    test('a normalised transform always renders without empty corners', () {
      const transform = ImageTransform(
        pan: Offset(0.5, -0.5),
        zoom: 1,
        rotation: AppMetrics.maxRotation,
      );
      final normalised = transform.normalized();
      final cover = minZoomForRotation(normalised.rotation);

      expect(normalised.zoom, greaterThanOrEqualTo(cover));
      expect(normalised.zoom, lessThanOrEqualTo(AppMetrics.maxZoom));
      expectPhotoCoversViewport(normalised);
    });
  });
}
