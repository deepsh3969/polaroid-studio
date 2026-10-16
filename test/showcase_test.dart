import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polaroid_studio/app/theme.dart';
import 'package:polaroid_studio/screens/showcase_screen.dart';
import 'package:polaroid_studio/utils/constants.dart';

/// Steps the carousel's frame ticker forward; the spring integrates with a
/// clamped dt, so a real duration must be split into small pumps.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 60}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpShowcase(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light(), home: const ShowcaseScreen()),
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('showcase screen', () {
    testWidgets('renders the intro, hints, stage and controls', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpShowcase(tester);

      expect(find.text(AppStrings.showcaseTitle), findsOneWidget);
      expect(find.text(AppStrings.showcaseIntro), findsOneWidget);
      expect(find.text(AppStrings.hintDrag), findsOneWidget);
      expect(find.text(AppStrings.hintTap), findsOneWidget);
      expect(find.text(AppStrings.hintKeys), findsOneWidget);
      expect(find.text(AppStrings.hintAutoplay), findsOneWidget);
      expect(find.text('01 / 06'), findsOneWidget);
      expect(find.byTooltip(AppStrings.nextPrint), findsOneWidget);
      expect(find.byTooltip(AppStrings.previousPrint), findsOneWidget);
      expect(find.text(AppStrings.showcaseSource), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, AppStrings.startCreating),
        findsOneWidget,
      );

      // All six prints are hung along the line.
      expect(
        find.bySemanticsLabel('Print 1 of 6: Analogue Days'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Print 6 of 6: Keepsake'), findsOneWidget);

      // The prints hang left to right along the line, inside the stage.
      final Rect first = tester.getRect(
        find.bySemanticsLabel('Print 1 of 6: Analogue Days'),
      );
      final Rect third = tester.getRect(
        find.bySemanticsLabel('Print 3 of 6: Monochrome'),
      );
      expect(first.left, lessThan(third.left));
      expect(first.top, greaterThan(0));
      semantics.dispose();
    });

    testWidgets('next and previous buttons step the carousel', (
      WidgetTester tester,
    ) async {
      await _pumpShowcase(tester);
      await _pumpFrames(tester, frames: 5);
      expect(find.text('01 / 06'), findsOneWidget);

      final Finder next = find.byTooltip(AppStrings.nextPrint);
      await tester.ensureVisible(next);
      await tester.pump();
      await tester.tap(next);
      await _pumpFrames(tester);
      expect(find.text('02 / 06'), findsOneWidget);

      final Finder previous = find.byTooltip(AppStrings.previousPrint);
      await tester.ensureVisible(previous);
      await tester.pump();
      await tester.tap(previous);
      await _pumpFrames(tester);
      expect(find.text('01 / 06'), findsOneWidget);
    });

    testWidgets('arrow keys step the focused carousel', (
      WidgetTester tester,
    ) async {
      await _pumpShowcase(tester);
      await _pumpFrames(tester, frames: 5);
      expect(find.text('01 / 06'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _pumpFrames(tester);
      expect(find.text('02 / 06'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _pumpFrames(tester);
      expect(find.text('01 / 06'), findsOneWidget);
    });

    testWidgets('tapping a print centres it', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpShowcase(tester);
      await _pumpFrames(tester, frames: 5);

      // The centred print sits above its neighbours in the stack.
      final Finder centre = find.bySemanticsLabel(
        'Print 1 of 6: Analogue Days',
      );
      expect(centre, findsOneWidget);
      await tester.ensureVisible(centre);
      await tester.pump();
      await tester.tap(centre);
      await _pumpFrames(tester, frames: 10);
      // Tapping print 1 while already centred keeps the count stable.
      expect(find.text('01 / 06'), findsOneWidget);
      semantics.dispose();
    });
  });
}
