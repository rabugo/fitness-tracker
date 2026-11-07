// The database flows of spec 01-log-workouts, against a real SQLite in memory.
import 'package:fitness_tracker/db/database.dart';
import 'package:fitness_tracker/db/models.dart';
import 'package:fitness_tracker/db/repo.dart';
import 'package:fitness_tracker/util/format.dart';
import 'package:fitness_tracker/util/sets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Repo repo;
  late Exercise bench;
  late Exercise plank;
  late Exercise squat;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    final db = await openAppDatabase(factory: databaseFactoryFfiNoIsolate, path: inMemoryDatabasePath);
    repo = Repo(db);
    final all = await repo.listExercises();
    bench = all.firstWhere((e) => e.name == 'Bench press');
    plank = all.firstWhere((e) => e.name == 'Plank');
    squat = all.firstWhere((e) => e.name == 'Squat');
  });

  tearDown(() => repo.db.close());

  /// A live workout on Monday 12/10/2026 with three bench sets and one plank set.
  Future<int> logPush() async {
    final t0 = DateTime(2026, 10, 12, 8).millisecondsSinceEpoch;
    final w = await repo.createWorkout(WorkoutStatus.live);
    await repo.setWorkoutDate(w, '2026-10-12');
    final we1 = await repo.addWorkoutExercise(w, bench.id);

    await repo.startSet(we1, t0, endRest: false);
    var s = await repo.sets(we1);
    await repo.stopSet(s[0], t0 + 42000);
    await repo.updateSet(s[0].id, const SetValues(reps: 8, weightKg: 60, timeSeconds: 42));

    await repo.startSet(we1, t0 + 132000, endRest: true); // rested 1:30
    s = await repo.sets(we1);
    await repo.stopSet(s[1], t0 + 172000);
    await repo.updateSet(s[1].id, const SetValues(reps: 8, weightKg: 60, timeSeconds: 40));

    // Done drops the running rest; reopening and starting a set must not invent one.
    await repo.setExerciseDone(we1, true);
    await repo.setExerciseDone(we1, false);
    await repo.startSet(we1, t0 + 600000, endRest: false);
    s = await repo.sets(we1);
    await repo.stopSet(s[2], t0 + 630000);
    await repo.updateSet(s[2].id, const SetValues(reps: 6, weightKg: 65, timeSeconds: 30));
    await repo.setExerciseDone(we1, true);

    final we2 = await repo.addWorkoutExercise(w, plank.id);
    await repo.startSet(we2, t0 + 700000, endRest: false);
    await repo.stopSet((await repo.sets(we2)).first, t0 + 745000);
    return w;
  }

  test('seeds 30 exercises with their measures', () async {
    expect((await repo.listExercises()).length, 30);
    expect(bench.measures, [Measure.reps, Measure.weight]);
    expect(plank.measures, [Measure.time]);
  });

  test('set timer, rest timer and set lines', () async {
    final w = await logPush();
    final we = (await repo.workoutExercises(w)).first;
    final s = await repo.sets(we.id);
    expect(s[0].restSeconds, 90);
    expect(formatSetLine(s[0], bench.measures), '1 · 8 × 60 kg · 0:42 · rest 1:30');
    expect(s[1].restSeconds, isNull, reason: 'reopened exercise: the dropped rest stays empty');
    expect(we.done, isTrue);
    expect(we.setCount, 3);
  });

  test('resume, reorder, duration from the timers, finish', () async {
    final w = await logPush();
    expect((await repo.openWorkout())?.id, w);

    final list = await repo.workoutExercises(w);
    await repo.moveWorkoutExercise(w, list[1].id, -1);
    expect((await repo.workoutExercises(w)).map((e) => e.name), ['Plank', 'Bench press']);

    final timed = await repo.timedDuration(w);
    expect(timed, 745);
    expect(formatDuration(timed), '0:12');

    await repo.finishWorkout(w, name: 'Push', date: '2026-10-12', durationSeconds: timed, notes: null);
    expect(await repo.openWorkout(), isNull);
    expect((await repo.workoutExercises(w)).every((e) => e.done), isTrue);
  });

  test('last time, past workout, week Monday to Sunday', () async {
    final w1 = await logPush();
    await repo.finishWorkout(w1, name: 'Push', date: '2026-10-12', durationSeconds: 745, notes: null);

    final w2 = await repo.createWorkout(WorkoutStatus.live);
    var last = await repo.lastSetsByExercise(excludeWorkoutId: w2);
    expect(formatLastTime(last[bench.id], bench.measures), 'Last: 8 × 60 kg, 8 × 60 kg, 6 × 65 kg');
    expect(formatLastTime(last[plank.id], plank.measures), 'Last: 0:45');
    expect(formatLastTime(last[squat.id], squat.measures), 'First time');
    await repo.deleteWorkout(w2);

    final w3 = await repo.createWorkout(WorkoutStatus.manual);
    final we3 = await repo.addWorkoutExercise(w3, bench.id);
    for (var i = 0; i < 3; i++) {
      await repo.addManualSet(we3, const SetValues(reps: 5, weightKg: 70));
    }
    expect(await repo.timedDuration(w3), isNull);
    await repo.finishWorkout(w3,
        name: 'Past', date: '2026-10-15', durationSeconds: parseDuration('1:05'), notes: 'felt good');
    last = await repo.lastSetsByExercise();
    expect(formatLastTime(last[bench.id], bench.measures), 'Last: 3 × 5 @ 70 kg');

    final monday = startOfWeek(DateTime(2026, 10, 18)); // a Sunday
    expect(toIsoDate(monday), '2026-10-12');
    expect(weekdayName(monday), 'Monday');
    final week = await repo.workoutsBetween(toIsoDate(monday), toIsoDate(addDays(monday, 6)));
    expect(week.map((w) => w.workout.name), ['Push', 'Past']);
    expect(week.first.exerciseCount, 2);
    final total = week.fold<int>(0, (sum, w) => sum + (w.workout.durationSeconds ?? 0));
    expect(formatDuration(total), '1:17');
    expect(await repo.workoutsBetween('2026-10-19', '2026-10-25'), isEmpty);
  });

  test('correct a set, remove a set, delete cascades', () async {
    final w = await repo.createWorkout(WorkoutStatus.manual);
    final we = await repo.addWorkoutExercise(w, bench.id);
    await repo.addManualSet(we, const SetValues(reps: 5, weightKg: 70));
    await repo.addManualSet(we, const SetValues(reps: 5, weightKg: 70));
    final s = await repo.sets(we);
    await repo.updateSet(s[0].id, const SetValues(reps: 6, weightKg: 70));
    await repo.deleteSet(s[1].id);
    expect((await repo.sets(we)).single.reps, 6);
    await repo.deleteWorkout(w);
    expect(await repo.sets(we), isEmpty);
  });

  test('formats', () {
    expect(formatClock(42), '0:42');
    expect(formatClock(3725), '1:02:05');
    expect(parseClock('1:30'), 90);
    expect(parseNumber('62,5'), 62.5);
    expect(parseDuration('45'), 2700);
    expect(formatDate('2026-10-12'), '12/10/2026');
  });
}
