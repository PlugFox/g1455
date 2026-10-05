import 'package:flutter/material.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import 'toast.dart';

/// Text a reader would copy — a page's title and summary, a guide, an API
/// table, code — and nothing else.
///
/// The site used to select through one `SelectionArea` around the whole page,
/// with the demos opted out. Opting out keeps a demo's labels out of the
/// selection but not its gestures: the area still took a double click on a
/// demo and selected the word nearest to it, which is the text above the
/// stage. So a selection is a region around the text that has one, and a
/// demo, a button or a bar is outside every region.
///
/// Copying from the menu finishes the job: the text goes to the clipboard,
/// the menu closes, the selection clears and a toast says so. Left selected,
/// the highlight and the menu stayed over the page until the next click.
class SiteSelectionArea extends StatelessWidget {
  const SiteSelectionArea({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(contextMenuBuilder: _menu, child: child);

  static Widget _menu(BuildContext context, SelectableRegionState region) => AdaptiveTextSelectionToolbar.buttonItems(
    anchors: region.contextMenuAnchors,
    buttonItems: <ContextMenuButtonItem>[
      for (final ContextMenuButtonItem item in region.contextMenuButtonItems)
        if (item.type == ContextMenuButtonType.copy)
          item.copyWith(
            onPressed: () {
              // The region's own copy reads the selection, so it goes first.
              item.onPressed?.call();
              region
                ..hideToolbar()
                ..clearSelection();
              showGlassToast(context, 'Copied', icon: SFIcons.sf_document_on_document);
            },
          )
        else
          item,
    ],
  );
}

/// [SiteSelectionArea]'s menu for a flutter_md [MarkdownSelectionScope].
Widget markdownSelectionMenu(BuildContext context, MarkdownSelectionScopeState scope) =>
    AdaptiveTextSelectionToolbar.buttonItems(
      anchors: scope.contextMenuAnchors,
      buttonItems: <ContextMenuButtonItem>[
        for (final ContextMenuButtonItem item in scope.contextMenuButtonItems)
          if (item.type == ContextMenuButtonType.copy)
            item.copyWith(
              onPressed: () async {
                await scope.copySelection();
                scope.clearSelection();
                if (context.mounted) {
                  showGlassToast(context, 'Copied', icon: SFIcons.sf_document_on_document);
                }
              },
            )
          else
            item,
      ],
    );
