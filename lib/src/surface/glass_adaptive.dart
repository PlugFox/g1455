// Glass that reads its own backdrop.
//
// Every other input to the label and to the branch of `.regular` is declared:
// the screen's mean ([GlassThemeData.backdrop]), whether it is an image
// ([GlassThemeData.richBackdrop]), the platform's appearance. A declaration is
// one number for a whole screen, and a screen is not one level: a bar over a
// photograph's sky and a button over its shadow are on different branches of
// Apple's own material, which picks per glass, from what is under it (D230).
//
// The host already holds that: the atlas is the pixels under every surface.
// This file is the price of looking at them, and the machinery that keeps the
// answer from flickering.
//
//  - **Off by default, and nothing at all when off.** No reader exists, no
//    picture is recorded, nothing is read back, no ticker is made, and the
//    components take the path they always took. [GlassProxyHandle.readBacks]
//    is the counter that says so.
//  - **On, one read-back per capture at most, and never one per frame.** A
//    frame that keeps its capture — a still screen, glass moving over content
//    that stays put — has nothing new under the glass and reads nothing. A
//    frame that captures asks for one read of a texture of 4 × 4 pixels per
//    surface ([ProxyReading]), at most once per [GlassAdaptive.interval],
//    asynchronously: the frame that asked does not wait for it, and the answer
//    is applied on a later one.
//  - **A band and a hold.** A reading moves the verdict only when it is more
//    than [GlassAdaptive.band] code values from the reading the verdict was
//    last taken from, and not within [GlassAdaptive.hold] of the last move. So
//    a glass over a backdrop near the threshold — a list of alternating rows
//    scrolling under a bar — keeps the branch it has, and a real change of
//    backdrop moves it at most once per hold.
//  - **Moves animate.** A component crossing between branches tweens its
//    finish over [GlassAdaptive.duration], and snaps under
//    `MediaQuery.disableAnimations`. The label is not tweened: on each frame
//    it is the one that reads on the glass as drawn, which keeps the floor
//    where a lerped label would pass through grey on grey.
//
// **What a reading replaces, and what it does not** — the precedence, from the
// strongest:
//
//  1. A finish a surface or component names for itself is held: no reading
//     re-picks it. The label over it is still chosen against the reading, as it
//     would be against a declared [GlassThemeData.backdrop].
//  2. A finish the host or an inner [GlassTheme] names is held the same way —
//     `GlassHost(finish: GlassFinish.regularDark)` is a dark glass whatever is
//     under it, which is how an application asks for one.
//  3. Otherwise the finish is `.regular`, and its branch is the reading's, by
//     [GlassFinish.regular] against the appearance's threshold. Before a glass
//     has a reading — its first two frames, a rung that captures nothing — it is
//     what the declarations give, exactly as with this off.
//
// And the label: a reading stands in for [GlassThemeData.backdrop] for the one
// glass it was read under, so the label, the high-contrast outline and the
// [GlassThemeData.minLabelContrast] dim are all chosen against it. Unless the
// screen is declared [GlassThemeData.richBackdrop], in which case a mean is
// still the wrong statistic for a label — it says nothing about the brightest
// corner of a photograph — and the label stays chosen against every backdrop;
// the reading then moves only the branch.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../proxy/proxy_atlas.dart';
import '../proxy/proxy_pipeline.dart';
import '../proxy/proxy_reading.dart';
import 'glass_finish.dart';
import 'glass_host.dart';
import 'glass_ledger.dart';

/// How a [GlassHost]'s glass reads its own backdrop: pass one as
/// `GlassHost.adaptive` to turn it on.
///
/// ```dart
/// GlassHost(
///   adaptive: const GlassAdaptive(),
///   child: Stack(children: <Widget>[photo, Positioned(top: 48, child: GlassBar(child: title))]),
/// )
/// ```
///
/// **What it costs.** Nothing on a frame that keeps its capture, which is every
/// frame of a still screen. On a frame that captures — a scroll, an animation
/// under the glass — one picture of one `drawImageRect` per surface, recorded
/// on the UI thread (microseconds), and at most once per [interval] a
/// rasterization of it into a texture of 4 × 4 pixels per surface and a copy of
/// that texture back to the CPU, both asynchronous. On Impeller and Skia the
/// copy is a few hundred bytes queued behind the frame's own work; the frame
/// that asked does not wait for it.
///
/// **On the web it is dearer, and the default [interval] is longer there for
/// that reason.** CanvasKit answers `Picture.toImage` by drawing into a surface
/// and reading its pixels back synchronously — the same stall the capture
/// itself pays on that renderer (see the README's Platforms section) — so each
/// read is a GPU flush on the frame it lands in, however small the texture.
/// Skwasm reads on its own thread and pays less. One read a second is the
/// default on both; raise [interval] further on CanvasKit if the screen
/// scrolls a lot.
@immutable
class GlassAdaptive {
  const GlassAdaptive({
    this.band = kDefaultBand,
    this.hold = kDefaultHold,
    this.interval = kDefaultInterval,
    this.duration = kDefaultDuration,
  }) : assert(band >= 0, 'a band is a distance');

