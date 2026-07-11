# ADR-001: Contrast Protection — Replace Luma-Extrema Opacity Solver and Stacked-Shadow Delivery with Exact Per-Color Solver and Dilated Halo

**Status:** Accepted, implemented (see §7 “As built” for deltas from the proposal)
**Date:** 2026-07-10 (proposed) / 2026-07-11 (implemented)
**Scope:** `lib/effects/protection.dart` (new), `lib/effects/shadows.dart`, `lib/effects/opacity.dart` (deleted), JS parity port
**Deciders:** libmonet maintainers

---

## 0. Plain-language summary

**Job:** text over an image — find the minimum scrim/halo opacity so the text meets contrast against every pixel under it.

**Bug being fixed:** there is no single "worst pixel." There is a worst pixel *per opacity*, and it changes. Black text, white scrim, background pixels gray `(70,70,70)` and blue `(0,0,255)`:

| scrim opacity | gray becomes | blue becomes | darkest (worst) pixel |
|---|---|---|---|
| 0% | T30 | T32 | gray |
| 25% | T52 | T41 | blue |
| 50% | T67 | T59 | blue |

A scrim moves pixels along straight lines in RGB, but tone is a curved function of RGB, so equal moves give unequal tone gains (gray's mid channels climb the steep part of the gamma curve; blue's maxed 255 channel gains nothing) — tone *order is not preserved*. The current solver keeps only the darkest/lightest tones at opacity 0 and can therefore certify contrast against a pixel that is no longer the worst one — reporting contrast the screen doesn't have. No 1D summary (tone, Y, luma) can avoid this.

**Fix:** check every background color the caller provides, at every candidate opacity. Every existing call site (`getOpacityForBackgrounds`, `getShadowOpacitiesForBackgrounds`, example app, shadows) already passes the foreground *and* the full background color list in the same call — the current code receives the full list and then discards everything but min/max luma before solving. The input set is small (sampled points or a palette: dozens of colors), so the exact solve is trivially cheap: 256 opacity steps × N colors of simple arithmetic. **Error relative to the provided colors: zero, by construction.**

**The input contract (this is where correctness now lives):** the solver is exact against the colors it is given, so the only way to under-protect is to give it colors that aren't really there. Two rules: (1) sample real pixels; if downscaling first, use min/max pooling, never averaging — averaged black+white pixels hallucinate a mid-gray that hides both extremes (the same failure D2 had inside the solver). (2) Quantizer palette entries (`argbToCount` keys) are WSMeans cluster centers — i.e. averages — acceptable for theming, not for protection. Prefer raw sampled pixels from the region under the text.

**Known deliberate behavior (not a bug):** if the background contains both much-darker and much-lighter pixels than the text (checkerboard under mid-tone text), per-pixel contrast can pass at opacity 0. This solver refuses that and pushes the whole background to one side of the text's tone — gray-on-checkerboard is illegible regardless of what per-pixel WCAG says, and APCA's polarity isn't even well-defined across a straddle. Flagged on results as `straddleCollapsed`.

**Delivery:** one dilated-then-blurred halo replaces the stacked-shadow loop. The region under the glyph stays solid before blurring, so the paint alpha equals the solved alpha exactly — no layer-accumulation model. Stacked shadows remain as a documented fallback for renderers without dilation (CSS `text-shadow`).

## 1. Context

libmonet guarantees text legibility over unknown backgrounds by computing a "protection" layer (scrim or shadow stack) whose blended result meets a WCAG 2.1 or APCA contrast target. The current implementation has two layers:

1. **Opacity solver** (`getOpacityForArgbs`): reduces backgrounds to min/max, derives candidate opacities analytically via L*→luma, verifies via ARGB compositing, with crossed-pairing fallbacks and a best-effort-at-1.0 terminal case.
2. **Shadow delivery** (`getShadowOpacitiesForArgbs`): converts required scrim opacity into N stacked Gaussian `Shadow`s using a discrete kernel model of edge coverage.

Review and randomized/rendered probes established the following defects:

