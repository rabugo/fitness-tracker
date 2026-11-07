import 'package:flutter/material.dart';

import '../app.dart';
import '../db/models.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/date_field.dart';
import 'workout_detail_screen.dart';

/// Summary before saving: name, date, duration (from the set timers when timed), notes.
class FinishScreen extends StatefulWidget {
  const FinishScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  State<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends State<FinishScreen> {
  Workout? _workout;
  final _name = TextEditingController();
  final _duration = TextEditingController();
  final _notes = TextEditingController();
  String _date = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final w = await repo.workout(widget.workoutId);
    final timed = await repo.timedDuration(widget.workoutId);
    if (w == null || !mounted) return;
    // A live workout takes its duration from the set timers; a saved one keeps what I set.
    final seconds = w.status == WorkoutStatus.live ? (timed ?? w.durationSeconds) : (w.durationSeconds ?? timed);
    setState(() {
      _workout = w;
      _name.text = w.name;
      _date = w.date;
      _duration.text = seconds != null ? formatDuration(seconds) : '';
      _notes.text = w.notes ?? '';
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _duration, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final w = _workout!;
    final text = _duration.text.trim();
    final seconds = text.isEmpty ? null : parseDuration(text);
    if (text.isNotEmpty && seconds == null) {
      setState(() => _error = 'Duration should look like 1:15 (hours:minutes).');
      return;
    }
    final wasSaved = w.status == WorkoutStatus.done;
    await repo.finishWorkout(
      w.id,
      name: _name.text.trim().isEmpty ? 'Workout' : _name.text.trim(),
      date: _date,
      durationSeconds: seconds,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    if (!mounted) return;
    if (wasSaved) {
      Navigator.of(context).popUntil(ModalRoute.withName(WorkoutDetailScreen.routeName));
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
      currentTab.value = 1; // History
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _workout;
    if (w == null) return const Scaffold();
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(w.status == WorkoutStatus.done ? 'Save changes' : 'Finish workout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          DateField(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.datetime,
            onChanged: (_) => setState(() => _error = null),
            decoration: InputDecoration(labelText: 'Duration (h:mm)', hintText: '0:45', errorText: _error),
          ),
          const SizedBox(height: 12),
          TextField(controller: _notes, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save')),
          if (w.status != WorkoutStatus.done)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Saving marks every exercise as done.',
                  textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
            ),
        ],
      ),
    );
  }
}
