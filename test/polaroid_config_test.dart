import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/models/filter_model.dart';
import 'package:polaroid_studio/models/frame_model.dart';
import 'package:polaroid_studio/models/polaroid_model.dart';
import 'package:polaroid_studio/utils/constants.dart';

import 'support/photo_coverage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PolaroidConfig', () {
    test('initial configuration starts neutral', () {
      final config = PolaroidConfig.initial(imagePath: '/tmp/photo.jpg');

      expect(config.imagePath, '/tmp/photo.jpg');
      expect(config.caption, '');
      expect(config.frameStyle, FrameStyle.classic);
      expect(config.filter, FilterType.original);
      expect(config.showDate, isFalse);
      expect(config.dateFormat, DateStampFormat.dayMonthYear);
      expect(config.captionStyle, const CaptionStyle());
      expect(config.transform, const ImageTransform());
    });

    test('survives a JSON round trip', () {
      final config = PolaroidConfig.initial(imagePath: '/tmp/photo.jpg')
          .copyWith(
            caption: 'Summer 2026',
            frameStyle: FrameStyle.vintageCream,
            filter: FilterType.sepia,
            showDate: true,
            dateFormat: DateStampFormat.numeric,
            captionStyle: const CaptionStyle(
              font: CaptionFont.specialElite,
              sizeScale: 1.2,
              align: TextAlign.left,
              letterSpacing: 2,
            ),
            transform: const ImageTransform(
              pan: Offset(0.1, -0.2),
              zoom: 1.5,
              rotation: 0.1,
            ),
          );

      final restored = PolaroidConfig.fromJson(config.toJson());

      expect(restored, config);
      expect(restored.caption, 'Summer 2026');
      expect(restored.captionStyle.font, CaptionFont.specialElite);
      expect(restored.transform.zoom, 1.5);
      expect(restored.date.toIso8601String(), config.date.toIso8601String());
    });

    test('tolerates a partial or unknown payload', () {
      final restored = PolaroidConfig.fromJson(const <String, dynamic>{
        'imagePath': 'a.jpg',
        'frameStyle': 'does-not-exist',
        'filter': 42,
        'captionStyle': <String, dynamic>{},
        'transform': <String, dynamic>{},
      });

      expect(restored.imagePath, 'a.jpg');
      expect(restored.frameStyle, FrameStyle.classic);
      expect(restored.filter, FilterType.original);
      expect(restored.caption, '');
      expect(restored.showDate, isFalse);
    });

    test('copyWith keeps untouched values', () {
      final config = PolaroidConfig.initial(imagePath: 'a.jpg');
      final copy = config.copyWith(caption: 'New');

      expect(copy.caption, 'New');
      expect(copy.imagePath, config.imagePath);
      expect(copy.frameStyle, config.frameStyle);
      expect(identical(copy, config), isFalse);
    });
  });

  group('caption helpers', () {
    test('sanitizeCaption collapses line breaks and trims', () {
      expect(sanitizeCaption('hello\nworld'), 'hello world');
      expect(sanitizeCaption('  padded  '), 'padded');
      expect(sanitizeCaption(''), '');
    });

    test('sanitizeCaption enforces the maximum length', () {
      final long = 'x' * (AppMetrics.captionMaxLength + 25);
      expect(sanitizeCaption(long).length, AppMetrics.captionMaxLength);
    });

    test('captionCounter shows the used budget', () {
      expect(captionCounter('abc'), '3 / ${AppMetrics.captionMaxLength}');
      expect(captionCounter(''), '0 / ${AppMetrics.captionMaxLength}');
    });
  });

  group('DateStampFormat', () {
    final date = DateTime(2026, 10, 2);

    test('formats the device date in every supported layout', () {
      expect(DateStampFormat.dayMonthYear.format(date), '02 OCT 2026');
      expect(DateStampFormat.monthDayYear.format(date), 'OCT 02, 2026');
      expect(DateStampFormat.numeric.format(date), '02/10/2026');
    });

    test('ignores the time of day', () {
      final late = DateTime(2026, 10, 2, 23, 59);
      expect(DateStampFormat.dayMonthYear.format(late), '02 OCT 2026');
    });

    test('labels show an example instead of today', () {
      for (final format in DateStampFormat.values) {
        expect(format.example(), format.format(DateTime(2026, 10, 2)));
      }
    });
  });

  group('CaptionStyle', () {
    test('survives a JSON round trip', () {
      const style = CaptionStyle(
        font: CaptionFont.homemadeApple,
        sizeScale: 0.9,
        align: TextAlign.right,
        color: Color(0xFF112233),
        letterSpacing: 1.5,
      );

      final restored = CaptionStyle.fromJson(style.toJson());

      expect(restored.font, CaptionFont.homemadeApple);
      expect(restored.sizeScale, 0.9);
      expect(restored.align, TextAlign.right);
      expect(restored.color, const Color(0xFF112233));
      expect(restored.letterSpacing, 1.5);
    });

    test('a null colour falls back to the frame ink', () {
      const style = CaptionStyle();
      expect(style.color, isNull);

      final restored = CaptionStyle.fromJson(<String, dynamic>{
        'font': CaptionFont.caveat.name,
      });
      expect(restored.color, isNull);
      expect(restored, const CaptionStyle());
    });

    test('every font maps to a bundled family', () {
      const families = <CaptionFont, String>{
        CaptionFont.caveat: 'Caveat',
        CaptionFont.patrickHand: 'PatrickHand',
        CaptionFont.shadowsIntoLight: 'ShadowsIntoLight',
        CaptionFont.homemadeApple: 'HomemadeApple',
        CaptionFont.specialElite: 'SpecialElite',
      };

      for (final entry in families.entries) {
        expect(entry.key.family, entry.value);
        expect(entry.key.label, isNotEmpty);
        expect(entry.key.textStyle(), isNotNull);
      }
    });
  });

  group('ImageTransform', () {
    test('survives a JSON round trip', () {
      const transform = ImageTransform(
        pan: Offset(-0.2, 0.3),
        zoom: 2.4,
        rotation: -0.2,
      );

      final restored = ImageTransform.fromJson(transform.toJson());

      expect(restored, transform);
      expect(restored.pan.dx, closeTo(-0.2, 1e-9));
      expect(restored.pan.dy, closeTo(0.3, 1e-9));
    });

    test('normalized clamps every axis', () {
      const wild = ImageTransform(pan: Offset(9, -9), zoom: 99, rotation: 5);
      final clamped = wild.normalized();

      expect(clamped.zoom, AppMetrics.maxZoom);
      expect(clamped.rotation, AppMetrics.maxRotation);
      expect(clamped.zoom.isFinite, isTrue);
      expect(clamped.rotation.isFinite, isTrue);
      expect(clamped.pan.dx.isFinite, isTrue);
      expectPhotoCoversViewport(clamped);
    });

    test('normalized repairs invalid numbers', () {
      const broken = ImageTransform(
        pan: Offset(double.nan, double.nan),
        zoom: double.nan,
        rotation: double.nan,
      );
      final repaired = broken.normalized();

      expect(repaired.zoom.isFinite, isTrue);
      expect(repaired.rotation.isFinite, isTrue);
      expect(repaired.pan.dx.isFinite, isTrue);
      expect(repaired.pan.dy.isFinite, isTrue);
      expect(repaired.zoom, greaterThanOrEqualTo(AppMetrics.minZoom));
      expect(repaired.rotation, 0);
      expect(repaired.pan, Offset.zero);
    });

    test('normalized never breaks a valid transform', () {
      const healthy = ImageTransform(
        pan: Offset(0.1, -0.2),
        zoom: 2,
        rotation: 0.3,
      );

      expect(healthy.normalized(), healthy);
      expectPhotoCoversViewport(healthy.normalized());
    });
  });
}
