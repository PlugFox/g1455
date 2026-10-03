import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';

import '../app/routes.dart';
import '../app/theme.dart';
import '../shell/shell.dart';

/// An address the site has no page for.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.path, super.key});

  final String path;

  @override
  Widget build(BuildContext context) => SiteShell(
    title: 'Not found',
    builder: (BuildContext context, EdgeInsets insets) => Padding(
      padding: EdgeInsets.fromLTRB(16, insets.top, 16, insets.bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: GlassCard(
            padding: const EdgeInsets.all(28),
            child: Builder(
              builder: (BuildContext context) {
                final Color label = DefaultTextStyle.of(context).style.color ?? kSiteText;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        '404',
                        style: TextStyle(color: label, fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: -2),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'There is no glass at $path.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: label.withValues(alpha: 0.8), fontSize: 16),
                    ),
                    const SizedBox(height: 22),
                    GlassButton(onPressed: () => openHome(context), child: const Text('Back to the overview')),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
