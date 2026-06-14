import {argbFromRgb, blueFromArgb, greenFromArgb, redFromArgb} from './color.js';
import {lstarFromArgb} from './hct.js';
import type {Argb} from './color.js';
import type {QuantizerResult} from './extract.js';
import {QuantizerMap} from './quantizer-map.js';

export class QuantizerWu {
  weights: number[] = [];
  momentsR: number[] = [];
  momentsG: number[] = [];
  momentsB: number[] = [];
  moments: number[] = [];
  cubes: Box[] = [];

  static readonly indexBits = 5;
  static readonly maxIndex = 32;
  static readonly sideLength = 33;
  static readonly totalSize = 35937;

  quantize(pixels: Iterable<Argb>, colorCount: number): QuantizerResult {
    const mapResult = new QuantizerMap().quantize(pixels, colorCount);
    this.constructHistogram(mapResult.argbToCount);
    this.computeMoments();
    const createBoxesResult = this.createBoxes(colorCount);
    const colors = this.createResult(createBoxesResult.resultCount);
    const result: QuantizerResult = {
      argbToCount: new Map<Argb, number>(colors.map(color => [color, 0] as [Argb, number])),
    };
    if (mapResult.lstarToCount) {
      result.lstarToCount = mapResult.lstarToCount;
    }
    return result;
  }

  static getIndex(r: number, g: number, b: number): number {
    return r * QuantizerWu.sideLength * QuantizerWu.sideLength + g * QuantizerWu.sideLength + b;
  }

  constructHistogram(pixels: Map<Argb, number>): void {
    this.weights = Array<number>(QuantizerWu.totalSize).fill(0);
    this.momentsR = Array<number>(QuantizerWu.totalSize).fill(0);
    this.momentsG = Array<number>(QuantizerWu.totalSize).fill(0);
    this.momentsB = Array<number>(QuantizerWu.totalSize).fill(0);
    this.moments = Array<number>(QuantizerWu.totalSize).fill(0);
    for (const [pixel, count] of pixels.entries()) {
      const red = redFromArgb(pixel);
      const green = greenFromArgb(pixel);
      const blue = blueFromArgb(pixel);
      const bitsToRemove = 8 - QuantizerWu.indexBits;
      const iR = (red >> bitsToRemove) + 1;
      const iG = (green >> bitsToRemove) + 1;
      const iB = (blue >> bitsToRemove) + 1;
      const index = QuantizerWu.getIndex(iR, iG, iB);
      this.weights[index]! += count;
      this.momentsR[index]! += red * count;
      this.momentsG[index]! += green * count;
      this.momentsB[index]! += blue * count;
      this.moments[index]! += count * ((red * red) + (green * green) + (blue * blue));
    }
  }

  computeMoments(): void {
    for (let r = 1; r < QuantizerWu.sideLength; ++r) {
      const area = Array<number>(QuantizerWu.sideLength).fill(0);
      const areaR = Array<number>(QuantizerWu.sideLength).fill(0);
      const areaG = Array<number>(QuantizerWu.sideLength).fill(0);
      const areaB = Array<number>(QuantizerWu.sideLength).fill(0);
      const area2 = Array<number>(QuantizerWu.sideLength).fill(0);
      for (let g = 1; g < QuantizerWu.sideLength; g++) {
        let line = 0;
        let lineR = 0;
        let lineG = 0;
        let lineB = 0;
        let line2 = 0;
        for (let b = 1; b < QuantizerWu.sideLength; b++) {
          const index = QuantizerWu.getIndex(r, g, b);
          line += this.weights[index]!;
          lineR += this.momentsR[index]!;
          lineG += this.momentsG[index]!;
          lineB += this.momentsB[index]!;
          line2 += this.moments[index]!;

          area[b]! += line;
          areaR[b]! += lineR;
          areaG[b]! += lineG;
          areaB[b]! += lineB;
          area2[b]! += line2;

          const previousIndex = QuantizerWu.getIndex(r - 1, g, b);
          this.weights[index] = this.weights[previousIndex]! + area[b]!;
          this.momentsR[index] = this.momentsR[previousIndex]! + areaR[b]!;
          this.momentsG[index] = this.momentsG[previousIndex]! + areaG[b]!;
          this.momentsB[index] = this.momentsB[previousIndex]! + areaB[b]!;
          this.moments[index] = this.moments[previousIndex]! + area2[b]!;
        }
      }
    }
  }

