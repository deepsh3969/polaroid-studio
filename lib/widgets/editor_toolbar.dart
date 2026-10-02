import 'package:flutter/material.dart';

import '../models/polaroid_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'caption_editor.dart';
import 'filter_selector.dart';
import 'frame_selector.dart';

/// Scrollable stack of editor controls (frame, filter, caption, adjust,
/// typography and date) shown under the live Polaroid preview.
class EditorToolbar extends StatelessWidget {
  const EditorToolbar({
    super.key,
    required this.config,
    required this.onConfigChanged,
    required this.captionController,
    required this.captionFocusNode,
    required this.captionFieldKey,
    required this.onCaptionChanged,
    required this.thumbnailImage,
    required this.onResetPosition,
  });

  final PolaroidConfig config;
  final ValueChanged<PolaroidConfig> onConfigChanged;
  final TextEditingController captionController;
  final FocusNode captionFocusNode;

  /// Attached to the caption field so the editor can scroll it into view.
  final GlobalKey captionFieldKey;

  final ValueChanged<String> onCaptionChanged;
  final ImageProvider thumbnailImage;
  final VoidCallback onResetPosition;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _SectionHeader(label: AppStrings.sectionFrame),
          FrameSelector(
            selected: config.frameStyle,
            onSelected: (style) =>
                onConfigChanged(config.copyWith(frameStyle: style)),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(label: AppStrings.sectionFilter),
          FilterSelector(
            selected: config.filter,
            previewImage: thumbnailImage,
            onSelected: (filter) =>
                onConfigChanged(config.copyWith(filter: filter)),
          ),
          const SizedBox(height: 18),
          const _SectionHeader(label: AppStrings.sectionCaption),
          CaptionEditor(
            key: captionFieldKey,
            controller: captionController,
            focusNode: captionFocusNode,
            onChanged: onCaptionChanged,
          ),
          const SizedBox(height: 18),
          const _SectionHeader(label: AppStrings.sectionAdjust),
          _AdjustPanel(
            config: config,
            onConfigChanged: onConfigChanged,
            onResetPosition: onResetPosition,
          ),
          const SizedBox(height: 8),
          _TypographyPanel(config: config, onConfigChanged: onConfigChanged),
          const SizedBox(height: 18),
          _DatePanel(config: config, onConfigChanged: onConfigChanged),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Small uppercase section title.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          letterSpacing: 2.2,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Zoom / tilt controls for the photo inside the viewport.
class _AdjustPanel extends StatelessWidget {
  const _AdjustPanel({
    required this.config,
    required this.onConfigChanged,
    required this.onResetPosition,
  });

  final PolaroidConfig config;
  final ValueChanged<PolaroidConfig> onConfigChanged;
  final VoidCallback onResetPosition;

  @override
  Widget build(BuildContext context) {
    final transform = config.transform;
    final minZoom = minZoomForRotation(transform.rotation);

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            const SizedBox(width: 44, child: Text('Zoom')),
            Expanded(
              child: Slider(
                key: const ValueKey<String>('zoom-slider'),
                value: transform.zoom
                    .clamp(minZoom, AppMetrics.maxZoom)
                    .toDouble(),
                min: minZoom,
                max: AppMetrics.maxZoom,
                onChanged: (value) => onConfigChanged(
                  config.copyWith(
                    transform: transform.copyWith(zoom: value).normalized(),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '${transform.zoom.toStringAsFixed(1)}x',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        Row(
          children: <Widget>[
            const SizedBox(width: 44, child: Text('Tilt')),
            Expanded(
              child: Slider(
                key: const ValueKey<String>('rotation-slider'),
                value: transform.rotation
                    .clamp(-AppMetrics.maxRotation, AppMetrics.maxRotation)
                    .toDouble(),
                min: -AppMetrics.maxRotation,
                max: AppMetrics.maxRotation,
                onChanged: (value) => onConfigChanged(
                  config.copyWith(
                    transform: transform.copyWith(rotation: value).normalized(),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '${(transform.rotation * 180 / 3.14159).toStringAsFixed(0)}°',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey<String>('reset-position'),
            onPressed: onResetPosition,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(AppStrings.resetPosition),
          ),
        ),
        Text(
          'Pinch to zoom, drag to reposition, double tap to reset.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Font family, size, spacing, alignment and colour controls.
class _TypographyPanel extends StatelessWidget {
  const _TypographyPanel({required this.config, required this.onConfigChanged});

  final PolaroidConfig config;
  final ValueChanged<PolaroidConfig> onConfigChanged;

  static const List<Color> _colors = <Color>[
    Color(0xFF26211B),
    Color(0xFF4A3B28),
    Color(0xFF9B6A4A),
    Color(0xFF7A1F1F),
    Color(0xFF1F3A5F),
    Color(0xFFFDFBF4),
  ];

  @override
  Widget build(BuildContext context) {
    final style = config.captionStyle;
    final scheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const ValueKey<String>('typography-panel'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
        title: Text(
          AppStrings.sectionTypography,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final font in CaptionFont.values)
                ChoiceChip(
                  key: ValueKey<String>('font-${font.name}'),
                  label: Text(font.label),
                  selected: style.font == font,
                  onSelected: (_) => onConfigChanged(
                    config.copyWith(captionStyle: style.copyWith(font: font)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const SizedBox(width: 56, child: Text('Size')),
              Expanded(
                child: Slider(
                  key: const ValueKey<String>('font-size-slider'),
                  value: style.sizeScale.clamp(0.7, 1.4).toDouble(),
                  min: 0.7,
                  max: 1.4,
                  onChanged: (value) => onConfigChanged(
                    config.copyWith(
                      captionStyle: style.copyWith(sizeScale: value),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const SizedBox(width: 56, child: Text('Spacing')),
              Expanded(
                child: Slider(
                  key: const ValueKey<String>('letter-spacing-slider'),
                  value: style.letterSpacing.clamp(0.0, 4.0).toDouble(),
                  min: 0,
                  max: 4,
                  onChanged: (value) => onConfigChanged(
                    config.copyWith(
                      captionStyle: style.copyWith(letterSpacing: value),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const SizedBox(width: 56, child: Text('Align')),
              SegmentedButton<TextAlign>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const <ButtonSegment<TextAlign>>[
                  ButtonSegment<TextAlign>(
                    value: TextAlign.left,
                    icon: Icon(Icons.format_align_left_rounded, size: 18),
                    tooltip: 'Align left',
                  ),
                  ButtonSegment<TextAlign>(
                    value: TextAlign.center,
                    icon: Icon(Icons.format_align_center_rounded, size: 18),
                    tooltip: 'Align centre',
                  ),
                  ButtonSegment<TextAlign>(
                    value: TextAlign.right,
                    icon: Icon(Icons.format_align_right_rounded, size: 18),
                    tooltip: 'Align right',
                  ),
                ],
                selected: <TextAlign>{style.align},
                onSelectionChanged: (selection) => onConfigChanged(
                  config.copyWith(
                    captionStyle: style.copyWith(align: selection.first),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(width: 56, child: Text('Colour')),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final color in _colors)
                      _ColorDot(
                        color: color,
                        selected: style.color == color,
                        onTap: () => onConfigChanged(
                          config.copyWith(
                            captionStyle: style.copyWith(color: color),
                          ),
                        ),
                      ),
                    _ColorDot(
                      color: scheme.surface,
                      border: scheme.onSurface,
                      selected: style.color == null,
                      label: 'A',
                      onTap: () => onConfigChanged(
                        config.copyWith(
                          captionStyle: style.copyWith(clearColor: true),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
    this.border,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label == null ? 'Caption colour' : 'Frame default colour',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : border ?? scheme.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: label == null
              ? null
              : Center(
                  child: Text(
                    label!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: border ?? scheme.onSurface,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Date stamp toggle plus format chooser.
class _DatePanel extends StatelessWidget {
  const _DatePanel({required this.config, required this.onConfigChanged});

  final PolaroidConfig config;
  final ValueChanged<PolaroidConfig> onConfigChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppStrings.showDate,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            Switch(
              key: const ValueKey<String>('date-switch'),
              value: config.showDate,
              onChanged: (value) =>
                  onConfigChanged(config.copyWith(showDate: value)),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: config.showDate
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final format in DateStampFormat.values)
                        ChoiceChip(
                          key: ValueKey<String>('date-format-${format.name}'),
                          label: Text(format.label),
                          selected: config.dateFormat == format,
                          onSelected: (_) => onConfigChanged(
                            config.copyWith(dateFormat: format),
                          ),
                        ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (config.showDate)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Stamped with your device date: ${config.formattedDate}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
