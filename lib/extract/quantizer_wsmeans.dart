// Modified and maintained by open-source contributors, on behalf of libmonet.
//
// Original notice:
// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:collection' show HashMap;
import 'dart:math' as math show Random, min;
import 'dart:typed_data';

import 'package:libmonet/core/argb_srgb_xyz_lab.dart';
import 'package:libmonet/extract/point_provider.dart';
import 'package:libmonet/extract/point_provider_lab.dart';
import 'package:libmonet/extract/quantizer_result.dart';

class QuantizerWsmeans {
  static const debug = false;

  static void debugLog(String log) {
    if (debug) {
      // ignore: avoid_print
      print(log);
    }
  }

  static QuantizerResult quantize(
    Iterable<int> inputPixels,
    int maxColors, {
    List<int> startingClusters = const [],
    PointProvider pointProvider = const PointProviderLab(),
    int maxIterations = 5,
    bool returnInputPixelToClusterPixel = false,
  }) {
    if (pointProvider is PointProviderLab) {
      return _quantizeLab(
        inputPixels,
        maxColors,
        startingClusters: startingClusters,
        maxIterations: maxIterations,
        returnInputPixelToClusterPixel: returnInputPixelToClusterPixel,
      );
    }

    final pixelToIndex = HashMap<int, int>();
    final points = <List<double>>[];
    final pixels = <int>[];
    final countValues = <int>[];
    for (var inputPixel in inputPixels) {
      final index = pixelToIndex[inputPixel];
      if (index == null) {
        pixelToIndex[inputPixel] = pixels.length;
        points.add(pointProvider.fromInt(inputPixel));
        pixels.add(inputPixel);
        countValues.add(1);
      } else {
        countValues[index]++;
      }
    }

    final pointCount = pixels.length;
    final counts = countValues;

    var clusterCount = math.min(maxColors, pointCount);

    final clusters = startingClusters
        .map((e) => pointProvider.fromInt(e))
        .toList();
    final additionalClustersNeeded = clusterCount - clusters.length;
    if (additionalClustersNeeded > 0) {
      final random = math.Random(0x42688);
      final indices = <int>{};
      for (var i = 0; i < additionalClustersNeeded; i++) {
        // Use existing points rather than generating random centroids.
        //
        // KMeans is extremely sensitive to initial clusters. This quantizer
        // is meant to be used with a Wu quantizer that provides initial
        // centroids, but Wu is very slow on unscaled images and when extracting
        // more than 256 colors.
        //
        // Here, we can safely assume that more than 256 colors were requested
        // for extraction. Generating random centroids tends to lead to many
        // "empty" centroids, as the random centroids are nowhere near any pixels
        // in the image, and the centroids from Wu are very refined and close
        // to pixels in the image.
        //
        // Rather than generate random centroids, we'll pick centroids that
        // are actual pixels in the image, and avoid duplicating centroids.

        // Safeguard: if we've exhausted all unique points, stop adding clusters.
        if (indices.length >= points.length) {
          break;
        }
        var index = random.nextInt(points.length);
        while (indices.contains(index)) {
          index = random.nextInt(points.length);
        }
        indices.add(index);
      }

      for (var index in indices) {
        clusters.add(points[index]);
      }
    }
    debugLog(
      'have ${clusters.length} starting clusters, ${points.length} points',
    );
    final clusterIndices = List<int>.generate(
      pointCount,
      (index) => index % clusterCount,
    );

    final clusterDistanceMatrix = Float64List(clusterCount * clusterCount);
    final neighborIndexMatrix = Int32List(clusterCount * clusterCount);
    for (var i = 0; i < clusterCount; i++) {
      final rowOffset = i * clusterCount;
      for (var j = 0; j < clusterCount; j++) {
        neighborIndexMatrix[rowOffset + j] = j;
      }
    }
    final neighborDistanceMatrix = Float64List(clusterCount * clusterCount);
    final neighborLimits = Int32List(clusterCount);
    final previousDistances = Float64List(pointCount);
    final maxPreviousDistancesByCluster = Float64List(clusterCount);

    final pixelCountSums = List<int>.filled(clusterCount, 0);
    final componentASums = List<double>.filled(clusterCount, 0);
    final componentBSums = List<double>.filled(clusterCount, 0);
    final componentCSums = List<double>.filled(clusterCount, 0);
    for (var iteration = 0; iteration < maxIterations; iteration++) {
      if (debug) {
        for (var i = 0; i < clusterCount; i++) {
          pixelCountSums[i] = 0;
        }
        for (var i = 0; i < pointCount; i++) {
          final clusterIndex = clusterIndices[i];
          final count = counts[i];
          pixelCountSums[clusterIndex] += count;
        }
        var emptyClusters = 0;
        for (var cluster = 0; cluster < clusterCount; cluster++) {
          if (pixelCountSums[cluster] == 0) {
            emptyClusters++;
          }
        }
        debugLog(
          'starting iteration ${iteration + 1}; $emptyClusters clusters are empty of $clusterCount',
        );
      }

      var pointsMoved = 0;
      for (var i = 0; i < clusterCount; i++) {
        maxPreviousDistancesByCluster[i] = 0;
      }
      for (var i = 0; i < pointCount; i++) {
        final clusterIndex = clusterIndices[i];
        final distance = pointProvider.distance(
          points[i],
          clusters[clusterIndex],
        );
        previousDistances[i] = distance;
        if (distance > maxPreviousDistancesByCluster[clusterIndex]) {
          maxPreviousDistancesByCluster[clusterIndex] = distance;
        }
      }
      if (iteration == 0) {
        for (var i = 0; i < pointCount; i++) {
          final point = points[i];
          final previousClusterIndex = clusterIndices[i];
          var minimumDistance = previousDistances[i];
          var newClusterIndex = -1;
          for (
            var candidateClusterIndex = 0;
            candidateClusterIndex < clusterCount;
            candidateClusterIndex++
          ) {
            if (candidateClusterIndex == previousClusterIndex) {
              continue;
            }
            final distance = pointProvider.distance(
              point,
              clusters[candidateClusterIndex],
            );
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex != -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      } else {
        for (var i = 0; i < clusterCount; i++) {
          final distanceRowOffset = i * clusterCount;
          for (var j = i + 1; j < clusterCount; j++) {
            final distance = pointProvider.distance(clusters[i], clusters[j]);
            clusterDistanceMatrix[j * clusterCount + i] = distance;
            clusterDistanceMatrix[distanceRowOffset + j] = distance;
          }
          final neighborLimit = _partitionNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            clusterDistanceMatrix,
            distanceRowOffset,
            clusterCount,
            4 * maxPreviousDistancesByCluster[i],
          );
          neighborLimits[i] = neighborLimit;
          _sortNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            neighborLimit,
          );
        }

        for (var i = 0; i < pointCount; i++) {
          final point = points[i];
          final previousClusterIndex = clusterIndices[i];
          final previousDistance = previousDistances[i];
          final neighborDistanceThreshold = 4 * previousDistance;
          var minimumDistance = previousDistance;
          var newClusterIndex = -1;
          final previousClusterNeighborRowOffset =
              previousClusterIndex * clusterCount;
          final neighborLimit = neighborLimits[previousClusterIndex];
          for (var j = 0; j < neighborLimit; j++) {
            final neighborOffset = previousClusterNeighborRowOffset + j;
            final candidateClusterIndex = neighborIndexMatrix[neighborOffset];
            if (neighborDistanceMatrix[neighborOffset] >=
                neighborDistanceThreshold) {
              break;
            }
            if (candidateClusterIndex == previousClusterIndex) {
              continue;
            }
            final distance = pointProvider.distance(
              point,
              clusters[candidateClusterIndex],
            );
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex != -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      }

      if (pointsMoved == 0 && iteration > 0) {
        debugLog('terminated after $iteration k-means iterations');
        break;
      }

      debugLog('iteration ${iteration + 1} moved $pointsMoved');
      for (var i = 0; i < clusterCount; i++) {
        pixelCountSums[i] = 0;
        componentASums[i] = 0;
        componentBSums[i] = 0;
        componentCSums[i] = 0;
      }
      for (var i = 0; i < pointCount; i++) {
        final clusterIndex = clusterIndices[i];
        final point = points[i];
        final count = counts[i];
        pixelCountSums[clusterIndex] += count;
        componentASums[clusterIndex] += (point[0] * count);
        componentBSums[clusterIndex] += (point[1] * count);
        componentCSums[clusterIndex] += (point[2] * count);
      }
      for (var i = 0; i < clusterCount; i++) {
        final count = pixelCountSums[i];
        if (count == 0) {
          clusters[i] = [0.0, 0.0, 0.0];
          continue;
        }
        final a = componentASums[i] / count;
        final b = componentBSums[i] / count;
        final c = componentCSums[i] / count;
        clusters[i] = [a, b, c];
      }
    }

    final clusterArgbs = <int>[];
    final clusterPopulations = <int>[];
    for (var i = 0; i < clusterCount; i++) {
      final count = pixelCountSums[i];
      if (count == 0) {
        continue;
      }

      final possibleNewCluster = pointProvider.toInt(clusters[i]);
      if (clusterArgbs.contains(possibleNewCluster)) {
        continue;
      }

      clusterArgbs.add(possibleNewCluster);
      clusterPopulations.add(count);
    }
    debugLog(
      'kmeans finished and generated ${clusterArgbs.length} clusters; $clusterCount were requested',
    );

    final inputPixelToClusterPixel = <int, int>{};
    if (returnInputPixelToClusterPixel) {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < pixels.length; i++) {
        final inputPixel = pixels[i];
        final clusterIndex = clusterIndices[i];
        final cluster = clusters[clusterIndex];
        final clusterPixel = pointProvider.toInt(cluster);
        inputPixelToClusterPixel[inputPixel] = clusterPixel;
      }
      debugLog(
        'took ${stopwatch.elapsedMilliseconds} ms to create input to cluster map',
      );
    }

    return QuantizerResult(
      Map.fromIterables(clusterArgbs, clusterPopulations),
      inputPixelToClusterPixel: inputPixelToClusterPixel,
      lstarToCount: {},
    );
  }

  static QuantizerResult _quantizeLab(
    Iterable<int> inputPixels,
    int maxColors, {
    List<int> startingClusters = const [],
    int maxIterations = 5,
    bool returnInputPixelToClusterPixel = false,
  }) {
    final inputPixelList = inputPixels is List<int>
        ? inputPixels
        : List<int>.from(inputPixels, growable: false);
    final pixelToIndex = HashMap<int, int>();
    final pixels = Int32List(inputPixelList.length);
    final counts = Int32List(inputPixelList.length);
    final pointLs = Float64List(inputPixelList.length);
    final pointAs = Float64List(inputPixelList.length);
    final pointBs = Float64List(inputPixelList.length);
    final lab = Float64List(3);
    var pointCount = 0;
    for (final inputPixel in inputPixelList) {
      final index = pixelToIndex[inputPixel];
      if (index == null) {
        final newIndex = pointCount++;
        pixelToIndex[inputPixel] = newIndex;
        labFromArgbTo(inputPixel, lab);
        pointLs[newIndex] = lab[0];
        pointAs[newIndex] = lab[1];
        pointBs[newIndex] = lab[2];
        pixels[newIndex] = inputPixel;
        counts[newIndex] = 1;
      } else {
        counts[index]++;
      }
    }

    var clusterCount = math.min(maxColors, pointCount);

    final clusterLs = Float64List(clusterCount);
    final clusterAs = Float64List(clusterCount);
    final clusterBs = Float64List(clusterCount);
    var startingClusterCount = math.min(startingClusters.length, clusterCount);
    for (var i = 0; i < startingClusterCount; i++) {
      labFromArgbTo(startingClusters[i], lab);
      clusterLs[i] = lab[0];
      clusterAs[i] = lab[1];
      clusterBs[i] = lab[2];
    }

    final additionalClustersNeeded = clusterCount - startingClusterCount;
    if (additionalClustersNeeded > 0) {
      final random = math.Random(0x42688);
      final indices = <int>{};
      for (var i = 0; i < additionalClustersNeeded; i++) {
        if (indices.length >= pointCount) {
          break;
        }
        var index = random.nextInt(pointCount);
        while (indices.contains(index)) {
          index = random.nextInt(pointCount);
        }
        indices.add(index);
      }

      for (final index in indices) {
        clusterLs[startingClusterCount] = pointLs[index];
        clusterAs[startingClusterCount] = pointAs[index];
        clusterBs[startingClusterCount] = pointBs[index];
        startingClusterCount++;
      }
    }

    debugLog(
      'have $startingClusterCount starting clusters, $pointCount points',
    );

    final clusterIndices = Int32List(pointCount);
    for (var i = 0; i < pointCount; i++) {
      clusterIndices[i] = i % clusterCount;
    }

    final clusterDistanceMatrix = Float64List(clusterCount * clusterCount);
    final neighborIndexMatrix = Int32List(clusterCount * clusterCount);
    for (var i = 0; i < clusterCount; i++) {
      final rowOffset = i * clusterCount;
      for (var j = 0; j < clusterCount; j++) {
        neighborIndexMatrix[rowOffset + j] = j;
      }
    }
    final neighborDistanceMatrix = Float64List(clusterCount * clusterCount);
    final neighborLimits = Int32List(clusterCount);
    final previousDistances = Float64List(pointCount);
    final maxPreviousDistancesByCluster = Float64List(clusterCount);

    final pixelCountSums = Int32List(clusterCount);
    final componentASums = Float64List(clusterCount);
    final componentBSums = Float64List(clusterCount);
    final componentCSums = Float64List(clusterCount);
    for (var iteration = 0; iteration < maxIterations; iteration++) {
      if (debug) {
        for (var i = 0; i < clusterCount; i++) {
          pixelCountSums[i] = 0;
        }
        for (var i = 0; i < pointCount; i++) {
          final clusterIndex = clusterIndices[i];
          final count = counts[i];
          pixelCountSums[clusterIndex] += count;
        }
        var emptyClusters = 0;
        for (var cluster = 0; cluster < clusterCount; cluster++) {
          if (pixelCountSums[cluster] == 0) {
            emptyClusters++;
          }
        }
        debugLog(
          'starting iteration ${iteration + 1}; $emptyClusters clusters are empty of $clusterCount',
        );
      }

      var pointsMoved = 0;
      for (var i = 0; i < clusterCount; i++) {
        maxPreviousDistancesByCluster[i] = 0;
      }
      for (var i = 0; i < pointCount; i++) {
        final pointL = pointLs[i];
        final pointA = pointAs[i];
        final pointB = pointBs[i];
        final clusterIndex = clusterIndices[i];
        final dL = pointL - clusterLs[clusterIndex];
        final dA = pointA - clusterAs[clusterIndex];
        final dB = pointB - clusterBs[clusterIndex];
        final distance = dL * dL + dA * dA + dB * dB;
        previousDistances[i] = distance;
        if (distance > maxPreviousDistancesByCluster[clusterIndex]) {
          maxPreviousDistancesByCluster[clusterIndex] = distance;
        }
      }
      if (iteration == 0) {
        for (var i = 0; i < pointCount; i++) {
          final pointL = pointLs[i];
          final pointA = pointAs[i];
          final pointB = pointBs[i];
          final previousClusterIndex = clusterIndices[i];
          var minimumDistance = previousDistances[i];
          var newClusterIndex = -1;
          for (
            var candidateClusterIndex = 0;
            candidateClusterIndex < clusterCount;
            candidateClusterIndex++
          ) {
            if (candidateClusterIndex == previousClusterIndex) {
              continue;
            }
            final dL = pointL - clusterLs[candidateClusterIndex];
            final dA = pointA - clusterAs[candidateClusterIndex];
            final dB = pointB - clusterBs[candidateClusterIndex];
            final distance = dL * dL + dA * dA + dB * dB;
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex != -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      } else {
        for (var i = 0; i < clusterCount; i++) {
          final distanceRowOffset = i * clusterCount;
          final clusterL = clusterLs[i];
          final clusterA = clusterAs[i];
          final clusterB = clusterBs[i];
          for (var j = i + 1; j < clusterCount; j++) {
            final dL = clusterL - clusterLs[j];
            final dA = clusterA - clusterAs[j];
            final dB = clusterB - clusterBs[j];
            final distance = dL * dL + dA * dA + dB * dB;
            clusterDistanceMatrix[j * clusterCount + i] = distance;
            clusterDistanceMatrix[distanceRowOffset + j] = distance;
          }
          final neighborLimit = _partitionNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            clusterDistanceMatrix,
            distanceRowOffset,
            clusterCount,
            4 * maxPreviousDistancesByCluster[i],
          );
          neighborLimits[i] = neighborLimit;
          _sortNeighborRow(
            neighborIndexMatrix,
            neighborDistanceMatrix,
            distanceRowOffset,
            neighborLimit,
          );
        }

        for (var i = 0; i < pointCount; i++) {
          final pointL = pointLs[i];
          final pointA = pointAs[i];
          final pointB = pointBs[i];
          final previousClusterIndex = clusterIndices[i];
          final previousDistance = previousDistances[i];
          final neighborDistanceThreshold = 4 * previousDistance;
          var minimumDistance = previousDistance;
          var newClusterIndex = -1;
          final previousClusterNeighborRowOffset =
              previousClusterIndex * clusterCount;
          final neighborLimit = neighborLimits[previousClusterIndex];
          for (var j = 0; j < neighborLimit; j++) {
            final neighborOffset = previousClusterNeighborRowOffset + j;
            final candidateClusterIndex = neighborIndexMatrix[neighborOffset];
            if (neighborDistanceMatrix[neighborOffset] >=
                neighborDistanceThreshold) {
              break;
            }
            if (candidateClusterIndex == previousClusterIndex) {
              continue;
            }
            final dL = pointL - clusterLs[candidateClusterIndex];
            final dA = pointA - clusterAs[candidateClusterIndex];
            final dB = pointB - clusterBs[candidateClusterIndex];
            final distance = dL * dL + dA * dA + dB * dB;
            if (distance <= minimumDistance) {
              minimumDistance = distance;
              newClusterIndex = candidateClusterIndex;
            }
          }
          if (newClusterIndex != -1) {
            pointsMoved++;
            clusterIndices[i] = newClusterIndex;
          }
        }
      }

      if (pointsMoved == 0 && iteration > 0) {
        debugLog('terminated after $iteration k-means iterations');
        break;
      }

      debugLog('iteration ${iteration + 1} moved $pointsMoved');
      for (var i = 0; i < clusterCount; i++) {
        pixelCountSums[i] = 0;
        componentASums[i] = 0;
        componentBSums[i] = 0;
        componentCSums[i] = 0;
      }
      for (var i = 0; i < pointCount; i++) {
        final clusterIndex = clusterIndices[i];
        final count = counts[i];
        pixelCountSums[clusterIndex] += count;
        componentASums[clusterIndex] += pointLs[i] * count;
        componentBSums[clusterIndex] += pointAs[i] * count;
        componentCSums[clusterIndex] += pointBs[i] * count;
      }
      for (var i = 0; i < clusterCount; i++) {
        final count = pixelCountSums[i];
        if (count == 0) {
          clusterLs[i] = 0;
          clusterAs[i] = 0;
          clusterBs[i] = 0;
          continue;
        }
        clusterLs[i] = componentASums[i] / count;
        clusterAs[i] = componentBSums[i] / count;
        clusterBs[i] = componentCSums[i] / count;
      }
    }

    final clusterArgbs = <int>[];
    final clusterPopulations = <int>[];
    for (var i = 0; i < clusterCount; i++) {
      final count = pixelCountSums[i];
      if (count == 0) {
        continue;
      }

      final possibleNewCluster = argbFromLab(
        clusterLs[i],
        clusterAs[i],
        clusterBs[i],
      );
      if (clusterArgbs.contains(possibleNewCluster)) {
        continue;
      }

      clusterArgbs.add(possibleNewCluster);
      clusterPopulations.add(count);
    }
    debugLog(
      'kmeans finished and generated ${clusterArgbs.length} clusters; $clusterCount were requested',
    );

    final inputPixelToClusterPixel = <int, int>{};
    if (returnInputPixelToClusterPixel) {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < pointCount; i++) {
        final inputPixel = pixels[i];
        final clusterIndex = clusterIndices[i];
        final clusterPixel = argbFromLab(
          clusterLs[clusterIndex],
          clusterAs[clusterIndex],
          clusterBs[clusterIndex],
        );
        inputPixelToClusterPixel[inputPixel] = clusterPixel;
      }
      debugLog(
        'took ${stopwatch.elapsedMilliseconds} ms to create input to cluster map',
      );
    }

    return QuantizerResult(
      Map.fromIterables(clusterArgbs, clusterPopulations),
      inputPixelToClusterPixel: inputPixelToClusterPixel,
      lstarToCount: {},
    );
  }

  static void _sortNeighborRow(
    Int32List indices,
    Float64List distances,
    int rowOffset,
    int length,
  ) {
    if (length < 2) {
      return;
    }
    _quickSortNeighborRow(
      indices,
      distances,
      rowOffset,
      rowOffset + length - 1,
    );
  }

  static int _partitionNeighborRow(
    Int32List indices,
    Float64List neighborDistances,
    int neighborOffset,
    Float64List distances,
    int distanceOffset,
    int length,
    double maxDistance,
  ) {
    var limit = 0;
    for (var i = 0; i < length; i++) {
      final index = indices[neighborOffset + i];
      final distance = distances[distanceOffset + index];
      if (distance < maxDistance) {
        final writeOffset = neighborOffset + limit;
        indices[neighborOffset + i] = indices[writeOffset];
        indices[writeOffset] = index;
        neighborDistances[writeOffset] = distance;
        limit++;
      }
    }
    return limit;
  }

  static void _quickSortNeighborRow(
    Int32List indices,
    Float64List distances,
    int left,
    int right,
  ) {
    while (right - left > 16) {
      var i = left;
      var j = right;
      final pivotDistance = distances[(left + right) >> 1];

      while (i <= j) {
        while (distances[i] < pivotDistance) {
          i++;
        }
        while (distances[j] > pivotDistance) {
          j--;
        }
        if (i <= j) {
          final swapIndex = indices[i];
          indices[i] = indices[j];
          indices[j] = swapIndex;
          final swapDistance = distances[i];
          distances[i] = distances[j];
          distances[j] = swapDistance;
          i++;
          j--;
        }
      }

      if (j - left < right - i) {
        if (left < j) {
          _quickSortNeighborRow(indices, distances, left, j);
        }
        left = i;
      } else {
        if (i < right) {
          _quickSortNeighborRow(indices, distances, i, right);
        }
        right = j;
      }
    }

    for (var i = left + 1; i <= right; i++) {
      final index = indices[i];
      final distance = distances[i];
      var j = i - 1;
      while (j >= left && distances[j] > distance) {
        indices[j + 1] = indices[j];
        distances[j + 1] = distances[j];
        j--;
      }
      indices[j + 1] = index;
      distances[j + 1] = distance;
    }
  }
}
