import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/a11y.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// ENTRANCE
/// A subtle fade-and-rise entrance for list/grid items. Staggers by [index] and
/// fully disables itself when the OS "reduce motion" setting is on, so motion is
/// never forced on users who opted out.
/// ─────────────────────────────────────────────────────────────────────────────

class Entrance extends StatelessWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.maxStagger = 8,
  });

  final Widget child;

  /// Position in the list — used to stagger the start of the animation.
  final int index;

  /// Cap on how many items stagger, so long lists don't accumulate big delays.
  final int maxStagger;

  @override
  Widget build(BuildContext context) {
    if (A11y.reduceMotion(context)) return child;

    final delay = DurationTokens.fast * (index.clamp(0, maxStagger));
    return child
        .animate()
        .fadeIn(duration: DurationTokens.normal, delay: delay)
        .moveY(begin: 12, end: 0, duration: DurationTokens.normal, delay: delay, curve: Curves.easeOutCubic);
  }
}
