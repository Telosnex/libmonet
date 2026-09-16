# Lazy Monet colors and paint subscriptions

**Motion choice: shared-progress interpolation.** Every palette/recipe uses one
critically damped 0→1 progress spring, shared by all its colors. Retargets snapshot
only observed/prewarmed visible RGB values and restart from rest. Visual review
found no benefit to the more complex alternative, per-color velocity-preserving
springs; restarting progress sometimes felt more responsive. The per-color
engine and its comparison demo have been removed.

This deliberately gives up momentum continuity and the per-color engine's
low-lag behavior during very frequent target streams. Shared progress can leave
more catching-up after scrolling stops.
Position continuity, smooth contrast-polarity fades, lazy work, and exact settled
endpoints remain requirements. Tests cover interrupted transitions, models,
paths, response speeds, and the normalized progress formula.

**Read palette getters normally; no color dependency list is required.**
`MonetTheme.of(context).primary.text` still participates in inherited animation.
Paint-only widgets own a palette subscription instead of rebuilding each tick;
their getter reads automatically discover which outputs to animate. Subscription
ownership belongs in the reusable widget/hook, not every application call site.

`AnimatedMonetTheme` has two channels:

- **Inherited:** `MonetTheme.of(context)` rebuilds dependents at
  `maxUpdatesPerSecond` (default 30; `null` means every tick; `0` final-only).
- **Paint:** `MonetPaintColorsScope.of(context)` provides the coordinator.
  Listen to a **binding**, which owns the outputs its consumer has read. Ticks
  notify only bindings interested in potentially changing roles. All consumers
  of a shared frame reuse each lazy RGB calculation. Endpoints are not re-solved
  on ticks. There is no scope-wide paint compatibility channel. Coordinator
  listeners receive logical theme changes and completion only, not paint ticks
  or custom recipe updates. Existing paint listeners must move to bindings.

All outputs defer intermediate RGB conversion until a frame is read. Notification
is conservative: near completion a color may round to its previous RGB value.
Avoiding unused calculations and unrelated notifications is preferred to exact
per-frame RGB change detection. Completion still stops notifications without reads.
Retargets flatten the retained colors into a bounded RGB snapshot, not nested
lerp trees. Completion checks run on ticks: remaining progress and predicted
one-frame travel must both be at most 0.01%. Completion does not wait for a getter.
No outputs are eagerly retained just because inherited mode is enabled.

Material `ThemeData` stays anchored to the last settled theme by default.
`animateThemeData: true` opts into intermediate Material themes; Material getters
also discover outputs, rather than prewarming all 123 possibilities. Duration is a
spring pacing hint, not a completion deadline; `curve` is compatibility-only.
Ticker elapsed time respects Flutter's `timeDilation`. Inherited publish limits
use undilated frame time, so slowing animation doesn't also slow notification
throttling. Cartesian motion may cross low-chroma colors; polar motion follows
a shortest hue arc. Switching basis preserves pixels and restarts progress.
Intermediate colors need not meet endpoint contrast.

## Migration and lifecycle

In final-only mode, **ordinary inherited consumers receive only the settled
result**. Paint integrations bind once, read `binding.value` on each paint, and
dispose when unmounted or when the scope identity changes. No role enumeration
is necessary. Bind/update in lifecycle, not during paint; getters ARE safe
during paint and never synchronously notify listeners or start a ticker.

The first getter for a previously unseen output may resolve its endpoint and
retain that output. Optional `roles: {...}` prewarms outputs before paint or before
an interactive state is first displayed. It is a hint, not an allowlist: reading
another role always works. Removing a prewarm hint releases an output only if
the consumer never read it. Observed outputs persist until binding disposal,
including across skipped paints and recipe updates. This bounded, sticky demand
avoids dropping dependencies merely because a repaint boundary skipped a frame.

Reusable controls can call `binding.prewarm(PaletteStates.fill)` (or `color` /
`text`) in lifecycle to prepare just their state family. This keeps cold contrast
solves out of their first hover/press paint and makes those states join an existing
fade. It does not interpolate dormant state colors on ticks. Arbitrary first-use
getters remain legal and may solve a new endpoint during paint.

