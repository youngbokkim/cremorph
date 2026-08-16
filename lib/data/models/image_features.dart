/// Colour/texture fingerprint of a photo.
///
/// Ported from the object returned by `analyzePixels()` in `js/engine.js`. The
/// first eight fields make up a morph "signature" and are what
/// `MorphScorer.score` compares; [contrast], [meanL] and [sharp] are only used
/// for quality grading.
class ImageFeatures {
  const ImageFeatures({
    required this.white,
    required this.orange,
    required this.yellow,
    required this.dark,
    required this.gray,
    required this.brown,
    required this.spots,
    required this.sat,
    this.contrast = 0,
    this.meanL = 0,
    this.sharp = 0,
  });

  /// Compact constructor for the hardcoded catalog signatures, which only carry
  /// the eight comparison fields.
  const ImageFeatures.signature({
    required this.white,
    required this.orange,
    required this.yellow,
    required this.dark,
    required this.gray,
    required this.brown,
    required this.spots,
    required this.sat,
  }) : contrast = 0,
       meanL = 0,
       sharp = 0;

  final double white;
  final double orange;
  final double yellow;
  final double dark;
  final double gray;
  final double brown;

  /// Density of dark spots surrounded by lighter pixels, 0–1.
  final double spots;

  /// Mean HSL saturation.
  final double sat;

  /// Standard deviation of lightness.
  final double contrast;

  /// Mean lightness.
  final double meanL;

  /// Horizontal gradient energy, a rough focus/detail measure.
  final double sharp;

  Map<String, double> toJson() => {
    'white': white,
    'orange': orange,
    'yellow': yellow,
    'dark': dark,
    'gray': gray,
    'brown': brown,
    'spots': spots,
    'sat': sat,
    'contrast': contrast,
    'meanL': meanL,
    'sharp': sharp,
  };

  static ImageFeatures? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    double read(String key) => (json[key] as num?)?.toDouble() ?? 0;
    return ImageFeatures(
      white: read('white'),
      orange: read('orange'),
      yellow: read('yellow'),
      dark: read('dark'),
      gray: read('gray'),
      brown: read('brown'),
      spots: read('spots'),
      sat: read('sat'),
      contrast: read('contrast'),
      meanL: read('meanL'),
      sharp: read('sharp'),
    );
  }
}
