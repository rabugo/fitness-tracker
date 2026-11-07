import 'package:flutter/material.dart';

import '../app.dart';
import '../db/models.dart';
import '../theme.dart';
import '../util/sets.dart';
import 'exercise_screen.dart';

/// The built-in list: search, category chips, and what I did last time under each.
class PickScreen extends StatefulWidget {
  const PickScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  State<PickScreen> createState() => _PickScreenState();
}

class _PickScreenState extends State<PickScreen> with LoadsFromRepo {
  List<Exercise> _exercises = [];
  Map<int, List<WorkoutSet>> _last = {};
  String _query = '';
  Category? _category;

  @override
  Future<void> load() async {
    final ex = await repo.listExercises();
    final last = await repo.lastSetsByExercise(excludeWorkoutId: widget.workoutId);
    if (!mounted) return;
    setState(() {
      _exercises = ex;
      _last = last;
    });
  }

  Future<void> _pick(Exercise e) async {
    final weId = await repo.addWorkoutExercise(widget.workoutId, e.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ExerciseScreen(workoutId: widget.workoutId, workoutExerciseId: weId),
      ),
    );
  }

  String _title(Category? c) => c == null ? 'All' : '${c.name[0].toUpperCase()}${c.name.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final q = _query.trim().toLowerCase();
    final shown = _exercises
        .where((e) => (_category == null || e.category == _category) && (q.isEmpty || e.name.toLowerCase().contains(q)))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add exercise')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autocorrect: false,
              onChanged: (t) => setState(() => _query = t),
              decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final cat in <Category?>[null, ...Category.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_title(cat)),
                      selected: cat == _category,
                      onSelected: (_) => setState(() => _category = cat),
                      selectedColor: c.primary,
                      labelStyle: TextStyle(color: cat == _category ? c.onPrimary : c.text),
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text('No exercise matches “$_query”.', style: TextStyle(color: c.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = shown[i];
                      return ListTile(
                        title: Text(e.name),
                        subtitle: Text(
                          formatLastTime(_last[e.id], e.measures),
                          style: TextStyle(color: c.textSecondary),
                        ),
                        onTap: () => _pick(e),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
