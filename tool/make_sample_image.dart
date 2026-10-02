// Generates `assets/images/sample_photo.jpg`, the bundled example photo used
// by the home screen. Run with:  dart run tool/make_sample_image.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const int width = 1200;
const int height = 1200;

void main() {
  final image = img.Image(width: width, height: height);
  final rng = math.Random(20261002);

  const double horizonRatio = 0.615;
  const double horizon = height * horizonRatio;
  const double sunX = width * 0.63;
  const double sunY = height * 0.40;
  const double sunR = height * 0.105;

  // Ridge lines of the far shore, painted far to near. They rise above the
  // horizon and never extend below it, so the water stays in the foreground.
  final List<_Ridge> ridges = <_Ridge>[
    const _Ridge(
      base: horizon,
      amp1: 44,
      freq1: 0.0042,
      phase1: 0.6,
      amp2: 18,
      freq2: 0.0091,
      phase2: 2.1,
      color: <int>[96, 106, 132],
      haze: 0.5,
    ),
    const _Ridge(
      base: horizon,
      amp1: 72,
      freq1: 0.0031,
      phase1: 2.4,
      amp2: 26,
      freq2: 0.0073,
      phase2: 0.4,
      color: <int>[74, 80, 102],
      haze: 0.26,
    ),
    const _Ridge(
      base: horizon,
      amp1: 52,
      freq1: 0.0057,
      phase1: 4.1,
      amp2: 17,
      freq2: 0.0121,
      phase2: 1.7,
      color: <int>[58, 60, 76],
      haze: 0.1,
    ),
  ];

  final List<_Cloud> clouds = <_Cloud>[
    const _Cloud(
      center: height * 0.16,
      thickness: 46,
      speed: 0.0048,
      phase: 0.3,
    ),
    const _Cloud(
      center: height * 0.24,
      thickness: 34,
      speed: 0.0061,
      phase: 1.9,
    ),
    const _Cloud(
      center: height * 0.33,
      thickness: 58,
      speed: 0.0037,
      phase: 3.4,
    ),
    const _Cloud(
      center: height * 0.47,
      thickness: 40,
      speed: 0.0055,
      phase: 5.2,
    ),
  ];

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      double r;
      double g;
      double b;

      if (y < horizon) {
        // Sky: violet blue overhead fading into a warm horizon glow.
        final double t = y / horizon;
        r = _mix(46, 255, math.pow(t, 1.35).toDouble());
        g = _mix(58, 214, math.pow(t, 1.5).toDouble());
        b = _mix(104, 176, math.pow(t, 1.1).toDouble());

        // Sun: a broad glow with a soft disc on top (always continuous).
        final double dx = x - sunX;
        final double dy = y - sunY;
        final double dist = math.sqrt(dx * dx + dy * dy);
        final double glow = math.exp(
          -math.pow(dist / (sunR * 2.4), 2).toDouble(),
        );
        r = _mix(r, 255, glow * 0.75);
        g = _mix(g, 232, glow * 0.7);
        b = _mix(b, 186, glow * 0.62);
        if (dist < sunR) {
          final double disc = math.sqrt(1 - dist / sunR);
          r = _mix(r, 255, disc * 0.9);
          g = _mix(g, 252, disc * 0.9);
          b = _mix(b, 232, disc * 0.9);
        }

        // Soft cloud bands.
        for (final cloud in clouds) {
          final double wobble =
              0.72 + 0.28 * math.sin(x * cloud.speed + cloud.phase);
          final double w = cloud.thickness * wobble;
          final double d = (y - cloud.center) / w;
          if (d.abs() > 2.4) continue;
          double cover = math.exp(-d * d) * 0.62;
          cover *= 0.45 + 0.55 * math.sin(x * 0.013 + cloud.phase * 2.7);
          if (cover <= 0.02) continue;
          r = _mix(r, 255, cover);
          g = _mix(g, 236, cover);
          b = _mix(b, 214, cover);
        }
      } else {
        // Water: deep teal with horizontal shimmer and a glitter path.
        final double t = (y - horizon) / (height - horizon);
        r = _mix(96, 44, t);
        g = _mix(132, 82, t);
        b = _mix(150, 104, t);

        final double shimmer = math.sin(
          y * 0.19 + math.sin(x * 0.011) * 1.7 + t * 9,
        );
        final double nearSun = math.exp(
          -math.pow((x - sunX) / (width * 0.16), 2).toDouble(),
        );
        final double glint = (shimmer * 0.5 + 0.5) * (0.25 + 0.75 * nearSun);
        r = _mix(r, 255, glint * 0.42);
        g = _mix(g, 214, glint * 0.4);
        b = _mix(b, 168, glint * 0.36);

        final double ripple = 0.5 + 0.5 * math.sin(y * 0.42 + x * 0.004);
        r += ripple * 4.5;
        g += ripple * 4.5;
        b += ripple * 4;
      }

      // Far shore hills: painted over the sky, never over the water.
      if (y <= horizon) {
        for (final ridge in ridges) {
          final double ridgeY = ridge.heightAt(x);
          if (y < ridgeY) continue;
          final double span = math.max(1, horizon - ridgeY);
          final double depth = math.min(1, (y - ridgeY) / span);
          final double shade = 1 - depth * 0.3;
          final double haze = ridge.haze * (1 - depth);
          r = _mix(ridge.color[0].toDouble() * shade, 236, haze);
          g = _mix(ridge.color[1].toDouble() * shade, 214, haze);
          b = _mix(ridge.color[2].toDouble() * shade, 186, haze);
        }
      }

      // Warm film cast.
      r *= 1.05;
      g *= 1.0;
      b *= 0.93;

      // Grain.
      final double grain = (rng.nextDouble() - 0.5) * 9;
      r += grain;
      g += grain;
      b += grain;

      // Vignette.
      final double nx = (x - width / 2) / (width / 2);
      final double ny = (y - height / 2) / (height / 2);
      final double radius2 = nx * nx + ny * ny;
      final double vig = 1 - 0.24 * math.pow(radius2, 1.35);
      r *= vig;
      g *= vig;
      b *= vig;

      // Values must stay inside 0..255: the image buffer is 8 bit per
      // channel and would silently wrap around.
      image.setPixelRgba(x, y, _clamp255(r), _clamp255(g), _clamp255(b), 255);
    }
  }

  _drawBirds(image, rng);

  final File out = File('assets/images/sample_photo.jpg');
  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(img.encodeJpg(image, quality: 90));
  stdout.writeln('Wrote ${out.path} (${out.lengthSync()} bytes)');
}

