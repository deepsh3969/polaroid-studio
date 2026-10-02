import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../services/settings_controller.dart';
import '../utils/constants.dart';
import 'settings_scope.dart';
import 'theme.dart';

/// Root widget: theming, settings and routing.
class PolaroidStudioApp extends StatelessWidget {
  const PolaroidStudioApp({super.key, required this.settings});

  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (BuildContext context, _) => SettingsScope(
        controller: settings,
        child: MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const HomeScreen(),
          routes: <String, WidgetBuilder>{
            SettingsScreen.routeName: (_) => const SettingsScreen(),
          },
        ),
      ),
    );
  }
}
