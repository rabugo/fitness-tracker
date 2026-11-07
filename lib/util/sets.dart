import '../db/models.dart';
import 'format.dart';

/// One set as a short line, e.g. "8 × 60 kg", "5 km · 25:00", "0:45".
String formatSetValues(SetValues s, List<Measure> measures) {
  final parts = <String>[];
  final reps = s.reps;
  final kg = s.weightKg;
  if (measures.contains(Measure.reps) && reps != null) {
    parts.add(measures.contains(Measure.weight) && kg != null ? '$reps × ${formatNumber(kg)} kg' : '$reps reps');
  } else if (measures.contains(Measure.weight) && kg != null) {
    parts.add('${formatNumber(kg)} kg');
  }
  final km = s.distanceKm;
  if (measures.contains(Measure.distance) && km != null) parts.add('${formatNumber(km)} km');
  final time = s.timeSeconds;
  if (measures.contains(Measure.time) && time != null) parts.add(formatClock(time));
  return parts.isEmpty ? '–' : parts.join(' · ');
}

/// A saved set in the list: "1 · 8 × 60 kg · 0:42 · rest 1:30".
String formatSetLine(WorkoutSet s, List<Measure> measures) {
  final parts = ['${s.position}', formatSetValues(s, measures)];
  final time = s.timeSeconds;
  if (!measures.contains(Measure.time) && time != null) parts.add(formatClock(time));
  final rest = s.restSeconds;
  if (rest != null) parts.add('rest ${formatClock(rest)}');
  return parts.join(' · ');
}

/// What I did last time: "Last: 3 × 8 @ 60 kg" when all sets match, otherwise each set.
String formatLastTime(List<WorkoutSet>? sets, List<Measure> measures) {
  if (sets == null || sets.isEmpty) return 'First time';
  final lines = sets.map((s) => formatSetValues(s, measures)).toList();
  if (lines.every((l) => l == lines.first)) {
    final one = sets.first;
    if (measures.contains(Measure.reps) && measures.contains(Measure.weight) && one.reps != null && one.weightKg != null) {
      return 'Last: ${sets.length} × ${one.reps} @ ${formatNumber(one.weightKg!)} kg';
    }
    return sets.length > 1 ? 'Last: ${sets.length} × ${lines.first}' : 'Last: ${lines.first}';
  }
  return 'Last: ${lines.join(', ')}';
}
