import 'package:flutter/material.dart';

import '../app.dart';
import '../db/models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'workout_screen.dart';

/// Log tab: start a workout, or log one I did earlier. An unsaved workout can be resumed.
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> with LoadsFromRepo {
  Workout? _open;
  bool _loaded = false;

  @override
  Future<void> load() async {
    final open = await repo.openWorkout();
    if (!mounted) return;
    setState(() {
      _open = open;
      _loaded = true;
    });
  }

  Future<void> _start(WorkoutStatus status) async {
    final id = await repo.createWorkout(status);
    if (mounted) pushScreen(context, WorkoutScreen(workoutId: id));
  }

  Future<void> _discard(Workout w) async {
    final yes = await confirm(context,
        title: 'Discard workout?', message: 'Everything logged in it is removed.', action: 'Discard');
    if (yes) await repo.deleteWorkout(w.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final open = _open;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: !_loaded
              ? const SizedBox.shrink()
              : open != null
                  ? Card(
                      elevation: 0,
                      color: c.element,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 8,
                          children: [
                            Text(
                              open.status == WorkoutStatus.live ? 'Workout in progress' : 'Past workout not saved yet',
                              style: TextStyle(color: c.warning, fontWeight: FontWeight.w700),
                            ),
                            Text(open.name, style: Theme.of(context).textTheme.headlineMedium),
                            Text(formatDate(open.date), style: TextStyle(color: c.textSecondary)),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () => pushScreen(context, WorkoutScreen(workoutId: open.id)),
                              child: const Text('Resume'),
                            ),
                            TextButton(onPressed: () => _discard(open), child: const Text('Discard')),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 16,
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                          onPressed: () => _start(WorkoutStatus.live),
                          child: const Text('Start workout'),
                        ),
                        TextButton(
                          onPressed: () => _start(WorkoutStatus.manual),
                          child: const Text('Log a past workout'),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
