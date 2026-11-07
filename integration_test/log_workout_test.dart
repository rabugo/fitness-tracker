// Drives the real app on the phone, like a person tapping. Uses its own database file,
// so my real workouts are never touched. Run with:
//   flutter test integration_test -d <device> --no-uninstall
// (--no-uninstall: without it, the app is uninstalled afterwards and all data is lost.)
import 'package:fitness_tracker/app.dart';
import 'package:fitness_tracker/db/database.dart';
import 'package:fitness_tracker/db/repo.dart';
import 'package:fitness_tracker/main.dart';
import 'package:fitness_tracker/widgets/timer_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    final path = p.join(await getDatabasesPath(), 'integration_test.db');
    await deleteDatabase(path);
    repo = Repo(await openAppDatabase(path: path));
    currentTab.value = 0;
  });

  tearDown(() => repo.db.close());

  /// Pumps frame by frame for [duration] and fails if [text] ever shows.
  Future<void> neverShows(WidgetTester tester, String text, Duration duration) async {
    final frames = duration.inMilliseconds ~/ 16;
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text(text), findsNothing, reason: '"$text" flashed on screen');
    }
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.widgetWithText(TextField, label), value);
    await tester.pump();
  }

  testWidgets('start a workout: no flash of the Resume card', (tester) async {
    await tester.pumpWidget(const FitnessApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start workout'));
    await neverShows(tester, 'Workout in progress', const Duration(milliseconds: 800));
    expect(find.text('Add exercise'), findsOneWidget);
  });

  testWidgets('log a past workout: no flash of the Resume card', (tester) async {
    await tester.pumpWidget(const FitnessApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log a past workout'));
    await neverShows(tester, 'Past workout not saved yet', const Duration(milliseconds: 800));
    expect(find.text('Add exercise'), findsOneWidget);
  });

  testWidgets('stop, save set, rest; stop, continue', (tester) async {
    await tester.pumpWidget(const FitnessApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench press'));
    await tester.pumpAndSettle();

    // Set 1: start, stop → paused (yellow) with the time filled in.
    await tester.tap(find.byType(TimerCircle));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byType(TimerCircle));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Paused · tap the timer to continue'), findsOneWidget);
    final time = tester.widget<TextField>(find.widgetWithText(TextField, 'Time (m:ss)'));
    expect(time.controller!.text, isNot(isEmpty), reason: 'the stopped time must be filled in');

    // Save set → rest timer (red), the set is saved, not running again.
    await fill(tester, 'Reps', '8');
    await fill(tester, 'kg', '60');
    await tester.tap(find.text('Save set'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Rest'), findsOneWidget);
    expect(find.text('Resting after set 1 · tap to start set 2'), findsOneWidget);
    expect(find.textContaining('1 · 8 × 60 kg'), findsOneWidget);
    expect(tester.widget<TimerCircle>(find.byType(TimerCircle)).mode, TimerMode.resting);

    // Set 2: start (ends the rest), stop, then continue by tapping the timer.
    await tester.tap(find.byType(TimerCircle));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('rested'), findsOneWidget);
    await tester.tap(find.byType(TimerCircle));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Paused · tap the timer to continue'), findsOneWidget);
    await tester.tap(find.byType(TimerCircle));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Rest'), findsNothing, reason: 'the rest timer flashed while continuing');
    }
    expect(tester.widget<TimerCircle>(find.byType(TimerCircle)).mode, TimerMode.running);
    expect(tester.widget<TimerCircle>(find.byType(TimerCircle)).seconds, greaterThan(2));

    // Stop and save set 2 too, then Done.
    await tester.tap(find.byType(TimerCircle));
    await tester.pump(const Duration(milliseconds: 500));
    await fill(tester, 'Reps', '8');
    await fill(tester, 'kg', '60');
    await tester.tap(find.text('Save set'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('2 · 8 × 60 kg'), findsOneWidget);
    expect(tester.widget<TimerCircle>(find.byType(TimerCircle)).mode, TimerMode.resting);
  });
}
