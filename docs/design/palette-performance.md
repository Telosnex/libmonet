# Palette performance: contracts and measurements

## What is guaranteed structurally

- Ordinary motion ticks do no RGB interpolation and no endpoint contrast solving.
  First-use getters can solve endpoints; interruption snapshots calculate retained
  colors as necessary. Those are separate operations, not hidden tick work.
- Each used role is memoized per shared immutable frame, not per widget.
- Shared polarity is an O(1) lookup in a cached, quarter-tone APCA envelope
  table. The research optimizer never runs per endpoint, role, or frame; choosing
  direction also avoids the former throwaway neutral text solve.
- Binding-local notifications reach only consumers of potentially changing roles.
  Same-RGB rounding plateaus can still notify. Completion works without getters.
- Consumer disposal releases recipe entries; equal recipes share endpoint work
  even when visual histories differ. Histories contain sparse RGB starts, not
  nested lerp chains. Inherited demand is at most 3 × 41 roles per scope.
- The Material cache retains at most 32 semantic/environment keys. Weak values
  permit earlier collection; the bound also covers strongly retained keys.
- Color-only binding updates can repaint without build/layout. A render test
  verifies this and that an unrelated repaint boundary stays clean.

These are regression-tested in `binding_invalidation_test.dart`,
`automatic_paint_roles_test.dart`, `palette_infrastructure_test.dart`, and the
shared-progress/lifecycle tests. `PaletteWorkStats` additionally measures actual
computed-palette boundary work (factory background synthesis, contrast requests,
and color materializations), replacing toy language-laziness tests.

No structural contract guarantees a complete application's frame budget on every
machine. Dependency work, first-use cost, notification delivery, paint and raster
must be measured separately.

## Reproducible native harness

The standalone entry point `example/lib/palette_benchmark.dart` runs 8 scopes and
320 independently repaintable swatches: 80 moving and 240 static. It emits JSON
with controller timings, Flutter UI/raster p50/p95/p99, paint/listener counts,
color work and process RSS. No downloads, Studio navigation, or application
integration is required.

```sh
cd example
flutter run --profile -d macos -t lib/palette_benchmark.dart \
  --dart-define=PALETTE_BENCH_MODE=local \
  --dart-define=PALETTE_BENCH_PREWARM_ALL=true \
  --dart-define=PALETTE_BENCH_EXIT=true
```

Modes:

- `local`: production binding-local invalidation and lazy getters.
- `scope`: benchmark-only broad forwarding of representative binding signals,
  with lazy getters. Production no longer has scope-wide paint notifications.
- `eagerScope`: **benchmark-only approximation**, reading retained outputs and
  comparing exact RGB before a scope-wide notification. It uses the current
  controller, not an archived engine. It is useful to isolate the cost of eager
  comparison, but must not be presented as an exact old/new release comparison.

The default retains only the two drawn roles. `PREWARM_ALL=true` retains all 41,
modeling previously encountered but currently dormant interaction states. All
modes draw the same two outputs. There are 120 warmup frames, then 600 measured
samples; the last 120 are idle to include completion and rounding-plateau costs.
Targets follow deterministic 120-Hz animation timestamps, replayed one per actual
display frame. This does **not** claim the display itself runs at 120 Hz.
Frame timings arrive batched, so their count includes a few boundary frames.
RSS includes the entire Flutter process, not just palettes or retained heap.

Run modes sequentially, repeat with reversed order, and use `--release` as well
as `--profile` on the slowest supported hardware. Record OS, device, refresh rate,
thermal state, Flutter version, and workload. In DevTools also inspect allocations,
GC and long-lived heap after repeated mount/unmount cycles; RSS alone cannot prove
leak freedom. Keep frame-time thresholds out of timing-noisy unit-test CI.

## Measurements from this implementation

ARM64 macOS, Flutter 3.47.1 / Dart 3.13.1, native **profile** mode, Impeller/Metal.
One run per mode, sequential, on the available development machine, before the
scope-wide compatibility path was removed and branded text got its own verified
endpoint tone. These measurements have not been rerun for those follow-up fixes.
Numbers are
microseconds unless indicated. Not a weakest-device certification.

| Retained roles | Notification mode | Sample p50 / p95 | UI p50 / p95 / p99 | Paint calls |
|---|---|---:|---:|---:|
| All 41 | Eager scope approximation | 392 / 537 | 4,533 / 6,174 / 6,492 | 162,320 |
| All 41 | Lazy scope | 14 / 56 | 4,332 / 5,811 / 6,158 | 165,120 |
| All 41 | Lazy local | 13 / 56 | 3,902 / 5,350 / 5,713 | 41,280 |
| Used 2 | Lazy local | 29 / 68 | 879 / 1,304 / 2,368 | 41,280 |

All-41 local versus eager scope: ~75% fewer paints, ~49% fewer interpolations
(165,352 vs 326,032, **including interruption work**), and ~13% lower UI p95 in
this run. Lazy local and lazy scope perform the same color work; locality reduces
notifications and paints, not shared calculations. The scope case illustrates the
tradeoff: avoiding exact RGB suppression causes some extra plateau paints, while
local delivery removes the much larger unrelated-consumer workload.

Prewarming all roles still costs at **retarget**: local p50/p95 was 3,578/5,030 µs,
versus 224/325 µs for two roles. Lazy tick work does not make full endpoint solving
free. Prefer automatic demand or a control's small state family, not all outputs.

Raster p95 ranged 1,751–2,711 µs across runs and did not consistently improve.
Maximum RSS ranged roughly 109–123 MB. Those noisy process/GPU measurements are
not evidence of a universal GPU or memory improvement. CPU/render work and exact
operation-count reductions are the stronger findings here.

The older debug/JIT scroll-chase test also improved its all-prewarmed sample+read
median from approximately 2,636 µs to 122 µs. That is a different workload and
runtime, **not** a native frame-time comparison. Raw local diagnostic logs are
under ignored `build/palette-review/`; the reproducible harness and contracts are
checked in instead of machine-specific VM-service URLs or generated logs.

## Remaining validation and design choices

- Repeat on the slowest production device with representative application UI,
  not just simple swatches, and collect GC/allocation and long-run heap traces.
- Application paint integrations must listen to bindings. Coordinator listeners
  now receive theme lifecycle events only; paint compatibility fan-out was removed.
  Telosnex's Mod controls were subsequently migrated, including background-mode
  TextInput and the dropdown's text/chevron. Other hardware/application validation
  remains outstanding; the table above is not a Telosnex benchmark.
- OKLCH's native background cap is now 0.04; CAM16 models retain 16. This is a
  documented design parameter, not a mathematical cross-model equivalence.
  Automated tests verify tone/cap and explicit-background preservation; visual
  approval across real wallpapers remains a product/design task.
- Unprepared first-ever roles start at the current endpoint. Controls needing
  synchronized first-hover motion should prewarm their state family in lifecycle.
- Unreachable contrast targets remain best effort, and smooth polarity reversals
  can temporarily have low contrast. WCAG endpoint tones now verify actual
  quantized RGB instead of treating continuous L* math as sufficient. This does
  not make every intermediate animation frame accessibility-compliant.
