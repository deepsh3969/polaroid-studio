import 'package:flutter/material.dart';

import '../models/filter_model.dart';
import '../models/frame_model.dart';
import '../models/polaroid_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/line_carousel.dart';

/// Component showcase: the Polaroid line carousel, framed like an editorial
/// demo page - intro, hint chips, the live stage and a closing action.
class ShowcaseScreen extends StatelessWidget {
  const ShowcaseScreen({super.key});

  static const String routeName = '/showcase';

  /// One bundled photo, styled six ways with the editor's own frames and
  /// filters so the demo runs completely offline.
  static final List<LineCarouselSlide> _slides = <LineCarouselSlide>[
    const LineCarouselSlide(
      image: samplePhotoProvider,
      title: 'Analogue Days',
      caption: 'Classic paper, untouched colours',
      frameStyle: FrameStyle.classic,
      filter: FilterType.original,
    ),
    LineCarouselSlide(
      image: samplePhotoProvider,
      title: 'Golden Hour',
      caption: 'Vintage Cream with a warm wash',
      frameStyle: FrameStyle.vintageCream,
      filter: FilterType.vintage,
      date: DateStampFormat.dayMonthYear.format(DateTime(2026, 6, 14)),
      transform: const ImageTransform(zoom: 1.15),
    ),
    const LineCarouselSlide(
      image: samplePhotoProvider,
      title: 'Monochrome',
      caption: 'Black frame, deep grayscale',
      frameStyle: FrameStyle.black,
      filter: FilterType.blackWhite,
      transform: ImageTransform(zoom: 1.3, pan: Offset(0.1, -0.08)),
    ),
    LineCarouselSlide(
      image: samplePhotoProvider,
      title: 'Sunday Light',
      caption: 'Warm White paper, gentle glow',
      frameStyle: FrameStyle.warmWhite,
      filter: FilterType.warm,
      date: DateStampFormat.dayMonthYear.format(DateTime(2026, 7, 2)),
      transform: const ImageTransform(zoom: 1.2, pan: Offset(-0.12, 0.06)),
    ),
    const LineCarouselSlide(
      image: samplePhotoProvider,
      title: 'First Light',
      caption: 'Minimal borders, airy fade',
      frameStyle: FrameStyle.minimal,
      filter: FilterType.faded,
      transform: ImageTransform(zoom: 1.1, pan: Offset(0.06, 0.1)),
    ),
    const LineCarouselSlide(
      image: samplePhotoProvider,
      title: 'Keepsake',
      caption: 'Sepia keepsake with room to write',
      frameStyle: FrameStyle.classic,
      filter: FilterType.sepia,
      transform: ImageTransform(zoom: 1.25, pan: Offset(-0.06, -0.1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double stageHeight = (MediaQuery.sizeOf(context).height * 0.58).clamp(
      340.0,
      600.0,
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          AppStrings.showcase,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildIntro(textTheme, colors),
                      const SizedBox(height: 20),
                      LineCarousel(slides: _slides, height: stageHeight),
                      const SizedBox(height: 14),
                      _buildMeta(textTheme, colors),
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text(AppStrings.startCreating),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildIntro(TextTheme textTheme, ColorScheme colors) {
    final List<(IconData, String)> hints = <(IconData, String)>[
      (Icons.swipe, AppStrings.hintDrag),
      (Icons.touch_app_outlined, AppStrings.hintTap),
      (Icons.keyboard_alt_outlined, AppStrings.hintKeys),
      (Icons.play_circle_outline, AppStrings.hintAutoplay),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.showcase,
          style: textTheme.labelLarge?.copyWith(
            letterSpacing: 3,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(AppStrings.showcaseTitle, style: textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(
          AppStrings.showcaseIntro,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final (IconData icon, String label) in hints)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(icon, size: 16, color: colors.primary),
                label: Text(label),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMeta(TextTheme textTheme, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            AppStrings.showcaseMeta,
            style: textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            AppStrings.showcaseSource,
            style: textTheme.labelSmall?.copyWith(letterSpacing: 0.4),
          ),
        ),
      ],
    );
  }
}
