import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// A title bar on top and a "now playing" bar at the bottom, over a photo.
class BarDemo extends StatefulWidget {
  const BarDemo({super.key});

  @override
  State<BarDemo> createState() => _BarDemoState();
}

/// The finishes a demo offers, by the name its knob shows. "Default" is the
/// host's own choice.
const Map<String, GlassFinish?> _kFinishes = <String, GlassFinish?>{
  'Default': null,
  'Clear': GlassFinish.clear,
  'Regular': GlassFinish.regularDark,
  'Frosted': GlassFinish.frosted,
};

class _BarDemoState extends State<BarDemo> {
  String _finish = 'Default';
  bool _capsule = true;
  bool _playing = true;
  int _photo = 3;

  BorderRadius get _radius => _capsule ? kGlassCapsule : const BorderRadius.all(Radius.circular(20));

  @override
  Widget build(BuildContext context) => DemoStage(
    height: 360,
    background: PhotoBackdrop(seed: _photo),
    hint: 'Change the finish and watch the labels pick black or white. Tap the photo for another one.',
    knobs: <Widget>[
      KnobChoice<String>(
        label: 'Finish',
        values: _kFinishes.keys.toList(),
        selected: _finish,
        onChanged: (String f) => setState(() => _finish = f),
      ),
      KnobChoice<bool>(
        label: 'Corners',
        values: const <bool>[true, false],
        selected: _capsule,
        labelOf: (bool c) => c ? 'Capsule' : '20 px',
        onChanged: (bool c) => setState(() => _capsule = c),
      ),
    ],
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setState(() => _photo = (_photo + 1) % 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                GlassBar(
                  finish: _kFinishes[_finish],
                  borderRadius: _radius,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: const Row(
                    children: <Widget>[
                      _BarIcon(icon: Icons.arrow_back_ios_new, label: 'Back'),
                      Expanded(
                        child: Text(
                          'Library',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                      ),
                      _BarIcon(icon: Icons.search, label: 'Search'),
                    ],
                  ),
                ),
                GlassBar(
                  finish: _kFinishes[_finish],
                  borderRadius: _radius,
                  padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
                  child: Row(
                    children: <Widget>[
                      const _Artwork(),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Glass Animals',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Heat Waves',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      _BarIcon(
                        icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        label: _playing ? 'Pause' : 'Play',
                        onTap: () => setState(() => _playing = !_playing),
                      ),
                      const _BarIcon(icon: Icons.fast_forward_rounded, label: 'Next'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// An icon in a bar: content, not glass, in the colour the bar picked.
class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () {},
      child: SizedBox.fromSize(
        size: kGlassMinTapTarget,
        child: Icon(icon, size: 24, color: IconTheme.of(context).color),
      ),
    ),
  );
}

class _Artwork extends StatelessWidget {
  const _Artwork();

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[Color(0xFFFF9F0A), Color(0xFFFF375F), Color(0xFF5E5CE6)],
      ),
    ),
    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
  );
}
