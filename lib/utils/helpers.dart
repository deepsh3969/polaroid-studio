import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';

/// Application level exception carrying a message that is always safe to show
/// to the user. Raw platform errors are logged for developers only.
class AppException implements Exception {
  const AppException(this.message, {this.logDetails});

  final String message;
  final String? logDetails;

  @override
  String toString() => 'AppException: $message';
}

/// Wraps an arbitrary error into a user friendly [AppException].
AppException toAppException(Object error, String fallback) {
  if (error is AppException) return error;
  debugPrint('[PolaroidStudio] $fallback -> $error');
  return AppException(fallback, logDetails: error.toString());
}

/// Unique, sortable identifier for a created Polaroid.
String generateCreationId() {
  final now = DateTime.now();
  final stamp = DateFormat('yyyyMMddHHmmss', 'en_US').format(now);
  final suffix = now.millisecondsSinceEpoch % 100000;
  return 'pld_$stamp${suffix.toString().padLeft(5, '0')}';
}

/// Bundled artwork used as the example Polaroid on the home screen.
const ImageProvider samplePhotoProvider = AssetImage(
  'assets/images/sample_photo.jpg',
);

// ---------------------------------------------------------------------------
// Photo positioning maths
// ---------------------------------------------------------------------------

/// Smallest zoom that guarantees a rotated photo still covers the square
/// viewport.
///
/// The angle is folded into `0 .. 45°`, so out of range values behave like
/// their nearest supported tilt instead of poisoning the maths with `NaN`.
double minZoomForRotation(double rotation) {
  if (!rotation.isFinite) return 1;
  const quarterTurn = math.pi / 2;
  final folded = rotation.abs() % quarterTurn;
  final angle = folded > quarterTurn / 2 ? quarterTurn - folded : folded;
  return math.cos(angle) + math.sin(angle);
}

/// Maximum normalized pan allowed for a given zoom / rotation combination.
double panLimitFor(double zoom, double rotation) {
  if (!zoom.isFinite || !rotation.isFinite) return 0;
  final coverage = minZoomForRotation(rotation);
  final limit = zoom / 2 - coverage / 2;
  return limit.isFinite && limit > 0 ? limit : 0;
}

/// Keeps the pan inside the viewport.
///
/// The limit is a box in *photo* space: rotating the pan into the photo's
/// frame, clamping both axes and rotating back keeps every viewport corner
/// covered by the photo, which a simple `dx / dy` clamp cannot do while the
/// picture is tilted.
Offset clampPan(Offset pan, double zoom, double rotation) {
  final limit = panLimitFor(zoom, rotation);
  if (limit <= 0) return Offset.zero;
  final dx = pan.dx.isFinite ? pan.dx : 0.0;
  final dy = pan.dy.isFinite ? pan.dy : 0.0;
  final cos = math.cos(rotation);
  final sin = math.sin(rotation);
  final along = (dx * cos + dy * sin).clamp(-limit, limit).toDouble();
  final across = (-dx * sin + dy * cos).clamp(-limit, limit).toDouble();
  return Offset(along * cos - across * sin, along * sin + across * cos);
}

/// Clamps zoom to the safe range for the given rotation.
double clampZoom(double zoom, double rotation) {
  final min = math.max(AppMetrics.minZoom, minZoomForRotation(rotation));
  if (zoom.isNaN || zoom.isInfinite) return min;
  return zoom.clamp(min, AppMetrics.maxZoom).toDouble();
}

/// Clamps a rotation to the supported tilt range.
double clampRotation(double rotation) {
  if (rotation.isNaN || rotation.isInfinite) return 0;
  return rotation
      .clamp(-AppMetrics.maxRotation, AppMetrics.maxRotation)
      .toDouble();
}
