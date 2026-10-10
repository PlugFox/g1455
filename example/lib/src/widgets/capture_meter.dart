import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
// The host's counter: read here to show what an interaction costs. An
// application has no reason to import this library.
import 'package:g1455/glass_diagnostics.dart' show GlassProxyHandle, GlassProxyScope;

import '../app/theme.dart';
import 'site_icon.dart';

/// How many captures the host took for the last thing done on the stage, and
/// for everything since the page opened.
///
/// The captures of one interaction come in a burst: a run of frames that each
/// capture, then a quiet spell. The meter polls the host's counter ten times a
/// second, which repaints nothing, and closes a burst after [_kQuiet] polls
/// without a capture. It repaints only when a burst closes.
///
/// The host is the site's, and on a wide window its sidebar glass spans the
/// page, so a repaint anywhere on the page can be a capture, the meter's own
/// included: a burst below [_kNoise] is the meter answering itself, or the
/// page around the stage, and is not counted.
class CaptureMeter extends StatefulWidget {
  const CaptureMeter({super.key});

  @override
  State<CaptureMeter> createState() => _CaptureMeterState();
}

/// Polls without a capture that close a burst: 400 ms.
const int _kQuiet = 4;

/// The smallest burst that is the demo's, not the meter's own repaint.
const int _kNoise = 3;

class _CaptureMeterState extends State<CaptureMeter> {
  GlassProxyHandle? _handle;
  Timer? _timer;
  int _last = 0;
  int _burst = 0;
  int _quiet = 0;
  int? _shown;
  int _total = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final GlassProxyHandle? handle = GlassProxyScope.maybeOf(context);
    if (!identical(handle, _handle)) {
      _handle = handle;
      _last = handle?.generation ?? 0;
      _timer?.cancel();
      _timer = handle == null ? null : Timer.periodic(const Duration(milliseconds: 100), (_) => _poll());
    }
  }

  void _poll() {
    final int now = _handle?.generation ?? _last;
    final int fresh = now - _last;
    _last = now;
    if (fresh > 0) {
      _burst += fresh;
      _quiet = 0;
      return;
    }
    if (_burst == 0 || ++_quiet < _kQuiet) {
      return;
    }
    final int burst = _burst;
    _burst = 0;
    if (burst >= _kNoise) {
      setState(() {
        _shown = burst;
        _total += burst;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_handle == null) {
      return const SizedBox.shrink();
    }
    final int? shown = _shown;
    final String text = shown == null ? 'captures: none yet · total 0' : 'captures: last burst $shown · total $_total';
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SiteIcon(SFIcons.sf_camera, size: 16, color: shown == null ? kSiteTextMuted : kSiteAccent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: kSiteText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