| # | Defect | Location | Severity |
|---|---|---|---|
| D1 | APCA signed contrast compared without `.abs()` in no-protection gate; white-on-black demands opacity 1.0 instead of 0 | `opacity.dart:79` | Critical (correctness) |
| D2 | Min/max-**luma** background reduction is unsound: a mid-luma chromatic pixel can be the binding constraint (measured: 3.87 achieved vs 4.5 target). Luma blends linearly, but γ is applied per-channel *after* blending, so equal-luma colors diverge in blended luminance (up to ~12×, e.g. pure blue vs gray-18) | `getOpacityForBackgrounds`, `getShadowOpacitiesForBackgrounds` | Critical (silent under-protection) |
| D3 | Analytical candidates (L*→grayscale luma) are approximate for chromatic colors; failed candidates are discarded, not refined → returns e.g. white@1.0 where black@0.28 suffices | `_calculateProtection`, `_chooseBestProtection` | High (quality) |
| D4 | `contentRadius < blurRadius` sums the far Gaussian tail (`take(n)` from `-blurRadius`) instead of samples adjacent to the edge; underestimates coverage ~0.20 vs ~0.30 rendered | `shadows.dart:112` | High |
| D5 | 11-layer cap and `gap < 0.004` break exit silently; `ShadowResult` cannot express "target not met." Best-effort opacity 1.0 is asymptotically unreachable by stacking (`Aₙ = 1−(1−e)ⁿ`), so infeasible targets are laundered into plausible-looking output | `shadows.dart` loop | High |
| D6 | Stacked full-alpha blurred copies are capped at edge coverage ≈0.30–0.47 per layer, so high targets require 8–16 blur passes — expensive and aesthetically heavy | architecture | High (perf/design) |
| D7 | No input validation (negative/fractional radii, NaN, translucent inputs, empty `reduce`) | both files | Medium |

Verified counter-facts (probes, 2026-07):

- **Channel-bounds sufficiency:** blended WCAG-Y/APCA-Y of every pixel is sandwiched by the blends of the per-channel min/max "corner colors" for all α and halo colors (monotonicity of `Σw·γ(c)` per channel): 0 violations / 420k evaluations; end-to-end α-solve + full-pixel audit: **0 violations / 174,940 audits**, 0 false-impossibles.
- **Interval-vs-band is required:** naive "both corners pass" failed 134/6,000 trials (mid-tone text: forbidden luminance band interior to corner interval).
- **Conservatism cost:** median +8/255 α vs exact-all-pixels, p90 +23/255, always over-protecting.
- **Dilated halo:** Skia render of a 3px stem — plain shadow edge alpha 0.302/layer; `BlurStyle.solid` with 2px spread: **1.000 in one layer**.

## 2. Decision

### API surface (after)

```dart
// lib/effects/opacity.dart
class ProtectionResult {
  final int protectionArgb;       // black or white (this ADR)
  final double opacity;           // solved alpha, 1/255 granularity
  final bool meetsTarget;
  final double achievedContrast;  // worst case over the frontier bounds
  final ClearedSide clearedSide;  // low | high: which side of the band was cleared
  final bool straddleCollapsed;   // true if a lower alpha existed where all pixels
                                  // passed on OPPOSITE sides of the band (see §3)
}

ProtectionResult getProtectionOpacity({
  required int foregroundArgb,
  required List<int> backgroundArgbs, // real sampled pixels; see input contract
  required double contrast,           // as today
  required Algo algo,
});

// lib/effects/shadows.dart
class HaloResult {
  final int argb;
  final double opacity;    // == solver alpha exactly (edge coverage is 1.0)
  final double spread;     // mask dilation in px
  final double blurRadius;
  final bool meetsTarget;
}

HaloResult getHalo({
  required int foregroundArgb,
  required List<int> backgroundArgbs,
  required double contrast,
  required Algo algo,
  double spread = 1.0,
  double blurRadius = 4.0,
});

// Fallback for renderers without mask dilation (e.g. CSS text-shadow):
StackedShadowResult getStackedShadows({...}); // closed-form n + meetsTarget
```

