import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../util/format.dart';
import 'models.dart';

/// Every read and write the app does. After each write, [changes] ticks so open screens reload.
class Repo {
  Repo(this.db);

  final Database db;
  final changes = ValueNotifier<int>(0);

  void _changed() => changes.value++;

  // ---------- Exercises ----------

  Future<List<Exercise>> listExercises() async {
    final rows = await db.rawQuery('SELECT * FROM exercise ORDER BY name COLLATE NOCASE');
    return rows.map(Exercise.fromRow).toList();
  }

  /// The sets from the most recent saved workout that contains each exercise, keyed by
  /// exercise id. [excludeWorkoutId] leaves out the workout being logged.
  Future<Map<int, List<WorkoutSet>>> lastSetsByExercise({int? excludeWorkoutId}) async {
    final rows = await db.rawQuery('''
      SELECT we.exercise_id AS ex_id, we.id AS we_id, s.*
        FROM workout_set s
        JOIN workout_exercise we ON we.id = s.workout_exercise_id
        JOIN workout w ON w.id = we.workout_id
       WHERE w.status = 'done' AND w.id != ?
       ORDER BY w.date DESC, w.id DESC, we.position, s.position''', [excludeWorkoutId ?? -1]);
    final used = <int, int>{}; // exercise id -> workout_exercise id it came from
    final result = <int, List<WorkoutSet>>{};
    for (final r in rows) {
      final exId = r['ex_id'] as int;
      final weId = r['we_id'] as int;
      final first = used.putIfAbsent(exId, () => weId);
      if (first != weId) continue;
      result.putIfAbsent(exId, () => []).add(WorkoutSet.fromRow(r));
    }
    return result;
  }

  // ---------- Workouts ----------

  /// A workout that was started (live) or is being typed in (manual) and isn't saved yet.
  Future<Workout?> openWorkout() async {
    final rows = await db.rawQuery(
        "SELECT * FROM workout WHERE status IN ('live', 'manual') ORDER BY id DESC LIMIT 1");
    return rows.isEmpty ? null : Workout.fromRow(rows.first);
  }

  Future<int> createWorkout(WorkoutStatus status) async {
    final id = await db.insert('workout', {'name': 'Workout', 'date': todayIso(), 'status': status.name});
    _changed();
    return id;
  }

