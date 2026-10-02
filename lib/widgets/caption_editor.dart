import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/constants.dart';

/// Text field for the Polaroid caption with a `0 / 40` character counter.
class CaptionEditor extends StatelessWidget {
  const CaptionEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Caption, maximum ${AppMetrics.captionMaxLength} characters',
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        maxLength: AppMetrics.captionMaxLength,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(AppMetrics.captionMaxLength),
        ],
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Add a caption...',
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: scheme.primary, width: 1.6),
          ),
        ),
        buildCounter:
            (
              BuildContext context, {
              required int currentLength,
              required bool isFocused,
              int? maxLength,
            }) => Text(
              '$currentLength / ${maxLength ?? AppMetrics.captionMaxLength}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
      ),
    );
  }
}