double _mix(double a, double b, double t) {
  final double clamped = t < 0 ? 0 : (t > 1 ? 1 : t);
  return a + (b - a) * clamped;
}

double _clamp255(double value) {
  if (value < 0) return 0;
  if (value > 255) return 255;
  return value;
}

/// Draws a handful of small birds as two short parabola wings.
void _drawBirds(img.Image image, math.Random rng) {
  const List<List<int>> spots = <List<int>>[
    <int>[330, 250],
    <int>[410, 205],
    <int>[268, 330],
    <int>[520, 300],
  ];
  for (final spot in spots) {
    final int bx = spot[0];
    final int by = spot[1];
    final int size = 7 + rng.nextInt(4);
    for (int i = -size; i <= size; i++) {
      if (i == 0) continue;
      final double k = i / size;
      final int wing = (k * k * 9).round();
      final int px = bx + i;
      final int py = by - wing;
      if (px < 0 || px >= width || py < 0 || py >= height) continue;
      _blendPixel(image, px, py, 44, 42, 52, 0.72);
      _blendPixel(image, px, py + 1, 44, 42, 52, 0.35);
    }
  }
}

void _blendPixel(
  img.Image image,
  int x,
  int y,
  double r,
  double g,
  double b,
  double a,
) {
  final double sr = image.getPixel(x, y).r.toDouble();
  final double sg = image.getPixel(x, y).g.toDouble();
  final double sb = image.getPixel(x, y).b.toDouble();
  image.setPixelRgba(x, y, _mix(sr, r, a), _mix(sg, g, a), _mix(sb, b, a), 255);
}

/// One distant hill silhouette.
class _Ridge {
  const _Ridge({
    required this.base,
    required this.amp1,
    required this.freq1,
    required this.phase1,
    required this.amp2,
    required this.freq2,
    required this.phase2,
    required this.color,
    required this.haze,
  });

  final double base;
  final double amp1;
  final double freq1;
  final double phase1;
  final double amp2;
  final double freq2;
  final double phase2;
  final List<int> color;

  /// Amount of atmospheric haze mixed into the crest (`0 .. 1`).
  final double haze;

  double heightAt(int x) =>
      base -
      amp1 * math.sin(x * freq1 + phase1) -
      amp2 * math.sin(x * freq2 + phase2);
}

/// A soft horizontal cloud band.
class _Cloud {
  const _Cloud({
    required this.center,
    required this.thickness,
    required this.speed,
    required this.phase,
  });

  final double center;
  final double thickness;
  final double speed;
  final double phase;
}
