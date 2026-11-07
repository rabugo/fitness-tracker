import 'package:flutter/material.dart';

import '../db/models.dart';
import '../theme.dart';
import '../util/format.dart';

/// The fields a set needs: only the ones its exercise uses (reps, kg, time, distance).
class SetForm extends StatefulWidget {
  const SetForm({
    super.key,
    required this.measures,
    required this.initial,
    required this.onSave,
    this.showTime = false,
    this.saveLabel = 'Save set',
    this.onCancel,
    this.onDelete,
  });

  final List<Measure> measures;
  final SetValues initial;

  /// Also show the time field when the exercise doesn't measure time (a timed set always has one).
  final bool showTime;
  final String saveLabel;
  final ValueChanged<SetValues> onSave;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  @override
  State<SetForm> createState() => _SetFormState();
}

class _SetFormState extends State<SetForm> {
  late final _reps = TextEditingController(text: widget.initial.reps?.toString() ?? '');
  late final _kg = TextEditingController(text: _num(widget.initial.weightKg));
  late final _time = TextEditingController(
      text: widget.initial.timeSeconds != null ? formatClock(widget.initial.timeSeconds!) : '');
  late final _km = TextEditingController(text: _num(widget.initial.distanceKm));

  static String _num(double? n) => n != null ? formatNumber(n) : '';

  bool _has(Measure m) => widget.measures.contains(m);
  bool get _withTime => _has(Measure.time) || widget.showTime;

  @override
  void dispose() {
    for (final c in [_reps, _kg, _time, _km]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final reps = parseNumber(_reps.text);
    widget.onSave(SetValues(
      reps: _has(Measure.reps) && reps != null ? reps.round() : null,
      weightKg: _has(Measure.weight) ? parseNumber(_kg.text) : null,
      timeSeconds: _withTime ? parseClock(_time.text) : null,
      distanceKm: _has(Measure.distance) ? parseNumber(_km.text) : null,
    ));
  }

  Widget _field(String label, TextEditingController c, TextInputType type, String hint) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: type,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const decimal = TextInputType.numberWithOptions(decimal: true);
    final c = AppColors.of(context);
    final fields = [
      if (_has(Measure.reps)) _field('Reps', _reps, TextInputType.number, '0'),
      if (_has(Measure.weight)) _field('kg', _kg, decimal, '0'),
      if (_has(Measure.distance)) _field('km', _km, decimal, '0'),
      if (_withTime) _field('Time (m:ss)', _time, TextInputType.datetime, '0:00'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(spacing: 8, children: fields),
        FilledButton(onPressed: _save, child: Text(widget.saveLabel)),
        if (widget.onCancel != null || widget.onDelete != null)
          Row(
            children: [
              if (widget.onCancel != null)
                Expanded(child: TextButton(onPressed: widget.onCancel, child: const Text('Cancel'))),
              if (widget.onDelete != null)
                Expanded(
                  child: TextButton(
                    onPressed: widget.onDelete,
                    style: TextButton.styleFrom(foregroundColor: c.danger),
                    child: const Text('Remove set'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
