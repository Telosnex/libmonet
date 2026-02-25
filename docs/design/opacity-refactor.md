# Opacity API Refactor Design Doc

## Problem Statement

The current `getOpacity()` API accepts L* values for backgrounds, but alpha blending operates in sRGB/luma space. This mismatch forces worst-case assumptions because:

- A single luma value maps to a **~31 L* range** for chromatic colors
- Converting L* → luma requires assuming grayscale or accepting huge uncertainty
- The API cannot give accurate answers without knowing actual colors

## Current API

```dart
OpacityResult getOpacity({
  required double minBgLstar,
  required double maxBgLstar,
  required double foregroundLstar,
  required double contrast,
  required Algo algo,
});
```

### Problems

1. **Wrong input space**: Alpha blending is `BLENDED = α * FG + (1 - α) * BG` in sRGB, not L*
2. **Forced uncertainty**: `lumaFromLstar()` assumes grayscale; chromatic colors diverge wildly
3. **Complexity explosion**: Crossed pairings, fallbacks, edge cases — all symptoms of fighting the wrong abstraction
4. **Inaccurate results**: Must assume worst-case across the L* → luma range

## Proposed API

### Base API (luma-native)

```dart
/// Core opacity calculation in the native space for alpha blending.
/// 
/// All luma values are 0.0 to 1.0 (relative luminance).
OpacityResult getOpacityFromLuma({
  required double foregroundLuma,
  required double minBackgroundLuma,
  required double maxBackgroundLuma,
  required double contrast,
  required Algo algo,
  bool debug = false,
});
```

**Why luma?**
- Alpha blending formula uses linear RGB values
- Luma is the weighted sum of linearized RGB
- No ambiguity: one color = one luma value

### Convenience: Two Colors

```dart
/// Calculate opacity needed for foreground to contrast with background.
/// 
/// Most common case: you know both colors exactly.
OpacityResult getOpacityForColors({
  required Color foreground,
  required Color background,
  required double contrast,
  required Algo algo,
  bool debug = false,
}) {
  final fgLuma = lumaFromArgb(foreground.value) / 100.0;
  final bgLuma = lumaFromArgb(background.value) / 100.0;
  return getOpacityFromLuma(
    foregroundLuma: fgLuma,
    minBackgroundLuma: bgLuma,
    maxBackgroundLuma: bgLuma,  // min == max when bg is known
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
}
```

### Convenience: Multiple Background Colors

```dart
/// Calculate opacity that works across a set of possible backgrounds.
/// 
/// Use case: text over an image, sampled at multiple points.
OpacityResult getOpacityForBackgrounds({
  required Color foreground,
  required Iterable<Color> backgrounds,
  required double contrast,
  required Algo algo,
  bool debug = false,
}) {
  final fgLuma = lumaFromArgb(foreground.value) / 100.0;
  final bgLumas = backgrounds.map((c) => lumaFromArgb(c.value) / 100.0);
  return getOpacityFromLuma(
    foregroundLuma: fgLuma,
    minBackgroundLuma: bgLumas.reduce(min),
    maxBackgroundLuma: bgLumas.reduce(max),
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
}
```

### Convenience: L* (Backward Compatibility)

```dart
/// Calculate opacity from L* values.
/// 
/// ⚠️ DEPRECATED: Prefer color-based APIs for accurate results.
/// 
/// This assumes grayscale colors. For chromatic colors, results may
/// require more opacity than necessary (conservative) or fail to meet
/// contrast requirements for saturated colors (especially blue).
@Deprecated('Use getOpacityForColors() for accurate results')
OpacityResult getOpacity({
  required double minBgLstar,
  required double maxBgLstar,
  required double foregroundLstar,
  required double contrast,
  required Algo algo,
  bool debug = false,
}) {
  // Convert assuming grayscale (L* → gray RGB → luma)
  final fgLuma = lumaFromLstar(foregroundLstar) / 100.0;
  final minBgLuma = lumaFromLstar(minBgLstar) / 100.0;
  final maxBgLuma = lumaFromLstar(maxBgLstar) / 100.0;
  return getOpacityFromLuma(
    foregroundLuma: fgLuma,
    minBackgroundLuma: minBgLuma,
    maxBackgroundLuma: maxBgLuma,
    contrast: contrast,
    algo: algo,
    debug: debug,
  );
}
```

