import 'package:flutter/material.dart';

import '../app.dart';
import '../db/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/date_field.dart';
import 'exercise_screen.dart';
import 'finish_screen.dart';
import 'pick_screen.dart';

/// The workout: its exercises in order, Add exercise, Finish workout. Also edits a saved one.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with LoadsFromRepo {
  Workout? _workout;
  List<WorkoutExercise> _exercises = [];

  @override
  Future<void> load() async {
    final w = await repo.workout(widget.workoutId);
    final ex = await repo.workoutExercises(widget.workoutId);
    if (!mounted) return;
    setState(() {
      _workout = w;
      _exercises = ex;
    });
  }

  Future<void> _open(WorkoutExercise we) async {
    var reopened = false;
    if (we.done) {
      await repo.setExerciseDone(we.id, false);
      reopened = true;
    }
    if (mounted) {
      pushScreen(context, ExerciseScreen(workoutId: widget.workoutId, workoutExerciseId: we.id, reopened: reopened));
    }
  }

  Future<void> _remove(WorkoutExercise we) async {
    final yes = await confirm(context, title: 'Remove ${we.name}?', message: 'Its sets are removed too.', action: 'Remove');
    if (yes) await repo.removeWorkoutExercise(we.id);
  }

  @override
  Widget build(BuildContext context) {
    final w = _workout;
    if (w == null) return const Scaffold();
    final c = AppColors.of(context);
    final editing = w.status == WorkoutStatus.done;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit workout' : 'Workout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _NameField(key: ValueKey(w.id), initial: w.name, onSave: (name) => repo.renameWorkout(w.id, name)),
          const SizedBox(height: 12),
          if (w.status == WorkoutStatus.live)
            Text(formatDate(w.date),
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textSecondary, fontSize: 30, fontWeight: FontWeight.w300))
          else
            DateField(label: 'Date', value: w.date, centered: true, onChanged: (d) => repo.setWorkoutDate(w.id, d)),
          const SizedBox(height: 16),
          for (final (i, we) in _exercises.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: c.element,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _open(we),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: we.done
                                ? Text('${we.name} · ${we.setCount} ${we.setCount == 1 ? 'set' : 'sets'} ✓',
                                    style: TextStyle(color: c.success, fontSize: 16))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(we.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                      Text('${we.setCount} ${we.setCount == 1 ? 'set' : 'sets'}',
                                          style: TextStyle(color: c.textSecondary)),
                                    ],
                                  ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Move up',
                          onPressed: i == 0 ? null : () => repo.moveWorkoutExercise(w.id, we.id, -1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Move down',
                          onPressed: i == _exercises.length - 1 ? null : () => repo.moveWorkoutExercise(w.id, we.id, 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          color: c.danger,
                          onPressed: () => _remove(we),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => pushScreen(context, PickScreen(workoutId: w.id)),
            child: const Text('Add exercise'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _exercises.isEmpty ? null : () => pushScreen(context, FinishScreen(workoutId: w.id)),
            child: Text(editing ? 'Save changes' : 'Finish workout'),
          ),
        ],
      ),
    );
  }
}

/// The workout's name; saved when I leave the field. Empty falls back to "Workout".
class _NameField extends StatefulWidget {
  const _NameField({super.key, required this.initial, required this.onSave});

  final String initial;
  final ValueChanged<String> onSave;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _controller = TextEditingController(text: widget.initial);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    final clean = _controller.text.trim().isEmpty ? 'Workout' : _controller.text.trim();
    _controller.text = clean;
    if (clean != widget.initial) widget.onSave(clean);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        focusNode: _focus,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _focus.unfocus(),
        decoration: const InputDecoration(labelText: 'Name', floatingLabelAlignment: FloatingLabelAlignment.center),
      );
}
