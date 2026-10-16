import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;

import '../models/filter_model.dart';
import '../models/frame_model.dart';
import '../models/polaroid_model.dart';
import '../utils/constants.dart';
import 'polaroid_frame.dart';

/// One instant print hanging from the line.
@immutable
class LineCarouselSlide {
  const LineCarouselSlide({
    required this.image,
    required this.title,
    required this.caption,
    this.date,
    this.frameStyle = FrameStyle.classic,
    this.filter = FilterType.original,
    this.transform = const ImageTransform.none(),
  });

  /// Photo provider shown inside the print.
  final ImageProvider image;

  /// Handwritten caption printed on the Polaroid card.
  final String title;

  /// Supporting line shown under the title in the bottom bar.
  final String caption;

  /// Optional date stamp (`null` hides it).
  final String? date;

  final FrameStyle frameStyle;
  final FilterType filter;
  final ImageTransform transform;
}

/// Polaroid prints pegged to a sagging string.
///
/// Drag the line to slide the prints, tap one to centre it, focus the
/// carousel and use the arrow keys, or let autoplay step through them.
/// A spring moves the line while each print swings on its peg - the whole
/// simulation is written straight to the DOM widget tree every frame.
class LineCarousel extends StatefulWidget {
  const LineCarousel({
    super.key,
    required this.slides,
    required this.height,
    this.autoplayInterval = const Duration(milliseconds: 4500),
  });

  final List<LineCarouselSlide> slides;

  /// Stage height; the string and prints are laid out inside it.
  final double height;

  /// Delay between automatic steps. The timer pauses while dragging or
  /// shortly after a manual interaction, mirroring the web component.
  final Duration autoplayInterval;

  @override
  State<LineCarousel> createState() => _LineCarouselState();
}

