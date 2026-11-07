import 'dart:async';

import 'package:flutter/material.dart';

import '../app.dart';
import '../db/models.dart';
import '../theme.dart';
import '../util/sets.dart';
import '../widgets/set_form.dart';
import '../widgets/timer_circle.dart';

/// One exercise. Live workout: the set timer and the rest timer in one big circle.
/// Past or saved workout: sets are typed in by hand.
class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key, required this.workoutId, required this.workoutExerciseId, this.reopened = false});

  final int workoutId;
  final int workoutExerciseId;

  /// Opened again after Done: starts idle, the rest that Done dropped doesn't come back.
  final bool reopened;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> with LoadsFromRepo, WidgetsBindingObserver {
  Workout? _workout;
  WorkoutExercise? _we;
  List<WorkoutSet> _sets = [];
  List<WorkoutSet>? _last;

  late bool _reopened = widget.reopened;
  int? _enteringId; // the set just stopped, waiting for its reps/kg
  int? _correctingId; // a saved set being corrected
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Elapsed time is computed from stored start times, so a tick only needs to redraw.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && (_running != null || _resting)) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> load() async {
    final we = await repo.workoutExercise(widget.workoutExerciseId);
    final w = await repo.workout(widget.workoutId);
    final sets = await repo.sets(widget.workoutExerciseId);
    final last = we == null ? null : (await repo.lastSetsByExercise(excludeWorkoutId: widget.workoutId))[we.exerciseId];
    if (!mounted) return;
    setState(() {
      _we = we;
      _workout = w;
      _sets = sets;
      _last = last;
    });
  }

  bool get _live => _workout?.status == WorkoutStatus.live;
  WorkoutSet? get _lastSet => _sets.isEmpty ? null : _sets.last;

  WorkoutSet? get _running {
    final s = _lastSet;
    return _live && s != null && s.startedAt != null && s.timeSeconds == null ? s : null;
  }

  bool get _resting {
    final s = _lastSet;
    return _live &&
        _running == null &&
        _enteringId == null &&
        !_reopened &&
        s?.endedAt != null &&
        s?.restSeconds == null;
  }

  /// The set that's stopped and waiting for its reps/kg (paused, yellow), but only once its
  /// stopped time is loaded: the form has to start with that time filled in.
  WorkoutSet? get _paused => _sets.where((s) => s.id == _enteringId && s.timeSeconds != null).firstOrNull;

  Future<void> _tapCircle() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final running = _running;
    final paused = _paused;
    if (_enteringId != null && paused == null) return; // the stop is still being saved
    if (paused != null) {
      await _continueSet(paused);
    } else if (running != null) {
      setState(() => _enteringId = running.id);
      await repo.stopSet(running, now);
    } else {
      final endRest = _resting;
      setState(() => _reopened = false);
      await repo.startSet(widget.workoutExerciseId, now, endRest: endRest);
    }
  }

  Future<void> _saveEntering(SetValues v) async {
    final paused = _paused;
    if (paused == null) return;
    // A timed set always keeps a time: an emptied time field keeps the stopped time,
    // otherwise the set would read as still running.
    final values = SetValues(
      reps: v.reps,
      weightKg: v.weightKg,
      timeSeconds: v.timeSeconds ?? paused.timeSeconds,
      distanceKm: v.distanceKm,
    );
    setState(() => _enteringId = null);
    await repo.updateSet(paused.id, values);
  }

  /// Stopped by accident: the set runs again from its original start. The paused state is
  /// cleared only after the set is running again in the loaded data, so the rest timer
  /// never shows in between.
  Future<void> _continueSet(WorkoutSet s) async {
    await repo.continueSet(s.id);
    await load();
    if (mounted) setState(() => _enteringId = null);
  }

  Future<void> _saveCorrection(WorkoutSet s, SetValues v) async {
    setState(() => _correctingId = null);
    await repo.updateSet(s.id, v);
  }

  Future<void> _removeSet(WorkoutSet s) async {
    setState(() {
      _correctingId = null;
      if (s.id == _enteringId) _enteringId = null;
    });
    await repo.deleteSet(s.id);
  }

  Future<void> _done() async {
    await repo.setExerciseDone(widget.workoutExerciseId, true);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _card(AppColors c, String title, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: c.element, borderRadius: BorderRadius.circular(12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        child,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final we = _we;
    if (we == null || _workout == null) return const Scaffold();
    final c = AppColors.of(context);
    final now = DateTime.now().millisecondsSinceEpoch;
    final running = _running;
    final entering = _paused;
    final next = _sets.length + 1;

    final mode = running != null
        ? TimerMode.running
        : entering != null
        ? TimerMode.stopped
        : _resting
        ? TimerMode.resting
        : TimerMode.idle;
    final seconds = switch (mode) {
      TimerMode.running => (now - running!.startedAt!) / 1000,
      TimerMode.stopped => (entering!.timeSeconds ?? 0).toDouble(),
      TimerMode.resting => (now - _lastSet!.endedAt!) / 1000,
      TimerMode.idle => 0.0,
    };
    final (caption, captionStyle) = switch (mode) {
      TimerMode.running => ('Tap to stop', TextStyle(color: c.textSecondary)),
      TimerMode.stopped => (
        'Paused · tap the timer to continue',
        TextStyle(color: c.paused, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      TimerMode.resting => (
        'Resting after set ${_lastSet!.position} · tap to start set $next',
        TextStyle(color: c.rest, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      TimerMode.idle => (null, null),
    };
    final listed = _sets.where((s) => s.id != running?.id && s.id != _enteringId).toList();

    return Scaffold(
      appBar: AppBar(title: Text(we.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            formatLastTime(_last, we.measures),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          if (_live) ...[
            TimerCircle(mode: mode, seconds: seconds, idleLabel: 'Start set $next', onTap: _tapCircle),
            if (caption != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(caption, textAlign: TextAlign.center, style: captionStyle),
              ),
          ] else
            _card(
              c,
              'Set $next',
              SetForm(
                key: ValueKey('new-${_sets.length}'),
                measures: we.measures,
                initial: SetValues.empty,
                saveLabel: 'Add set',
                onSave: (v) => repo.addManualSet(widget.workoutExerciseId, v),
              ),
            ),
          const SizedBox(height: 16),
          if (entering != null) ...[
            _card(
              c,
              'Set ${entering.position}',
              SetForm(
                key: ValueKey(entering.id),
                measures: we.measures,
                initial: entering,
                showTime: true,
                onSave: _saveEntering,
                onDelete: () => _removeSet(entering),
              ),
            ),
            const SizedBox(height: 16),
          ],
          for (final s in listed)
            _correctingId == s.id
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _card(
                      c,
                      'Set ${s.position}',
                      SetForm(
                        measures: we.measures,
                        initial: s,
                        showTime: s.timeSeconds != null,
                        saveLabel: 'Save',
                        onSave: (v) => _saveCorrection(s, v),
                        onCancel: () => setState(() => _correctingId = null),
                        onDelete: () => _removeSet(s),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(formatSetLine(s, we.measures)),
                        trailing: Icon(Icons.edit_outlined, size: 18, color: c.textSecondary),
                        onTap: () => setState(() => _correctingId = s.id),
                      ),
                      const Divider(height: 1),
                    ],
                  ),
          if (listed.isNotEmpty) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: running != null || entering != null ? null : _done, child: const Text('Done')),
          ],
        ],
      ),
    );
  }
}