Inherited reads have no per-paint owner. Their demand lives with the scope (at
most 3 × 41 roles), and is released when inherited motion is disabled or the
scope is disposed. Bindings provide precise lifetimes for dynamic custom palettes.

This example paints without rebuilding on animation ticks. `CustomPainter`'s
`repaint` subscription handles listener attachment/removal; the State owns the
binding. A render-object integration instead subscribes on attach, marks paint
dirty on notifications, and unsubscribes on detach.

```dart
import 'package:flutter/material.dart';
import 'package:libmonet/libmonet.dart';

class PaintBoundSwatch extends StatefulWidget {
  const PaintBoundSwatch({super.key, this.palette = MonetPalette.primary});
  final MonetPalette palette;

  @override
  State<PaintBoundSwatch> createState() => _PaintBoundSwatchState();
}

class _PaintBoundSwatchState extends State<PaintBoundSwatch> {
  MonetPaintColors? _bus;
  MonetPaletteBinding? _binding;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = MonetPaintColorsScope.of(context);
    if (identical(next, _bus)) return;
    _binding?.dispose();
    _bus = next;
    _binding = next.bindThemePalette(widget.palette);
  }

  @override
  void didUpdateWidget(covariant PaintBoundSwatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.palette != widget.palette) {
      _binding?.update(widget.palette, widget.palette.resolve);
    }
  }

  @override
  void dispose() {
    _binding?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(48, 48),
    painter: _SwatchPainter(_binding!),
  );
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.binding) : super(repaint: binding);
  final MonetPaletteBinding binding;

  @override
  void paint(Canvas canvas, Size size) {
    final palette = binding.value;
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide / 4,
        Paint()..color = palette.color);
  }

  // Widget updates can change a binding in place. Animation ticks don't call
  // this: they repaint directly through the binding subscription.
  @override
  bool shouldRepaint(covariant _SwatchPainter oldDelegate) => true;
}
```

## Derived recipes and sharing

Prefer `bus.bindRecipe(ColorPaletteRecipe(seed))` for custom palettes: immutable
inputs and identity live together, including optional tone, explicit background,
contrast, algorithm and model overrides. Null overrides inherit the logical
theme endpoint. Update with `binding.updateRecipe(nextRecipe)`.

Use `bus.bind(key, resolve)` as an escape hatch for arbitrary recipes. The resolver gets
**the logical theme endpoint**, not an intermediate paint frame. Include all
recipe parameters in a key with stable equality/hashCode. Equal keys must
resolve equivalent outputs for any endpoint. Do not capture changing external
state without also changing the key; replacing a closure with the same key
is not an invalidation mechanism. `MonetPalette` keys are reserved for built-ins.

For example, capture the current seed rather than reading a mutable widget later:

```dart
final seed = widget.seed;
final key = ('swatch', seed);
Palette resolve(MonetThemeData endpoint) => Palette.from(
  seed,
  backgroundTone: endpoint.backgroundTone,
  contrast: endpoint.contrast,
  algo: endpoint.algo,
  colorModel: endpoint.colorModel,
);
// Initial lifecycle: binding = bus.bind(key, resolve);
// Later recipe change: binding.update(key, resolve);
```

Bindings normally share each key's union of retained roles with independent
reference counts. A keyed registry shares endpoint resolution immediately, even
between distinct moving histories, and drops keys when the last history is released.
Updating to a derived key already in use cannot immediately
join a different moving history without jumping. The departing consumer keeps
its own visible colors and rebased transition until both histories settle, then
their roles and consumers coalesce **without resolving new endpoints during the tick**. New
bindings join the first retained history for that key. A duration-zero update
coalesces immediately. Built-in palette changes join the common built-in palette
immediately instead of starting a new derived transition.

### First reads and saved frames: the deliberate tradeoff

A first getter joins an existing shared role transition if one exists. Otherwise it
starts at the **current endpoint**, not at a reconstructed hypothetical spring
through every past target. Once observed, it preserves its actual motion across
retargets. This is deliberately bounded: there is no unbounded lazy history or
periodic eager flattening of 41 unused roles. It is NOT identical to the old
lerped palette's first-ever mid-flight reads. Prewarm a hover/pressed output
before a transition if its first appearance must join an existing trajectory.

