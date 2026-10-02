import 'package:flutter/material.dart';

import '../models/filter_model.dart';
import '../services/filter_service.dart';

/// Horizontal list of vintage filters with live thumbnails.
class FilterSelector extends StatelessWidget {
  const FilterSelector({
    super.key,
    required this.selected,
    required this.previewImage,
    required this.onSelected,
  });

  final FilterType selected;

  /// Small, cheap to decode preview of the current photo.
  final ImageProvider previewImage;

  final ValueChanged<FilterType> onSelected;

  static const double _thumbSize = 66;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: _thumbSize + 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: FilterType.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (BuildContext context, int index) {
          final filter = FilterType.values[index];
          final isSelected = filter == selected;

          return Semantics(
            button: true,
            selected: isSelected,
            label: '${filter.label} filter',
            child: InkWell(
              key: ValueKey<String>('filter-${filter.name}'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelected(filter),
              child: SizedBox(
                width: 76,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: EdgeInsets.all(isSelected ? 3 : 1),
                      decoration: BoxDecoration(
                        color: isSelected ? scheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: SizedBox(
                          width: _thumbSize,
                          height: _thumbSize,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix(
                              FilterService.matrixFor(filter),
                            ),
                            child: Image(
                              image: previewImage,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.low,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      filter.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? scheme.primary
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
