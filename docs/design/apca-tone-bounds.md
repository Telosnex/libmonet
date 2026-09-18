# APCA from CIE L*: derived bounds, not fitted error padding

This began as a research result. The branch-complete optimizer remains a
research/verification tool, but its forward envelope now supports production's
shared foreground-polarity policy. It does not replace canonical APCA or the
actual-RGB role solver.
Reproduce from the libmonet root:

```sh
dart run tool/apca_tone_bounds.dart --exhaustive
dart run tool/apca_tone_bounds.dart --write-production
```

The standalone Dart tool writes `build/apca-tone-investigation/report.json` and
`tone-bounds.csv`. The second command regenerates both production tables from
one solve. The default command checks stored values against a fresh solve with
1e-14 tolerance, then checks both source files against the **stored Dart values**
for exact formatting/cross-language synchronization. Last-bit differences from
a platform's floating-point evaluation therefore do not defeat the tolerance.
The tool does not invoke Flutter tests or affected tests. Scope: opaque sRGB,
libmonet's actual CIE L* definition, and the APCA constants currently in
`lib/contrast/apca.dart`. Not wide-gamut/HDR or uncomposited transparent colors.

## Production adoption

`lib/contrast/apca_tone_bounds_data.dart` contains the forward envelope at
quarter-tone intervals. `apcaBrightnessBoundsAtTone` brackets with floor/ceiling
entries (never interpolation), rounds outward by 1e-10, and caches returned
values. Envelope monotonicity makes those brackets conservative: a feasible RGB
can move to an adjacent Y by monotonically changing channels, and raw APCA
brightness moves in the same direction. The optimizer therefore does not run
per palette or role.

`sharedForegroundDirection` uses a ±0.3 CIE L* interval around the original
logical background tone. The margin encloses the 0.260590 worst displacement
found by enumerating every 8-bit rounded RGB cell and the half-code continuous
preimage that HCT can quantize into it. It also exceeds transfer-knee and solver
residuals observed in verification. This is a materialization allowance for HCT,
not permission to supply an arbitrary RGB background far from its nominal tone.
APCA compares worst-case black and white capacities from the bounds;
WCAG uses direct L* luminance. Both use the text requirement for the context.

The selected direction is then forced through the existing actual-RGB solver.
Thus hue/chroma still controls how far each role moves, while independent
palettes sharing nominal tone/contrast/algorithm cannot choose opposite sides.
Unreachable roles clamp at the selected extreme and never switch polarity.

`Palette.fromColorAndBackground(..., backgroundTone: T)` is the plumbing for
explicit RGB backgrounds known to share logical context T. Omitting the tone
deliberately makes an explicit surface its own context. Synthesized palettes,
theme triads, recipes, Material surface/error colors, Telosnex Eicher triads and
status palettes carry their original tone. Nested button/fill/interaction
surfaces make separate decisions from their own container tone; specialized
border selection is unchanged.

### Numerical assurance, not formal certification

The production helper now has outward padding and materialization handling:
quarter-tone brackets, 1e-10 brightness padding, the ±0.3 tone interval, and final
actual-RGB role solving. The mathematical envelope is conservative; its floating-
point evaluation is corroborated by the checks below, not certified by interval
arithmetic. A formal numerical guarantee would still require a proof of rounding
error or directed interval evaluation. The research optimizer is offline only;
canonical APCA and HCT tone definitions are unchanged.

## What was already here

James's October 28, 2023 commits:

- `63d95cd`: **APCA Y to L* range landed fully**.
- `fe331e8`: **Land proof of L* range from APCA Y; identify error tolerances**.

Current descendants:

- `lib/contrast/apca_contrast.dart`: `apcaYToLstarRange`,
  `findBoundaryArgbsForApcaY`, `LstarRange`.
- `test/contrast/apca_contrast_test.dart`: skipped **Full RGB Explorer**, skipped
  **all RGBs are in range of L* produced from their APCA Y**, and CSV generator.