  createBoxes(maxColorCount: number): CreateBoxesResult {
    this.cubes = Array.from({length: maxColorCount}, () => new Box());
    if (maxColorCount > 0) {
      this.cubes[0] = new Box({r0: 0, r1: QuantizerWu.maxIndex, g0: 0, g1: QuantizerWu.maxIndex, b0: 0, b1: QuantizerWu.maxIndex, vol: 0});
    }

    const volumeVariance = Array<number>(maxColorCount).fill(0);
    let next = 0;
    let generatedColorCount = maxColorCount;
    for (let i = 1; i < maxColorCount; i++) {
      if (this.cut(this.cubes[next]!, this.cubes[i]!)) {
        volumeVariance[next] = this.cubes[next]!.vol > 1 ? this.variance(this.cubes[next]!) : 0;
        volumeVariance[i] = this.cubes[i]!.vol > 1 ? this.variance(this.cubes[i]!) : 0;
      } else {
        volumeVariance[next] = 0;
        i--;
      }

      next = 0;
      let temp = volumeVariance[0]!;
      for (let j = 1; j <= i; j++) {
        if (volumeVariance[j]! > temp) {
          temp = volumeVariance[j]!;
          next = j;
        }
      }
      if (temp <= 0) {
        generatedColorCount = i + 1;
        break;
      }
    }

    return new CreateBoxesResult(maxColorCount, generatedColorCount);
  }

  createResult(colorCount: number): number[] {
    const colors: number[] = [];
    for (let i = 0; i < colorCount; ++i) {
      const cube = this.cubes[i]!;
      const weight = QuantizerWu.volume(cube, this.weights);
      if (weight > 0) {
        const r = Math.round(QuantizerWu.volume(cube, this.momentsR) / weight);
        const g = Math.round(QuantizerWu.volume(cube, this.momentsG) / weight);
        const b = Math.round(QuantizerWu.volume(cube, this.momentsB) / weight);
        colors.push(argbFromRgb(r, g, b));
      }
    }
    return colors;
  }

