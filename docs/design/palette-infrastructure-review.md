# Palette infrastructure review: lazy values, motion history, and repaint delivery

> **Historical investigation, followed by implementation.** The observations below
> describe the pre-fix system. The fixes now include output-only palette adapters,
> complete snapshots, lazy binding-local invalidation, a keyed shared endpoint
> registry, typed recipes/state prewarming, a bounded environment-aware Material
> cache, contrast-policy propagation, quantized WCAG verification, actual-surface
> border checks, and native-model background chroma caps. See
> [paint-bindings.md](paint-bindings.md) for the current contract and
> [palette-performance.md](palette-performance.md) for measurements and remaining
> device/visual validation. Follow-up work migrated Telosnex Mod paint consumers,
> removed scope-wide paint compatibility notifications, and fixed branded text
> tone verification. The historical findings below predate those follow-ups.

## Executive recommendation

Keep the lazy color solver and shared-progress interpolation. Keep a small amount
of role history and explicit ownership of paint consumers. **Do not assume that
those require eagerly calculating every retained color on every frame.**

The preferred next prototype is:

> Immutable, shared, lazy palette frames; binding-local conservative repaint
> notifications; sparse retained colors for interruption continuity.

“Conservative” means a binding is told when its colors *might* change, without
first calculating all their exact RGB values. Calculate and memoize those values
when read. This relaxes exact suppression of redundant repaints near rounding
plateaus, not color correctness, continuity, or completion.

Before that experiment, address concrete cache/adapter problems. Do not combine
this research with a wholesale rewrite of color science or the application.

## Scope and evidence

This reviews libmonet's palette pipeline: construction, lazy dependencies,
contrast solving, interpolation, role discovery, binding lifetime/sharing,
Material adaptation, caches, alternate palette representations, and tests.
Telosnex integration was deliberately not investigated or changed.

Evidence consists of source inspection, ten temporary characterization probes,
and the existing three `paint_motion_cost_test.dart` workloads. The probes
characterize current behavior, including bugs; their passing does **not** certify
that behavior as desirable. No production code was changed for this review.

Timing environment: ARM64 macOS, Flutter 3.47.1 / Dart 3.13.1, `flutter test`
(debug/JIT). No release-device UI/raster benchmark or heap-retention measurement
was performed. Timings below are diagnostic, not frame-time guarantees.

## 1. The PM's getter model is mostly right

A static palette is already largely “ask once, compute once, remember.” Its
`late final` colors and intermediate tones are memoized on each palette instance.
A second read does not repeat that work.

Two qualifications matter:

1. **One requested color can require several prerequisites.** For example, an
   icon on a hovered fill depends on the fill, hover surface, text polarity and
   contrast solves. That is real necessary work, not evidence that laziness failed.
2. **A new palette is a new memoization lifetime.** Continuously constructing
   recipes during scrolling can cost much more than repeatedly reading a stable
   palette. The bounded global tone/color caches help, but do not erase this cost.

`Palette.from` is also not zero-cost, despite its documentation. It converts the
seed to HCT and synthesizes the background immediately. The explicit-background
factory defers more work. The tests called “late final laziness” in
`test/theming/palette_test.dart` test a toy `_LazyProbe`, not this actual factory.

### What the animation adds

A single progress value blends each color's start and endpoint. On interruption,
previously used colors need a finite starting snapshot; otherwise repeatedly
wrapping lazy lerps can retain an ever-growing history.

There are three different questions:

- **Value:** what color is this now? A memoized getter can answer it.
- **History:** which colors need their starting position preserved at retargets?
- **Delivery:** which painters need to be told to repaint?

The last two questions are why “just a getter” does not replace the entire
animation integration. But they do not require per-color springs, nor necessarily
per-frame RGB calculations before paint.

## 2. What role tracking and bindings actually do today

`PaletteRole` enumerates 41 public outputs. It is not the solver's dependency
system: the solver already manages its intermediate dependencies with lazy fields.

A binding owns the set of outputs its consumer has ever read, plus optional
prewarm hints. Multiple consumers share the union of roles for a recipe. When a
binding is disposed, its reference counts are released. Inherited reads have no
individual owner and persist for the scope lifetime (at most 123 built-in roles).

This is **sticky historical demand**, not knowledge of what is currently visible.
A hover color read once stays retained after the pointer leaves. A temporarily
unpainted/offscreen-but-mounted consumer does not automatically release it.
That is deliberate: skipped paints are not reliable evidence of disinterest.

Bindings are not inherently expensive, nor a sign of a flawed design. Some owner
must attach/detach notifications and stop retaining dynamic recipes. This should
be owned by reusable widgets/render objects, not managed at every product callsite.

