import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';
import 'seed.dart';

const databaseName = 'fitness_tracker.db';

/// Opens the app's database on the phone. Tests pass their own [factory] and [path].
Future<Database> openAppDatabase({DatabaseFactory? factory, String? path}) async {
  final f = factory ?? databaseFactory;
  return f.openDatabase(
    path ?? p.join(await f.getDatabasesPath(), databaseName),
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _createV1(db),
      // Future data-model changes: bump `version` and add an onUpgrade step per version.
    ),
  );
}

Future<void> _createV1(Database db) async {
  final batch = db.batch()
    ..execute('''
      CREATE TABLE exercise (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        measures TEXT NOT NULL,
        built_in INTEGER NOT NULL DEFAULT 0
      )''')
    ..execute('''
      CREATE TABLE workout (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        duration_seconds INTEGER,
        notes TEXT,
        status TEXT NOT NULL,
        plan_id INTEGER
      )''')
    ..execute('''
      CREATE TABLE workout_exercise (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL REFERENCES workout(id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL REFERENCES exercise(id),
        position INTEGER NOT NULL,
        notes TEXT,
        done INTEGER NOT NULL DEFAULT 0
      )''')
    ..execute('''
      CREATE TABLE workout_set (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL REFERENCES workout_exercise(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        reps INTEGER,
        weight_kg REAL,
        time_seconds INTEGER,
        distance_km REAL,
        started_at INTEGER,
        rest_seconds INTEGER
      )''')
    ..execute('CREATE INDEX workout_date ON workout(date)')
    ..execute('CREATE INDEX workout_exercise_workout ON workout_exercise(workout_id)')
    ..execute('CREATE INDEX workout_set_exercise ON workout_set(workout_exercise_id)');
  for (final (name, category, measures) in seedExercises) {
    batch.insert('exercise', {
      'name': name,
      'category': category.name,
      'measures': measuresToString(measures),
      'built_in': 1,
    });
  }
  await batch.commit(noResult: true);
}
