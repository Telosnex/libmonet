import {argbFromLab, labFromArgb} from './xyz-lab.js';
import type {Argb} from './color.js';
import type {PointProvider} from './point-provider.js';

export class PointProviderLab implements PointProvider {
  fromInt(argb: Argb): number[] {
    return labFromArgb(argb);
  }

  toInt(lab: number[]): Argb {
    return argbFromLab(lab[0]!, lab[1]!, lab[2]!);
  }

  distance(one: number[], two: number[]): number {
    const dL = one[0]! - two[0]!;
    const dA = one[1]! - two[1]!;
    const dB = one[2]! - two[2]!;
    return dL * dL + dA * dA + dB * dB;
  }
}