Deprecation map (superseded — see §7): the legacy opacity API was removed outright rather than wrapped. `getShadowOpacitiesForBackgrounds` survives as a Flutter-typed view over `getStackedShadowSpec`.

### D-1. Background representation: the caller's actual colors, checked exhaustively

Replace min/max-luma reduction with nothing: the solver evaluates every provided background color at every candidate opacity. Every current call site already holds the full color list and the foreground simultaneously, so no stored summary is needed, and none is added. Exactness against the provided colors is by construction; cost is 2 × 256 × N cheap evaluations worst case (N = tens).

Scalar projections remain forbidden as *internal* reductions: luma/L*/Y pairs are unsound (D2) — the worst pixel at one opacity is not the worst at another (§0 table), so any "reduce then solve" design must not return. `QuantizerResult.lstarToCount` is exactly such a projection and must not feed protection math.

Input contract (documented on the API): real sampled pixels from the region under the text; min/max pooling if downscaling; quantizer cluster centers are averages and under-represent extremes. If N is ever large (whole-image pixel feeds), an internal *uncapped* channel-wise Pareto prefilter may prune dominated colors before the scan — a pure optimization with zero effect on the answer (dominance is opacity-invariant under affine blending; see `tool/probe_winner_list.dart`); it is not API surface.

### D-2. Solver: feasibility gate → forbidden band → interval scan

Replace `_calculateProtection`/`_chooseBestProtection`/crossed pairings with:

1. **Feasibility gate:** for each protection color `P ∈ {black, white}` (later: arbitrary halo colors), require `|contrast(fg, P)| ≥ target` (exact: as α→1 all backgrounds converge to P). Uses `.abs()` throughout (fixes D1).
2. **Forbidden band:** derive `[yLo, yHi]` of background luminance failing the target for `(fg, algo, target)` — analytically (both formulas invert in closed form); band edges must not be clamped to [0,1] (float-safety; see verification note below).
3. **α scan (0..255):** smallest α such that the blended-luminance interval `[min over colors, max over colors]` wholly clears the band. Interval-vs-band, **not** endpoint checks. Return the cheaper of the black/white solutions.

This subsumes D3 (scan is exact at 1/255 granularity relative to 8-bit alpha compositing) and removes ~200 LOC of pairing heuristics.

### D-3. Honest results

`OpacityResult` and `ShadowResult` gain `meetsTarget: bool` and `achievedContrast: double`. `_bestEffortFullOpacity` may remain as a convenience but must set `meetsTarget: false`. Downstream consumers must never receive an unmet target implicitly (fixes D5's laundering path).

### D-4. Delivery: single dilated halo replaces stacked shadows (primary path)

`getHalo` returns a **spec** for one layer: mask dilated by `spread`, kept at full alpha inside the original mask, blurred outside. With dilation, coverage at the glyph edge is 1.0, so **the solved scrim α is the paint α** — no kernel model, no `contentRadius`, no layer loop, no cap.

libmonet is a color-science library; it emits the spec and does not render. Renderer guidance ships as docs, not code: Flutter = text stroke of width `2·spread` + `MaskFilter.blur(BlurStyle.solid, sigma)` (measured edge alpha 1.000); any renderer with only plain Gaussian blur = stroke-dilate + normal blur (measured ≥0.96 at `spread ≈ 2σ`); renderers with neither (CSS `text-shadow`) = D-5 fallback.

### D-5. Stacked shadows demoted to compatibility fallback

Retained only for renderers without spread/solid blur (e.g., CSS `text-shadow` in the JS port). Rewritten as closed form:

```
n = ceil(log(1 − requiredOpacity) / log(1 − e)),  e = edge coverage
```

with: `contentRadius` redefined to sample kernel entries adjacent to the edge (fixes D4); calibration constants from rendered-pixel measurements; explicit `meetsTarget: false` when `n > nMax` or `requiredOpacity ≥ 1 − (1−e)^nMax`. Per-layer alpha is quantized **up** to the next 1/255: the closed form hits the solver's *minimal* α with equality, and letting the renderer round it would ride the exact boundary the solver proved is the last passing step. `meetsTarget` here is conditional on the straight-edge kernel model (unlike the solver's exact guarantee) — the golden calibration below is what backs it. The current iterative loop, `numApplications` luma math, and debug-blend bookkeeping are deleted.

