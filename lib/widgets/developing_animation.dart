import 'package:flutter/material.dart';

import '../utils/constants.dart';

/// Builds the child for a given development progress (`0` blank .. `1` done).
typedef DevelopingBuilder = Widget Function(
  BuildContext context,
  double progress,
);

/// Plays the "photo developing" reveal: the print fades in, scales up and the
/// photo slowly gains opacity and saturation.
///
/// The animation never blocks the UI and can be skipped at any time.
class DevelopingAnimation extends StatefulWidget {
  const DevelopingAnimation({
    super.key,
    required this.enabled,
    required this.builder,
    this.duration = AppMetrics.developingDuration,
    this.onComplete,
  });

  final bool enabled;

  /// Duration of the reveal (2 - 4 seconds is the sweet spot).
  final Duration duration;

  final DevelopingBuilder builder;
  final VoidCallback? onComplete;

  @override
  State<DevelopingAnimation> createState() => _DevelopingAnimationState();
}

class _DevelopingAnimationState extends State<DevelopingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.enabled) {
      _controller.forward().whenComplete(_handleComplete);
    } else {
      _controller.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleComplete());
    }
  }

  void _handleComplete() {
    if (!mounted) return;
    widget.onComplete?.call();
  }

  void _skip() {
    if (_controller.value >= 1) return;
    _controller.animateTo(1, duration: const Duration(milliseconds: 320));
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
      builder: (BuildContext context, _) {
        final progress = _controller.value;
        final animating = widget.enabled && progress < 1;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: animating ? _skip : null,
              child: Transform.scale(
                scale: 0.965 + 0.035 * progress,
                child: Opacity(
                  opacity: 0.12 + 0.88 * progress,
                  child: widget.builder(context, progress),
                ),
              ),
            ),
            if (animating)
              Positioned(
                top: -14,
                right: -6,
                child: Semantics(
                  button: true,
                  label: 'Skip the developing animation',
                  child: Material(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    elevation: 2,
                    child: InkWell(
                      onTap: _skip,
                      borderRadius: BorderRadius.circular(20),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          AppStrings.skipAnimation,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
