import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/app/app.dart';
import 'package:polaroid_studio/models/filter_model.dart';
import 'package:polaroid_studio/models/frame_model.dart';
import 'package:polaroid_studio/models/polaroid_model.dart';
import 'package:polaroid_studio/services/settings_controller.dart';
import 'package:polaroid_studio/utils/constants.dart';
import 'package:polaroid_studio/utils/helpers.dart';
import 'package:polaroid_studio/widgets/polaroid_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `path_provider` has no engine behind it in widget tests, so the history
/// load would wait forever without this mock.
void _mockPathProvider(Directory documents) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall call) async =>
            call.method == 'getApplicationDocumentsDirectory'
            ? documents.path
            : null,
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final Directory documents = Directory.systemTemp.createTempSync(
    'polaroid_studio_test',
  );
  _mockPathProvider(documents);
  tearDownAll(() async {
    if (documents.existsSync()) {
      documents.deleteSync(recursive: true);
    }
  });

  group('home screen', () {
    testWidgets('shows the brand, primary actions and empty history', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      // The history load touches real files, which only progresses inside
      // `runAsync` (widget tests otherwise run on a fake clock).
      await tester.runAsync(() async {
        await tester.pumpWidget(
          PolaroidStudioApp(settings: SettingsController.defaults()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text(AppStrings.brandLine1), findsOneWidget);
      expect(find.text(AppStrings.brandLine2), findsOneWidget);
      expect(find.text(AppStrings.takePhoto), findsOneWidget);
      expect(find.text(AppStrings.chooseFromGallery), findsOneWidget);
      expect(find.text(AppStrings.recentCreations), findsOneWidget);

      // The history resolves to an empty list in the test environment.
      expect(find.text(AppStrings.emptyCreations), findsOneWidget);

      // The bundled example print is rendered on the landing screen.
      expect(find.text('Analogue days'), findsOneWidget);
    });

    testWidgets('opens settings and stores the chosen theme mode', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = SettingsController.defaults();
      await tester.pumpWidget(PolaroidStudioApp(settings: settings));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const ValueKey<String>('settings-button')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settings), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('settings-animation')),
        findsOneWidget,
      );

      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(settings.themeMode, ThemeMode.dark);

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-date-numeric')),
      );
      await tester.pump();
      expect(settings.dateFormat, DateStampFormat.numeric);
    });
  });

  group('polaroid frame', () {
    testWidgets('renders the photo, caption and date stamp', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PolaroidFrame(
                image: samplePhotoProvider,
                caption: 'Analogue days',
                frameStyle: FrameStyle.classic,
                filter: FilterType.vintage,
                showDate: true,
                date: '02 OCT 2026',
                width: 300,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Analogue days'), findsOneWidget);
      expect(find.text('02 OCT 2026'), findsOneWidget);

      final frame = tester.widget<PolaroidFrame>(find.byType(PolaroidFrame));
      final layout = FrameLayout.forStyle(FrameStyle.classic, 300);
      expect(find.byType(SizedBox), findsWidgets);

      // The card keeps the exact geometry the exporter relies on.
      expect(layout.photoSize, 300 - 2 * layout.sidePadding);
      expect(frame.width, 300);
      expect(
        layout.height,
        layout.topPadding + layout.photoSize + layout.bottomBarHeight,
      );
    });

    testWidgets('hides the date stamp when it is switched off', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PolaroidFrame(
              image: samplePhotoProvider,
              caption: 'No date',
              showDate: false,
              date: '02 OCT 2026',
              width: 260,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No date'), findsOneWidget);
      expect(find.text('02 OCT 2026'), findsNothing);
    });
  });
}