The old algorithm generates rounded cube-edge colors plus a gray, then pads its
L* interval by `0.08747562332222003` on the dark side and `0.23986207179298447`
on the light side. Those are empirically measured computational errors, **not**
the entire true chromatic range. The explorer also records `4.7867847389446965`
for `#00005f`: distance to an endpoint of the old padded interval, not a direct
measurement of all colors at exactly the same L*.

In February 2026, `cc3c999` made `lstarToApcaY` float precision. It removed the
unnecessary 8-bit rounding of its hypothetical gray, but did not remove the
underlying difference between colored and gray APCA luminance.

## The short answer

1. **One exact APCA value cannot be recovered from ordinary CIE L* alone.**
   Different colors at exactly the same L* really have different APCA values,
   before quantization. A concrete counterexample is below.
2. **Tight continuous-gamut bounds can be derived without empirical padding.**
   The code evaluates that derivation in floating point. This is not a formally
   certified interval-arithmetic implementation. Production adds the safeguards
   described above; those do not constitute formal numerical certification.
3. **A guaranteed minimum contrast can therefore be solved from tones alone.**
   Use the appropriate worst-case endpoints for both colors. This is a
   conservative policy using canonical APCA, not a claim that APCA has become
   hue-independent.
4. **An exact APCA-equivalent gray coordinate is also possible**, but it is not
   CIE L*. Renaming it tone does not preserve HCT's existing tone coordinate.

## Why the dependency exists

Let encoded sRGB channels `s_i` lie in [0,1]. With `p = 2.4`, the two luminances
used in this repo are:

```
Y = sum(c_i * decode_sRGB(s_i))     c = (.2126, .7152, .0722)
A = sum(a_i * s_i^p)              a = (.2126729, .7151522, .0721750)
```

`Y` uniquely determines CIE L*. `A` is raw APCA Y **before** its near-black soft
clamp. APCA then computes signed Lc from the two A values.

The principal mismatch is the transfer curve:

```
decode(s) = s / 12.92                       in the dark toe
            ((s + .055) / 1.055)^2.4        otherwise
```

APCA instead uses `s^2.4`. The exponent is the same, but the offset and toe mean
these functions are not proportional. APCA's coefficients also differ slightly
from the CIE coefficients in this repo, and sum to 1.0000001, not 1. Both facts
are included in the calculations here.

There is no explicit hue angle or chroma term. The dependency emerges because
channel nonlinearities happen **before summation**. If decode were simply
`s^2.4` and the coefficients matched, the dependency would vanish. That is not
actual sRGB decoding, so replacing one with the other changes the metric.

### A numerical disproof of an exact L* → APCA-Y function

These are continuous sRGB, not rounded hex colors:

| Exact L* | RGB character | Raw APCA Y | Black text Lc |
|---|---|---:|---:|
| 50 | Neutral gray | 0.16027158 | 32.93136 |
| 50 | Red, encoded R≈0.938783696, G=B=0 | 0.18275507 | 36.05070 |

Same L*, different A, different Lc. No algebra can reconstruct the discarded
channel distribution from one scalar while preserving both original definitions.

### The useful Jensen connection

Use linear channels `x_i = decode(s_i)` and write `h(x) = encode(x)^2.4`.
On the upper branch:

```
h(x)  = (1.055*x^(1/p) - .055)^p
h'(x) = 1.055*(1.055 - .055*x^(-1/p))^(p-1)
h''(x) > 0
```

The toe `h(x) = (12.92*x)^p` is also convex. On an individual smooth branch,
if weights matched, Jensen's inequality would make gray the minimum A at fixed
Y. Chromatic channel separation adds a nonnegative Jensen gap; it is not
symmetric random ±noise. The tiny coefficient mismatch shifts the exact minimum
slightly away from gray. At L*=67 that shift in A is only ~1.36e-7.