  /// How far, in code values of luma ([GlassFinish.levelOf]), a reading must
  /// be from the one the verdict was taken from to move it. 12 by default.
  ///
  /// **Taste, not a measurement**, and named so: D230 read Apple's switch
  /// between greys four codes apart, fresh from launch, and did not read its
  /// hysteresis. 12 is three of those steps — wider than the noise of a mean
  /// over a scrolling list of text, and narrow against the 200 codes between
  /// the two appearances' thresholds.
  final double band;

  /// The least time between two moves of one glass's verdict. 600 ms by
  /// default — taste, as [band] is: long enough that content scrolling past
  /// a threshold moves the glass once rather than once per row, and short
  /// enough that a screen settled over a new backdrop follows it within a
  /// glance. A reading that arrives inside the hold is kept, and taken when the
  /// hold ends if nothing newer has replaced it.
  final Duration hold;

  /// The least time between two read-backs. Captures that arrive sooner are
  /// read together when it has passed — the newest of them, once.
  ///
  /// 250 ms by default, and a second on the web, where a read-back is a
  /// synchronous GPU flush on CanvasKit (see the class's cost note).
  final Duration interval;

  /// How long a component takes to cross between branches. 300 ms by default,
  /// eased in and out — taste; Apple's own crossing was not timed. None under
  /// `MediaQuery.disableAnimations`.
  final Duration duration;

  /// [band]'s default.
  static const double kDefaultBand = 12;

  /// [hold]'s default.
  static const Duration kDefaultHold = Duration(milliseconds: 600);

  /// [interval]'s default: 250 ms natively, a second on the web.
  static const Duration kDefaultInterval = kIsWeb ? Duration(seconds: 1) : Duration(milliseconds: 250);

  /// [duration]'s default.
  static const Duration kDefaultDuration = Duration(milliseconds: 300);

  @override
  bool operator ==(Object other) =>
      other is GlassAdaptive &&
      other.band == band &&
      other.hold == hold &&
      other.interval == interval &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(band, hold, interval, duration);

  @override
  String toString() =>
      'GlassAdaptive(band $band, hold ${hold.inMilliseconds} ms, '
      'interval ${interval.inMilliseconds} ms, duration ${duration.inMilliseconds} ms)';
}

/// What one glass read of the backdrop under it: the mean of the captured
/// pixels inside its box.
///
/// Inside a component that reads its backdrop, `GlassTheme.of(context).reading`
/// is this, so content on the glass can follow it — an icon that is not a
/// label, a custom painter.
@immutable
class GlassBackdropReading {
  const GlassBackdropReading(this.mean);

  /// The mean encoded colour of the backdrop under the glass, opaque.
  ///
  /// Of the *captured* backdrop, which is the screen under the glass at the
  /// proxy's resolution and after the finish's residual blur — both of which a
  /// mean is blind to — and without the glass itself, which a capture never
  /// contains.
  final Color mean;

  /// [mean]'s luma in code values — the scale `.regular` switches on
  /// ([GlassFinish.levelOf]).
  double get level => GlassFinish.levelOf(mean);

  /// [mean]'s relative luminance, WCAG's.
  double get luminance => mean.computeLuminance();

  /// Whether the backdrop is light or dark, by which of black and white stands
  /// out more against it — the label rule ([GlassFinish.foregroundOver]) with
  /// no glass between.
  ///
  /// Not the branch of `.regular`, which depends on the appearance as well;
  /// `GlassTheme.of(context).finish` is that.
  Brightness get brightness =>
      GlassFinish.contrastRatio(mean, const Color(0xFF000000)) >=
          GlassFinish.contrastRatio(mean, const Color(0xFFFFFFFF))
      ? Brightness.light
      : Brightness.dark;

  @override
  bool operator ==(Object other) => other is GlassBackdropReading && other.mean == mean;

  @override
  int get hashCode => mean.hashCode;

  @override
  String toString() => 'GlassBackdropReading(level ${level.toStringAsFixed(1)})';
}

/// One glass's verdict over time: the readings it is offered, and the one it
/// keeps.
///
/// The whole anti-flicker rule, kept apart from the read-back so it can be
/// driven without a frame: [offer] moves the kept reading only when the fresh
/// one is more than [GlassAdaptive.band] away from it and the last move is at
/// least [GlassAdaptive.hold] old. A reading refused only by the hold is kept
/// as [pending], and [settle] takes it once [due] has passed.
///
/// Times are whatever monotonic clock the caller uses; the host's is the frame
/// timestamp, so a test's fake clock drives it.
class GlassBackdropVerdict {
  GlassBackdropVerdict(this.adaptive);

