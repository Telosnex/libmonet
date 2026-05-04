/// Color interpolation strategy used while animating libmonet palettes.
enum InterpolationStyle {
  /// Interpolate hue/chroma/tone as polar coordinates.
  ///
  /// Hue follows the shortest path around the color wheel while chroma and tone
  /// are interpolated linearly.
  polar,

  /// Interpolate in the cartesian UCS coordinates for the active color model.
  ///
  /// This allows hue and chroma to shift naturally through the perceptual color
  /// space instead of forcing a shortest-path hue rotation.
  cartesian,
}
