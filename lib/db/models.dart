// Row types. Names and fields follow data-model.md in the ICM workspace.

enum Measure { reps, weight, time, distance }

enum Category { strength, cardio, core, mobility }

/// live = working out with timers; manual = typing in a past workout; done = saved.
enum WorkoutStatus { live, manual, done }

List<Measure> parseMeasures(String s) =>
    s.split(',').where((m) => m.isNotEmpty).map((m) => Measure.values.byName(m)).toList();

String measuresToString(List<Measure> m) => m.map((x) => x.name).join(',');

class Exercise {
  Exercise({required this.id, required this.name, required this.category, required this.measures, required this.builtIn});

  factory Exercise.fromRow(Map<String, Object?> r) => Exercise(
        id: r['id'] as int,
        name: r['name'] as String,
        category: Category.values.byName(r['category'] as String),
        measures: parseMeasures(r['measures'] as String),
        builtIn: r['built_in'] == 1,
      );

  final int id;
  final String name;
  final Category category;
  final List<Measure> measures;
  final bool builtIn;
}

class Workout {
  Workout({
    required this.id,
    required this.name,
    required this.date,
    required this.durationSeconds,
    required this.notes,
    required this.status,
    required this.planId,
  });

  factory Workout.fromRow(Map<String, Object?> r) => Workout(
        id: r['id'] as int,
        name: r['name'] as String,
        date: r['date'] as String,
        durationSeconds: r['duration_seconds'] as int?,
        notes: r['notes'] as String?,
        status: WorkoutStatus.values.byName(r['status'] as String),
        planId: r['plan_id'] as int?,
      );

  final int id;
  final String name;
  final String date; // YYYY-MM-DD
  final int? durationSeconds;
  final String? notes;
  final WorkoutStatus status;
  final int? planId;
}

class WeekWorkout {
  WeekWorkout(this.workout, this.exerciseCount);
  final Workout workout;
  final int exerciseCount;
}

class WorkoutExercise {
  WorkoutExercise({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.position,
    required this.notes,
    required this.done,
    required this.name,
    required this.measures,
    required this.setCount,
  });

  factory WorkoutExercise.fromRow(Map<String, Object?> r) => WorkoutExercise(
        id: r['id'] as int,
        workoutId: r['workout_id'] as int,
        exerciseId: r['exercise_id'] as int,
        position: r['position'] as int,
        notes: r['notes'] as String?,
        done: r['done'] == 1,
        name: r['name'] as String,
        measures: parseMeasures(r['measures'] as String),
        setCount: (r['set_count'] as int?) ?? 0,
      );

  final int id;
  final int workoutId;
  final int exerciseId;
  final int position;
  final String? notes;
  final bool done;
  final String name;
  final List<Measure> measures;
  final int setCount;
}

/// The values I enter for a set; each one is optional, filled per the exercise's measures.
class SetValues {
  const SetValues({this.reps, this.weightKg, this.timeSeconds, this.distanceKm});

  static const empty = SetValues();

  final int? reps;
  final double? weightKg;
  final int? timeSeconds;
  final double? distanceKm;
}

class WorkoutSet extends SetValues {
  const WorkoutSet({
    required this.id,
    required this.workoutExerciseId,
    required this.position,
    super.reps,
    super.weightKg,
    super.timeSeconds,
    super.distanceKm,
    this.startedAt,
    this.restSeconds,
  });

  factory WorkoutSet.fromRow(Map<String, Object?> r) => WorkoutSet(
        id: r['id'] as int,
        workoutExerciseId: r['workout_exercise_id'] as int,
        position: r['position'] as int,
        reps: r['reps'] as int?,
        weightKg: (r['weight_kg'] as num?)?.toDouble(),
        timeSeconds: r['time_seconds'] as int?,
        distanceKm: (r['distance_km'] as num?)?.toDouble(),
        startedAt: r['started_at'] as int?,
        restSeconds: r['rest_seconds'] as int?,
      );

  final int id;
  final int workoutExerciseId;
  final int position;

  /// Epoch milliseconds when the set timer started; null when typed by hand.
  final int? startedAt;
  final int? restSeconds;

  /// When the set ended (and its rest began), if it was timed and stopped.
  int? get endedAt => startedAt != null && timeSeconds != null ? startedAt! + timeSeconds! * 1000 : null;
}