  /// The band and the hold. May be replaced; the next offer uses the new one.
  GlassAdaptive adaptive;

  /// The reading the verdict stands on, or null before the first.
  GlassBackdropReading? get kept => _kept;
  GlassBackdropReading? _kept;
  Duration? _keptAt;

  /// A reading outside the band that the hold turned away, or null.
  GlassBackdropReading? get pending => _pending;
  GlassBackdropReading? _pending;

  /// When [pending] may be taken, or null when there is none.
  Duration? get due => _pending == null ? null : _keptAt! + adaptive.hold;

  /// Takes [fresh], read at [now]. True when [kept] moved.
  bool offer(GlassBackdropReading fresh, Duration now) {
    final GlassBackdropReading? kept = _kept;
    if (kept != null) {
      if ((fresh.level - kept.level).abs() <= adaptive.band) {
        // Back inside the band: whatever the hold was keeping is stale.
        _pending = null;
        return false;
      }
      if (now - _keptAt! < adaptive.hold) {
        _pending = fresh;
        return false;
      }
    }
    _kept = fresh;
    _keptAt = now;
    _pending = null;
    return true;
  }

  /// Offers [pending] again, at [now]. True when [kept] moved.
  bool settle(Duration now) {
    final GlassBackdropReading? pending = _pending;
    return pending != null && offer(pending, now);
  }
}

/// The verdicts of every glass under one host, as something a component can
/// listen to.
///
/// Notifies when some glass's verdict moves and at no other time — which, by
/// the band and the hold, is a handful of times a session rather than a frame.
class GlassBackdropReadings extends ChangeNotifier {
  final Map<Object, GlassBackdropReading> _of = <Object, GlassBackdropReading>{};

  /// The verdict for [surface] — the `RenderGlassSurface` the reading was taken
  /// under — or null when it has none yet.
  GlassBackdropReading? of(Object surface) => _of[surface];

  /// How many glasses have a verdict.
  int get length => _of.length;

