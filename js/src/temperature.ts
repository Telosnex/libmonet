import {type Argb} from './color.js';
import {Hct, sanitizeDegreesDouble} from './hct.js';
import {labFromArgb} from './xyz-lab.js';

export function sanitizeDegreesInt(degrees: number): number {
  degrees = Math.trunc(degrees) % 360;
  return degrees < 0 ? degrees + 360 : degrees;
}

export function isBetween(angle: number, a: number, b: number): boolean {
  if (a < b) return a <= angle && angle <= b;
  return a <= angle || angle <= b;
}

export function rawTemperature(color: Hct): number {
  const lab = labFromArgb(color.toInt());
  const hue = sanitizeDegreesDouble(Math.atan2(lab[2]!, lab[1]!) * 180 / Math.PI);
  const chroma = Math.sqrt(lab[1]! * lab[1]! + lab[2]! * lab[2]!);
  return -0.5 + 0.02 * Math.pow(chroma, 1.07) * Math.cos(sanitizeDegreesDouble(hue - 50) * Math.PI / 180);
}

export class TemperatureCache {
  private hctsByTempCache?: Hct[];
  private hctsByHueCache?: Hct[];
  private tempsByHctCache?: Map<Argb, number>;
  private inputRelativeTemperatureCache = -1;
  private complementCache?: Hct;

  constructor(readonly input: Hct) {}

  get warmest(): Hct { return this.hctsByTemp[this.hctsByTemp.length - 1]!; }
  get coldest(): Hct { return this.hctsByTemp[0]!; }

  analogous(count = 5, divisions = 12): Hct[] {
    const startHue = Math.round(this.input.hue) % 360;
    const startHct = this.hctsByHue[startHue]!;
    let lastTemp = this.relativeTemperature(startHct);
    const allColors: Hct[] = [startHct];

    let absoluteTotalTempDelta = 0;
    for (let i = 0; i < 360; i++) {
      const hue = sanitizeDegreesInt(startHue + i);
      const hct = this.hctsByHue[hue]!;
      const temp = this.relativeTemperature(hct);
      absoluteTotalTempDelta += Math.abs(temp - lastTemp);
      lastTemp = temp;
    }

    let hueAddend = 1;
    const tempStep = absoluteTotalTempDelta / divisions;
    let totalTempDelta = 0;
    lastTemp = this.relativeTemperature(startHct);
    while (allColors.length < divisions) {
      const hue = sanitizeDegreesInt(startHue + hueAddend);
      const hct = this.hctsByHue[hue]!;
      const temp = this.relativeTemperature(hct);
      const tempDelta = Math.abs(temp - lastTemp);
      totalTempDelta += tempDelta;

      let indexSatisfied = totalTempDelta >= allColors.length * tempStep;
      let indexAddend = 1;
      while (indexSatisfied && allColors.length < divisions) {
        allColors.push(hct);
        indexSatisfied = totalTempDelta >= (allColors.length + indexAddend) * tempStep;
        indexAddend++;
      }
      lastTemp = temp;
      hueAddend++;
      if (hueAddend > 360) {
        while (allColors.length < divisions) allColors.push(hct);
        break;
      }
    }

    const answers: Hct[] = [this.input];
    const increaseHueCount = Math.floor((count - 1) / 2);
    for (let i = 1; i < increaseHueCount + 1; i++) {
      let index = -i;
      while (index < 0) index = allColors.length + index;
      if (index >= allColors.length) index %= allColors.length;
      answers.unshift(allColors[index]!);
    }
    const decreaseHueCount = count - increaseHueCount - 1;
    for (let i = 1; i < decreaseHueCount + 1; i++) {
      let index = i;
      while (index < 0) index = allColors.length + index;
      if (index >= allColors.length) index %= allColors.length;
      answers.push(allColors[index]!);
    }
    return answers;
  }

  get complement(): Hct {
    if (this.complementCache) return this.complementCache;
    const coldestHue = this.coldest.hue;
    const coldestTemp = this.tempsByHct.get(this.coldest.toInt())!;
    const warmestHue = this.warmest.hue;
    const warmestTemp = this.tempsByHct.get(this.warmest.toInt())!;
    const range = warmestTemp - coldestTemp;
    const startHueIsColdestToWarmest = isBetween(this.input.hue, coldestHue, warmestHue);
    const startHue = startHueIsColdestToWarmest ? warmestHue : coldestHue;
    const endHue = startHueIsColdestToWarmest ? coldestHue : warmestHue;
    let smallestError = 1000;
    let answer = this.hctsByHue[Math.round(this.input.hue) % 360]!;
    const complementRelativeTemp = 1 - this.inputRelativeTemperature;
    for (let hueAddend = 0; hueAddend <= 360; hueAddend += 1) {
      const hue = sanitizeDegreesDouble(startHue + hueAddend);
      if (!isBetween(hue, startHue, endHue)) continue;
      const possibleAnswer = this.hctsByHue[Math.round(hue) % 360]!;
      const relativeTemp = range === 0 ? 0.5 : (this.tempsByHct.get(possibleAnswer.toInt())! - coldestTemp) / range;
      const error = Math.abs(complementRelativeTemp - relativeTemp);
      if (error < smallestError) {
        smallestError = error;
        answer = possibleAnswer;
      }
    }
    this.complementCache = answer;
    return answer;
  }

  relativeTemperature(hct: Hct): number {
    const range = this.tempsByHct.get(this.warmest.toInt())! - this.tempsByHct.get(this.coldest.toInt())!;
    const differenceFromColdest = this.tempsByHct.get(hct.toInt())! - this.tempsByHct.get(this.coldest.toInt())!;
    if (range === 0) return 0.5;
    return differenceFromColdest / range;
  }

  get inputRelativeTemperature(): number {
    if (this.inputRelativeTemperatureCache >= 0) return this.inputRelativeTemperatureCache;
    const coldestTemp = this.tempsByHct.get(this.coldest.toInt())!;
    const range = this.tempsByHct.get(this.warmest.toInt())! - coldestTemp;
    const differenceFromColdest = this.tempsByHct.get(this.input.toInt())! - coldestTemp;
    this.inputRelativeTemperatureCache = range === 0 ? 0.5 : differenceFromColdest / range;
    return this.inputRelativeTemperatureCache;
  }

  get hctsByTemp(): Hct[] {
    if (this.hctsByTempCache) return this.hctsByTempCache;
    const tempsByHct = this.tempsByHct;
    const hcts = [...this.hctsByHue, this.input];
    hcts.sort((a, b) => tempsByHct.get(a.toInt())! - tempsByHct.get(b.toInt())!);
    this.hctsByTempCache = hcts;
    return hcts;
  }

  get tempsByHct(): Map<Argb, number> {
    if (this.tempsByHctCache) return this.tempsByHctCache;
    const map = new Map<Argb, number>();
    for (const hct of [...this.hctsByHue, this.input]) map.set(hct.toInt(), rawTemperature(hct));
    this.tempsByHctCache = map;
    return map;
  }

  get hctsByHue(): Hct[] {
    if (this.hctsByHueCache) return this.hctsByHueCache;
    this.hctsByHueCache = Array.from({length: 360}, (_, hue) => Hct.from(hue, this.input.chroma, this.input.tone, this.input.colorModel));
    return this.hctsByHueCache;
  }
}
