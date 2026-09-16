/// Color appearance model used by HCT/theming materialization.
enum ColorModel {
  /// Legacy CAM16 behavior retained for compatibility.
  cam16,

  /// Hellwig/Fairchild 2022 CAM16 revision.
  cam16v11,

  /// Oklab polar hue/chroma, with libmonet L* retained as tone.
  oklch;

  static const kDefault = cam16v11;

  /// Low-chroma canvas tint in native model units. OKLCH uses fractional
  /// chroma, not CAM16's tens. This is a design cap, not a unit conversion or
  /// a claim of identical appearance between models.
  double get neutralBackgroundChroma => switch (this) {
    cam16 || cam16v11 => 16,
    oklch => 0.04,
  };

  String get label {
    return switch (this) {
      ColorModel.cam16 => 'CAM16',
      ColorModel.cam16v11 => 'CAM16 v1.1',
      ColorModel.oklch => 'OKLCH',
    };
  }
}
