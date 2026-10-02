import 'package:flutter/material.dart';

import '../services/settings_controller.dart';

/// Exposes the persisted [SettingsController] to the widget tree.
///
/// Widgets read it with `SettingsScope.of(context)` and are rebuilt whenever a
/// preference changes.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static SettingsController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope is missing above this context');
    return scope!.notifier!;
  }
}
