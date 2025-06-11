// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/extract/quantizer_wsmeans.dart';
import 'package:libmonet/extract/quantizer_wsmeans_opt.dart';
import 'package:libmonet/extract/point_provider.dart';
import 'package:libmonet/extract/point_provider_lab.dart';
import 'package:libmonet/argb_srgb_xyz_lab.dart';
import '../perf/perf_tester.dart';

class QuantizerTestCase {
  final List<int> pixels;
  final int maxColors;
  final PointProvider pointProvider;
  final String description;
  
  QuantizerTestCase({
    required this.pixels,
    required this.maxColors,
    required this.pointProvider,
    required this.description,
  });
  
  @override
  String toString() => description;
}

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  print('Loading test images...');
  
  // Load test images using imageProviderToScaledRgba
  final testImages = <String, List<int>>{};
  final dataDir = Directory('/Users/jpo/dev/libmonet/test/data');
  
  for (final file in dataDir.listSync()) {
    if (file is File && file.path.endsWith('.png')) {
      final fileName = file.path.split('/').last;
      try {
        final imageProvider = FileImage(file);
        final byteData = await imageProviderToScaledRgba(imageProvider, 512); // Scale to reasonable size
        
        if (byteData.lengthInBytes > 0) {
          final bytes = byteData.buffer.asUint32List();
          final argbPixels = bytes
              .map(rgbaToArgb)
              .where((e) => alphaFromArgb(e) == 255) // Filter out transparent pixels like Extract.quantize does
              .toList();
          
          testImages[fileName] = argbPixels;
          final totalPixelCount = byteData.lengthInBytes ~/ 4; // 4 bytes per RGBA pixel
          print('Loaded $fileName: ${argbPixels.length} opaque pixels (from $totalPixelCount total)');
        }
      } catch (e) {
        print('Failed to load $fileName: $e');
      }
    }
  }
  
  if (testImages.isEmpty) {
    print('No test images found! Make sure PNG files exist in /Users/jpo/dev/libmonet/test/data');
    return;
  }
  
  // Create test cases with different parameters
  final testCases = <QuantizerTestCase>[];
  final pointProvider = PointProviderLab();
  
  // Test different color counts and images
  final colorCounts = [16, 32, 64, 128];
  
  for (final entry in testImages.entries) {
    final imageName = entry.key;
    final pixels = entry.value;
    
    // // Skip very large images to keep test reasonable
    // if (pixels.length > 100000) {
    //   print('Skipping $imageName (too large: ${pixels.length} pixels)');
    //   continue;
    // }
    
    for (final colorCount in colorCounts) {
      testCases.add(QuantizerTestCase(
        pixels: pixels,
        maxColors: colorCount,
        pointProvider: pointProvider,
        description: '$imageName-${colorCount}colors',
      ));
    }
  }
  
  print('Created ${testCases.length} test cases');
  
  // Define the implementations
  QuantizerResult? runOriginal(QuantizerTestCase testCase) {
    try {
      return QuantizerWsmeans.quantize(
        testCase.pixels,
        testCase.maxColors,
        pointProvider: testCase.pointProvider,
        maxIterations: 5,
      );
    } catch (e) {
      print('Original failed on ${testCase.description}: $e');
      return null;
    }
  }
  
  QuantizerResult? runOptimized(QuantizerTestCase testCase) {
    try {
      return QuantizerWsmeansOpt.quantize(
        testCase.pixels,
        testCase.maxColors,
        pointProvider: testCase.pointProvider,
        maxIterations: 5,
      );
    } catch (e) {
      print('Optimized failed on ${testCase.description}: $e');
      return null;
    }
  }
  
  // Custom equality check for QuantizerResult
  bool compareResults(QuantizerResult? result1, QuantizerResult? result2) {
    if (result1 == null || result2 == null) {
      return result1 == result2;
    }
    
    // Compare the color palettes
    final palette1 = result1.argbToCount;
    final palette2 = result2.argbToCount;
    
    if (palette1.length != palette2.length) {
      return false;
    }
    
    // Sort by color value for consistent comparison
    final sortedKeys1 = palette1.keys.toList()..sort();
    final sortedKeys2 = palette2.keys.toList()..sort();
    
    for (int i = 0; i < sortedKeys1.length; i++) {
      if (sortedKeys1[i] != sortedKeys2[i]) {
        return false;
      }
      if (palette1[sortedKeys1[i]] != palette2[sortedKeys2[i]]) {
        return false;
      }
    }
    
    return true;
  }
  
  // Run the performance test
  final perfTester = PerfTester<QuantizerTestCase, QuantizerResult?>(
    testName: 'WSMeans Quantizer Performance',
    testCases: testCases,
    implementation1: runOriginal,
    implementation2: runOptimized,
    impl1Name: 'Original WSMeans',
    impl2Name: 'Optimized WSMeans',
    equalityCheck: compareResults,
  );
  
  print('\nRunning performance comparison...');
  perfTester.run(
    warmupRuns: 5,
    benchmarkRuns: 10,
    skipEqualityCheck: false,
  );
  
  // Additional analysis
  print('\n=== Additional Analysis ===');
  
  // Test with a larger image if available
  final largerImage = testImages.entries
      .where((e) => e.value.length > 50000 && e.value.length <= 200000)
      .firstOrNull;
      
  if (largerImage != null) {
    print('\nTesting with larger image: ${largerImage.key} (${largerImage.value.length} pixels)');
    
    final largeTestCases = [
      QuantizerTestCase(
        pixels: largerImage.value,
        maxColors: 64,
        pointProvider: pointProvider,
        description: '${largerImage.key}-64colors-large',
      ),
      QuantizerTestCase(
        pixels: largerImage.value,
        maxColors: 128,
        pointProvider: pointProvider,
        description: '${largerImage.key}-128colors-large',
      ),
    ];
    
    final largePerfTester = PerfTester<QuantizerTestCase, QuantizerResult?>(
      testName: 'Large Image Test',
      testCases: largeTestCases,
      implementation1: runOriginal,
      implementation2: runOptimized,
      impl1Name: 'Original WSMeans',
      impl2Name: 'Optimized WSMeans',
      equalityCheck: compareResults,
    );
    
    largePerfTester.run(
      warmupRuns: 10,
      benchmarkRuns: 20,
      skipEqualityCheck: true, // Skip equality check for large images to save time
    );
  }
  
  // Memory usage estimation
  print('\n=== Memory Usage Estimation ===');
  final testCase = testCases.first;
  final uniquePixels = testCase.pixels.toSet().length;
  final clusters = testCase.maxColors;
  
  print('Test case: ${testCase.description}');
  print('Total pixels: ${testCase.pixels.length}');
  print('Unique pixels: $uniquePixels');
  print('Clusters: $clusters');
  
  // Estimate memory usage for original vs optimized
  final originalMemory = calculateOriginalMemoryUsage(uniquePixels, clusters);
  final optimizedMemory = calculateOptimizedMemoryUsage(uniquePixels, clusters);
  
  print('\nEstimated memory usage:');
  print('Original: ${(originalMemory / 1024).toStringAsFixed(1)} KB');
  print('Optimized: ${(optimizedMemory / 1024).toStringAsFixed(1)} KB');
  print('Memory saved: ${((originalMemory - optimizedMemory) / 1024).toStringAsFixed(1)} KB (${((originalMemory - optimizedMemory) / originalMemory * 100).toStringAsFixed(1)}%)');
}