Saved palette frames freeze their begin colors, endpoint and progress.
Even a first read much later returns that frame's color, not the current one.
Reading a frame from a departed recipe/endpoint, or after disposal, does not
resurrect subscriptions. Views memoize per-role colors and share their immutable
RGB starting snapshot across ticks. They do not reference the live owner strongly.
Equality/hashCode never resolve colors
or change with lazy reads. Different bindings have different observing wrappers
over a shared frame; do not depend on wrapper identity to establish sharing.

`bus.value` is a frame view even at rest, so its getters can observe demand.
Use `bus.target` / `bus.value.target` for logical endpoint comparisons, not
`bus.value == endpoint`. Palette endpoint solvers should consume `target`, not
an intermediate inherited view. Semantic scalars share a progress spring that
also preserves Material anchoring/onEnd even when no palette roles have been
observed. A custom-only recipe change can animate without a new theme endpoint.

## Manual driving and notifications

`retarget(time: ...)`, `sample(time)`, and the optional constructor `clock` all
use **finite, nonnegative, nondecreasing animation seconds in one epoch**.
Repeated timestamps are allowed and do not repeat color decoding. The widget
supplies its ticker clock; standalone tests/controllers must supply consistent
times themselves. The optional `requestFrame` callback asks the owner to sample
later; a standalone bus does not create its own ticker.

`bind`, getters, and `binding.update` never notify listeners synchronously: these calls
can run while Flutter holds the widget-tree lock. An update that changes paint
requests a later sample, including a duration-zero snap. Consumers should also
read current binding state when building/updating their painter.
`retarget`, `sample`, and the `value` setter can notify synchronously; do not
call them from paint or treat them as binding-lifecycle operations.

`bus.value` is the latest immutable theme frame; `bus.target` is the logical endpoint.
`bus.isAnimating` includes custom-only motion and keeps the ticker alive.
`bus.value.isAnimating` describes only the theme transition: local recipe changes
must not delay Material anchoring, semantic metadata, or the theme's `onEnd`.
Palette bindings are the paint
source of truth for derived recipes, not `bus.value.primary` or a re-solved
palette built from an intermediate frame. Work-count tests establish role
sharing, lazy conversions and solver-free ticks after discovery; they do not
establish app frame-time savings. First-use endpoint resolution still has a cost.

## Palette adapters and cache compatibility

`Palette` is an output interface with unchanged `from` / `fromColorAndBackground`
factories. Computed endpoints alone contain solver state. Custom adapters should
extend `RolePalette` and implement `readRole`, or implement all Palette getters;
`super.base` is no longer an adapter constructor. Direct `Palette.base` factory
calls remain supported. `PaletteSnapshot` captures every role and compares actual
outputs; `ResolvedPalette` accepts only complete, immutable lists. Motion no longer
uses partial public palettes for change detection. `PaletteLerped` constructs
without reading colors and reads only the selected endpoint at t=0/1.

Material ThemeData caching is capped at 32 semantic/environment keys, including
direction, text scaler, pixel density and platform. Weak values alone do not bound
strong keys. Cache hits register MediaQuery dependencies just like misses.

Intentional color corrections: Material surface/error respect the chosen contrast
algorithm; WCAG verifies quantized RGB before accepting a tone; overlay borders
validate actual surfaces (either side, best effort). OKLCH page backgrounds use
a native 0.04 chroma cap rather than CAM16's 16. Explicit backgrounds are unchanged.
`MonetColorScheme.fromPalettes` now maps fill/text fields to their actual families,
not the color-surface family. These corrections also update JS parity fixtures.

Branded `text` now solves its own hue/chroma against the actual background, using
the neutral text's chosen polarity. Reusing the neutral tone changed the RGB after
contrast verification (one recorded WCAG case was 4.468:1 instead of 4.5:1).
This adds one memoized endpoint solve when branded text is first requested—not
work on animation ticks—and applies consistently in Dart and TypeScript.

See [palette-performance.md](palette-performance.md) for profile measurements,
the reproducible harness, and limits of the performance claims.
