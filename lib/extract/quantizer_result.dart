import 'package:json_annotation/json_annotation.dart';
part 'quantizer_result.g.dart';

@JsonSerializable(anyMap: true)
class QuantizerResult {
  final Map<int, int> argbToCount;
  final Map<int, int> inputPixelToClusterPixel;
  final Map<int, int> lstarToCount;
  const QuantizerResult(
    this.argbToCount, {
    this.inputPixelToClusterPixel = const {},
    required this.lstarToCount,
  });

  factory QuantizerResult.fromJson(Map json) => _$QuantizerResultFromJson(json);

  Map toJson() => _$QuantizerResultToJson(this);
}
