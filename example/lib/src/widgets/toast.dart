import 'dart:async';

import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import 'site_icon.dart';

/// Says, for a moment, that something happened: a capsule of glass at the
/// foot of the window — "Link copied", "Code copied".
///
/// In the root overlay, which is under the app's one `GlassHost`, so the
/// toast is glass like any other and reads over whatever the page shows
/// there. It grows in through [GlassSurface.presence] and its finish arrives
/// through [GlassSurface.materialize], the way the package brings glass in;
/// a second toast replaces the first rather than stacking on it.
void showGlassToast(BuildContext context, String message, {IconData icon = SFIcons.sf_checkmark_circle}) {
  final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }
  _current?.dismiss();
  final toast = _Toast(message: message, icon: icon);
  _current = toast;
  toast.show(overlay);
}

_Toast? _current;

const Duration _kShown = Duration(milliseconds: 1800);
const Duration _kIn = Duration(milliseconds: 320);
const Duration _kOut = Duration(milliseconds: 220);

class _Toast {
  _Toast({required this.message, required this.icon});

  final String message;
  final IconData icon;
  final GlobalKey<_ToastViewState> _view = GlobalKey<_ToastViewState>();
  OverlayEntry? _entry;
  Timer? _timer;

  void show(OverlayState overlay) {
    final entry = OverlayEntry(
      builder: (BuildContext context) => _ToastView(key: _view, message: message, icon: icon),
    );
    _entry = entry;
    overlay.insert(entry);
    _timer = Timer(_kShown, dismiss);
  }

  Future<void> dismiss() async {
    _timer?.cancel();
    _timer = null;
    final OverlayEntry? entry = _entry;
    if (entry == null) {
      return;
    }
    _entry = null;
    if (identical(_current, this)) {
      _current = null;
    }
    await _view.currentState?.leave();
    entry.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.message, required this.icon, super.key});

  final String message;
  final IconData icon;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: _kIn,
    reverseDuration: _kOut,
  )..forward();

  Future<void> leave() => _presence.reverse().orCancel.catchError((Object _) {});

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool still = MediaQuery.disableAnimationsOf(context);
    final Color label = GlassTheme.of(context).legibility().label;
    return Positioned(
      left: 16,
      right: 16,
      bottom: safe.bottom + 28,
      child: IgnorePointer(
        // Animating over a still page: its own layer, so the page under it
        // is not repainted with it.
        child: RepaintBoundary(
          child: Semantics(
            liveRegion: true,
            child: Center(
              child: AnimatedBuilder(
                animation: _presence,
                builder: (BuildContext context, Widget? child) {
                  final double t = still ? (_presence.value > 0 ? 1 : 0) : _presence.value;
                  return Transform.translate(
                    offset: Offset(0, (1 - Curves.easeOutCubic.transform(t)) * 24),
                    child: GlassSurface(
                      borderRadius: kGlassCapsule,
                      presence: Curves.easeOutBack.transform(t).clamp(0.0, 1.0),
                      materialize: Curves.easeIn.transform(t),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SiteIcon(widget.icon, size: 18, color: label),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          // Over the overlay, not a page: no `Material` above to set
                          // the text, so all of it is set here.
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: label,
                            fontSize: 14,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