int calculateOriginalMemoryUsage(int uniquePixels, int clusters) {
  // Major data structures in original:
  // - indexMatrix: clusters * clusters * 4 bytes (int)
  // - distanceToIndexMatrix: clusters * clusters * 16 bytes (DistanceAndIndex object)
  // - points: uniquePixels * 3 * 8 bytes (List<double>)
  // - clusters: clusters * 3 * 8 bytes (List<double>)
  // - clusterIndices: uniquePixels * 4 bytes (int)
  // - various sums arrays: clusters * 8 bytes (double) * 3
  
  int memory = 0;
  memory += clusters * clusters * 4; // indexMatrix
  memory += clusters * clusters * 16; // distanceToIndexMatrix
  memory += uniquePixels * 3 * 8; // points
  memory += clusters * 3 * 8; // clusters
  memory += uniquePixels * 4; // clusterIndices
  memory += clusters * 8 * 3; // sum arrays
  
  return memory;
}

int calculateOptimizedMemoryUsage(int uniquePixels, int clusters) {
  // Major data structures in optimized:
  // - distanceMatrix: clusters * clusters * 8 bytes (Float64List)
  // - distanceToIndexMatrix: clusters * clusters * 16 bytes (DistanceAndIndex object)
  // - points: uniquePixels * 3 * 8 bytes (List<double>)
  // - clusters: clusters * 3 * 8 bytes (List<double>)
  // - clusterIndices: uniquePixels * 4 bytes (int)
  // - previousDistances: uniquePixels * 8 bytes (Float64List)
  // - clusterMoved: clusters * 1 byte (bool)
  // - various sums arrays: clusters * 8 bytes (double) * 3
  // NOTE: No indexMatrix (removed)
  
  int memory = 0;
  memory += clusters * clusters * 8; // distanceMatrix (Float64List)
  memory += clusters * clusters * 16; // distanceToIndexMatrix
  memory += uniquePixels * 3 * 8; // points
  memory += clusters * 3 * 8; // clusters
  memory += uniquePixels * 4; // clusterIndices
  memory += uniquePixels * 8; // previousDistances
  memory += clusters * 1; // clusterMoved
  memory += clusters * 8 * 3; // sum arrays
  
  return memory;
}

// Helper functions from extract.dart
int rgbaToArgb(int rgba) {
  int r = (rgba >> 0) & 0xFF;
  int g = (rgba >> 8) & 0xFF;
  int b = (rgba >> 16) & 0xFF;
  int a = (rgba >> 24) & 0xFF;

  return (a << 24) | (r << 16) | (g << 8) | b;
}

// Copy of imageProviderToScaledRgba function from extract.dart
Future<ByteData> imageProviderToScaledRgba(
    ImageProvider imageProvider, double maxDimension) {
  final stream = imageProvider
      .resolve(ImageConfiguration(size: Size(maxDimension, maxDimension)));
  late ImageStreamListener listener;
  final completer = Completer<ByteData>();
  listener = ImageStreamListener((frame, sync) async {
    try {
      stream.removeListener(listener);
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      var paintWidth = width.toDouble();
      var paintHeight = height.toDouble();
      final rescale = width > maxDimension || height > maxDimension;
      if (rescale) {
        paintWidth =
            (width > height) ? maxDimension : (maxDimension / height) * width;
        paintHeight =
            (height > width) ? maxDimension : (maxDimension / width) * height;
      }
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      paintImage(
          canvas: canvas,
          rect: Rect.fromLTRB(0, 0, paintWidth, paintHeight),
          image: image,
          filterQuality: FilterQuality.none);
      final picture = pictureRecorder.endRecording();
      final scaledImage =
          await picture.toImage(paintWidth.toInt(), paintHeight.toInt());
      final byteData = await scaledImage.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba);
      completer.complete(byteData);
    } catch (e, stack) {
      debugPrint('error scaling image: $e, $stack');
      completer.completeError('Failed to scale image. Error receieved: $e');
    }
  });
  stream.addListener(listener);
  return completer.future;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => this.isEmpty ? null : first;
}