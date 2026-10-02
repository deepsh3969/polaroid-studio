import 'package:flutter/material.dart';

/// Preset Polaroid paper styles the user can switch between.
enum FrameStyle { classic, warmWhite, black, vintageCream, minimal }

/// Visual description of one [FrameStyle].
///
/// All measurements are expressed as a fraction of the card width so the
/// composition renders identically in the editor, in the preview and in the
/// high resolution export.
@immutable
class FrameConfig {
  const FrameConfig({
    required this.paper,
    required this.paperEdge,
    required this.ink,
    required this.inkSoft,
    required this.sideBorder,
    required this.topBorder,
    required this.bottomBorder,
    required this.radius,
    required this.shadowColor,
    required this.shadowOpacity,
    required this.shadowBlur,
    required this.shadowOffsetY,
    required this.photoEdgeColor,
  });

  /// Paper colour of the frame.
  final Color paper;

  /// Slightly darker paper colour used for a subtle vertical gradient.
  final Color paperEdge;

  /// Default caption ink colour.
  final Color ink;

  /// Softer ink used for the date stamp.
  final Color inkSoft;

  /// Left / right border, as a fraction of the card width.
  final double sideBorder;

  /// Top border, as a fraction of the card width.
  final double topBorder;

  /// Bottom (caption) border, as a fraction of the card width.
  final double bottomBorder;

  /// Corner radius, as a fraction of the card width.
  final double radius;

  /// Colour of the natural paper shadow.
  final Color shadowColor;

  /// Opacity of the paper shadow.
  final double shadowOpacity;

  /// Blur radius, as a fraction of the card width (~0.085 => 25px at 300px).
  final double shadowBlur;

  /// Vertical offset, as a fraction of the card width.
  final double shadowOffsetY;

  /// Hairline drawn around the photo area.
  final Color photoEdgeColor;

  bool get isDark => paper.computeLuminance() < 0.3;
}

extension FrameStyleX on FrameStyle {
  String get label => switch (this) {
    FrameStyle.classic => 'Classic',
    FrameStyle.warmWhite => 'Warm White',
    FrameStyle.black => 'Black',
    FrameStyle.vintageCream => 'Vintage Cream',
    FrameStyle.minimal => 'Minimal',
  };

  FrameConfig get config => switch (this) {
    FrameStyle.classic => const FrameConfig(
      paper: Color(0xFFFFFDF7),
      paperEdge: Color(0xFFF7F1E4),
      ink: Color(0xFF26211B),
      inkSoft: Color(0xFF5B534A),
      sideBorder: 0.055,
      topBorder: 0.055,
      bottomBorder: 0.2,
      radius: 0.035,
      shadowColor: Color(0x00000000),
      shadowOpacity: 0.18,
      shadowBlur: 0.085,
      shadowOffsetY: 0.04,
      photoEdgeColor: Color(0x14000000),
    ),
    FrameStyle.warmWhite => const FrameConfig(
      paper: Color(0xFFFAF3E4),
      paperEdge: Color(0xFFF0E7D3),
      ink: Color(0xFF3A342B),
      inkSoft: Color(0xFF6B6254),
      sideBorder: 0.055,
      topBorder: 0.055,
      bottomBorder: 0.205,
      radius: 0.035,
      shadowColor: Color(0x00000000),
      shadowOpacity: 0.18,
      shadowBlur: 0.085,
      shadowOffsetY: 0.04,
      photoEdgeColor: Color(0x14000000),
    ),
    FrameStyle.black => const FrameConfig(
      paper: Color(0xFF17161A),
      paperEdge: Color(0xFF0D0C10),
      ink: Color(0xFFEFE9DE),
      inkSoft: Color(0xFFB6AE9F),
      sideBorder: 0.055,
      topBorder: 0.055,
      bottomBorder: 0.2,
      radius: 0.03,
      shadowColor: Color(0x00000000),
      shadowOpacity: 0.3,
      shadowBlur: 0.09,
      shadowOffsetY: 0.045,
      photoEdgeColor: Color(0x33000000),
    ),
    FrameStyle.vintageCream => const FrameConfig(
      paper: Color(0xFFEFE2C8),
      paperEdge: Color(0xFFE2D1AF),
      ink: Color(0xFF4A3B28),
      inkSoft: Color(0xFF7A6A51),
      sideBorder: 0.06,
      topBorder: 0.06,
      bottomBorder: 0.215,
      radius: 0.03,
      shadowColor: Color(0x00000000),
      shadowOpacity: 0.2,
      shadowBlur: 0.09,
      shadowOffsetY: 0.042,
      photoEdgeColor: Color(0x1F000000),
    ),
    FrameStyle.minimal => const FrameConfig(
      paper: Color(0xFFFDFCFA),
      paperEdge: Color(0xFFF4F1EC),
      ink: Color(0xFF2A2A2A),
      inkSoft: Color(0xFF6E6E6E),
      sideBorder: 0.03,
      topBorder: 0.03,
      bottomBorder: 0.135,
      radius: 0.012,
      shadowColor: Color(0x00000000),
      shadowOpacity: 0.12,
      shadowBlur: 0.05,
      shadowOffsetY: 0.022,
      photoEdgeColor: Color(0x10000000),
    ),
  };
}

/// Exact geometry of a Polaroid card for a given width.
///
/// Both the on screen widget and the export pipeline use this class, which
/// guarantees the exported pixels match the preview.
@immutable
class FrameLayout {
  const FrameLayout(this.width, this.config);

  final double width;
  final FrameConfig config;

  factory FrameLayout.forStyle(FrameStyle style, double width) =>
      FrameLayout(width, style.config);

  /// Left / right paper border.
  double get sidePadding => width * config.sideBorder;

  /// Top paper border.
  double get topPadding => width * config.topBorder;

  /// Bottom (caption) paper border - noticeably larger than the others.
  double get bottomBarHeight => width * config.bottomBorder;

  /// Square photo viewport edge length.
  double get photoSize => width - 2 * sidePadding;

  /// Corner radius of the paper card.
  double get radius => width * config.radius;

  /// Total card height.
  double get height => topPadding + photoSize + bottomBarHeight;

  /// Aspect ratio (height / width) of the complete card.
  double get aspectRatio => height / width;

  /// Shadow specification, scaled to the current width.
  BoxShadow get shadow => BoxShadow(
    color: config.shadowColor.withValues(alpha: config.shadowOpacity),
    blurRadius: width * config.shadowBlur,
    spreadRadius: width * 0.003,
    offset: Offset(0, width * config.shadowOffsetY),
  );
}
