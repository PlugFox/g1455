import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../backdrops.dart';
import '../widgets/site_icon.dart';

/// The rest of the kit, on glass cards that scroll under the bars: a
/// segmented control, a search field, a toolbar's group, and the modal layer —
/// an alert, a sheet, a menu.
///
/// The cards are glass and the bars are lifted over them ([GlassScrollEdge]
/// lifts what it carries), so the bars show the cards going under them, and
/// the scroll edge blurs them as they go. The segmented control at the top
/// picks the edge's style for the whole app.
class KitPage extends StatefulWidget {
  const KitPage({
    required this.insets,
    required this.edge,
    required this.onEdge,
    super.key,
  });

  final EdgeInsets insets;

  /// The scroll edge's style, or null for none.
  final GlassScrollEdgeStyle? edge;
  final ValueChanged<GlassScrollEdgeStyle?> onEdge;

  @override
  State<KitPage> createState() => _KitPageState();
}

class _KitPageState extends State<KitPage> {
  int _range = 1;
  String _last = 'nothing yet';

  void _say(String what) => setState(() => _last = what);

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final int edge = switch (widget.edge) {
      GlassScrollEdgeStyle.soft => 0,
      GlassScrollEdgeStyle.hard => 1,
      null => 2,
    };
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              widget.insets.top + 8,
              16,
              widget.insets.bottom + 16,
            ),
            children: <Widget>[
              _Card(
                title: 'Scroll edge',
                child: GlassSegmentedControl(
                  segments: const <Widget>[
                    Text('Soft'),
                    Text('Hard'),
                    Text('None'),
                  ],
                  selectedIndex: edge,
                  onSelected: (int i) => widget.onEdge(
                    <GlassScrollEdgeStyle?>[
                      GlassScrollEdgeStyle.soft,
                      GlassScrollEdgeStyle.hard,
                      null,
                    ][i],
                  ),
                ),
              ),
              _Card(
                title: 'Segments',
                child: GlassSegmentedControl(
                  segments: const <Widget>[
                    Text('Day'),
                    Text('Week'),
                    Text('Month'),
                    Text('Year'),
                  ],
                  selectedIndex: _range,
                  onSelected: (int i) => setState(() => _range = i),
                ),
              ),
              _Card(
                title: 'Search',
                child: GlassTextField.search(
                  onSubmitted: (String q) => _say('searched "$q"'),
                ),
              ),
              _Card(
                title: 'Toolbar',
                child: Row(
                  children: <Widget>[
                    GlassButtonGroup(
                      items: <GlassToolbarItem>[
                        GlassToolbarItem(
                          icon: const SiteIcon(SFIcons.sf_square_and_arrow_up),
                          label: 'Share',
                          onPressed: () => _say('share'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GlassButtonGroup(
                      items: <GlassToolbarItem>[
                        GlassToolbarItem(
                          icon: const SiteIcon(SFIcons.sf_heart),
                          label: 'Like',
                          onPressed: () => _say('like'),
                        ),
                        GlassToolbarItem(
                          icon: const SiteIcon(SFIcons.sf_bookmark),
                          label: 'Save',
                          onPressed: () => _say('save'),
                        ),
                        GlassToolbarItem(
                          icon: const SiteIcon(SFIcons.sf_trash),
                          label: 'Delete',
                          onPressed: () => _say('delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _Card(
                title: 'Modal',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    GlassButton(
                      onPressed: () => showGlassDialog<void>(
                        context: context,
                        builder: (BuildContext context) => GlassAlert(
                          title: const Text('Delete the photo?'),
                          message: const Text(
                            'It will be gone from every device.',
                          ),
                          actions: <GlassAlertAction>[
                            GlassAlertAction(
                              label: 'Cancel',
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            GlassAlertAction(
                              label: 'Delete',
                              isDestructive: true,
                              onPressed: () {
                                Navigator.of(context).pop();
                                _say('deleted');
                              },
                            ),
                          ],
                        ),
                      ),
                      child: const Text('Alert'),
                    ),
                    GlassButton(
                      onPressed: () => showGlassSheet<void>(
                        context: context,
                        builder: (BuildContext context) => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'A sheet',
                                style: text.titleLarge?.copyWith(
                                  color: DefaultTextStyle.of(context).style.color,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Drag it down, or tap above it, to let it go.',
                              ),
                              const SizedBox(height: 160),
                            ],
                          ),
                        ),
                      ),
                      child: const Text('Sheet'),
                    ),
                    GlassMenuAnchor(
                      items: <GlassMenuItem>[
                        GlassMenuItem(
                          label: 'Rename',
                          icon: const SiteIcon(SFIcons.sf_pencil, size: 18),
                          onPressed: () => _say('rename'),
                        ),
                        GlassMenuItem(
                          label: 'Duplicate',
                          icon: const SiteIcon(SFIcons.sf_document_on_document, size: 18),
                          onPressed: () => _say('duplicate'),
                        ),
                        GlassMenuItem(
                          label: 'Delete',
                          icon: const SiteIcon(SFIcons.sf_trash, size: 18),
                          isDestructive: true,
                          onPressed: () => _say('delete'),
                        ),
                      ],
                      builder: (BuildContext context, GlassMenuController menu) => GlassButton(
                        onPressed: menu.open,
                        child: const Text('Menu'),
                      ),
                    ),
                  ],
                ),
              ),
              _Card(title: 'Last action', child: Text(_last)),
              for (var i = 0; i < 12; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: GradientTile(index: i, height: 90),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: DefaultTextStyle.of(context).style.color?.withValues(alpha: 0.7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    ),
  );
}
