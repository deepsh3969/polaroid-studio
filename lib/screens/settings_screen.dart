import 'package:flutter/material.dart';

import '../app/settings_scope.dart';
import '../models/polaroid_model.dart';
import '../utils/constants.dart';

/// App preferences: appearance, default date format, animations and about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          AppStrings.settings,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: <Widget>[
          _sectionLabel(context, 'Appearance'),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const <ButtonSegment<ThemeMode>>[
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto_rounded, size: 18),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined, size: 18),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined, size: 18),
              ),
            ],
            selected: <ThemeMode>{settings.themeMode},
            onSelectionChanged: (selection) =>
                settings.setThemeMode(selection.first),
          ),
          const SizedBox(height: 26),
          _sectionLabel(context, AppStrings.dateFormatLabel),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final format in DateStampFormat.values)
                ChoiceChip(
                  key: ValueKey<String>('settings-date-${format.name}'),
                  label: Text(format.label),
                  selected: settings.dateFormat == format,
                  onSelected: (_) => settings.setDateFormat(format),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Used for new Polaroids.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 26),
          _sectionLabel(context, 'Motion'),
          SwitchListTile(
            key: const ValueKey<String>('settings-animation'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Developing animation'),
            subtitle: const Text('Reveal the print when previewing a Polaroid'),
            value: settings.animateDeveloping,
            onChanged: settings.setAnimateDeveloping,
          ),
          const Divider(height: 28),
          _sectionLabel(context, 'About'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(AppStrings.appName, style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.privacyNotice,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
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
