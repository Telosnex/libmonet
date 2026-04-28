import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/colorspaces/color_model.dart';
import 'package:libmonet/contrast/contrast.dart';
import 'package:libmonet/extract/quantizer_result.dart';
import 'package:libmonet/theming/monet_theme_data.dart';

final monetThemeDataProvider =
    Provider.family<MonetThemeData, MonetThemeDataRequest>((ref, request) {
  final quantizerResult = request.quantizerResult;
  if (quantizerResult != null) {
    return MonetThemeData.fromQuantizerResult(
      brightness: request.brightness,
      backgroundTone: request.backgroundTone,
      quantizerResult: quantizerResult,
      contrast: request.contrast,
      algo: request.algo,
      colorModel: request.colorModel,
      scale: request.scale,
    );
  }

  return MonetThemeData.fromColor(
    brightness: request.brightness,
    backgroundTone: request.backgroundTone,
    color: request.seedColor,
    contrast: request.contrast,
    algo: request.algo,
    colorModel: request.colorModel,
    scale: request.scale,
  );
});

@immutable
class MonetThemeDataRequest {
  const MonetThemeDataRequest({
    required this.brightness,
    required this.backgroundTone,
    required this.seedColor,
    required this.contrast,
    required this.algo,
    required this.scale,
    this.quantizerResult,
    this.colorModel = ColorModel.kDefault,
  });

  final Brightness brightness;
  final double backgroundTone;
  final Color seedColor;
  final QuantizerResult? quantizerResult;
  final double contrast;
  final Algo algo;
  final double scale;
  final ColorModel colorModel;

  MonetThemeDataRequest copyWith({
    Brightness? brightness,
    double? backgroundTone,
    Color? seedColor,
    QuantizerResult? quantizerResult,
    bool clearQuantizerResult = false,
    double? contrast,
    Algo? algo,
    double? scale,
    ColorModel? colorModel,
  }) {
    return MonetThemeDataRequest(
      brightness: brightness ?? this.brightness,
      backgroundTone: backgroundTone ?? this.backgroundTone,
      seedColor: seedColor ?? this.seedColor,
      quantizerResult:
          clearQuantizerResult ? null : quantizerResult ?? this.quantizerResult,
      contrast: contrast ?? this.contrast,
      algo: algo ?? this.algo,
      scale: scale ?? this.scale,
      colorModel: colorModel ?? this.colorModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MonetThemeDataRequest &&
            brightness == other.brightness &&
            backgroundTone == other.backgroundTone &&
            seedColor == other.seedColor &&
            quantizerResult == other.quantizerResult &&
            contrast == other.contrast &&
            algo == other.algo &&
            scale == other.scale &&
            colorModel == other.colorModel;
  }

  @override
  int get hashCode => Object.hash(
        brightness,
        backgroundTone,
        seedColor,
        quantizerResult,
        contrast,
        algo,
        scale,
        colorModel,
      );
}
