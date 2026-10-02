import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'filter_model.dart';
import 'frame_model.dart';

/// Format of the optional date printed on the Polaroid.
enum DateStampFormat {
  /// `02 OCT 2026`
  dayMonthYear,

  /// `OCT 02, 2026`
  monthDayYear,

  /// `02/10/2026`
  numeric,
}

extension DateStampFormatX on DateStampFormat {
  String get label => switch (this) {
    DateStampFormat.dayMonthYear => '02 OCT 2026',
    DateStampFormat.monthDayYear => 'OCT 02, 2026',
    DateStampFormat.numeric => '02/10/2026',
  };

  /// Formats [date] (device local time) for this stamp format.
  String format(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    switch (this) {
      case DateStampFormat.dayMonthYear:
        return DateFormat('dd MMM yyyy', 'en_US').format(local).toUpperCase();
      case DateStampFormat.monthDayYear:
        return DateFormat('MMM dd, yyyy', 'en_US').format(local).toUpperCase();
      case DateStampFormat.numeric:
        return DateFormat('dd/MM/yyyy', 'en_US').format(local);
    }
  }

  /// Example shown in the format selector (never today's date).
  String example() => format(DateTime(2026, 10, 2));
}

/// Handwriting / typewriter typefaces available for captions.
enum CaptionFont {
  caveat,
  patrickHand,
  shadowsIntoLight,
  homemadeApple,
  specialElite,
}

extension CaptionFontX on CaptionFont {
  String get label => switch (this) {
    CaptionFont.caveat => 'Caveat',
    CaptionFont.patrickHand => 'Patrick Hand',
    CaptionFont.shadowsIntoLight => 'Shadows',
    CaptionFont.homemadeApple => 'Homemade',
    CaptionFont.specialElite => 'Typewriter',
  };

  /// Font family declared in `pubspec.yaml`.
  ///
  /// The files are bundled, so captions render identically offline and inside
  /// exported images.
  String get family => switch (this) {
    CaptionFont.caveat => 'Caveat',
    CaptionFont.patrickHand => 'PatrickHand',
    CaptionFont.shadowsIntoLight => 'ShadowsIntoLight',
    CaptionFont.homemadeApple => 'HomemadeApple',
    CaptionFont.specialElite => 'SpecialElite',
  };

  /// Builds the caption text style through `google_fonts` (which resolves to
  /// the bundled asset first, falling back to the same family).
  TextStyle textStyle({
    Color? color,
    double fontSize = 16,
    double letterSpacing = 0,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    final base = switch (this) {
      CaptionFont.caveat => GoogleFonts.caveat(),
      CaptionFont.patrickHand => GoogleFonts.patrickHand(),
      CaptionFont.shadowsIntoLight => GoogleFonts.shadowsIntoLight(),
      CaptionFont.homemadeApple => GoogleFonts.homemadeApple(),
      CaptionFont.specialElite => GoogleFonts.specialElite(),
    };
    return base.copyWith(
      color: color,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      height: 1.1,
    );
  }
}

/// Typography of the caption area.
@immutable
class CaptionStyle {
  const CaptionStyle({
    this.font = CaptionFont.caveat,
    this.sizeScale = 1,
    this.align = TextAlign.center,
    this.color,
    this.letterSpacing = 0,
  });

  final CaptionFont font;

  /// Multiplier applied to the base caption size (`0.7 .. 1.4`).
  final double sizeScale;

  final TextAlign align;

  /// `null` uses the frame's default ink colour.
  final Color? color;

  /// Extra letter spacing in logical pixels (scaled with the card).
  final double letterSpacing;

  CaptionStyle copyWith({
    CaptionFont? font,
    double? sizeScale,
    TextAlign? align,
    Color? color,
    bool clearColor = false,
    double? letterSpacing,
  }) => CaptionStyle(
    font: font ?? this.font,
    sizeScale: sizeScale ?? this.sizeScale,
    align: align ?? this.align,
    color: clearColor ? null : (color ?? this.color),
    letterSpacing: letterSpacing ?? this.letterSpacing,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'font': font.name,
    'sizeScale': sizeScale,
    'align': align.name,
    if (color != null) 'color': color!.toARGB32(),
    'letterSpacing': letterSpacing,
  };