class _LineCarouselState extends State<LineCarousel>
    with SingleTickerProviderStateMixin {
  /// Depth of the string's sag as a fraction of the stage height.
  static const double _sagRatio = 0.06;

  /// Distance of the line's anchor from the top of the stage.
  static const double _y0Ratio = 0.2;

  static const double _springStiffness = 110;
  static const double _springDamping = 18;
  static const double _swingStiffness = 60;
  static const double _swingDamping = 7;
  static const double _swingCouple = 0.0007;
  static const double _idleSway = 0.006;

  late final Ticker _ticker;
  Timer? _autoplay;

  /// Line position: pixels scrolled along the string.
  double _offset = 0;
  double _vel = 0;
  int _targetIndex = 0;
  int _active = 0;

  /// Per print swing (radians) and angular velocity.
  final List<double> _angle = <double>[];
  final List<double> _angleVel = <double>[];

  double _cw = 150;
  double _spacing = 162;
  bool _reduced = false;

  bool _dragging = false;
  double _dragStartX = 0;
  double _dragStartOffset = 0;
  double _dragLastDx = 0;
  double _dragVelMs = 0;
  int _dragLastMs = 0;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);
  Duration? _lastElapsed;

  int get _count => widget.slides.length;
  double get _maxOffset => math.max(0, (_count - 1) * _spacing);

  @override
  void initState() {
    super.initState();
    _angle.addAll(List<double>.filled(widget.slides.length, 0));
    _angleVel.addAll(List<double>.filled(widget.slides.length, 0));
    _ticker = createTicker(_onTick)..start();
    _autoplay = Timer.periodic(widget.autoplayInterval, (_) => _autoAdvance());
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final Duration? previous = _lastElapsed;
    _lastElapsed = elapsed;
    double dt = previous == null
        ? 1 / 60
        : (elapsed - previous).inMicroseconds / 1e6;
    if (dt <= 0) dt = 1 / 60;
    if (dt > 0.033) dt = 0.033;

    final double target = (_targetIndex * _spacing).clamp(0.0, _maxOffset);
    final double before = _offset;
    if (!_dragging) {
      if (_reduced) {
        _offset = target;
        _vel = 0;
      } else {
        _vel +=
            ((target - _offset) * _springStiffness - _vel * _springDamping) *
            dt;
        _offset += _vel * dt;
      }
    }
    final double lineVel = -(_offset - before) / math.max(dt, 1e-3);

    final int near = (_offset / _spacing).round().clamp(0, _count - 1);
    if (near != _active) _active = near;

    if (!_reduced) {
      for (int i = 0; i < _count; i++) {
        _angleVel[i] +=
            ((-_angle[i] * _swingStiffness -
                _angleVel[i] * _swingDamping +
                lineVel * _swingCouple) *
            dt);
        _angle[i] += _angleVel[i] * dt;
        if (_angle[i] > 0.6) _angle[i] = 0.6;
        if (_angle[i] < -0.6) _angle[i] = -0.6;
      }
    } else {
      for (int i = 0; i < _count; i++) {
        _angle[i] = 0;
        _angleVel[i] = 0;
      }
    }

    if (mounted) setState(() {});
  }

  void _goTo(int index) {
    _targetIndex = index.clamp(0, _count - 1);
    _lastTouch = DateTime.now();
  }

  void _step(int direction) {
    _goTo(_active + direction);
    if (mounted) setState(() {});
  }

  void _autoAdvance() {
    if (!mounted || _dragging || _count < 2) return;
    if (DateTime.now().difference(_lastTouch) < widget.autoplayInterval) {
      return;
    }
    _goTo(_active >= _count - 1 ? 0 : _active + 1);
  }

  void _onDragStart(DragStartDetails details) {
    _lastTouch = DateTime.now();
    _dragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartOffset = _offset;
    _dragLastDx = 0;
    _dragVelMs = 0;
    _dragLastMs = DateTime.now().millisecondsSinceEpoch;
    _vel = 0;
    if (mounted) setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final double dx = details.localPosition.dx - _dragStartX;
    double off = _dragStartOffset - dx;
    if (off < 0) {
      off *= 0.35;
    } else if (off > _maxOffset) {
      off = _maxOffset + (off - _maxOffset) * 0.35;
    }
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final int dtMs = math.max(1, nowMs - _dragLastMs);
    final double instVel = (dx - _dragLastDx) / dtMs;
    _dragVelMs = 0.7 * instVel + 0.3 * _dragVelMs;
    _dragLastDx = dx;
    _dragLastMs = nowMs;
    _lastTouch = DateTime.now();
    _offset = off;
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    _vel = -_dragVelMs * 1000;
    _targetIndex = ((_offset - _dragVelMs * 180) / _spacing).round().clamp(
      0,
      _count - 1,
    );
    _lastTouch = DateTime.now();
    if (mounted) setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _step(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _pad(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    _reduced = MediaQuery.disableAnimationsOf(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: 'Polaroid line carousel',
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: SizedBox(
          height: widget.height,
          child: Column(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints cons) {
                    final double w = cons.maxWidth;
                    final double h = cons.maxHeight;
                    final double cw = math.max(
                      150.0,
                      math.min(240.0, math.min(w * 0.42, h * 0.42)),
                    );
                    _cw = cw;
                    _spacing = cw * 1.08;

                    final double y0 = math.max(40, h * _y0Ratio);
                    final double sag = h * _sagRatio;

                    final List<_Slot> slots = <_Slot>[];
                    for (int i = 0; i < _count; i++) {
                      final double x = w / 2 + i * _spacing - _offset;
                      slots.add(_Slot(i, x));
                    }
                    // Farthest prints first so the centred one sits on top.
                    slots.sort(
                      (a, b) =>
                          (b.x - w / 2).abs().compareTo((a.x - w / 2).abs()),
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      onHorizontalDragCancel: () {
                        if (_dragging) _onDragEnd(DragEndDetails());
                      },
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: <Widget>[
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _StringPainter(
                                y0: y0,
                                sag: sag,
                                color: colors.outlineVariant,
                              ),
                            ),
                          ),
                          for (final _Slot slot in slots)
                            _buildPrint(slot, w, y0, sag, colors),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _buildBar(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrint(
    _Slot slot,
    double w,
    double y0,
    double sag,
    ColorScheme colors,
  ) {
    final LineCarouselSlide slide = widget.slides[slot.i];
    final double t = w == 0 ? 0.5 : slot.x / w;
    final double lineY = y0 + 4 * t * (1 - t) * sag;
    final double cardH = FrameLayout.forStyle(slide.frameStyle, _cw).height;

    double angle = _angle[slot.i];
    if (!_reduced) {
      final Duration elapsed = _lastElapsed ?? Duration.zero;
      angle +=
          math.sin(elapsed.inMilliseconds / 1300 + slot.i * 1.7) * _idleSway;
    }

    return Positioned(
      left: slot.x - _cw / 2,
      top: lineY - 4,
      width: _cw,
      height: cardH + 2,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        button: true,
        label: 'Print ${slot.i + 1} of $_count: ${slide.title}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _goTo(slot.i);
            if (mounted) setState(() {});
          },
          child: Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: _cw,
              height: cardH,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: PolaroidFrame(
                      image: slide.image,
                      caption: slide.title,
                      date: slide.date,
                      showDate: slide.date != null,
                      frameStyle: slide.frameStyle,
                      filter: slide.filter,
                      transform: slide.transform,
                      width: _cw,
                    ),
                  ),
                  Positioned(
                    top: -5,
                    left: _cw / 2 - 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppPalette.accentDeep,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppPalette.cream,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(ColorScheme colors) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final LineCarouselSlide slide = widget.slides[_active];
    final String count = '${_pad(_active + 1)} / ${_pad(_count)}';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  slide.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelLarge,
                ),
                Text(
                  slide.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            liveRegion: true,
            label: 'Print ${_active + 1} of $_count: ${slide.title}',
            child: ExcludeSemantics(
              child: Text(
                count,
                style: textTheme.labelLarge?.copyWith(
                  letterSpacing: 1.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: AppStrings.previousPrint,
            onPressed: () => _step(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: AppStrings.nextPrint,
            onPressed: () => _step(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// A print's slot along the line (index and x position).
class _Slot {
  const _Slot(this.i, this.x);

  final int i;
  final double x;
}

/// The sagging string behind the prints.
class _StringPainter extends CustomPainter {
  const _StringPainter({
    required this.y0,
    required this.sag,
    required this.color,
  });

  final double y0;
  final double sag;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final Path path = Path()
      ..moveTo(0, y0)
      ..quadraticBezierTo(size.width / 2, y0 + 2 * sag, size.width, y0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StringPainter oldDelegate) =>
      oldDelegate.y0 != y0 ||
      oldDelegate.sag != sag ||
      oldDelegate.color != color;
}
