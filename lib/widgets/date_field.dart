import 'package:flutter/material.dart';

import '../util/format.dart';

/// A date shown as DD/MM/YYYY; tapping it opens the date picker. No dates in the future.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final String value; // YYYY-MM-DD
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: fromIsoDate(value),
          firstDate: DateTime(2000),
          lastDate: DateTime(now.year, now.month, now.day),
        );
        if (picked != null) onChanged(toIsoDate(picked));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today, size: 18)),
        child: Text(formatDate(value), style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
