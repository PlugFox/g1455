import 'package:flutter/material.dart';
import 'package:g1455/g1455.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app/theme.dart';
import '../platform/site_update.dart';
import 'site_icon.dart';

/// Says that a newer build of the site is live, and reloads into it.
///
/// A capsule of glass at the foot of the window, as the toast is, but it stays
/// until it is answered: "Reload" moves the tab onto the new build, the cross
/// puts it off until the next visit. Over [child], which is the whole app — it
/// is above the navigator, so it stands over every page and every route.
class SiteUpdateBanner extends StatefulWidget {
  const SiteUpdateBanner({required this.child, super.key});

  final Widget child;

  @override
  State<SiteUpdateBanner> createState() => _SiteUpdateBannerState();
}

class _SiteUpdateBannerState extends State<SiteUpdateBanner> with SingleTickerProviderStateMixin {
  final SiteUpdates? _updates = watchSiteUpdates();

  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );

  bool _dismissed = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _updates?.addListener(_changed);
  }

  @override
  void dispose() {
    _updates
      ?..removeListener(_changed)
      ..dispose();
    _presence.dispose();
    super.dispose();
  }

  void _changed() {
    if (_updates?.available ?? false) {
      setState(() {});
      _presence.forward();
    }
  }

  Future<void> _dismiss() async {
    await _presence.reverse().orCancel.catchError((Object _) {});
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  Future<void> _reload() async {
    setState(() => _applying = true);
    await _updates?.apply();
  }

  @override
  Widget build(BuildContext context) {
    final bool shown = (_updates?.available ?? false) && !_dismissed;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: widget.child),
        if (shown) _banner(context),
      ],
    );
  }

  Widget _banner(BuildContext context) {
    final EdgeInsets safe = MediaQuery.paddingOf(context);
    final bool still = MediaQuery.disableAnimationsOf(context);
    final Color label = GlassTheme.of(context).legibility().label;
    // Over the navigator, not a page: no `Material` above to set the text, so
    // all of it is set here.
    final TextStyle text = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: label,
      fontSize: 14,
      height: 1.3,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    );
    return Positioned(
      left: 16,
      right: 16,
      bottom: safe.bottom + 24,
      child: Center(
        child: Semantics(
          liveRegion: true,
          container: true,
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
              padding: const EdgeInsets.fromLTRB(20, 6, 6, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SiteIcon(SFIcons.sf_arrow_down_app, size: 18, color: label),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text('A new version of the site is out', maxLines: 2, style: text),
                  ),
                  const SizedBox(width: 12),
                  // Not glass: a control on a glass panel is glass on glass, a
                  // second capture level for one tap target.
                  _Pill(
                    label: _applying ? 'Reloading…' : 'Reload',
                    style: text.copyWith(color: kSiteBackground),
                    onTap: _applying ? null : _reload,
                  ),
                  _Close(colour: label, onTap: _applying ? null : _dismiss),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.style, required this.onTap});

  final String label;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const ShapeDecoration(shape: StadiumBorder(), color: kSiteAccent),
          child: Text(label, style: style),
        ),
      ),
    ),
  );
}

class _Close extends StatelessWidget {
  const _Close({required this.colour, required this.onTap});

  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: 'Later',
    excludeSemantics: true,
    child: MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: SiteIcon(SFIcons.sf_xmark, size: 18, color: colour.withValues(alpha: 0.75)),
        ),
      ),
    ),
  );
}
