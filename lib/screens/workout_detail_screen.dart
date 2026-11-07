import 'package:flutter/material.dart';

import '../app.dart';
import '../db/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/sets.dart';
import 'workout_screen.dart';

/// A saved workout, read-only, with Edit and Delete.
class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  static const routeName = '/workout-detail';

  final int workoutId;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> with LoadsFromRepo {
  Workout? _workout;
  List<(WorkoutExercise, List<WorkoutSet>)> _exercises = [];
  bool _loaded = false;

  @override
  Future<void> load() async {
    final w = await repo.workout(widget.workoutId);
    final list = <(WorkoutExercise, List<WorkoutSet>)>[];
    for (final we in await repo.workoutExercises(widget.workoutId)) {
      list.add((we, await repo.sets(we.id)));
    }
    if (!mounted) return;
    setState(() {
      _workout = w;
      _exercises = list;
      _loaded = true;
    });
  }

  Future<void> _delete(Workout w) async {
    final yes = await confirm(context,
        title: 'Delete workout?', message: '${w.name} on ${formatDate(w.date)} is removed for good.', action: 'Delete');
    if (!yes) return;
    await repo.deleteWorkout(w.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final w = _workout;
    if (!_loaded) return const Scaffold();
    if (w == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('This workout was deleted.', style: TextStyle(color: c.textSecondary))),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(w.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${formatDate(w.date)} · ${formatDuration(w.durationSeconds)}', style: TextStyle(color: c.textSecondary)),
          if (w.notes != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(w.notes!)),
          const SizedBox(height: 16),
          for (final (we, sets) in _exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(we.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (sets.isEmpty)
                    Text('No sets', style: TextStyle(color: c.textSecondary))
                  else
                    for (final s in sets) Text(formatSetLine(s, we.measures)),
                ],
              ),
            ),
          FilledButton(
            onPressed: () => pushScreen(context, WorkoutScreen(workoutId: w.id)),
            child: const Text('Edit'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: c.danger, side: BorderSide(color: c.danger)),
            onPressed: () => _delete(w),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
