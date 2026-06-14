import {argbFromLab} from './xyz-lab.js';
import type {Argb} from './color.js';
import type {QuantizerResult} from './extract.js';
import type {PointProvider} from './point-provider.js';
import {PointProviderLab} from './point-provider-lab.js';

export class QuantizerWsmeans {
  static readonly debug = false;

  static debugLog(log: string): void {
    if (QuantizerWsmeans.debug) {
      // eslint-disable-next-line no-console
      console.log(log);
    }
  }

  static quantize(
    inputPixels: Iterable<Argb>,
    maxColors: number,
    {
      startingClusters = [],
      pointProvider = defaultPointProvider,
      maxIterations = 5,
      returnInputPixelToClusterPixel = false,
    }: {
      startingClusters?: readonly Argb[];
      pointProvider?: PointProvider;
      maxIterations?: number;
      returnInputPixelToClusterPixel?: boolean;
    } = {},
  ): QuantizerResult {
    if (pointProvider instanceof PointProviderLab) {
      return QuantizerWsmeans.quantizeLab(
        inputPixels,
        maxColors,
        {
          startingClusters,
          maxIterations,
          returnInputPixelToClusterPixel,
        },
      );
    }

    const pixelToIndex = new Map<Argb, number>();
    const points: number[][] = [];
    const pixels: Argb[] = [];
    const countValues: number[] = [];
    for (const inputPixel of inputPixels) {
      const index = pixelToIndex.get(inputPixel);
      if (index === undefined) {
        pixelToIndex.set(inputPixel, pixels.length);
        points.push(pointProvider.fromInt(inputPixel));
        pixels.push(inputPixel);
        countValues.push(1);
      } else {
        countValues[index] = (countValues[index] ?? 0) + 1;
      }
    }

    const pointCount = pixels.length;
    if (pointCount === 0) {
      return {argbToCount: new Map<Argb, number>(), lstarToCount: new Map<number, number>()};
    }

    const counts = countValues;
    const clusterCount = Math.min(maxColors, pointCount);

    const clusters = startingClusters.map(color => pointProvider.fromInt(color));
    const additionalClustersNeeded = clusterCount - clusters.length;
    if (additionalClustersNeeded > 0) {
      const random = new Random(0x42688);
      const indices = new Set<number>();
      for (let i = 0; i < additionalClustersNeeded; i++) {
        if (indices.size >= points.length) break;
        let index = random.nextInt(points.length);
        while (indices.has(index)) {
          index = random.nextInt(points.length);
        }
        indices.add(index);
      }
      for (const index of indices) {
        clusters.push(points[index]!);
      }
    }

    QuantizerWsmeans.debugLog(`have ${clusters.length} starting clusters, ${points.length} points`);

    const clusterIndices = Array.from({length: pointCount}, (_, index) => index % clusterCount);
    const clusterDistanceMatrix = new Float64Array(clusterCount * clusterCount);
    const neighborIndexMatrix = new Int32Array(clusterCount * clusterCount);
    for (let i = 0; i < clusterCount; i++) {
      const rowOffset = i * clusterCount;
      for (let j = 0; j < clusterCount; j++) {
        neighborIndexMatrix[rowOffset + j] = j;
      }
    }
    const neighborDistanceMatrix = new Float64Array(clusterCount * clusterCount);
    const neighborLimits = new Int32Array(clusterCount);
    const previousDistances = new Float64Array(pointCount);
    const maxPreviousDistancesByCluster = new Float64Array(clusterCount);

    const pixelCountSums = Array<number>(clusterCount).fill(0);
    const componentASums = Array<number>(clusterCount).fill(0);
    const componentBSums = Array<number>(clusterCount).fill(0);
    const componentCSums = Array<number>(clusterCount).fill(0);
    for (let iteration = 0; iteration < maxIterations; iteration++) {
      if (QuantizerWsmeans.debug) {
        for (let i = 0; i < clusterCount; i++) {
          pixelCountSums[i] = 0;
        }
        for (let i = 0; i < pointCount; i++) {
          const clusterIndex = clusterIndices[i]!;
          const count = counts[i]!;
          pixelCountSums[clusterIndex] = (pixelCountSums[clusterIndex] ?? 0) + count;
        }
        let emptyClusters = 0;
        for (let cluster = 0; cluster < clusterCount; cluster++) {
          if (pixelCountSums[cluster] === 0) emptyClusters++;
        }
        QuantizerWsmeans.debugLog(`starting iteration ${iteration + 1}; ${emptyClusters} clusters are empty of ${clusterCount}`);
      }

      let pointsMoved = 0;
      for (let i = 0; i < clusterCount; i++) {
        maxPreviousDistancesByCluster[i] = 0;
      }
      for (let i = 0; i < pointCount; i++) {
        const clusterIndex = clusterIndices[i]!;
        const distance = pointProvider.distance(points[i]!, clusters[clusterIndex]!);
        previousDistances[i] = distance;
        if (distance > maxPreviousDistancesByCluster[clusterIndex]!) {
          maxPreviousDistancesByCluster[clusterIndex] = distance;
        }
      }
      if (iteration === 0) {
        for (let i = 0; i < pointCount; i++) {
          const point = points[i]!;
          const previousClusterIndex = clusterIndices[i]!;
          let minimumDistance = previousDistances[i]!;
          let newClusterIndex = -1;
          for (let candidateClusterIndex = 0; candidateClusterIndex < clusterCount; candidateClusterIndex++) {
            if (candidateClusterIndex === previousClusterIndex) continue;
            const distance = pointProvider.distance(point, clusters[candidateClusterIndex]!);
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex !== -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      } else {
        for (let i = 0; i < clusterCount; i++) {
          const distanceRowOffset = i * clusterCount;
          for (let j = i + 1; j < clusterCount; j++) {
            const distance = pointProvider.distance(clusters[i]!, clusters[j]!);
            clusterDistanceMatrix[j * clusterCount + i] = distance;
            clusterDistanceMatrix[distanceRowOffset + j] = distance;
          }
          const neighborLimit = QuantizerWsmeans.partitionNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            clusterDistanceMatrix,
            distanceRowOffset,
            clusterCount,
            4 * maxPreviousDistancesByCluster[i]!,
          );
          neighborLimits[i] = neighborLimit;
          QuantizerWsmeans.sortNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            neighborLimit,
          );
        }

        for (let i = 0; i < pointCount; i++) {
          const point = points[i]!;
          const previousClusterIndex = clusterIndices[i]!;
          const previousDistance = previousDistances[i]!;
          const neighborDistanceThreshold = 4 * previousDistance;
          let minimumDistance = previousDistance;
          let newClusterIndex = -1;
          const previousClusterNeighborRowOffset = previousClusterIndex * clusterCount;
          const neighborLimit = neighborLimits[previousClusterIndex]!;
          for (let j = 0; j < neighborLimit; j++) {
            const neighborOffset = previousClusterNeighborRowOffset + j;
            const candidateClusterIndex = neighborIndexMatrix[neighborOffset]!;
            if (neighborDistanceMatrix[neighborOffset]! >= neighborDistanceThreshold) {
              break;
            }
            if (candidateClusterIndex === previousClusterIndex) continue;
            const distance = pointProvider.distance(point, clusters[candidateClusterIndex]!);
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex !== -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      }

      if (pointsMoved === 0 && iteration > 0) {
        QuantizerWsmeans.debugLog(`terminated after ${iteration} k-means iterations`);
        break;
      }

      QuantizerWsmeans.debugLog(`iteration ${iteration + 1} moved ${pointsMoved}`);
      for (let i = 0; i < clusterCount; i++) {
        pixelCountSums[i] = 0;
        componentASums[i] = 0;
        componentBSums[i] = 0;
        componentCSums[i] = 0;
      }
      for (let i = 0; i < pointCount; i++) {
        const clusterIndex = clusterIndices[i]!;
        const point = points[i]!;
        const count = counts[i]!;
        pixelCountSums[clusterIndex] = (pixelCountSums[clusterIndex] ?? 0) + count;
        componentASums[clusterIndex] = (componentASums[clusterIndex] ?? 0) + (point[0]! * count);
        componentBSums[clusterIndex] = (componentBSums[clusterIndex] ?? 0) + (point[1]! * count);
        componentCSums[clusterIndex] = (componentCSums[clusterIndex] ?? 0) + (point[2]! * count);
      }
      for (let i = 0; i < clusterCount; i++) {
        const count = pixelCountSums[i]!;
        if (count === 0) {
          clusters[i] = [0, 0, 0];
          continue;
        }
        const a = componentASums[i]! / count;
        const b = componentBSums[i]! / count;
        const c = componentCSums[i]! / count;
        clusters[i] = [a, b, c];
      }
    }

    const clusterArgbs: Argb[] = [];
    const clusterPopulations: number[] = [];
    for (let i = 0; i < clusterCount; i++) {
      const count = pixelCountSums[i]!;
      if (count === 0) continue;

      const possibleNewCluster = pointProvider.toInt(clusters[i]!);
      if (clusterArgbs.includes(possibleNewCluster)) continue;

      clusterArgbs.push(possibleNewCluster);
      clusterPopulations.push(count);
    }
    QuantizerWsmeans.debugLog(`kmeans finished and generated ${clusterArgbs.length} clusters; ${clusterCount} were requested`);

    const inputPixelToClusterPixel = new Map<Argb, Argb>();
    if (returnInputPixelToClusterPixel) {
      for (let i = 0; i < pixels.length; i++) {
        const inputPixel = pixels[i]!;
        const clusterIndex = clusterIndices[pixelToIndex.get(inputPixel)!] ?? 0;
        inputPixelToClusterPixel.set(inputPixel, pointProvider.toInt(clusters[clusterIndex]!));
      }
    }

    const result: QuantizerResult = {
      argbToCount: new Map<Argb, number>(clusterArgbs.map((color, index) => [color, clusterPopulations[index]!] as [Argb, number])),
      lstarToCount: new Map<number, number>(),
    };
    if (returnInputPixelToClusterPixel) {
      result.inputPixelToClusterPixel = inputPixelToClusterPixel;
    }
    return result;
  }

  static quantizeLab(
    inputPixels: Iterable<Argb>,
    maxColors: number,
    {
      startingClusters = [],
      maxIterations = 5,
      returnInputPixelToClusterPixel = false,
    }: {
      startingClusters?: readonly Argb[];
      maxIterations?: number;
      returnInputPixelToClusterPixel?: boolean;
    } = {},
  ): QuantizerResult {
    const inputPixelList = Array.isArray(inputPixels) ? inputPixels : Array.from(inputPixels);
    const pixelToIndex = new Map<Argb, number>();
    const pixels = new Int32Array(inputPixelList.length);
    const counts = new Int32Array(inputPixelList.length);
    const pointLs = new Float64Array(inputPixelList.length);
    const pointAs = new Float64Array(inputPixelList.length);
    const pointBs = new Float64Array(inputPixelList.length);
    const lab = new Float64Array(3);
    let pointCount = 0;
    for (const inputPixel of inputPixelList) {
      const index = pixelToIndex.get(inputPixel);
      if (index === undefined) {
        const newIndex = pointCount++;
        pixelToIndex.set(inputPixel, newIndex);
        labFromArgbTo(inputPixel, lab);
        pointLs[newIndex] = lab[0]!;
        pointAs[newIndex] = lab[1]!;
        pointBs[newIndex] = lab[2]!;
        pixels[newIndex] = inputPixel;
        counts[newIndex] = 1;
      } else {
        counts[index] = (counts[index] ?? 0) + 1;
      }
    }

    let clusterCount = Math.min(maxColors, pointCount);
    if (clusterCount === 0) {
      return {argbToCount: new Map<Argb, number>(), lstarToCount: new Map<number, number>()};
    }

    const clusterLs = new Float64Array(clusterCount);
    const clusterAs = new Float64Array(clusterCount);
    const clusterBs = new Float64Array(clusterCount);
    let startingClusterCount = Math.min(startingClusters.length, clusterCount);
    for (let i = 0; i < startingClusterCount; i++) {
      labFromArgbTo(startingClusters[i]!, lab);
      clusterLs[i] = lab[0]!;
      clusterAs[i] = lab[1]!;
      clusterBs[i] = lab[2]!;
    }

    const additionalClustersNeeded = clusterCount - startingClusterCount;
    if (additionalClustersNeeded > 0) {
      const random = new Random(0x42688);
      const indices = new Set<number>();
      for (let i = 0; i < additionalClustersNeeded; i++) {
        if (indices.size >= pointCount) break;
        let index = random.nextInt(pointCount);
        while (indices.has(index)) {
          index = random.nextInt(pointCount);
        }
        indices.add(index);
      }

      for (const index of indices) {
        clusterLs[startingClusterCount] = pointLs[index]!;
        clusterAs[startingClusterCount] = pointAs[index]!;
        clusterBs[startingClusterCount] = pointBs[index]!;
        startingClusterCount++;
      }
    }

    QuantizerWsmeans.debugLog(`have ${startingClusterCount} starting clusters, ${pointCount} points`);

    const clusterIndices = new Int32Array(pointCount);
    for (let i = 0; i < pointCount; i++) {
      clusterIndices[i] = i % clusterCount;
    }

    const clusterDistanceMatrix = new Float64Array(clusterCount * clusterCount);
    const neighborIndexMatrix = new Int32Array(clusterCount * clusterCount);
    for (let i = 0; i < clusterCount; i++) {
      const rowOffset = i * clusterCount;
      for (let j = 0; j < clusterCount; j++) {
        neighborIndexMatrix[rowOffset + j] = j;
      }
    }
    const neighborDistanceMatrix = new Float64Array(clusterCount * clusterCount);
    const neighborLimits = new Int32Array(clusterCount);
    const previousDistances = new Float64Array(pointCount);
    const maxPreviousDistancesByCluster = new Float64Array(clusterCount);

    const pixelCountSums = new Int32Array(clusterCount);
    const componentASums = new Float64Array(clusterCount);
    const componentBSums = new Float64Array(clusterCount);
    const componentCSums = new Float64Array(clusterCount);
    for (let iteration = 0; iteration < maxIterations; iteration++) {
      if (QuantizerWsmeans.debug) {
        for (let i = 0; i < clusterCount; i++) {
          pixelCountSums[i] = 0;
        }
        for (let i = 0; i < pointCount; i++) {
          const clusterIndex = clusterIndices[i]!;
          const count = counts[i]!;
         pixelCountSums[clusterIndex] = (pixelCountSums[clusterIndex] ?? 0) + count;
        }
        let emptyClusters = 0;
        for (let cluster = 0; cluster < clusterCount; cluster++) {
          if (pixelCountSums[cluster] === 0) emptyClusters++;
        }
        QuantizerWsmeans.debugLog(`starting iteration ${iteration + 1}; ${emptyClusters} clusters are empty of ${clusterCount}`);
      }

      let pointsMoved = 0;
      for (let i = 0; i < clusterCount; i++) {
        maxPreviousDistancesByCluster[i] = 0;
      }
      for (let i = 0; i < pointCount; i++) {
        const pointL = pointLs[i]!;
        const pointA = pointAs[i]!;
        const pointB = pointBs[i]!;
        const clusterIndex = clusterIndices[i]!;
        const dL = pointL - clusterLs[clusterIndex]!;
        const dA = pointA - clusterAs[clusterIndex]!;
        const dB = pointB - clusterBs[clusterIndex]!;
        const distance = dL * dL + dA * dA + dB * dB;
        previousDistances[i] = distance;
        if (distance > maxPreviousDistancesByCluster[clusterIndex]!) {
          maxPreviousDistancesByCluster[clusterIndex] = distance;
        }
      }
      if (iteration === 0) {
        for (let i = 0; i < pointCount; i++) {
          const pointL = pointLs[i]!;
          const pointA = pointAs[i]!;
          const pointB = pointBs[i]!;
          const previousClusterIndex = clusterIndices[i]!;
          let minimumDistance = previousDistances[i]!;
          let newClusterIndex = -1;
          for (let candidateClusterIndex = 0; candidateClusterIndex < clusterCount; candidateClusterIndex++) {
            if (candidateClusterIndex === previousClusterIndex) continue;
            const dL = pointL - clusterLs[candidateClusterIndex]!;
            const dA = pointA - clusterAs[candidateClusterIndex]!;
            const dB = pointB - clusterBs[candidateClusterIndex]!;
            const distance = dL * dL + dA * dA + dB * dB;
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex !== -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      } else {
        for (let i = 0; i < clusterCount; i++) {
          const distanceRowOffset = i * clusterCount;
          const clusterL = clusterLs[i]!;
          const clusterA = clusterAs[i]!;
          const clusterB = clusterBs[i]!;
          for (let j = i + 1; j < clusterCount; j++) {
            const dL = clusterL - clusterLs[j]!;
            const dA = clusterA - clusterAs[j]!;
            const dB = clusterB - clusterBs[j]!;
            const distance = dL * dL + dA * dA + dB * dB;
            clusterDistanceMatrix[j * clusterCount + i] = distance;
            clusterDistanceMatrix[distanceRowOffset + j] = distance;
          }
          const neighborLimit = QuantizerWsmeans.partitionNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            clusterDistanceMatrix,
            distanceRowOffset,
            clusterCount,
            4 * maxPreviousDistancesByCluster[i]!,
          );
          neighborLimits[i] = neighborLimit;
          QuantizerWsmeans.sortNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            neighborLimit,
          );
        }

        for (let i = 0; i < pointCount; i++) {
          const pointL = pointLs[i]!;
          const pointA = pointAs[i]!;
          const pointB = pointBs[i]!;
          const previousClusterIndex = clusterIndices[i]!;
          const previousDistance = previousDistances[i]!;
          const neighborDistanceThreshold = 4 * previousDistance;
          let minimumDistance = previousDistance;
          let newClusterIndex = -1;
          const previousClusterNeighborRowOffset = previousClusterIndex * clusterCount;
          const neighborLimit = neighborLimits[previousClusterIndex]!;
          for (let j = 0; j < neighborLimit; j++) {
            const neighborOffset = previousClusterNeighborRowOffset + j;
            const candidateClusterIndex = neighborIndexMatrix[neighborOffset]!;
            if (neighborDistanceMatrix[neighborOffset]! >= neighborDistanceThreshold) {
              break;
            }
            if (candidateClusterIndex === previousClusterIndex) continue;
            const dL = pointL - clusterLs[candidateClusterIndex]!;
            const dA = pointA - clusterAs[candidateClusterIndex]!;
            const dB = pointB - clusterBs[candidateClusterIndex]!;
            const distance = dL * dL + dA * dA + dB * dB;
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex !== -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      }

      if (pointsMoved === 0 && iteration > 0) {
        QuantizerWsmeans.debugLog(`terminated after ${iteration} k-means iterations`);
        break;
      }

      QuantizerWsmeans.debugLog(`iteration ${iteration + 1} moved ${pointsMoved}`);
      for (let i = 0; i < clusterCount; i++) {
        pixelCountSums[i] = 0;
        componentASums[i] = 0;
        componentBSums[i] = 0;
        componentCSums[i] = 0;
      }
      for (let i = 0; i < pointCount; i++) {
        const clusterIndex = clusterIndices[i]!;
        const count = counts[i]!;
        pixelCountSums[clusterIndex] = (pixelCountSums[clusterIndex] ?? 0) + count;
        componentASums[clusterIndex] = (componentASums[clusterIndex] ?? 0) + (pointLs[i]! * count);
        componentBSums[clusterIndex] = (componentBSums[clusterIndex] ?? 0) + (pointAs[i]! * count);
        componentCSums[clusterIndex] = (componentCSums[clusterIndex] ?? 0) + (pointBs[i]! * count);
      }
      for (let i = 0; i < clusterCount; i++) {
        const count = pixelCountSums[i]!;
        if (count === 0) {
          clusterLs[i] = 0;
          clusterAs[i] = 0;
          clusterBs[i] = 0;
          continue;
        }
        clusterLs[i] = componentASums[i]! / count;
        clusterAs[i] = componentBSums[i]! / count;
        clusterBs[i] = componentCSums[i]! / count;
      }
    }

    const clusterArgbs: Argb[] = [];
    const clusterPopulations: number[] = [];
    for (let i = 0; i < clusterCount; i++) {
      const count = pixelCountSums[i]!;
      if (count === 0) continue;

      const possibleNewCluster = argbFromLab(clusterLs[i]!, clusterAs[i]!, clusterBs[i]!);
      if (clusterArgbs.includes(possibleNewCluster)) continue;

      clusterArgbs.push(possibleNewCluster);
      clusterPopulations.push(count);
    }
    QuantizerWsmeans.debugLog(`kmeans finished and generated ${clusterArgbs.length} clusters; ${clusterCount} were requested`);

    const inputPixelToClusterPixel = new Map<Argb, Argb>();
    if (returnInputPixelToClusterPixel) {
      for (let i = 0; i < pointCount; i++) {
        const inputPixel = pixels[i]!;
        const clusterIndex = clusterIndices[i]!;
        inputPixelToClusterPixel.set(
          inputPixel,
          argbFromLab(clusterLs[clusterIndex]!, clusterAs[clusterIndex]!, clusterBs[clusterIndex]!),
        );
      }
    }

    const result: QuantizerResult = {
      argbToCount: new Map<Argb, number>(clusterArgbs.map((color, index) => [color, clusterPopulations[index]!] as [Argb, number])),
      lstarToCount: new Map<number, number>(),
    };
    if (returnInputPixelToClusterPixel) {
      result.inputPixelToClusterPixel = inputPixelToClusterPixel;
    }
    return result;
  }

  static sortNeighborRow(
    indices: Int32Array,
    distances: Float64Array,
    rowOffset: number,
    length: number,
  ): void {
    if (length < 2) return;
    QuantizerWsmeans.quickSortNeighborRow(indices, distances, rowOffset, rowOffset + length - 1);
  }

  static partitionNeighborRow(
    indices: Int32Array,
    neighborDistances: Float64Array,
    neighborOffset: number,
    distances: Float64Array,
    distanceOffset: number,
    length: number,
    maxDistance: number,
  ): number {
    let limit = 0;
    for (let i = 0; i < length; i++) {
      const index = indices[neighborOffset + i]!;
      const distance = distances[distanceOffset + index]!;
      if (distance < maxDistance) {
        const writeOffset = neighborOffset + limit;
        indices[neighborOffset + i] = indices[writeOffset]!;
        indices[writeOffset] = index;
        neighborDistances[writeOffset] = distance;
        limit++;
      }
    }
    return limit;
  }

  static quickSortNeighborRow(
    indices: Int32Array,
    distances: Float64Array,
    left: number,
    right: number,
  ): void {
    while (right - left > 16) {
      let i = left;
      let j = right;
      const pivotDistance = distances[(left + right) >> 1]!;

      while (i <= j) {
        while (distances[i]! < pivotDistance) i++;
        while (distances[j]! > pivotDistance) j--;
        if (i <= j) {
          const swapIndex = indices[i]!;
          indices[i] = indices[j]!;
          indices[j] = swapIndex;
          const swapDistance = distances[i]!;
          distances[i] = distances[j]!;
          distances[j] = swapDistance;
          i++;
          j--;
        }
      }

      if (j - left < right - i) {
        if (left < j) QuantizerWsmeans.quickSortNeighborRow(indices, distances, left, j);
        left = i;
      } else {
        if (i < right) QuantizerWsmeans.quickSortNeighborRow(indices, distances, i, right);
        right = j;
      }
    }

    for (let i = left + 1; i <= right; i++) {
      const index = indices[i]!;
      const distance = distances[i]!;
      let j = i - 1;
      while (j >= left && distances[j]! > distance) {
        indices[j + 1] = indices[j]!;
        distances[j + 1] = distances[j]!;
        j--;
      }
      indices[j + 1] = index;
      distances[j + 1] = distance;
    }
  }
}

const defaultPointProvider = new PointProviderLab();

function labFromArgbTo(argb: Argb, lab: Float64Array): void {
  const converted = defaultPointProvider.fromInt(argb);
  lab[0] = converted[0]!;
  lab[1] = converted[1]!;
  lab[2] = converted[2]!;
}

class Random {
  constructor(private seed: number) {}

  nextInt(max: number): number {
    this.seed = (this.seed * 1103515245 + 12345) & 0x7fffffff;
    return this.seed % max;
  }
}