For channel ranges entirely within one smooth branch, the gap is controlled by
weighted channel variance: between `0.5*min(h'')*Var(x)` and
`0.5*max(h'')*Var(x)`, when using common normalized weights. This explains why
subdued backgrounds generally deviate less than full-gamut saturated examples.
It is not a universal conversion from CAM16/OKLCH chroma units.

**Do not apply global Jensen blindly.** At sRGB's toe junction the derivative
changes in the wrong direction for global convexity, and the published cutoff
constants also introduce a tiny discontinuity. The tool splits branches explicitly.

## Deriving both bounds

### Forward: fixed Y (therefore fixed L*) → min/max A

Choose each channel's toe or upper branch: only **eight combinations**.
On each combination:

- The allowed channels form a box; fixing `sum(c_i*x_i)=Y` cuts it with a plane.
- `sum(a_i*h(x_i))` is a separable convex objective on that slice.
- Its **maximum** is at a vertex of the box/plane intersection: two channels
  are at branch endpoints, with the third solved directly. Enumerate them.
- Its **minimum** satisfies `a_i*h'(x_i)=lambda*c_i` for free channels, with
  the others clamped to branch bounds. Invert the derivative analytically,
  then bisect the single multiplier lambda to satisfy the luminance constraint.

Take the smallest/largest answers over the eight branch combinations. No RGB
rounding and no empirical additive margin are part of this construction.

The derivative inverses used by the code are:

```
toe:   x = (d / (p*12.92^p))^(1/(p-1))
upper: x = (.055 / (1.055 - (d/1.055)^(1/(p-1))))^p
```

Here `d=lambda*c_i/a_i`, clamped via the branch's derivative endpoints first.

### Reverse: fixed A → min/max Y (therefore L*)

Use `u_i=s_i^p`. The constraint is now `sum(a_i*u_i)=A` and:

```
g(u) = u^(1/p) / 12.92                    toe
       ((u^(1/p) + .055) / 1.055)^p       upper
```

Each branch is concave. Therefore the **minimum** is at a sliced-box vertex;
the **maximum** is the one-multiplier concave optimum. Again enumerate all eight
branch combinations. Finally convert the extrema of Y monotonically to L*.

This completes/refines the old boundary conjecture: one extreme is at boundaries;
the other is generally near gray **in the interior**, not at a cube edge. The
old algorithm included a gray explicitly, so its practical coverage was better
than the wording of its boundary conjecture suggests.

### Precision and endpoints

The tool uses the exact `linearized` branch selector `s<=0.040449936` from this
repo. At that selector the upper/lower decoded limits differ by about 2.2e-9 in
normalized physical Y. Both one-sided closures are enumerated; at an open
endpoint a reported extremum is an infimum/supremum. This avoids quietly
assuming a perfectly smooth transfer curve.

The proof identifies the extremizers; double-precision bisection evaluates them.
64 multiplier iterations and direct witnesses expose numerical residuals. This
is not a claim of symbolic exact decimal answers or formally directed rounding.
Production uses a table generated by this optimizer, not the optimizer itself;
canonical APCA and the actual-RGB solver remain responsible for contrast.

## Numbers at fixed tone

The following bounds allow **any sRGB hue/chroma** at the exact indicated actual
L*. Foreground is pure black or pure white. Values are Lc magnitudes; rounded for
readability, not suitable as outward-rounded accessibility thresholds.

| Background L* | Black text | White text |
|---:|---:|---:|
| 20 | 0.00–7.48 | 100.10–102.69 |
| 30 | 12.34–16.03 | 92.63–95.91 |
| 50 | 32.93–36.05 | 73.53–76.62 |
| 60 | 45.20–48.05 | 61.34–64.27 |
| 65 | 51.80–53.06 | 56.11–57.43 |
| 66 | 53.15–54.27 | 54.84–56.01 |
| 67 | 54.52–55.51 | 53.53–54.58 |
| 68 | 55.90–56.85 | 52.12–53.12 |
| 80 | 73.36–74.37 | 33.17–34.28 |
| 90 | 89.16–89.93 | 15.78–16.65 |

