import 'package:flutter/material.dart';

import 'expressive_shape_content.dart';

export 'expressive_shape_content.dart';

enum ExpressiveButtonVariant { filled, outlined, elevated }

/// A stock Flutter button with endpoint-safe content layout.
///
/// Colors, focus, keyboard activation, semantics and ink remain Flutter's.
/// [style] controls appearance, but shape, content padding, alignment, sizing,
/// visual density and animation duration are owned here to keep paint and layout
/// coordinates identical. Use [padding] and [constraints] instead of style sizing.
///
/// Preserve [geometry] across animation ticks. Both endpoints share one stable
/// layout; intermediate clipping is allowed. The default overflow policy shrinks
/// content if the parent will not permit its full size; use `error` to detect
/// that situation during development rather than accepting smaller labels.
class ExpressiveButton extends StatelessWidget {
  const ExpressiveButton({
    super.key,
    required this.geometry,
    required this.onPressed,
    required this.child,
    this.variant = ExpressiveButtonVariant.elevated,
    this.progress = 1,
    this.stretch = false,
    this.padding = const EdgeInsets.all(8),
    this.clearance = 5,
    this.minimumScale = 2 / 3,
    this.overflow = ExpressiveContentOverflow.scaleDown,
    this.style,
    this.constraints = const BoxConstraints(minWidth: 48, minHeight: 48),
    this.statesController,
    this.focusNode,
    this.autofocus = false,
  }) : assert(minimumScale >= 0 && minimumScale <= 1);

  final ExpressiveShapeGeometry geometry;
  final VoidCallback? onPressed;
  final Widget child;
  final ExpressiveButtonVariant variant;
  final double progress;
  final bool stretch;
  final EdgeInsetsGeometry padding;
  final double clearance;
  final double minimumScale;
  final ExpressiveContentOverflow overflow;
  final ButtonStyle? style;

  /// Surface sizing, applied before content fitting. Overrides style sizes.
  final BoxConstraints constraints;
  final WidgetStatesController? statesController;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final border = geometry.border(progress: progress, stretch: stretch);
    final base = style ?? const ButtonStyle();
    final themedSide = switch (variant) {
      ExpressiveButtonVariant.filled => FilledButtonTheme.of(
        context,
      ).style?.side,
      ExpressiveButtonVariant.outlined => OutlinedButtonTheme.of(
        context,
      ).style?.side,
      ExpressiveButtonVariant.elevated => ElevatedButtonTheme.of(
        context,
      ).style?.side,
    };
    // Reserve the supplied clearance; callers with custom thick/stateful sides
    // must reserve their maximum inward stroke/miter extent explicitly.
    final effectiveStyle = base.copyWith(
      shape: WidgetStatePropertyAll(border),
      side:
          base.side ??
          themedSide ??
          WidgetStatePropertyAll(
            variant == ExpressiveButtonVariant.outlined
                ? BorderSide(color: Theme.of(context).colorScheme.outline)
                : BorderSide.none,
          ),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      alignment: Alignment.center,
      visualDensity: VisualDensity.standard,
      animationDuration: Duration.zero,
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      maximumSize: const WidgetStatePropertyAll(Size.infinite),
      // Infinite fixed axes are ignored by ButtonStyleButton, while a null
      // value would fall back to a themed fixed size and break our coordinates.
      fixedSize: const WidgetStatePropertyAll(Size.infinite),
    );
    return LayoutBuilder(
      builder: (context, parentConstraints) {
        final content = ConstrainedBox(
          constraints: constraints.enforce(parentConstraints),
          child: ExpressiveShapeContent(
            geometry: geometry,
            stretch: stretch,
            padding: padding,
            clearance: clearance,
            minimumScale: minimumScale,
            overflow: overflow,
            child: child,
          ),
        );
        return switch (variant) {
          ExpressiveButtonVariant.filled => FilledButton(
            onPressed: onPressed,
            style: effectiveStyle,
            statesController: statesController,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
          ExpressiveButtonVariant.outlined => OutlinedButton(
            onPressed: onPressed,
            style: effectiveStyle,
            statesController: statesController,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
          ExpressiveButtonVariant.elevated => ElevatedButton(
            onPressed: onPressed,
            style: effectiveStyle,
            statesController: statesController,
            focusNode: focusNode,
            autofocus: autofocus,
            clipBehavior: Clip.antiAlias,
            child: content,
          ),
        };
      },
    );
  }
}
