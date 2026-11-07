import 'package:flutter/material.dart';

import '../app.dart';
import '../db/models.dart';
import '../theme.dart';
import '../util/format.dart';
import 'workout_detail_screen.dart';

/// This week, Monday to Sunday, with each day's workouts and the week's totals.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with LoadsFromRepo {
  DateTime _weekStart = startOfWeek(DateTime.now());
  List<WeekWorkout> _workouts = [];

  String get _from => toIsoDate(_weekStart);
  String get _to => toIsoDate(addDays(_weekStart, 6));

  @override
  Future<void> load() async {
    final list = await repo.workoutsBetween(_from, _to);
    if (mounted) setState(() => _workouts = list);
  }

  void _moveWeek(int days) {
    setState(() => _weekStart = addDays(_weekStart, days));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final total = _workouts.fold<int>(0, (sum, w) => sum + (w.workout.durationSeconds ?? 0));
    final today = todayIso();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous week',
                onPressed: () => _moveWeek(-7),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${formatDate(_from)} – ${formatDate(_to)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(tooltip: 'Next week', onPressed: () => _moveWeek(7), icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.element, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                _Total(value: '${_workouts.length}', label: _workouts.length == 1 ? 'workout' : 'workouts'),
                _Total(value: formatDuration(total), label: 'total time'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < 7; i++) _day(context, c, addDays(_weekStart, i), today),
        ],
      ),
    );
  }

  Widget _day(BuildContext context, AppColors c, DateTime day, String today) {
    final iso = toIsoDate(day);
    final list = _workouts.where((w) => w.workout.date == iso);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          Text(
            '${weekdayName(day)} ${formatDate(iso).substring(0, 5)}',
            style: TextStyle(color: iso == today ? c.primary : c.textSecondary, fontSize: 13),
          ),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('–', style: TextStyle(color: c.border)),
            )
          else
            for (final w in list)
              Material(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: c.border),
                ),
                clipBehavior: Clip.antiAlias,
                color: Colors.transparent,
                child: ListTile(
                  title: Text(w.workout.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${formatDuration(w.workout.durationSeconds)} · ${w.exerciseCount} '
                    '${w.exerciseCount == 1 ? 'exercise' : 'exercises'}',
                    style: TextStyle(color: c.textSecondary),
                  ),
                  onTap: () => pushScreen(
                    context,
                    WorkoutDetailScreen(workoutId: w.workout.id),
                    name: WorkoutDetailScreen.routeName,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: TextStyle(color: AppColors.of(context).textSecondary)),
      ],
    ),
  );
}
