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

import 'package:libmonet/extract/quantizer_result.dart';

import 'quantizer.dart';
import 'quantizer_wsmeans.dart';
import 'quantizer_wu.dart';
import 'point_provider_lab.dart';

class QuantizerCelebi implements Quantizer {
  @override
  Future<QuantizerResult> quantize(
    Iterable<int> pixels,
    int maxColors, {
    bool returnInputPixelToClusterPixel = false,
  }) async {
    final wu = QuantizerWu();
    final wuResult = await wu.quantize(pixels, maxColors);
    final wsmeansResult = QuantizerWsmeans.quantize(
      pixels,
      maxColors,
      startingClusters: wuResult.argbToCount.keys.toList(),
      pointProvider: const PointProviderLab(),
      returnInputPixelToClusterPixel: returnInputPixelToClusterPixel,
    );
    return QuantizerResult(
      wsmeansResult.argbToCount,
      lstarToCount: wuResult.lstarToCount,
    );
  }
}
