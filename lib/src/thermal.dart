// The thermal vocabulary the host spends staleness against.
//
// Only the vocabulary: the package does not read the device. Flutter carries no
// thermal state, and reading it takes native code on every platform, which this
// package deliberately does not ship — the application passes what it read, from
// whatever source it has, to `GlassHost.thermal`.

/// Thermal pressure, in Apple's four names — the coarser vocabulary of the two,
/// so every Android status maps onto one of them and none of Apple's is
/// invented.
///
/// Android's seven statuses fold as `NONE` → [nominal], `LIGHT` and `MODERATE`
/// → [fair], `SEVERE` → [serious], `CRITICAL`, `EMERGENCY` and `SHUTDOWN` →
/// [critical]. The line between [fair] and [serious] is drawn where both
/// platforms' own documentation first says the user will notice: Apple's
/// `serious` is "system performance is impacted", Android's `SEVERE` is
/// "throttling where UX is largely impacted", and `MODERATE` is "not largely
/// impacted".
///
/// The package does not read the device: the application passes what it read
/// to [GlassHost.thermal], and [GlassHost.thermalPolicy] decides what each
/// state may spend on staleness. Null there is treated as [nominal].
///
/// ```dart
/// GlassThermalState? fromAndroid(int status) => switch (status) {
///   0 => GlassThermalState.nominal, // THERMAL_STATUS_NONE
///   1 || 2 => GlassThermalState.fair, // LIGHT, MODERATE
///   3 => GlassThermalState.serious, // SEVERE
///   4 || 5 || 6 => GlassThermalState.critical, // CRITICAL, EMERGENCY, SHUTDOWN
///   _ => null,
/// };
///
/// GlassHost(thermal: fromAndroid(status), child: const MyScreen());
/// ```
///
/// See also:
///
///  * [GlassThermalPolicy], which turns a state into frames of staleness.
///  * [RetakeReason.throttled], the decision a throttled frame reports.
///  * <https://g1455.plugfox.dev/foundations/performance>.
///
/// {@category Cost and policy}
enum GlassThermalState {
  /// No thermal pressure: Apple's `nominal`, Android's `NONE`. Spends nothing.
  nominal,

  /// Pressure the user does not notice: Apple's `fair`, Android's `LIGHT` and
  /// `MODERATE`. Spends [GlassThermalPolicy.fairDeltaE], zero by default.
  fair,

  /// Pressure that impacts the experience: Apple's `serious`, Android's
  /// `SEVERE`. Spends [GlassThermalPolicy.seriousDeltaE].
  serious,

  /// Pressure at or past the point the platform starts shutting things down:
  /// Apple's `critical`, Android's `CRITICAL`, `EMERGENCY` and `SHUTDOWN`.
  /// Spends [GlassThermalPolicy.criticalDeltaE].
  critical,
}
