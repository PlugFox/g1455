import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../widgets/stage.dart';

/// A button that asks before deleting a photo, and what the alert returned.
class AlertDemo extends StatefulWidget {
  const AlertDemo({super.key});

  @override
  State<AlertDemo> createState() => _AlertDemoState();
}

class _AlertDemoState extends State<AlertDemo> {
  bool _destructive = true;
  bool _message = true;
  bool _tapOutside = false;
  int _actions = 2;
  String _result = 'not asked yet';

  Future<void> _ask() async {
    final String? answer = await showGlassDialog<String>(
      context: context,
      barrierDismissible: _tapOutside,
      builder: (BuildContext context) {
        // Actions don't close the alert: each one pops with its answer.
        GlassAlertAction action(String label, String value, {bool destructive = false, bool isDefault = false}) =>
            GlassAlertAction(
              label: label,
              isDestructive: destructive,
              isDefault: isDefault,
              onPressed: () => Navigator.of(context).pop(value),
            );
        final GlassAlertAction delete = action(
          'Delete',
          'delete',
          destructive: _destructive,
          isDefault: !_destructive,
        );
        return GlassAlert(
          title: const Text('Delete “Lisbon.jpg”?', textAlign: TextAlign.center),
          message: _message
              ? const Text(
                  'The photo will be removed from all your devices. You can’t undo this.',
                  textAlign: TextAlign.center,
                )
              : null,
          actions: switch (_actions) {
            1 => <GlassAlertAction>[delete],
            2 => <GlassAlertAction>[action('Cancel', 'cancel'), delete],
            _ => <GlassAlertAction>[delete, action('Move to Archive', 'archive'), action('Cancel', 'cancel')],
          },
        );
      },
    );
    if (mounted) {
      setState(() => _result = answer == null ? 'null (dismissed)' : "'$answer'");
    }
  }

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 320,
    knobs: <Widget>[
      KnobChoice<int>(
        label: 'Actions',
        values: const <int>[1, 2, 3],
        selected: _actions,
        onChanged: (int n) => setState(() => _actions = n),
      ),
      KnobSwitch(label: 'Destructive', value: _destructive, onChanged: (bool v) => setState(() => _destructive = v)),
      KnobSwitch(label: 'Message', value: _message, onChanged: (bool v) => setState(() => _message = v)),
      KnobSwitch(
        label: 'Tap outside',
        value: _tapOutside,
        onChanged: (bool v) => setState(() => _tapOutside = v),
      ),
    ],
    hint: 'Two actions sit side by side; one or three are stacked. Watch the alert materialize: blur first, tint last.',
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GlassButton(
            onPressed: _ask,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[Icon(Icons.delete_outline, size: 20), SizedBox(width: 8), Text('Delete photo')],
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0x99000000)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Returned: $_result',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