### D-6. Validation

`ArgumentError` on: NaN/infinite inputs, `contrast ∉ (0,1]`, negative radii, translucent fg/bg ARGBs (or documented alpha-stripping), empty background iterables (kept). Fractional radii rounded once, consistently (fixes D7).

## 3. Consequences

**Positive:** eliminates two silent under-protection classes (D1, D2); solver is exact against its inputs — zero approximation error, no tuning knobs; typical render cost drops from N blur layers to 1; ~40% less solver code; no new types or `QuantizerResult` changes; JS parity surface shrinks.

**Negative / accepted:**
- **The guarantee is polarity-coherent protection, deliberately stronger than per-pixel contrast.** The solver requires the *entire* blended-luminance interval to clear the forbidden band on one side. A per-pixel optimum can be lower when backgrounds **straddle** the band — some pixels far darker than the text, some far lighter, none inside it (canonical case: `#777` text over {black, white}, WCAG 3.0: every pixel passes at α=0; this solver returns α=0.82). We reject straddles on purpose, and this is a product decision, not solver slack: (i) both WCAG and APCA model text against a *uniform* surround, and APCA's Lc is signed — a straddle puts one glyph in both polarity regimes simultaneously, which the metrics do not certify; (ii) a color list carries no spatial or area information, so three specular-highlight pixels are indistinguishable from a genuine 50/50 bimodal background; (iii) accepting straddles makes α discontinuous in the background, hostile to animation. This margin is **unbounded** on constructed bimodal inputs; measured occurrence on randomized clouds (uniform/bimodal/gradient): 0 of 2,567 trials. `straddleCollapsed` on the result surfaces it when it fires.
- **Correctness burden shifts to sampling.** The solver is exact against its inputs; a caller who feeds averaged or unrepresentative samples gets an exact answer to the wrong question. Mitigated by the documented input contract and by `getOpacityForBackgrounds` remaining the primary entry point (callers pass colors; the library never guesses them).
- Visual change: existing consumers see one crisp-edged halo instead of N soft layers; spread default (2px) chosen to preserve the soft-halo aesthetic. Screenshot-test the example app.
- API churn: the legacy min/max-ARGB opacity API is deleted outright (§7); `contentRadius` and multi-layer `opacities` survive in the D-5 fallback only.

## 4. Alternatives considered

| Alternative | Rejected because |
|---|---|
| Keep luma extrema, fix only D1/D4 | D2 is a proven soundness hole; no scalar projection (luma, L*, Y — or all pairs jointly) bounds post-γ blended luminance |
| 6-int RGB min/max box as internal reduction | Sound but corners are virtual colors for any non-axis-aligned cloud; measured p99 overshoot 43–58/255 of unnecessary opacity on smooth gradients |
| Persistable background summary on `QuantizerResult` (capped channel-wise Pareto frontier) | Solves "answer future unknown text queries from a stored summary" — a use case no current caller has: every call site passes foreground and backgrounds together. Adds a type, a wire format, and an unavoidable cap-vs-exactness tradeoff (analysis and measurements preserved in `tool/probe_winner_list.dart`). Revisit only if a summary-store pattern emerges (§6) |
| Fix stacked shadows in place (refine loop, honest cap) | Still 4–16 blur passes and a modeled (not guaranteed) edge coverage; dilation makes the model unnecessary |
| Backdrop blur / scrim rect | Different aesthetic contract; composable with this design, not a replacement |

## 5. Verification plan

