/// Flux: Spring animations with velocity handoff.
///
/// Ported from Fuchsia's Mondrian story shell animation system, copied into
/// libmonet from telosnex's `features/flux` port so `AnimatedMonetTheme` can
/// use `MovingTargetAnimation` instead of a fixed-duration
/// `AnimationController`.
///
/// Note: the Flutter Hooks integration (`useFluxSpring`/`useFluxManual`) is
/// intentionally not copied here, since `libmonet` does not depend on
/// `flutter_hooks`. Use the `FluxAnimation`/`SimAnimationController`/
/// `MovingTargetAnimation` classes directly, as `AnimatedMonetTheme` does.
library;

export 'flux_animation.dart';
export 'flux_curve.dart';
export 'rk4_spring.dart';
export 'sim.dart';
export 'spring.dart';
