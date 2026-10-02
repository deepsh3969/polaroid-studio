import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences are read before the first frame so the correct theme applies
  // immediately. Failures fall back to in-memory defaults.
  final settings = await SettingsController.load();

  runApp(PolaroidStudioApp(settings: settings));
}