  factory CaptionStyle.fromJson(Map<String, dynamic> json) => CaptionStyle(
    font: _enumFromName(CaptionFont.values, json['font']),
    sizeScale: (json['sizeScale'] as num?)?.toDouble() ?? 1,
    align: _enumFromName(
      TextAlign.values,
      json['align'],
      orElse: TextAlign.center,
    ),
    color: json['color'] is int ? Color(json['color'] as int) : null,
    letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is CaptionStyle &&
      other.font == font &&
      other.sizeScale == sizeScale &&
      other.align == align &&
      other.color == color &&
      other.letterSpacing == letterSpacing;

  @override
  int get hashCode => Object.hash(font, sizeScale, align, color, letterSpacing);
}

/// Pan / zoom / tilt of the photo inside the square viewport.
@immutable
class ImageTransform {
  const ImageTransform({
    this.pan = Offset.zero,
    this.zoom = 1,
    this.rotation = 0,
  });

  /// Normalized offset (`-0.5 .. 0.5` relative to the viewport).
  final Offset pan;

  /// Zoom factor (`1 .. 4`).
  final double zoom;

  /// Rotation in radians.
  final double rotation;

  const ImageTransform.none() : this();

  /// Returns a copy clamped to the safe positioning range.
  ///
  /// Rotation is resolved first, then zoom for that rotation, and only then
  /// the pan - otherwise the pan would be limited for the wrong transform.
  ImageTransform normalized() {
    final safeRotation = clampRotation(rotation);
    final safeZoom = clampZoom(zoom, safeRotation);
    return ImageTransform(
      pan: clampPan(pan, safeZoom, safeRotation),
      zoom: safeZoom,
      rotation: safeRotation,
    );
  }

  ImageTransform copyWith({Offset? pan, double? zoom, double? rotation}) =>
      ImageTransform(
        pan: pan ?? this.pan,
        zoom: zoom ?? this.zoom,
        rotation: rotation ?? this.rotation,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'panDx': pan.dx,
    'panDy': pan.dy,
    'zoom': zoom,
    'rotation': rotation,
  };

  factory ImageTransform.fromJson(Map<String, dynamic> json) => ImageTransform(
    pan: Offset(
      (json['panDx'] as num?)?.toDouble() ?? 0,
      (json['panDy'] as num?)?.toDouble() ?? 0,
    ),
    zoom: (json['zoom'] as num?)?.toDouble() ?? 1,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is ImageTransform &&
      other.pan == pan &&
      other.zoom == zoom &&
      other.rotation == rotation;

  @override
  int get hashCode => Object.hash(pan, zoom, rotation);
}

/// Complete, serialisable description of one Polaroid composition.
@immutable
class PolaroidConfig {
  PolaroidConfig({
    required this.imagePath,
    this.caption = '',
    this.frameStyle = FrameStyle.classic,
    this.filter = FilterType.original,
    this.showDate = false,
    DateTime? date,
    this.dateFormat = DateStampFormat.dayMonthYear,
    this.captionStyle = const CaptionStyle(),
    this.transform = const ImageTransform(),
  }) : date = date ?? DateTime.now();

  /// Creates a fresh configuration for a picked / captured photo.
  factory PolaroidConfig.initial({required String imagePath}) =>
      PolaroidConfig(imagePath: imagePath);

  /// Absolute path of the ORIGINAL photo. It is never written to.
  final String imagePath;

  final String caption;
  final FrameStyle frameStyle;
  final FilterType filter;
  final bool showDate;

  /// Date printed on the Polaroid (device local time when it was created).
  final DateTime date;
  final DateStampFormat dateFormat;
  final CaptionStyle captionStyle;
  final ImageTransform transform;

