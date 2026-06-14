import type {Argb} from './color.js';

export interface PointProvider {
  fromInt(argb: Argb): number[];
  toInt(point: number[]): Argb;
  distance(one: number[], two: number[]): number;
}
