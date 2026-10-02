import 'package:flutter/material.dart';

import '../models/frame_model.dart';

/// Horizontal list of Polaroid paper styles.
class FrameSelector extends StatelessWidget {
  const FrameSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final FrameStyle selected;
  final ValueChanged<FrameStyle> onSelected;

  static const double _itemWidth = 96;
  static const double _height = 116;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: FrameStyle.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final style = FrameStyle.values[index];
          final isSelected = style == selected;

          return Semantics(
            button: true,
            selected: isSelected,
            label: '${style.label} paper',
            child: InkWell(
              key: ValueKey<String>('frame-${style.name}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => onSelected(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: _itemWidth,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? scheme.primary : scheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _PaperSwatch(style: style)),
                    const SizedBox(height: 8),
                    Text(
                      style.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tiny Polaroid preview used inside the selector.
class _PaperSwatch extends StatelessWidget {
  const _PaperSwatch({required this.style});

  final FrameStyle style;

  @override
  Widget build(BuildContext context) {
    final config = style.config;
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      decoration: BoxDecoration(
        color: config.paper,
        borderRadius: BorderRadius.circular(5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF6E7F8D), Color(0xFFB69B7E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