  /// The stamped date, ready to render.
  String get formattedDate => dateFormat.format(date);

  PolaroidConfig copyWith({
    String? imagePath,
    String? caption,
    FrameStyle? frameStyle,
    FilterType? filter,
    bool? showDate,
    DateTime? date,
    DateStampFormat? dateFormat,
    CaptionStyle? captionStyle,
    ImageTransform? transform,
  }) => PolaroidConfig(
    imagePath: imagePath ?? this.imagePath,
    caption: caption ?? this.caption,
    frameStyle: frameStyle ?? this.frameStyle,
    filter: filter ?? this.filter,
    showDate: showDate ?? this.showDate,
    date: date ?? this.date,
    dateFormat: dateFormat ?? this.dateFormat,
    captionStyle: captionStyle ?? this.captionStyle,
    transform: transform ?? this.transform,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'imagePath': imagePath,
    'caption': caption,
    'frameStyle': frameStyle.name,
    'filter': filter.name,
    'showDate': showDate,
    'date': date.toIso8601String(),
    'dateFormat': dateFormat.name,
    'captionStyle': captionStyle.toJson(),
    'transform': transform.toJson(),
  };

  factory PolaroidConfig.fromJson(Map<String, dynamic> json) => PolaroidConfig(
    imagePath: _stringOr(json['imagePath'], ''),
    caption: _stringOr(json['caption'], ''),
    frameStyle: _enumFromName(
      FrameStyle.values,
      json['frameStyle'],
      orElse: FrameStyle.classic,
    ),
    filter: _enumFromName(
      FilterType.values,
      json['filter'],
      orElse: FilterType.original,
    ),
    showDate: json['showDate'] as bool? ?? false,
    date: DateTime.tryParse(_stringOr(json['date'], '')) ?? DateTime.now(),
    dateFormat: _enumFromName(
      DateStampFormat.values,
      json['dateFormat'],
      orElse: DateStampFormat.dayMonthYear,
    ),
    captionStyle: json['captionStyle'] is Map<String, dynamic>
        ? CaptionStyle.fromJson(json['captionStyle'] as Map<String, dynamic>)
        : const CaptionStyle(),
    transform: json['transform'] is Map<String, dynamic>
        ? ImageTransform.fromJson(json['transform'] as Map<String, dynamic>)
        : const ImageTransform(),
  );

  @override
  bool operator ==(Object other) =>
      other is PolaroidConfig &&
      other.imagePath == imagePath &&
      other.caption == caption &&
      other.frameStyle == frameStyle &&
      other.filter == filter &&
      other.showDate == showDate &&
      other.date == date &&
      other.dateFormat == dateFormat &&
      other.captionStyle == captionStyle &&
      other.transform == transform;

  @override
  int get hashCode => Object.hash(
    imagePath,
    caption,
    frameStyle,
    filter,
    showDate,
    date,
    dateFormat,
    captionStyle,
    transform,
  );
}

/// Trims a caption to the maximum length and flattens it to one line.
String sanitizeCaption(String value) {
  final collapsed = value.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();
  if (collapsed.length <= AppMetrics.captionMaxLength) return collapsed;
  return collapsed.substring(0, AppMetrics.captionMaxLength);
}

/// Character counter shown under the caption field, e.g. `15 / 40`.
String captionCounter(String value) =>
    '${value.length} / ${AppMetrics.captionMaxLength}';

/// Looks up an enum member by name. Unknown, missing or wrongly typed values
/// fall back to [orElse] (or the first member), so corrupt payloads can never
/// crash a restored configuration.
T _enumFromName<T extends Enum>(List<T> values, Object? name, {T? orElse}) {
  if (name is String) {
    for (final value in values) {
      if (value.name == name) return value;
    }
  }
  return orElse ?? values.first;
}

/// Reads a string field, tolerating values written with the wrong type.
String _stringOr(Object? value, String fallback) =>
    value is String ? value : fallback;
