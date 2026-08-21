import 'package:flutter/widgets.dart';

/// Accessibility text-scaling policy for the app (R2).
///
/// `.sp` (width-resolved via ScreenUtil) is the single SIZE-scaling source.
/// On top of that, Flutter applies the system text scale at paint time, which
/// would double-scale large fonts. This policy bounds the system contribution:
///
///  * MAXIMUM is capped: a font is never system-scaled beyond 1.3x. We cap
///    only the ceiling so very large accessibility settings do not break the
///    width-tuned layout.
///  * MINIMUM is preserved at 1.0: we NEVER floor below 1.0, so users who set a
///    system scale below 1.0 (down-scaling) still get the smaller text they
///    asked for. We do not clamp the lower bound up to 1.0.
///
/// The cap is applied through the framework [TextScaler] API so nonlinear
/// scalers (Android 14+ uses a nonlinear curve) are handled correctly: we read
/// the system scale at the reference font size, clamp the resulting factor, and
/// hand back a linear scaler at the clamped factor.
const double kMaxSystemTextScale = 1.3;

/// Font size used to sample a (possibly nonlinear) system [TextScaler].
const double _kReferenceFontSize = 14.0;

/// Returns a [TextScaler] whose effective factor is
/// `min(systemFactor, kMaxSystemTextScale)` and is never raised toward 1.0
/// (down-scaling below 1.0 is preserved).
///
/// [systemScaler] is the device's current scaler (from `MediaQuery`). It may be
/// nonlinear; we sample it at [_kReferenceFontSize] to obtain a comparable
/// factor before clamping the ceiling.
TextScaler clampTextScaler(TextScaler systemScaler) {
  final double sampledFactor =
      systemScaler.scale(_kReferenceFontSize) / _kReferenceFontSize;
  if (sampledFactor <= kMaxSystemTextScale) {
    // Within (or below) the cap: keep the system scaler verbatim so down-scaling
    // and the device's own (possibly nonlinear) curve are preserved exactly.
    return systemScaler;
  }
  // Above the cap: replace with a linear scaler pinned at the ceiling.
  return const TextScaler.linear(kMaxSystemTextScale);
}
