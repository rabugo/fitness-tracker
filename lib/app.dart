import 'package:flutter/material.dart';

import 'db/repo.dart';

/// The app's database, opened once in main().
late Repo repo;

/// Which bottom tab is showing: 0 = Log, 1 = History.
final currentTab = ValueNotifier<int>(0);

/// Loads a screen's data when it opens and again after every database write,
/// so going back to a screen always shows what's stored.
mixin LoadsFromRepo<T extends StatefulWidget> on State<T> {
  Future<void> load();

  @override
  void initState() {
    super.initState();
    repo.changes.addListener(_onChange);
    load();
  }

  void _onChange() {
    if (mounted) load();
  }

  @override
  void dispose() {
    repo.changes.removeListener(_onChange);
    super.dispose();
  }
}

Future<T?> pushScreen<T>(BuildContext context, Widget screen, {String? name}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => screen,
    settings: RouteSettings(name: name),
  ),
);

/// A yes/no question before something that can't be undone.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  String cancel = 'Keep',
}) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancel)),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          child: Text(action),
        ),
      ],
    ),
  );
  return yes ?? false;
}
