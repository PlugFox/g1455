import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// A photo with a share button, opening a share sheet on glass; what the
/// sheet returned is read out underneath.
class SheetDemo extends StatefulWidget {
  const SheetDemo({super.key});

  @override
  State<SheetDemo> createState() => _SheetDemoState();
}

class _SheetDemoState extends State<SheetDemo> {
  String _finish = 'Theme';
  bool _grabber = true;
  bool _tapDim = true;
  String _result = 'not opened yet';

  GlassFinish? get _glass => switch (_finish) {
    'Light' => GlassFinish.regularLight,
    'Dark' => GlassFinish.regularDark,
    'Clear' => GlassFinish.clear,
    _ => null,
  };

  Future<void> _share() async {
    final GlassFinish? finish = _glass;
    final String? done = await showGlassSheet<String>(
      context: context,
      finish: finish,
      showGrabber: _grabber,
      barrierDismissible: _tapDim,
      // The content's width, centred, rather than the window's.
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (BuildContext context) => _ShareSheet(finish: finish),
    );
    if (mounted) {
      setState(() => _result = done ?? 'dismissed (null)');
    }
  }

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 320,
    background: const PhotoBackdrop(seed: 23),
    knobs: <Widget>[
      KnobChoice<String>(
        label: 'Finish',
        values: const <String>['Theme', 'Light', 'Dark', 'Clear'],
        selected: _finish,
        onChanged: (String v) => setState(() => _finish = v),
      ),
      KnobSwitch(label: 'Grabber', value: _grabber, onChanged: (bool v) => setState(() => _grabber = v)),
      KnobSwitch(label: 'Tap outside', value: _tapDim, onChanged: (bool v) => setState(() => _tapDim = v)),
    ],
    hint: 'The sheet rises from the bottom of the window, as wide as what it holds. Drag it down past a third of its height, or flick it, to close.',
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GlassButton(
            onPressed: _share,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[Icon(Icons.ios_share, size: 20), SizedBox(width: 8), Text('Share photo')],
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0x99000000)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Returned: $_result',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// What a share sheet holds: the item, people, apps and actions. Each choice
/// pops the sheet with what was done.
class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.finish});

  final GlassFinish? finish;

  @override
  Widget build(BuildContext context) {
    // The sheet doesn't colour its content: ask the theme what reads on it.
    final Color label = GlassTheme.of(context).legibility(finish).label;
    final Color secondary = label.withValues(alpha: 0.6);
    void done(String what) => Navigator.of(context).pop(what);
    return DefaultTextStyle.merge(
      style: TextStyle(color: label, fontSize: 15),
      child: IconTheme.merge(
        data: IconThemeData(color: label),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                    child: SizedBox(width: 48, height: 48, child: PhotoBackdrop(seed: 23)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('Lisbon.jpg', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        Text('Photo · 2.4 MB', style: TextStyle(color: secondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Close',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: label.withValues(alpha: 0.12),
                        child: Icon(Icons.close, size: 18, color: secondary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  for (final (String name, Color colour) in const <(String, Color)>[
                    ('Anna', Color(0xFFFF7A59)),
                    ('Ben', Color(0xFF5AC8FA)),
                    ('Chiara', Color(0xFFAF52DE)),
                    ('Dmitri', Color(0xFF34C759)),
                  ])
                    Expanded(
                      child: _Target(
                        onTap: () => done('sent to $name'),
                        label: name,
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: colour,
                          child: Text(
                            name[0],
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  for (final (String name, IconData icon, Color colour) in const <(String, IconData, Color)>[
                    ('Messages', Icons.chat_bubble, Color(0xFF34C759)),
                    ('Mail', Icons.mail, Color(0xFF0A84FF)),
                    ('Notes', Icons.sticky_note_2, Color(0xFFFFCC00)),
                    ('More', Icons.more_horiz, Color(0xFF8E8E93)),
                  ])
                    Expanded(
                      child: _Target(
                        onTap: () => done('shared via $name'),
                        label: name,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colour,
                            borderRadius: const BorderRadius.all(Radius.circular(14)),
                          ),
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(icon, color: Colors.white, size: 26),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: label.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.all(Radius.circular(18)),
                ),
                child: Column(
                  children: <Widget>[
                    for (final (String name, IconData icon) in const <(String, IconData)>[
                      ('Copy', Icons.copy),
                      ('Add to Album', Icons.photo_library_outlined),
                      ('Save to Files', Icons.folder_outlined),
                    ])
                      // No Material in a sheet's route: a plain detector.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => done(name.toLowerCase()),
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Semantics(
                              button: true,
                              child: Row(
                                children: <Widget>[
                                  Expanded(child: Text(name, style: const TextStyle(fontSize: 17))),
                                  Icon(icon, size: 22),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round target with its name under it.
class _Target extends StatelessWidget {
  const _Target({required this.onTap, required this.label, required this.child});

  final VoidCallback onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: <Widget>[
          child,
          const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}