- **Property tests (port of probes):** (a) sandwich invariant, randomized clouds × α × halos; (b) end-to-end solve-then-audit vs true per-pixel contrast, both algos, both polarities, mid-tone fg — 0 violations required; (c) infeasible-target trials must return `meetsTarget: false`, never a passing-looking α; (d) exactness: solver α must equal brute-force per-color-per-α oracle on randomized suites — zero tolerance; (e) straddle-collapse behavior pinned by the canonical case `#777` over {black, white} — must return the one-sided α with `straddleCollapsed: true`, and must NOT be counted as error against a per-pixel oracle; if the optional Pareto prefilter is implemented, property-test that it never changes any solved α. *Band edges must be computed unclamped:* a clamped band plus `apcaY(white) = 1.0000001` reproduced the exact infeasibility-laundering bug class this ADR removes.
- **Regression:** APCA white-on-black → zero protection; `#AA98F4 / {#7F4F5E, #1F9F39}` WCAG 2.4 → black ≤ 0.28, not white 1.0; luma counterexample set `{gray100, gray200, green}` must pass at solved α.
- **Rendered calibration (example app, not library):** golden-image tests measuring first-outside-pixel alpha for the documented Flutter recipe (`BlurStyle.solid` + spread; expect 1.0) and fallback stacked mode vs closed form (±0.03). These validate the shipped renderer *guidance*; the library's own guarantee is exercised by the property tests above.
- **Fixture parity:** regenerate `test/js/parity_fixture_test.dart` fixtures from the new solver.

## 6. Out of scope (follow-up ADRs)

Halo hue/chroma aesthetics (medoid-of-local-samples, chroma-capped, tone solver-owned); sampling-geometry guidance API (annulus = text box ⊕ spread + 2σ); persistable background summary for query-after-quantize patterns — if ever needed, the design is the capped channel-wise Pareto frontier, with measurements in `tool/probe_winner_list.dart` (winner-list sizes, cap-vs-error table). (Arbitrary protection colors, originally listed here, shipped in v1 — see §7.)

## 7. As built (2026-07-11)

What shipped differs from §2–§5 in these ways. The guarantees are unchanged or stronger; this section exists so the ADR stays truthful against the code.

- **File layout & names.** Everything landed in a new `lib/effects/protection.dart` (JS: `protection.ts`); `getStackedShadows`/`StackedShadowResult` shipped as `getStackedShadowSpec`/`StackedShadowSpec`. `shadows.dart` kept `ShadowResult`/`getShadowOpacitiesForBackgrounds` as a Flutter-typed view over the spec. The legacy `opacity.dart` solver (D1–D3 live) and its JS port were **deleted outright** — no deprecation release — along with their tests and parity fixtures (fixture schema 11 → 12).
- **Solver mechanics (D-2 simplified away).** The analytic forbidden band + blended-luminance interval scan was not built. Shipped: brute-force evaluation of all 256 alphas × N colors using the real `contrastBetweenArgbs` predicate, with a *downward suffix scan* — solved α is the lowest alpha such that it and every higher alpha passes one-sided — so “round up freely” holds even for scrim colors where blended contrast isn’t monotone in α. Same exactness claim (per provided color, per 1/255 step), no band inversion, so the §5 “unclamped band edges” note is moot.
- **Arbitrary scrim colors shipped early.** `protectionArgb` (any color, not just black/white) and `usage` are parameters on all three entry points; infeasible custom scrims report `meetsTarget: false` per D-3.
- **D-5 edge model upgraded.** “Kernel entries adjacent to the edge” was built, measured 0.04 optimistic on thin content against rendered Skia pixels, and rejected. Shipped: continuous Gaussian edge profile (Φ via erf, A&S 7.1.26, bit-identical across ports), with Skia’s own radius→sigma mapping. Layer cap is a `maxLayers` parameter (default 8).
- **Calibration lives in the library repo**, not the example app: `test/effects/shadow_pixel_calibration_test.dart` renders real pixels and gates edge-coverage (±0.01) and delivered-vs-required opacity (−0.03) per §5.
- **Translucent inputs are composited as opaque** (alpha bits ignored) — the “documented alpha-stripping” option from D-6, documented in the input contract, not an `ArgumentError`.