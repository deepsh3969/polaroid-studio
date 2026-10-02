import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/filter_model.dart';
import '../models/frame_model.dart';
import '../models/polaroid_model.dart';
import '../services/filter_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'date_stamp.dart';

/// Renders a complete Polaroid: paper card, square photo viewport, caption,
/// optional date stamp, filter and natural paper shadow.
///
/// Every measurement derives from [width], so the same widget renders the
/// on-screen preview and the high resolution export identically.
class PolaroidFrame extends StatelessWidget {
  const PolaroidFrame({
    super.key,
    required this.image,
    required this.caption,
    this.date,
    this.frameStyle = FrameStyle.classic,
    this.filter = FilterType.original,
    this.showDate = false,
    this.width = 320,
    this.captionStyle = const CaptionStyle(),
    this.transform = const ImageTransform(),
    this.developmentProgress = 1,
    this.interactive = false,
    this.onTransformChanged,
    this.onResetTransform,
    this.onCaptionTap,
  });

  /// Photo provider - the original file is never modified.
  final ImageProvider image;

  final String caption;

  /// Pre-formatted date stamp, rendered only when [showDate] is `true`.
  final String? date;

  final FrameStyle frameStyle;
  final FilterType filter;
  final bool showDate;

  /// Card width in logical pixels.
  final double width;

  final CaptionStyle captionStyle;
  final ImageTransform transform;

  /// `0` = blank print, `1` = fully developed.
  final double developmentProgress;

  /// Enables pinch / pan / rotate / double tap gestures.
  final bool interactive;

  final ValueChanged<ImageTransform>? onTransformChanged;
  final VoidCallback? onResetTransform;
  final VoidCallback? onCaptionTap;

  @override
  Widget build(BuildContext context) {
    final layout = FrameLayout.forStyle(frameStyle, width);
    final config = layout.config;

    return SizedBox(
      width: width,
      height: layout.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[config.paper, config.paperEdge],
            stops: const <double>[0.72, 1],
          ),
          borderRadius: BorderRadius.circular(layout.radius),
          boxShadow: <BoxShadow>[layout.shadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(height: layout.topPadding),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: layout.sidePadding),
              child: SizedBox(
                width: layout.photoSize,
                height: layout.photoSize,
                child: _PhotoArea(
                  image: image,
                  filter: filter,
                  transform: transform,
                  size: layout.photoSize,
                  developmentProgress: developmentProgress,
                  interactive: interactive,
                  onTransformChanged: onTransformChanged,
                  onResetTransform: onResetTransform,
                ),
              ),
            ),
            Expanded(child: _buildCaptionArea(layout)),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionArea(FrameLayout layout) {
    final config = layout.config;
    final ink = captionStyle.color ?? config.ink;
    final horizontal = layout.width * 0.05;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontal,
        layout.width * 0.018,
        horizontal,
        layout.width * 0.02,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(child: _buildCaption(layout, ink)),
          if (showDate && (date == null || date!.isEmpty))
            const SizedBox.shrink()
          else if (showDate)
            DateStamp(
              text: date ?? '',
              width: layout.width,
              color: config.inkSoft,
            ),
        ],
      ),
    );
  }

  Widget _buildCaption(FrameLayout layout, Color ink) {
    final baseSize = layout.width * 0.075 * captionStyle.sizeScale;
    final spacing = captionStyle.letterSpacing * layout.width / 300;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onCaptionTap,
      child: Semantics(
        button: onCaptionTap != null,
        label: caption.isEmpty ? 'Empty caption' : 'Caption: $caption',
        child: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: _alignmentFor(captionStyle.align),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Text(
                  caption,
                  textAlign: captionStyle.align,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: captionStyle.font.textStyle(
                    color: ink,
                    fontSize: baseSize,
                    letterSpacing: spacing,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Alignment _alignmentFor(TextAlign align) => switch (align) {
    TextAlign.left || TextAlign.start => Alignment.centerLeft,
    TextAlign.right || TextAlign.end => Alignment.centerRight,
    _ => Alignment.center,
  };
}

/// Square photo viewport: gestures, transform, filter, vignette and the
/// developing (print reveal) effect.
class _PhotoArea extends StatefulWidget {
  const _PhotoArea({
    required this.image,
    required this.filter,
    required this.transform,
    required this.size,
    required this.developmentProgress,
    required this.interactive,
    this.onTransformChanged,
    this.onResetTransform,
  });

  final ImageProvider image;
  final FilterType filter;
  final ImageTransform transform;
  final double size;
  final double developmentProgress;
  final bool interactive;
  final ValueChanged<ImageTransform>? onTransformChanged;
  final VoidCallback? onResetTransform;

  @override
  State<_PhotoArea> createState() => _PhotoAreaState();
}

class _PhotoAreaState extends State<_PhotoArea> {
  ImageTransform? _gestureStart;

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStart = widget.transform;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final start = _gestureStart;
    if (start == null || widget.onTransformChanged == null) return;

    final rotation = clampRotation(start.rotation + details.rotation);
    final zoom = clampZoom(start.zoom * details.scale, rotation);
    final delta = details.focalPointDelta;
    final rawPan =
        start.pan + Offset(delta.dx / widget.size, delta.dy / widget.size);
    final pan = clampPan(rawPan, zoom, rotation);

    widget.onTransformChanged!(
      ImageTransform(pan: pan, zoom: zoom, rotation: rotation),
    );
  }

  void _onScaleEnd(ScaleEndDetails details) {
    _gestureStart = null;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.developmentProgress.clamp(0.0, 1.0).toDouble();
    final params = _paramsForProgress(progress);

    Widget photo = Image(
      image: widget.image,
      fit: BoxFit.cover,
      width: widget.size,
      height: widget.size,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => ColoredBox(
        color: const Color(0xFFDDD6C8),
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: widget.size * 0.14,
            color: const Color(0xFF8A8177),
          ),
        ),
      ),
    );

    photo = _AnimatedFilter(
      params: params,
      animate: progress >= 1,
      child: photo,
    );

    photo = Transform.translate(
      offset: Offset(
        widget.transform.pan.dx * widget.size,
        widget.transform.pan.dy * widget.size,
      ),
      child: Transform.rotate(
        angle: widget.transform.rotation,
        child: Transform.scale(scale: widget.transform.zoom, child: photo),
      ),
    );

    final layers = <Widget>[
      Positioned.fill(child: photo),
      if (params.vignette > 0)
        Positioned.fill(
          child: CustomPaint(painter: _VignettePainter(params.vignette)),
        ),
    ];

    Widget content = ClipRect(
      child: Stack(fit: StackFit.expand, children: layers),
    );

    // Developing print: soft blur and a white veil while the emulsion settles.
    if (progress < 1) {
      final blur = (1 - progress) * 5;
      content = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      );
      content = Stack(
        fit: StackFit.expand,
        children: <Widget>[
          content,
          IgnorePointer(
            child: Opacity(
              opacity: (1 - Curves.easeOut.transform(progress)) * 0.94,
              child: const ColoredBox(color: Color(0xFFFDFBF4)),
            ),
          ),
        ],
      );
    }

    if (!widget.interactive) return content;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onDoubleTap: widget.onResetTransform,
      child: Semantics(
        image: true,
        label: 'Photo, pinch to zoom, drag to move, double tap to reset',
        child: content,
      ),
    );
  }

  /// Applies the filter, desaturating it while the print develops.
  FilterParams _paramsForProgress(double progress) {
    final base = widget.filter.params;
    if (progress >= 1) return base;

    final eased = Curves.easeOut.transform(progress);
    return FilterParams(
      saturation: base.saturation * (0.15 + 0.85 * eased),
      brightness: base.brightness - (1 - eased) * 0.04,
      contrast: 1 + (base.contrast - 1) * eased,
      temperature: base.temperature,
      fade: base.fade + (1 - eased) * 0.32,
      sepia: base.sepia,
      vignette: base.vignette * eased,
    );
  }
}

