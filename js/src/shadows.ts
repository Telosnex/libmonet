// Stacked-shadow wrappers over the exact protection solver (ADR-001 D-5).
// The math lives in protection.ts (getStackedShadowSpec); these exist for
// API compatibility. Direct port of lib/effects/shadows.dart.

import {type Argb} from './color.js';
import {Algo} from './contrast.js';
import {getStackedShadowSpec, type StackedShadowSpec} from './protection.js';

export {gauss1d, convertRadiusToSigma} from './protection.js';

export class ShadowResult {
  constructor(
    readonly blurRadius: number,
    /** ARGB of the shadow color (typically black or white). */
    readonly shadowArgb: Argb,
    /** Opacities for each shadow layer. Identical by construction. */
    readonly opacities: number[],
    /** False when no stack can meet the target (model-conditional; see StackedShadowSpec). */
    readonly meetsTarget: boolean = true,
  ) {}
}

function fromSpec(spec: StackedShadowSpec): ShadowResult {
  return new ShadowResult(spec.blurRadius, spec.argb, spec.opacities, spec.meetsTarget);
}

/**
 * Shadow layers so foreground meets contrast against every background — the
 * primary stacked-shadow entry point. All colors are checked exactly (no
 * min/max reduction; ADR-001 D-2).
 */
export function getShadowOpacitiesForBackgrounds(opts: {
  foreground: Argb; backgrounds: Iterable<Argb>; contrast: number; algo: Algo;
  blurRadius: number; contentRadius?: number;
}): ShadowResult {
  const backgroundArgbs = [...opts.backgrounds];
  return fromSpec(getStackedShadowSpec({
    foregroundArgb: opts.foreground,
    backgroundArgbs,
    contrast: opts.contrast,
    algo: opts.algo,
    blurRadius: opts.blurRadius,
    ...(opts.contentRadius === undefined ? {} : {contentRadius: opts.contentRadius}),
  }));
}

/** Shadow layers for a single known background. */
export function getShadowOpacitiesForColors(opts: {
  foreground: Argb; background: Argb; contrast: number; algo: Algo;
  blurRadius: number; contentRadius?: number;
}): ShadowResult {
  return getShadowOpacitiesForBackgrounds({...opts, backgrounds: [opts.background]});
}

