// Formats from design.md: metric, DD/MM/YYYY, weeks start on Monday.

String _pad(int n) => n.toString().padLeft(2, '0');

/// A date as ISO (YYYY-MM-DD), the way it's stored.
String toIsoDate(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

String todayIso() => toIsoDate(DateTime.now());

DateTime fromIsoDate(String iso) {
  final p = iso.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// YYYY-MM-DD → DD/MM/YYYY
String formatDate(String iso) {
  final p = iso.split('-');
  return '${p[2]}/${p[1]}/${p[0]}';
}

/// Monday of the week that contains [d].
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String weekdayName(DateTime d) => _weekdays[d.weekday - 1];

/// Seconds → m:ss, or h:mm:ss from one hour. Used by the set and rest timers.
String formatClock(num totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds.floor();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  return h > 0 ? '$h:${_pad(m)}:${_pad(sec)}' : '$m:${_pad(sec)}';
}

/// Seconds → h:mm. Used for workout durations.
String formatDuration(int? totalSeconds) {
  if (totalSeconds == null) return '–';
  final minutes = (totalSeconds / 60).round();
  return '${minutes ~/ 60}:${_pad(minutes % 60)}';
}

List<num>? _parts(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final parts = t.split(':').map(num.tryParse).toList();
  if (parts.any((p) => p == null || p < 0)) return null;
  return parts.cast<num>();
}

/// "h:mm" or "mm" → seconds, or null if it can't be read.
int? parseDuration(String text) {
  final p = _parts(text);
  if (p == null) return null;
  if (p.length == 1) return (p[0] * 60).round();
  if (p.length == 2) return (p[0] * 3600 + p[1] * 60).round();
  return null;
}

/// "m:ss", "h:mm:ss" or "ss" → seconds, or null if it can't be read.
int? parseClock(String text) {
  final p = _parts(text);
  if (p == null) return null;
  if (p.length == 1) return p[0].round();
  if (p.length == 2) return (p[0] * 60 + p[1]).round();
  if (p.length == 3) return (p[0] * 3600 + p[1] * 60 + p[2]).round();
  return null;
}

/// Reads a decimal typed with either a comma or a dot.
double? parseNumber(String text) {
  final t = text.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final n = double.tryParse(t);
  return n != null && n >= 0 ? n : null;
}

String formatNumber(num n) {
  if (n == n.roundToDouble()) return n.round().toString();
  return ((n * 100).round() / 100).toString();
}