  Future<Workout?> workout(int id) async {
    final rows = await db.query('workout', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Workout.fromRow(rows.first);
  }

  Future<void> renameWorkout(int id, String name) => _updateWorkout(id, {'name': name});

  Future<void> setWorkoutDate(int id, String isoDate) => _updateWorkout(id, {'date': isoDate});

  Future<void> _updateWorkout(int id, Map<String, Object?> fields) async {
    await db.update('workout', fields, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  Future<void> deleteWorkout(int id) async {
    await db.delete('workout', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  /// First set's start to last set's end, in seconds. Null when no set was timed.
  Future<int?> timedDuration(int workoutId) async {
    final r = (await db.rawQuery('''
      SELECT MIN(s.started_at) AS first, MAX(s.started_at + s.time_seconds * 1000) AS last
        FROM workout_set s JOIN workout_exercise we ON we.id = s.workout_exercise_id
       WHERE we.workout_id = ? AND s.started_at IS NOT NULL AND s.time_seconds IS NOT NULL''',
        [workoutId]))
        .first;
    final first = r['first'] as int?;
    final last = r['last'] as int?;
    if (first == null || last == null) return null;
    return ((last - first) / 1000).round();
  }

  /// Saves the workout: every exercise is marked done and the workout is done.
  Future<void> finishWorkout(int id,
      {required String name, required String date, required int? durationSeconds, required String? notes}) async {
    await db.transaction((txn) async {
      await txn.update('workout_exercise', {'done': 1}, where: 'workout_id = ?', whereArgs: [id]);
      await txn.update(
        'workout',
        {'name': name, 'date': date, 'duration_seconds': durationSeconds, 'notes': notes, 'status': 'done'},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    _changed();
  }

  /// Saved workouts between two ISO dates (inclusive), with how many exercises each has.
  Future<List<WeekWorkout>> workoutsBetween(String fromIso, String toIso) async {
    final rows = await db.rawQuery('''
      SELECT w.*, (SELECT COUNT(*) FROM workout_exercise we WHERE we.workout_id = w.id) AS exercise_count
        FROM workout w
       WHERE w.status = 'done' AND w.date BETWEEN ? AND ?
       ORDER BY w.date, w.id''', [fromIso, toIso]);
    return rows.map((r) => WeekWorkout(Workout.fromRow(r), r['exercise_count'] as int)).toList();
  }

  // ---------- Exercises inside a workout ----------

  static const _workoutExerciseSelect = '''
    SELECT we.*, e.name, e.measures,
           (SELECT COUNT(*) FROM workout_set s WHERE s.workout_exercise_id = we.id) AS set_count
      FROM workout_exercise we JOIN exercise e ON e.id = we.exercise_id''';

  Future<List<WorkoutExercise>> workoutExercises(int workoutId) async {
    final rows = await db.rawQuery('$_workoutExerciseSelect WHERE we.workout_id = ? ORDER BY we.position', [workoutId]);
    return rows.map(WorkoutExercise.fromRow).toList();
  }

  Future<WorkoutExercise?> workoutExercise(int id) async {
    final rows = await db.rawQuery('$_workoutExerciseSelect WHERE we.id = ?', [id]);
    return rows.isEmpty ? null : WorkoutExercise.fromRow(rows.first);
  }

  Future<int> addWorkoutExercise(int workoutId, int exerciseId) async {
    final id = await db.rawInsert('''
      INSERT INTO workout_exercise (workout_id, exercise_id, position)
      VALUES (?, ?, (SELECT COALESCE(MAX(position), 0) + 1 FROM workout_exercise WHERE workout_id = ?))''',
        [workoutId, exerciseId, workoutId]);
    _changed();
    return id;
  }

  Future<void> removeWorkoutExercise(int id) async {
    await db.delete('workout_exercise', where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  /// Swaps an exercise with its neighbour above (-1) or below (+1).
  Future<void> moveWorkoutExercise(int workoutId, int id, int direction) async {
    final list = await workoutExercises(workoutId);
    final i = list.indexWhere((we) => we.id == id);
    final j = i + direction;
    if (i < 0 || j < 0 || j >= list.length) return;
    await db.transaction((txn) async {
      await txn.update('workout_exercise', {'position': list[j].position}, where: 'id = ?', whereArgs: [list[i].id]);
      await txn.update('workout_exercise', {'position': list[i].position}, where: 'id = ?', whereArgs: [list[j].id]);
    });
    _changed();
  }

  Future<void> setExerciseDone(int id, bool done) async {
    await db.update('workout_exercise', {'done': done ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
    _changed();
  }

  // ---------- Sets ----------

  Future<List<WorkoutSet>> sets(int workoutExerciseId) async {
    final rows = await db.query('workout_set',
        where: 'workout_exercise_id = ?', whereArgs: [workoutExerciseId], orderBy: 'position');
    return rows.map(WorkoutSet.fromRow).toList();
  }

  /// Starts the next set's timer at [now] (epoch ms). If [endRest], the previous set's rest
  /// ends now and is saved on that set. Not after reopening a done exercise: that rest was dropped.
  Future<void> startSet(int workoutExerciseId, int now, {required bool endRest}) async {
    await db.transaction((txn) async {
      final rows = await txn.query('workout_set',
          where: 'workout_exercise_id = ?', whereArgs: [workoutExerciseId], orderBy: 'position DESC', limit: 1);
      final last = rows.isEmpty ? null : WorkoutSet.fromRow(rows.first);
      final end = last?.endedAt;
      if (endRest && last != null && end != null && last.restSeconds == null) {
        final rest = ((now - end) / 1000).round();
        await txn.update('workout_set', {'rest_seconds': rest < 0 ? 0 : rest},
            where: 'id = ?', whereArgs: [last.id]);
      }
      await txn.insert('workout_set', {
        'workout_exercise_id': workoutExerciseId,
        'position': (last?.position ?? 0) + 1,
        'started_at': now,
      });
    });
    _changed();
  }

  /// Stops a running set's timer at [now] and writes how long it took.
  Future<void> stopSet(WorkoutSet set, int now) async {
    final started = set.startedAt;
    if (started == null) return;
    final seconds = ((now - started) / 1000).round();
    await db.update('workout_set', {'time_seconds': seconds < 1 ? 1 : seconds}, where: 'id = ?', whereArgs: [set.id]);
    _changed();
  }

  /// Undoes an accidental stop: the set runs again from its original start.
  Future<void> continueSet(int id) async {
    await db.update('workout_set', {'time_seconds': null}, where: 'id = ? AND started_at IS NOT NULL', whereArgs: [id]);
    _changed();
  }

  Future<void> updateSet(int id, SetValues v) async {
    await db.update(
      'workout_set',
      {'reps': v.reps, 'weight_kg': v.weightKg, 'time_seconds': v.timeSeconds, 'distance_km': v.distanceKm},
      where: 'id = ?',
      whereArgs: [id],
    );
    _changed();
  }

  Future<void> addManualSet(int workoutExerciseId, SetValues v) async {
    await db.rawInsert('''
      INSERT INTO workout_set (workout_exercise_id, position, reps, weight_kg, time_seconds, distance_km)
      VALUES (?, (SELECT COALESCE(MAX(position), 0) + 1 FROM workout_set WHERE workout_exercise_id = ?), ?, ?, ?, ?)''',
        [workoutExerciseId, workoutExerciseId, v.reps, v.weightKg, v.timeSeconds, v.distanceKm]);
    _changed();
  }

  Future<void> deleteSet(int id) async {
    await db.delete('workout_set', where: 'id = ?', whereArgs: [id]);
    _changed();
  }
}