## OpacityResult Changes

### Current

```dart
class OpacityResult {
  final double lstar;      // L* of protection layer
  final double opacity;
  final double requiredLstar;
  
  Color get color => Color(argbFromLstar(lstar)).withOpacityNeue(opacity);
}
```

### Proposed

```dart
class OpacityResult {
  /// Luma of the protection layer (0.0 to 1.0).
  final double protectionLuma;
  
  /// Opacity of the protection layer (0.0 to 1.0).
  final double opacity;
  
  /// Target luma that the protection layer achieves after blending.
  final double targetLuma;
  
  /// Whether a protection layer is needed at all.
  bool get needsProtection => opacity > 0.0;
  
  /// Protection layer as a grayscale color with opacity applied.
  /// 
  /// For most use cases, black or white protection is ideal.
  Color get color {
    final gray = (protectionLuma * 255).round();
    return Color.fromARGB((opacity * 255).round(), gray, gray, gray);
  }
  
  /// L* of the protection layer (for compatibility).
  double get lstar => lstarFromLuma(protectionLuma * 100.0);
  
  /// L* of the target (for compatibility).
  double get requiredLstar => lstarFromLuma(targetLuma * 100.0);
}
```

## Implementation Notes

### Simplifications

The base `getOpacityFromLuma()` should be **much simpler** than current code:

1. **No L* → luma conversion** (caller's responsibility)
2. **No range ambiguity** (luma is exact)
3. **Direct formula application**:
   ```
   opacity = (targetLuma - bgLuma) / (protectionLuma - bgLuma)
   ```

### Protection Layer Strategy

Current code tries white (L*=100) and black (L*=0) protection. Keep this:

```dart
// For light foreground: prefer black protection (darkens bg)
// For dark foreground: prefer white protection (lightens bg)
// Choose whichever requires less opacity
```

### Edge Cases

| Case | Behavior |
|------|----------|
| Already sufficient contrast | Return `opacity: 0.0` |
| Protection same luma as bg | Try opposite protection color |
| Impossible (e.g., need darker than black) | Return `opacity: 1.0` with best-effort |

## Migration Path

1. **Add** new luma-based APIs alongside existing
2. **Deprecate** L*-based `getOpacity()`
3. **Update** internal callers to use color-based APIs
4. **Document** the luma vs L* distinction clearly
5. **Remove** deprecated API in next major version

## Testing

### New Tests

```dart
test('two identical colors need no protection', () {
  final result = getOpacityForColors(
    foreground: Color(0xFF000000),
    background: Color(0xFFFFFFFF),
    contrast: 4.5,
    algo: Algo.wcag21,
  );
  expect(result.needsProtection, false);
});

test('exact luma produces exact opacity', () {
  // Verify formula: opacity = (target - bg) / (protection - bg)
  // With known luma values, result should be precise
});

test('multiple backgrounds uses extremes', () {
  final result = getOpacityForBackgrounds(
    foreground: Colors.white,
    backgrounds: [Color(0xFF333333), Color(0xFF666666), Color(0xFF999999)],
    contrast: 4.5,
    algo: Algo.wcag21,
  );
  // Should handle the hardest case (0x999999, lightest bg)
});
```

### Deprecation Tests

```dart
test('L* API produces same result as color API for grayscale', () {
  // Verify backward compatibility for grayscale inputs
});
```

## Open Questions

1. **Should we also refactor shadows.dart?** (Likely yes, same issues)
2. **Is `Iterable<Color>` the right API, or should we take `ImageProvider`?** (Probably keep simple; image sampling is caller's job)
3. **Should `OpacityResult.color` allow non-grayscale protection?** (Probably not — black/white protection is standard practice and simpler)

## Summary

| | Current | Proposed |
|---|---------|----------|
| Input space | L* | Luma (with L* convenience) |
| Accuracy | ~31 L* worst-case range | Exact |
| Complexity | High (crossed pairings, fallbacks) | Low (direct formula) |
| API surface | 1 function | 3 functions (layered) |
