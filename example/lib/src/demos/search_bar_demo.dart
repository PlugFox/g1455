import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/capture_meter.dart';
import '../widgets/stage.dart';

/// A search bar over a photo, its matches on a glass card under it, and the
/// host's capture count under the stage: Cancel's slide is the one price.
class SearchBarDemo extends StatefulWidget {
  const SearchBarDemo({super.key});

  @override
  State<SearchBarDemo> createState() => _SearchBarDemoState();
}

const List<String> _kCities = <String>[
  'Amsterdam',
  'Berlin',
  'Kyoto',
  'Lisbon',
  'Oslo',
  'Porto',
  'Reykjavík',
  'Tbilisi',
  'Valencia',
];

class _SearchBarDemoState extends State<SearchBarDemo> {
  String _query = '';
  bool _cancel = true;
  String _last = 'nothing yet';

  @override
  Widget build(BuildContext context) {
    final String q = _query.toLowerCase();
    final List<String> shown = <String>[
      for (final String c in _kCities)
        if (c.toLowerCase().contains(q)) c,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DemoStage(
          height: 360,
          background: const PhotoBackdrop(seed: 17),
          knobs: <Widget>[
            KnobSwitch(label: 'Cancel button', value: _cancel, onChanged: (bool v) => setState(() => _cancel = v)),
          ],
          hint: _cancel
              ? 'Tap the field: Cancel slides in, and the narrowing glass is a capture a frame for 250 ms. '
                    'Typing and the clear button add none.'
              : 'Without Cancel the field keeps its box, and taking the focus costs nothing.',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: <Widget>[
                    GlassSearchBar(
                      // A new bar when the knob flips, so it starts unfocused.
                      key: ValueKey<bool>(_cancel),
                      showsCancelButton: _cancel,
                      onChanged: (String v) => setState(() => _query = v),
                      onSubmitted: (String v) => setState(() => _last = 'searched "$v"'),
                      onCancel: () => setState(() {
                        _query = '';
                        _last = 'cancelled';
                      }),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      // The matches are on glass, so filtering them repaints
                      // inside a surface and is no capture.
                      child: GlassCard(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                shown.isEmpty ? 'No matches' : '${shown.length} of ${_kCities.length}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Text(
                                  shown.join(' · '),
                                  style: const TextStyle(fontSize: 15),
                                  overflow: TextOverflow.fade,
                                ),
                              ),
                              Text('Last: $_last', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 0), child: CaptureMeter()),
      ],
    );
  }
}