### The current compromise

Inherited-only frames interpolate lazily. Paint-bound roles instead get sampled
before notification, so the coordinator can suppress ticks whose RGB colors did
not change. `PaletteMotion._snapshot` maintains a second, resolved color list for
that comparison alongside the lazy frame cache.

However, `MonetPaintColors` is one `ChangeNotifier` for the whole scope.
`MonetPaletteBinding` is not itself a listenable. **One changing binding still
notifies listeners for unrelated, unchanged palettes.** Sharing calculations does
not mean selectively delivering repaint notifications.

Confirmed probes:

| Workload | Observed result |
|---|---|
| One changing color + 1,000 static paint listeners in the same scope | 1 interpolation, 1,001 listener calls for one sample |
| Read one bound role once, then sample ten times without any further getters or listeners | 10 interpolations |
| 41 retained outputs, but only background/text read over 20 moving frames | Eager sampling: 820 interpolations; lazy sampling: 40; the two read outputs matched exactly |

The last probe exercises the existing `PaletteMotion.sample(paintRoles: {})`
lazy path against eager sampling. It is a mechanism demonstration, **not a complete
alternative controller benchmark**. It excludes retarget cost and widget/raster
work; the lazy path cannot provide exact changed-RGB notification suppression.
Listener counts are not measurements of actual repaints: downstream widgets may
coalesce or filter callbacks.

## 3. Performance findings

### Keep demand-driven endpoint solving

The existing scroll-chase workload has eight scopes, three built-in palettes and
two custom recipe keys per scope. It reads the same two roles in every mode:

| Mode | Retained roles/scope | Retarget p50 / p95 | Sample + reads p50 / p95 |
|---|---:|---:|---:|
| Prewarm all outputs | 205 | 14,703 / 16,284 µs | 2,636 / 3,160 µs |
| Prewarm the two used outputs | 10 | 159 / 253 µs | 94 / 165 µs |
| Discover those outputs automatically | 10 | 127 / 180 µs | 93 / 144 µs |

These modes run sequentially and share global caches. The workload constructs
built-in target themes before the timed retarget section. Do **not** read these
ratios as a cold-cache speedup guarantee or an app frame budget. The strong
conclusion is structural: resolving all 41 outputs is not an acceptable default
substitute for demand tracking in this workload.

A second diagnostic varied endpoint seeds/tones and timed construction plus
requested outputs. For the default CAM16 v1.1 model, representative p50s were
approximately 3 µs for factory + hash, 13 µs for first text, 77 µs for first hovered
fill icon, and 664 µs for all outputs. The same all-output workload in OKLCH was
about 1,637 µs. Cases were sequential with no cache flush; these are indicative
workload costs, not isolated solver timings or model-ranking guarantees.

### First-use latency is a distinct product concern

Laziness reduces total work but moves cold work to the first consumer. A getter
first used on pointer hover can resolve its endpoint in paint. Current “solver-free
ticks” tests mean **already-discovered endpoints are not contrast-solved again**,
not that no solver can ever run during paint. HCT interpolation itself still uses
gamut mapping; that is different from re-solving contrast against a new surface.

For interactive controls, prewarm the small state family they actually support at
a suitable lifecycle point. Do not prewarm every role in every palette. Ordinary
reads should remain legal; a strict “no cold solving in paint” mode would require
an explicit preparation contract, not just an assertion that getters are lazy.

### Caches are not all equivalent

- Palette lazy fields cache solved endpoints/intermediates for that instance.
- `contrastingTone` caches 1,024 whole answers, avoiding repeated APCA searches.
- HCT/CAM16 caches are bounded and keyed by discrete ARGB values.
- `_Endpoint` caches role outputs shared with saved frames, including arbitrary
  user-supplied Palette implementations.
- `_LazyPaletteFrame` caches interpolated outputs for its immutable frame.
- `ResolvedPalette` inside `PaletteMotion` additionally stores colors for change
  detection; this is a prime simplification target if invalidation becomes lazy.

Do not indiscriminately remove the lower-level caches or add a cache of every
intermediate hue/chroma/tone. `hct_solver.dart` documents a previous continuous-key
cache regression. Those historical measurements were not revalidated here.

## 4. Concrete defects and contract gaps

These are not all introduced by the current motion diff. This is a wholesale
review, including older exported/direct-import APIs.

### High priority: the Material theme cache retains keys without a bound

`monet_theme_data.dart:54,255–422` has a static map with strong `MonetThemeData`
keys and weak `ThemeData` values. There is no capacity or dead-entry pruning.
Weak values do **not** release the keys and their palettes. With intermediate
Material themes enabled, frame identities can also become permanent keys.

