import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Three pulsing dots — the splash's progress indicator in the approved
/// mockup, where a `CircularProgressIndicator` would read as "working" rather
/// than "starting".
///
/// Written rather than composed because no existing `tc_*` widget covers it:
/// [TcLoading] is a spinner with an optional caption, which is a different
/// shape of statement.
///
/// The phase is a pure function of the controller value, so a widget test that
/// pumps a fixed duration lands on a deterministic frame and the golden is
/// stable.
class TcDotsLoader extends StatefulWidget {
  const TcDotsLoader({
    super.key,
    this.color = AppColors.skyBlue,
    this.dotSize = 10,
    this.semanticsLabel,
  });

  final Color color;

  /// Design-spec diameter; scaled with `.r` at build time, never at static init.
  final double dotSize;

  /// Announced in place of the dots themselves, which say nothing useful to a
  /// screen reader.
  final String? semanticsLabel;

  @override
  State<TcDotsLoader> createState() => _TcDotsLoaderState();
}

class _TcDotsLoaderState extends State<TcDotsLoader>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 3;
  static const Duration _period = Duration(milliseconds: 1200);

  /// How far each dot trails the one before it, as a fraction of the period.
  static const double _stagger = 0.2;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Triangle wave, so the pulse eases in and out symmetrically without a
  /// visible jump when the controller wraps from 1.0 back to 0.0.
  double _opacityFor(int index, double t) {
    final phase = (t - index * _stagger) % 1.0;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + 0.7 * wave;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.dotSize.r;

    return Semantics(
      label: widget.semanticsLabel,
      // The dots are decoration once the label above carries the meaning.
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _dotCount; i++) ...[
              if (i > 0) SizedBox(width: AppDimensions.spacing8),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(
                    alpha: _opacityFor(i, _controller.value),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