/// Cross-fades between two filter parameter sets so switching filters in the
/// editor feels smooth.
class _AnimatedFilter extends StatefulWidget {
  const _AnimatedFilter({
    required this.params,
    required this.animate,
    required this.child,
  });

  final FilterParams params;
  final bool animate;
  final Widget child;

  @override
  State<_AnimatedFilter> createState() => _AnimatedFilterState();
}

class _AnimatedFilterState extends State<_AnimatedFilter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  FilterParamsTween _tween = FilterParamsTween(
    begin: FilterParams.none,
    end: FilterParams.none,
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _tween = FilterParamsTween(begin: widget.params, end: widget.params);
  }

  @override
  void didUpdateWidget(_AnimatedFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.params == widget.params) return;

    final current = _tween.evaluate(_controller.view);
    _tween = FilterParamsTween(begin: current, end: widget.params);
    if (widget.animate && mounted) {
      _controller.forward(from: 0);
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final params = _tween.evaluate(_controller.view);
        if (params.isNeutral) return child!;
        return ColorFiltered(
          colorFilter: ColorFilter.matrix(
            FilterService.matrixForParams(params),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Darkens the corners of the photo for a lens-vignette feel.
class _VignettePainter extends CustomPainter {
  const _VignettePainter(this.strength);

  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = RadialGradient(
        radius: 1,
        colors: <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: strength.clamp(0.0, 1.0)),
        ],
        stops: const <double>[0.52, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_VignettePainter oldDelegate) =>
      oldDelegate.strength != strength;
}

/// Exposed for tests: the exact metrics used when exporting.
double exportFrameHeight(FrameStyle style) =>
    FrameLayout.forStyle(style, AppMetrics.exportLogicalWidth).height;
