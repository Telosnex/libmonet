// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quantizer_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuantizerResult _$QuantizerResultFromJson(Map json) => QuantizerResult(
      (json['argbToCount'] as Map).map(
        (k, e) => MapEntry(int.parse(k as String), (e as num).toInt()),
      ),
      inputPixelToClusterPixel: (json['inputPixelToClusterPixel'] as Map?)?.map(
            (k, e) => MapEntry(int.parse(k as String), (e as num).toInt()),
          ) ??
          const {},
      lstarToCount: (json['lstarToCount'] as Map).map(
        (k, e) => MapEntry(int.parse(k as String), (e as num).toInt()),
      ),
    );

Map<String, dynamic> _$QuantizerResultToJson(QuantizerResult instance) =>
    <String, dynamic>{
      'argbToCount':
          instance.argbToCount.map((k, e) => MapEntry(k.toString(), e)),
      'inputPixelToClusterPixel': instance.inputPixelToClusterPixel
          .map((k, e) => MapEntry(k.toString(), e)),
      'lstarToCount':
          instance.lstarToCount.map((k, e) => MapEntry(k.toString(), e)),
    };