These aren't necessarily filled intervals: APCA's low-clip produces jumps.
In particular, it returns zero below a raw threshold and starts at magnitude
7.3 Lc when that threshold is crossed. Small Y differences can straddle that
jump; a universal "hue only causes 1–3 Lc error" claim is false.

Exhaustive 8-bit examples comparing actual APCA to the unrounded neutral reference
at the color's *actual* L*:

- `#0400c6`, L*=24.00916782: black text scores **10.66115**; neutral reference
  scores **0**. Largest black-text discrepancy in this finite sweep.
- `#eafc12`, L*=94.80480377: white text scores **0**; neutral reference scores
  **7.57082** in magnitude. Largest white-text discrepancy in this finite sweep.

These are low-contrast clipping phenomena, not 10-Lc uncertainty at every useful
body-text threshold. They also do not certify maxima for arbitrary pairs of
colored foreground and background, or for the entire continuous gamut.

### The near-67 polarity seam, precisely

Black/white magnitudes tie at raw APCA Y **0.341955253985208**.
The derived L* interval at that value is:

```
66.2262417684 … 67.0193095827
```

The low endpoint is a magenta-ish boundary color (encoded RGB approximately
1, .348836818, 1); the high endpoint is nearly gray. Gray alone ties at
**67.0192994357**. Thus across the full gamut:

- Below the band, white gives greater extreme contrast for all hues.
- Above it, black gives greater extreme contrast for all hues.
- Inside it, colors at the same tone can disagree.

This is the *greater extreme contrast* decision, not every aesthetic preference
or contrast-target fallback decision. It does not say an APCA 60 target is
achievable near the seam. At L*=67, **neither black nor white reaches 60**.

The existing `lstarPrefersLighterPair` aesthetic rule is unchanged:
`tone.round() <= 60`, i.e. `tone < 60.5` prefers a lighter foreground and
`tone >= 60.5` prefers darker. When `forceDirection` is null, the ARGB solver
first tries that direction. If it cannot meet the target, it compares
`abs(target - blackLc)` with `abs(target - whiteLc)` using actual
background RGB. Near tone 67 with a target of 60, both extremes undershoot, so
"closest to target" is exactly "larger magnitude" and the band above applies.
For different requested contrasts the reachable/fallback boundary can differ;
this is **not** a universal replacement of the aesthetic cutoff 60.5 by 67.

Requested palette tone and actual quantized output tone can also differ; this
band refers to actual CIE L*, not an ideal target fed to a gamut solver.

## Tone-only solving with guaranteed minimum contrast

Let `Amin(T)` and `Amax(T)` be the derived envelopes. Signed APCA `C(text,bg)` is
monotonically decreasing in text A and increasing in background A (including
its zero plateaus/jumps). For two independently colored surfaces:

```
Lc_min = C(Amax(textTone), Amin(backgroundTone))
Lc_max = C(Amin(textTone), Amax(backgroundTone))
```

For dark text, require `Lc_min >= target`. For light text, require
`Lc_max <= -target`. Do not use absolute values prematurely when the interval
crosses zero. Bisect foreground tone in the selected direction. Report impossible
when even the relevant black/white endpoint cannot meet the bound.

Examples for target **Lc 60**, covering arbitrary sRGB colors on *both* sides:

| Background actual L* | A sufficient light foreground L* | A sufficient dark foreground L* |
|---:|---:|---:|
| 20 | >=77.17727058 | impossible |
| 40 | >=86.62581717 | impossible |
| 50 | >=92.78151118 | impossible |
| 67 | impossible | impossible |
| 80 | impossible | <=24.64061992 |
| 94 | impossible | <=48.10229965 |

Numbers are mathematical thresholds evaluated numerically. Round away from the
boundary and verify materialized RGB in production. The guarantee assumes
*actual* tones; if quantization shifts them, evaluate an enclosing tone interval
or validate the final colors. No extra empirical "chroma error" padding is needed
in the mathematical envelope itself.

