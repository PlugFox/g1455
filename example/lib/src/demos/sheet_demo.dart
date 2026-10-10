import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';
import '../widgets/site_icon.dart';

/// A photo with a share button, opening a share sheet on glass that can be
/// pulled up to a large detent; what the sheet returned, and the detent it
/// last settled at, are read out underneath.
class SheetDemo extends StatefulWidget {
  const SheetDemo({super.key});

  @override
  State<SheetDemo> createState() => _SheetDemoState();
}

class _SheetDemoState extends State<SheetDemo> {
  String _finish = 'Theme';
  bool _grabber = true;
  bool _tapDim = true;
  bool _large = true;
  bool _opaque = true;
  String _result = 'not opened yet';
  String _detent = 'medium';

  GlassFinish? get _glass => switch (_finish) {
    'Light' => GlassFinish.regularLight,
    'Dark' => GlassFinish.regularDark,
    'Clear' => GlassFinish.clear,
    _ => null,
  };

  Future<void> _share() async {
    final GlassFinish? finish = _glass;
    setState(() => _detent = 'medium');
    final String? done = await showGlassSheet<String>(
      context: context,
      finish: finish,
      showGrabber: _grabber,
      barrierDismissible: _tapDim,
      // The content's width, centred, rather than the window's.
      constraints: const BoxConstraints(maxWidth: 520),
      detents: <GlassSheetDetent>[GlassSheetDetent.medium, if (_large) GlassSheetDetent.large],
      // Null is the finish laid on opaquely, which reads no backdrop at large;
      // the finish itself keeps the large sheet glass.
      largeFinish: _opaque ? null : finish ?? GlassTheme.of(context).finish,
      onDetentChanged: (GlassSheetDetent d) => setState(() => _detent = d.name),
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
      KnobSwitch(label: 'Large detent', value: _large, onChanged: (bool v) => setState(() => _large = v)),
      KnobChoice<bool>(
        label: 'At large',
        values: const <bool>[true, false],
        selected: _opaque,
        labelOf: (bool o) => o ? 'Opaque' : 'Glass',
        onChanged: (bool o) => setState(() => _opaque = o),
      ),
    ],
    hint: _large
        ? 'The sheet follows the finger: drag it up to the whole height, or down past a third of it to close. '
              'Opaque at large, it reads no backdrop and drops out of the capture.'
        : 'The sheet rises from the bottom of the window, as wide as what it holds. Drag it down past a third of its '
              'height, or flick it, to close.',
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GlassButton(
            onPressed: _share,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SiteIcon(SFIcons.sf_square_and_arrow_up, size: 20),
                SizedBox(width: 8),
                Text('Share photo'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0x99000000)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                'Returned: $_result · detent: $_detent',
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
                        child: SiteIcon(SFIcons.sf_xmark, size: 18, color: secondary),
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
                    ('Messages', SFIcons.sf_bubble_left_fill, Color(0xFF34C759)),
                    ('Mail', SFIcons.sf_envelope_fill, Color(0xFF0A84FF)),
                    ('Notes', SFIcons.sf_list_bullet_rectangle, Color(0xFFFFCC00)),
                    ('More', SFIcons.sf_ellipsis, Color(0xFF8E8E93)),
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
                            child: SiteIcon(icon, color: Colors.white, size: 26),
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
                      ('Copy', SFIcons.sf_document_on_document),
                      ('Add to Album', SFIcons.sf_photo_on_rectangle),
                      ('Save to Files', SFIcons.sf_folder),
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
                                  SiteIcon(icon, size: 22),
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