  variance(cube: Box): number {
    const dr = QuantizerWu.volume(cube, this.momentsR);
    const dg = QuantizerWu.volume(cube, this.momentsG);
    const db = QuantizerWu.volume(cube, this.momentsB);
    const xx = this.moments[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b1)]!
      - this.moments[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b0)]!
      - this.moments[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b1)]!
      + this.moments[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]!
      - this.moments[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b1)]!
      + this.moments[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]!
      + this.moments[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]!
      - this.moments[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)]!;

    const hypotenuse = (dr * dr + dg * dg + db * db);
    const volume = QuantizerWu.volume(cube, this.weights);
    return xx - hypotenuse / volume;
  }

  cut(one: Box, two: Box): boolean {
    const wholeR = QuantizerWu.volume(one, this.momentsR);
    const wholeG = QuantizerWu.volume(one, this.momentsG);
    const wholeB = QuantizerWu.volume(one, this.momentsB);
    const wholeW = QuantizerWu.volume(one, this.weights);

    const maxRResult = this.maximize(one, Direction.red, one.r0 + 1, one.r1, wholeR, wholeG, wholeB, wholeW);
    const maxGResult = this.maximize(one, Direction.green, one.g0 + 1, one.g1, wholeR, wholeG, wholeB, wholeW);
    const maxBResult = this.maximize(one, Direction.blue, one.b0 + 1, one.b1, wholeR, wholeG, wholeB, wholeW);

    let cutDirection: Direction;
    const maxR = maxRResult.maximum;
    const maxG = maxGResult.maximum;
    const maxB = maxBResult.maximum;
    if (maxR >= maxG && maxR >= maxB) {
      cutDirection = Direction.red;
      if (maxRResult.cutLocation < 0) return false;
    } else if (maxG >= maxR && maxG >= maxB) {
      cutDirection = Direction.green;
    } else {
      cutDirection = Direction.blue;
    }

    two.r1 = one.r1;
    two.g1 = one.g1;
    two.b1 = one.b1;

    switch (cutDirection) {
      case Direction.red:
        one.r1 = maxRResult.cutLocation;
        two.r0 = one.r1;
        two.g0 = one.g0;
        two.b0 = one.b0;
        break;
      case Direction.green:
        one.g1 = maxGResult.cutLocation;
        two.r0 = one.r0;
        two.g0 = one.g1;
        two.b0 = one.b0;
        break;
      case Direction.blue:
        one.b1 = maxBResult.cutLocation;
        two.r0 = one.r0;
        two.g0 = one.g0;
        two.b0 = one.b1;
        break;
    }

    one.vol = (one.r1 - one.r0) * (one.g1 - one.g0) * (one.b1 - one.b0);
    two.vol = (two.r1 - two.r0) * (two.g1 - two.g0) * (two.b1 - two.b0);
    return true;
  }

  maximize(cube: Box, direction: Direction, first: number, last: number, wholeR: number, wholeG: number, wholeB: number, wholeW: number): MaximizeResult {
    let bottomR = QuantizerWu.bottom(cube, direction, this.momentsR);
    let bottomG = QuantizerWu.bottom(cube, direction, this.momentsG);
    let bottomB = QuantizerWu.bottom(cube, direction, this.momentsB);
    let bottomW = QuantizerWu.bottom(cube, direction, this.weights);

    let max = 0;
    let cut = -1;

    for (let i = first; i < last; i++) {
      let halfR = bottomR + QuantizerWu.top(cube, direction, i, this.momentsR);
      let halfG = bottomG + QuantizerWu.top(cube, direction, i, this.momentsG);
      let halfB = bottomB + QuantizerWu.top(cube, direction, i, this.momentsB);
      let halfW = bottomW + QuantizerWu.top(cube, direction, i, this.weights);

      if (halfW === 0) continue;

      let tempNumerator = ((halfR * halfR) + (halfG * halfG) + (halfB * halfB));
      let tempDenominator = halfW;
      let temp = tempNumerator / tempDenominator;

      halfR = wholeR - halfR;
      halfG = wholeG - halfG;
      halfB = wholeB - halfB;
      halfW = wholeW - halfW;
      if (halfW === 0) continue;
      tempNumerator = ((halfR * halfR) + (halfG * halfG) + (halfB * halfB));
      tempDenominator = halfW;
      temp += tempNumerator / tempDenominator;

      if (temp > max) {
        max = temp;
        cut = i;
      }
    }
    return new MaximizeResult(cut, max);
  }

  static volume(cube: Box, moment: number[]): number {
    return moment[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b1)]!
      - moment[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b0)]!
      - moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b1)]!
      + moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]!
      - moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b1)]!
      + moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]!
      + moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]!
      - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)]!;
  }

  static bottom(cube: Box, direction: Direction, moment: number[]): number {
    switch (direction) {
      case Direction.red:
        return -moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b1)]!
          + moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]!
          + moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]!
          - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)]!;
      case Direction.green:
        return -moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b1)]!
          + moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]!
          + moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b1)]!
          - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)]!;
      case Direction.blue:
        return -moment[QuantizerWu.getIndex(cube.r1, cube.g1, cube.b0)]!
          + moment[QuantizerWu.getIndex(cube.r1, cube.g0, cube.b0)]!
          + moment[QuantizerWu.getIndex(cube.r0, cube.g1, cube.b0)]!
          - moment[QuantizerWu.getIndex(cube.r0, cube.g0, cube.b0)]!;
    }
  }

  static top(cube: Box, direction: Direction, position: number, moment: number[]): number {
    switch (direction) {
      case Direction.red:
        return moment[QuantizerWu.getIndex(position, cube.g1, cube.b1)]!
          - moment[QuantizerWu.getIndex(position, cube.g1, cube.b0)]!
          - moment[QuantizerWu.getIndex(position, cube.g0, cube.b1)]!
          + moment[QuantizerWu.getIndex(position, cube.g0, cube.b0)]!;
      case Direction.green:
        return moment[QuantizerWu.getIndex(cube.r1, position, cube.b1)]!
          - moment[QuantizerWu.getIndex(cube.r1, position, cube.b0)]!
          - moment[QuantizerWu.getIndex(cube.r0, position, cube.b1)]!
          + moment[QuantizerWu.getIndex(cube.r0, position, cube.b0)]!;
      case Direction.blue:
        return moment[QuantizerWu.getIndex(cube.r1, cube.g1, position)]!
          - moment[QuantizerWu.getIndex(cube.r1, cube.g0, position)]!
          - moment[QuantizerWu.getIndex(cube.r0, cube.g1, position)]!
          + moment[QuantizerWu.getIndex(cube.r0, cube.g0, position)]!;
    }
  }
}

export enum Direction { red, green, blue }

export class MaximizeResult {
  constructor(readonly cutLocation = -1, readonly maximum = 0) {}
}

export class CreateBoxesResult {
  constructor(readonly requestedCount = 0, readonly resultCount = 0) {}
}

export class Box {
  r0 = 0;
  r1 = 0;
  g0 = 0;
  g1 = 0;
  b0 = 0;
  b1 = 0;
  vol = 0;

  constructor(init: Partial<Box> = {}) {
    Object.assign(this, init);
  }

  toString(): string {
    return `Box: R ${this.r0} -> ${this.r1} G  ${this.g0} -> ${this.g1} B ${this.b0} -> ${this.b1} VOL = ${this.vol}`;
  }
}
