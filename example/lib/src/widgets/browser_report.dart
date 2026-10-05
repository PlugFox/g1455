import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app/theme.dart';
import '../platform/browser_info.dart';
import 'site_icon.dart';

/// Read once per visit: a WebGL2 context is not free, and the answers do not
/// change while the page is open.
final BrowserInfo? _kInfo = readBrowserInfo();

/// What this browser says about its GPU and screen, next to what the package
/// assumes about them — on the web only; nothing at all elsewhere.
class BrowserReport extends StatelessWidget {
  const BrowserReport({super.key});

  @override
  Widget build(BuildContext context) {
    final BrowserInfo? info = _kInfo;
    if (info == null) {
      return const SizedBox.shrink();
    }
    final GlassHardware hardware = GlassHardware.detect();
    final int assumed = hardware.maxTextureSide;
    final int? real = info.maxTextureSize;
    final double width = MediaQuery.sizeOf(context).width;
    return Semantics(
      container: true,
      label: 'This browser',
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kSiteFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kSiteLine),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  SiteIcon(SFIcons.sf_cpu, size: 18, color: kSiteAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This browser',
                      style: TextStyle(color: kSiteText, fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Read here, from WebGL2 and the navigator, and sent nowhere. '
                'GlassHardware.detect() answers ${hardware.name}, which caps the capture atlas at $assumed px'
                '${real == null
                    ? '.'
                    : real >= assumed
                    ? '; this GPU takes $real.'
                    : ', more than the $real this GPU takes.'}',
                style: const TextStyle(color: kSiteTextMuted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 28,
                runSpacing: 16,
                children: <Widget>[
                  for (final BrowserFacts group in info.groups)
                    SizedBox(
                      width: width < 600 ? double.infinity : 300,
                      child: _Group(group: group),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group});

  final BrowserFacts group;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        group.title.toUpperCase(),
        style: const TextStyle(color: kSiteAccent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
      const SizedBox(height: 6),
      for (final (String name, String value) in group.facts)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 4,
                child: Text(name, style: const TextStyle(color: kSiteTextMuted, fontSize: 12.5)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 7,
                child: Text(
                  value,
                  style: const TextStyle(color: kSiteText, fontSize: 12.5, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}