For choosing a common polarity, compare the worst-case black and white scores.
That **maximin** rule switches at approximately **66.63246160** in this full-gamut
model. It's one defensible policy, not a mandated aesthetic threshold. Independent
palettes given identical shared tone/algorithm/policy can make the same decision
without a central coordinator. A known actual background, or a proven restricted
gamut, permits less conservative foreground choices than these full-gamut bounds.

The same bounds could support background flexing: minimally shift an adjustable
background until the chosen direction becomes feasible. A wallpaper sample must
not be changed only in the solver without changing the painted backing.

## Could we get rid of the interval altogether?

Not while retaining **both** ordinary CIE L* and canonical APCA. The counterexample
above forbids an exact single-valued conversion.

An exact scalar coordinate for APCA already exists: A. A convenient normalized
"equivalent gray code" is `Q=(A/(a_R+a_G+a_B))^(1/2.4)`. It recovers A exactly
by `A=sum(a)*Q^2.4`. You can label it with the CIE L* of that hypothetical gray,
subject to the sRGB transfer-knee convention. But that label generally differs
from the color's real CIE L*. E.g. `#00005f` has real tone **7.46324536** but an
APCA-equivalent gray tone approximately **12.13826467**, a shift of **4.67501931**.
That's the largest absolute equivalent-gray tone shift in the 8-bit exhaustive
sweep. At that blue's A, the tight continuous CIE-L* range is approximately
**7.46324536–12.13826534**; the near-gray maximum differs microscopically from
exact gray because of the coefficient mismatch.

Alternatively, apply APCA's final contrast formula to `lstarToApcaY(T)` for both
colors. That is a consistent neutral-reference, tone-only **design metric**. It
matches neutral gray but is not canonical APCA for arbitrary chromatic colors.
It can choose shared polarity, but should not be presented as the actual contrast.

## Validation performed / limits

- 2,216 continuous RGB probes, including corners and values around the toe:
  forward/reverse containment and extremizer witness checks. Largest observed
  witness constraint residual about **1.2e-14**; objective residual zero in this run.
- All **16,777,216 8-bit RGBs** checked against conservative brackets from a
  4,097-point analytic envelope grid: **zero violations**. Bounds were bracketed
  by endpoints, not interpolated. This corroborates coverage, not tightness at
  every discrete color; the optimization argument establishes continuous extrema.
- Every 8-bit RGB cell was also compared with its encoded half-code continuous
  preimage. The largest possible CIE L* movement when HCT's exact-Y result is
  rounded into that cell was **0.2605899911**, below production's ±0.3 interval.
- Exact per-color neutral comparison in that finite exhaustive sweep, including
  APCA's clipping. No histogram of nominal rounded tones conflated with exact L*.
- A 10,001-point forward tone sweep and reverse A sweep. Maxima from those grids
  are explicitly marked sampled, not proven global maxima between sample points.
- Source APCA constants checked by the standalone tool; CIE conversion imported
  from the real core implementation. The APCA arithmetic is reproduced locally
  to avoid importing Flutter/dart:ui into a CLI research program.
- No affected-test sweep or application-wide test run was performed during the
  original research. Focused production policy, palette, parity, Eicher, and
  status-palette tests were added during adoption.

The forward helper `apcaBrightnessBoundsAtTone` is importable from Dart's
`contrast/apca_tone_bounds.dart` and exported from the TypeScript package root.
It returns an immutable cached value (final fields in Dart; readonly fields and
runtime freezing in TypeScript). These raw brightness bounds are conservative
policy inputs, not a substitute for validating a materialized RGB pair.
The branch-complete optimizer remains intentionally clear rather than fast and
runs only in this tool. Runtime code performs cached table lookups and canonical
actual-RGB contrast solving. Regenerate both language tables with
`--write-production`; a normal tool run rejects numerically stale values and
out-of-sync source files as separate checks.