Use a deliberately bounded cache, or scope-owned memoization with an explicit
sharing policy. Include a lifecycle/memory test. This conclusion follows directly
from the reference graph; the retained heap size was not measured.

### High priority: Material adaptation ignores the chosen contrast algorithm

`_createColorScheme` in `monet_theme_data.dart:1766` accepts `algo`, but omits it
from both the error-palette factory and the surface-text `contrastingTone` call.
Those default to APCA even for a WCAG theme.

A WCAG theme with background tone 94 and contrast .5 produced surface text with a
WCAG ratio of **3.76:1**, versus its configured **4.5:1** target. This was measured
on the actual generated surface/text colors. Error text also differed from the
requested algorithm's output. Propagate the algorithm and test the generated
Material colors, not just the theme's metadata.

### Older snapshot and extension representations have drifted

`palette_snapshot.dart` does not override/capture four current outputs:
`fillHoveredIcon`, `fillSplashedIcon`, `colorHoveredIcon`, `colorSplashedIcon`.
They fall back to the inherited solver configured with placeholder contrast/algorithm.
The probe found all four different from the source. Snapshot equality also inherits
seed-based comparison: two snapshots with different text colors compared equal.

`full_color_scheme.dart:239` maps fill and text properties to the color family
instead of their corresponding palette roles. This is not a faithful adapter.
Neither has an in-library consumer found by the scoped search, but the extension
is exported and direct-import users may exist. Remove/deprecate if unused after
an API-consumer audit; otherwise repair with exhaustive adapter tests. Do not
silently change a public mapping without checking whether anyone relies on it.

### Explicit lerps are less lazy than their API suggests

`PaletteLerped` construction reads `a.color` and `a.background` just to initialize
its concrete Palette superclass. Reading `text` at `t=0` still evaluates both
endpoint text getters before `_lerp` can short-circuit. Both were confirmed by
observing wrappers. Shared progress no longer requires the explicit tween API to
be a second, independently maintained palette-adapter implementation.

### “Near-neutral background” is not model-independent

`Palette.from` caps chroma at the numeric value 16 for every model. OKLCH chroma
uses much smaller units, so that cap does not neutralize ordinary OKLCH colors.
For red at background tone 60, the probe observed seed/background chroma of
0.215/0.209 in OKLCH, versus 51.71/16.10 in CAM16 v1.1. These are within-model
observations, not comparable cross-model chroma magnitudes.

Define the *design intent* of near-neutral backgrounds and calibrate it per model.
Do not blindly copy a conversion factor or mix this aesthetic change into the
shared-progress commit without visual review.

### Contrast promises need precision

“Contrast-safe colors” is too broad: some requested contrasts are unreachable,
several border policies are best-effort/either-side, and smooth polarity reversals
can pass through low-contrast intermediate colors. The animation docs already
acknowledge the latter. There is also a documentation/predicate inconsistency to
investigate: overlay-border comments say “both” references, whereas
`_hasValidContrastHelper` accepts contrast against either reference.

This is a design/accessibility contract to clarify and test, not justification
for putting the expensive contrast solver back on every frame.

## 5. Preferred architecture to prototype

### A. Separate a palette interface from its solver implementation

Currently snapshot, observed and lerped palettes subclass a concrete solver and
supply fake seed/contrast values, relying on every getter being overridden.
The incomplete snapshot shows why that is unsafe. It also couples wrapper object
layout to solver fields; measure allocation costs rather than assuming the compiler
removes them all.

Keep friendly `palette.text` syntax and factory entry points. Establish one
exhaustive output interface/schema, with implementations for:

- A computed, lazy endpoint palette.
- An immutable, lazy interpolation frame.
- A complete explicit snapshot when requested.
- A lightweight observing decorator.

Do not make a partial internal notification snapshot pretend to be a complete
public palette. Centralize repetitive adapters and test all roles. Keep ordinary
lazy intermediate fields in the solver; a generic reactive dependency framework
would likely add complexity without helping this fixed, small domain.

### B. Keep bindings, give them a more focused job

Bindings should own consumer lifetime, known role demand, and repaint delivery.
A painter should be able to listen to **its binding**, not require scope-wide
notification. The scope can retain a compatibility/global notification channel.

For common recipes, use an immutable typed descriptor as both cache key and
recipe inputs. Today an arbitrary `Object key` and a separate closure must agree
forever; stale captured inputs silently defeat that contract. Keep arbitrary
resolvers as an explicit escape hatch rather than making every caller recreate
this discipline.