  void _set(Map<Object, GlassBackdropReading> moved, Iterable<Object> gone) {
    var changed = false;
    for (final Object key in gone) {
      changed |= _of.remove(key) != null;
    }
    for (final MapEntry<Object, GlassBackdropReading> e in moved.entries) {
      if (_of[e.key] != e.value) {
        _of[e.key] = e.value;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }
}

/// The host's half: when to read, what to read, and what to do with the answer.
///
/// Exists only while `GlassHost.adaptive` is set, so a host without it carries
/// none of this — no picture, no timer, no counter moving.
class GlassBackdropReader {
  GlassBackdropReader(this._adaptive, this.handle);

  GlassAdaptive get adaptive => _adaptive;
  GlassAdaptive _adaptive;
  set adaptive(GlassAdaptive value) {
    _adaptive = value;
    for (final GlassBackdropVerdict v in _verdicts.values) {
      v.adaptive = value;
    }
  }

  /// Where the frames are, and where [GlassProxyHandle.readBacks] is counted.
  final GlassProxyHandle handle;

  /// What the components listen to.
  final GlassBackdropReadings readings = GlassBackdropReadings();

  final Map<Object, GlassBackdropVerdict> _verdicts = <Object, GlassBackdropVerdict>{};

  /// The newest capture not yet read: each surface and its box, in global
  /// logical pixels. Replaced by every capture, so a burst of them is read once.
  List<({GlassSurfaceGeometry surface, Rect box})>? _due;

  bool _inFlight = false;
  Duration? _lastRead;
  Timer? _wake;
  Duration? _wakeAt;
  final Set<int> _callbacks = <int>{};
  bool _disposed = false;

  /// Read-backs started and landed. [started] is mirrored to
  /// [GlassProxyHandle.readBacks].
  int started = 0;
  int landed = 0;

  /// Whether nothing has been handed to [captured] yet. The host hands a held
  /// frame over only then: a reader turned on over a still screen would
  /// otherwise wait for the next change to read anything at all.
  bool get hungry => _hungry;
  bool _hungry = true;

  /// Called by the host on a frame that published a capture, with every
  /// surface that capture holds and its box — and on a held one only while
  /// [hungry].
  void captured(List<({GlassSurfaceGeometry surface, Rect box})> surfaces, Duration now) {
    _hungry = false;
    _due = surfaces;
    _pump(now);
  }

  /// Drops the verdicts of surfaces that have left the register.
  ///
  /// Kept as well: a read in flight lands after this, and what it read for a
  /// surface that has left since is dropped rather than given a verdict again.
  void prune(Set<GlassSurfaceGeometry> registered) {
    _registered = registered;
    final gone = <Object>[
      for (final Object key in _verdicts.keys)
        if (!registered.contains(key)) key,
    ];
    if (gone.isEmpty) {
      return;
    }
    for (final Object key in gone) {
      _verdicts.remove(key);
    }
    readings._set(const <Object, GlassBackdropReading>{}, gone);
  }

  /// The register as of the last [prune].
  Set<GlassSurfaceGeometry> _registered = const <GlassSurfaceGeometry>{};

  void _pump(Duration now) {
    if (_due == null || _inFlight) {
      return;
    }
    final Duration? last = _lastRead;
    if (last != null && now - last < _adaptive.interval) {
      _wakeAfter(last + _adaptive.interval - now, now);
      return;
    }
    _start(now);
  }

  void _start(Duration now) {
    final List<({GlassSurfaceGeometry surface, Rect box})> due = _due!;
    _due = null;
    final keys = <GlassSurfaceGeometry>[];
    final sources = <ProxyReadingSource>[];
    for (final (:GlassSurfaceGeometry surface, :Rect box) in due) {
      // The frame published now, not the one the capture made: a level above
      // may have been re-recorded since, and the one it replaced is released.
      final GlassProxyFrame? frame = handle.frameFor(surface);
      final AtlasSlot? slot = frame?.slotForKey(surface);
      if (frame == null || slot == null) {
        continue;
      }
      keys.add(surface);
      sources.add((image: frame.image, source: ProxyReading.sourceIn(slot, box)));
    }
    if (keys.isEmpty) {
      return;
    }
    _inFlight = true;
    _lastRead = now;
    started++;
    handle.readBacks = started;
    ProxyReading.read(ProxyReading.record(sources), keys.length).then(
      (List<Color?> means) => _landed(keys, means),
      onError: (Object _) => _landed(keys, const <Color?>[]),
    );
  }

  /// The answer is in. Applied at the start of the next frame, whose timestamp
  /// is the clock the hold is measured on — and which a change of verdict
  /// would rebuild anyway.
  void _landed(List<GlassSurfaceGeometry> keys, List<Color?> means) {
    if (_disposed) {
      return;
    }
    landed++;
    _nextFrame((Duration now) {
      final moved = <Object, GlassBackdropReading>{};
      for (var i = 0; i < keys.length && i < means.length; i++) {
        final Color? mean = means[i];
        if (mean == null || !_registered.contains(keys[i])) {
          continue;
        }
        final GlassBackdropVerdict verdict = _verdicts.putIfAbsent(keys[i], () => GlassBackdropVerdict(_adaptive));
        if (verdict.offer(GlassBackdropReading(mean), now)) {
          moved[keys[i]] = verdict.kept!;
        }
      }
      readings._set(moved, const <Object>[]);
      _inFlight = false;
      _settleAndRearm(now);
      _pump(now);
    });
  }

  /// Takes every reading whose hold has ended, and wakes for the next one.
  void _settleAndRearm(Duration now) {
    final moved = <Object, GlassBackdropReading>{};
    Duration? next;
    for (final MapEntry<Object, GlassBackdropVerdict> e in _verdicts.entries) {
      final Duration? due = e.value.due;
      if (due == null) {
        continue;
      }
      if (due <= now) {
        if (e.value.settle(now)) {
          moved[e.key] = e.value.kept!;
        }
      } else if (next == null || due < next) {
        next = due;
      }
    }
    readings._set(moved, const <Object>[]);
    if (next != null) {
      _wakeAfter(next - now, now);
    }
  }

  /// Comes back at the start of a frame [after] from [now], for a read the
  /// interval deferred or a reading the hold did. A timer and then one frame,
  /// rather than a ticker: a screen that is still asks for nothing until then.
  void _wakeAfter(Duration after, Duration now) {
    final Duration at = now + after;
    final Duration? armed = _wakeAt;
    if (armed != null && armed <= at && _wake != null) {
      return;
    }
    _wake?.cancel();
    _wakeAt = at;
    _wake = Timer(after, () {
      _wake = null;
      _wakeAt = null;
      if (_disposed) {
        return;
      }
      _nextFrame((Duration t) {
        _settleAndRearm(t);
        _pump(t);
      });
    });
  }

  /// Runs [then] at the start of the next frame, with that frame's system
  /// timestamp, unless the reader is disposed first.
  void _nextFrame(void Function(Duration now) then) {
    late final int id;
    id = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _callbacks.remove(id);
      if (!_disposed) {
        then(SchedulerBinding.instance.currentSystemFrameTimeStamp);
      }
    });
    _callbacks.add(id);
  }

  void dispose() {
    _disposed = true;
    _wake?.cancel();
    _wake = null;
    for (final int id in _callbacks) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    }
    _callbacks.clear();
    readings.dispose();
  }
}
