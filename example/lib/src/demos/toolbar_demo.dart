import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../backdrops.dart';
import '../widgets/stage.dart';

/// A photo viewer: a group of two at the top, and a toolbar at the bottom of
/// a circle, a group and a circle — each group one glass surface.
class ToolbarDemo extends StatefulWidget {
  const ToolbarDemo({super.key});

  @override
  State<ToolbarDemo> createState() => _ToolbarDemoState();
}

const int _kPhotos = 12;

class _ToolbarDemoState extends State<ToolbarDemo> {
  int _photo = 0;
  bool _liked = false;
  String _last = 'nothing yet';
  int _middle = 3;
  bool _deleteEnabled = true;

  void _say(String what) => setState(() => _last = what);

  void _go(int by) => setState(() {
    _photo = (_photo + by) % _kPhotos;
    _liked = false;
    _last = by > 0 ? 'next photo' : 'previous photo';
  });

  @override
  Widget build(BuildContext context) {
    final List<GlassToolbarItem> middle = <GlassToolbarItem>[
      GlassToolbarItem(
        icon: Icon(_liked ? Icons.favorite : Icons.favorite_border),
        label: _liked ? 'Unlike' : 'Like',
        onPressed: () => setState(() {
          _liked = !_liked;
          _last = _liked ? 'liked' : 'unliked';
        }),
      ),
      GlassToolbarItem(icon: const Icon(Icons.info_outline), label: 'Info', onPressed: () => _say('info')),
      GlassToolbarItem(icon: const Icon(Icons.tune), label: 'Edit', onPressed: () => _say('edit')),
      GlassToolbarItem(icon: const Icon(Icons.crop), label: 'Crop', onPressed: () => _say('crop')),
    ].sublist(0, _middle);
    return DemoStage(
      height: 360,
      background: PhotoBackdrop(seed: 40 + _photo),
      knobs: <Widget>[
        KnobChoice<int>(
          label: 'Middle group',
          values: const <int>[1, 2, 3, 4],
          selected: _middle,
          labelOf: (int n) => n == 1 ? '1 item' : '$n items',
          onChanged: (int n) => setState(() => _middle = n),
        ),
        KnobSwitch(
          label: 'Delete enabled',
          value: _deleteEnabled,
          onChanged: (bool v) => setState(() => _deleteEnabled = v),
        ),
      ],
      hint: 'Press and hold an icon: only its cell lights up. A group is one glass surface, whatever its count.',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final double groupWidth = _middle == 1 ? kGlassToolbarHeight : _middle * kGlassToolbarItemWidth;
          // The circles at the sides need room: on a narrow stage the share
          // circle gives way first, then the delete one.
          final double room = box.maxWidth - 2 * 16 - groupWidth;
          final bool share = room >= 2 * (kGlassToolbarHeight + 12);
          final bool delete = room >= kGlassToolbarHeight + 12;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    GlassButtonGroup(
                      items: <GlassToolbarItem>[
                        GlassToolbarItem(
                          icon: const Icon(Icons.chevron_left),
                          label: 'Previous photo',
                          onPressed: () => _go(_kPhotos - 1),
                        ),
                        GlassToolbarItem(
                          icon: const Icon(Icons.chevron_right),
                          label: 'Next photo',
                          onPressed: () => _go(1),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _Label('${_photo + 1} of $_kPhotos'),
                  ],
                ),
                const Spacer(),
                _Label('Last action: $_last'),
                const Spacer(),
                Row(
                  children: <Widget>[
                    if (share)
                      GlassButtonGroup(
                        items: <GlassToolbarItem>[
                          GlassToolbarItem(
                            icon: const Icon(Icons.ios_share),
                            label: 'Share',
                            onPressed: () => _say('share'),
                          ),
                        ],
                      ),
                    const Spacer(),
                    GlassButtonGroup(items: middle),
                    const Spacer(),
                    if (delete)
                      GlassButtonGroup(
                        items: <GlassToolbarItem>[
                          GlassToolbarItem(
                            icon: const Icon(Icons.delete_outline),
                            label: 'Delete',
                            onPressed: _deleteEnabled ? () => _say('delete') : null,
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Plain content on the photo, not glass.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(shape: StadiumBorder(), color: Color(0x80000000)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