### C. Make paint invalidation conservative and local

At retarget:

1. Snapshot only previously retained roles to preserve continuity.
2. Resolve their new endpoint colors once.
3. Determine which retained roles have different start/end colors.
4. Restart shared progress.

On ticks:

1. Advance progress/completion, without evaluating role colors.
2. Notify bindings whose demand intersects potentially changing roles.
3. Let getters calculate and memoize the colors that are actually painted.
4. Preserve completion and semantic-theme notifications independently of reads.

This still needs role ownership, but potentially removes full per-frame resolved
lists and exact RGB comparisons. Dormant state colors remain available for future
retargets without being interpolated every tick. Static palettes should not get
notifications just because another local recipe is moving.

**The cost:** some notifications/repaints happen when an interpolated color rounds
to the same RGB as before. Compare total build/paint/raster/GC cost against today's
exact suppression before choosing this. A simple scope-wide lazy broadcaster is
useful as a benchmark baseline, not my preferred production architecture.

### D. Share endpoint work without conflating visual histories

Equal recipes can share immutable endpoint computation immediately. They cannot
always share in-flight frames: two widgets approaching the same endpoint from
red and green still have different displayed colors. Preserve separate transition
histories where required. The current fork/coalesce machinery serves a real
continuity requirement, not leftover velocity physics.

A keyed endpoint registry plus separate transition instances is worth testing.
Today `_derived` lookup is linear, and forks duplicate endpoint wrappers/resolvers
until settlement. Do not delete continuity to obtain a prettier data structure.

### E. State the unseen-role policy explicitly

The current rule is: join an already-retained role's transition, otherwise start
at the current endpoint. That can make a first-ever hover/pressed state look
out-of-phase with an existing fade. Prewarming a control's state family avoids it.

An exact reconstruction through arbitrarily many past interruptions cannot also
have zero unused historical computation, no retained history, and constant first-read
cost. Choose a documented policy: prewarm, endpoint start, or a bounded short-history
approximation. This is a product choice, not an accidental consequence of getters.

## 6. Performance contracts worth keeping or adding

| Contract | Verification |
|---|---|
| Repeated reads share color work | One calculation per role per shared immutable frame, not per widget |
| Unused outputs are not solved merely for equality/hash | Structural counters and actual Palette-construction tests |
| Already-known endpoints are not contrast-solved during motion ticks | Separate endpoint/contrast/gamut-map instrumentation |
| History cost is bounded | Long interrupted traces, saved frames, binding churn and disposal |
| Static unrelated consumers need not repaint | Mixed static/animated binding listener tests and real painter counts |
| Color-only changes do not require layout | Render-object/widget tests and release traces |
| Unread animations still finish | Completion tests independent of getter cadence |
| Caches have explicit bounds | Cache-size/lifecycle tests plus heap profiling |
| Cold interactions remain responsive | First-hover/press measurements on target hardware |
| Output remains correct across adapters/models | Exhaustive role tests, actual contrast pairs, model-specific visual fixtures |

Report cost by **distinct endpoints, retained roles, actually read roles, active
histories, consumers notified, and consumers painted**. A single “palette time” or
“role read count” hides the real bottleneck. Existing `roleReads` counts public
endpoint accesses, not all prerequisite contrast solves or factory work.

Use deterministic operation-count tests in CI, plus representative profile/release
benchmarks on the slowest supported device. Include p95/p99 UI and raster frame
times, allocations/GC, cold versus warm caches, 60/120 Hz retargets, and a long
scroll/mount/unmount trace. Agree on a palette budget as a fraction of the complete
frame budget; do not invent a universal millisecond guarantee from these JIT tests.

## 7. Sequencing

1. **Small correctness/hygiene commits:** bound the Material cache; propagate
   contrast policy; repair/deprecate drifted adapters; correct laziness claims.
2. **Establish structural and release-device baselines.** Preserve the current
   shared-progress engine as the reference for pixels, retargets and completion.
3. **Prototype binding-local conservative invalidation with lazy frame reads.**
   Benchmark against current exact suppression and a simple lazy broadcaster.
4. **Consolidate the palette interface and recipe identity**, with an explicit
   compatibility/migration plan. Prefer one adapter path over duplicate mechanisms.
5. **Separate visual-design work:** model-specific neutral backgrounds,
   first-interaction transition policy, and contrast during polarity reversal.

Do not prewarm all outputs, replace every getter with a reactive framework, revive
per-color velocity, or add continuous-coordinate caches as a shortcut. The aim is
less total user-visible work with clearer guarantees—not the smallest line count
and not the fewest color calculations at any cost.
