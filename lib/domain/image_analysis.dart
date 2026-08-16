import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../data/models/image_features.dart';

/// On-device colour/pattern analysis, ported from `analyzePixels()` in
/// `js/engine.js`.
///
/// The web version drew the photo into a 160×160 canvas and read the pixels
/// back; here `package:image` does the decode and resize so the same maths runs
/// identically on iOS, Android and web.
abstract final class ImageAnalysis {
  /// Working resolution. Must stay 160 to keep the hardcoded catalog signatures
  /// comparable.
  static const _size = 160;

  /// Pixels trimmed from each edge, so background corners bias the result less.
  static const _margin = 18;

  /// Decodes [bytes] and extracts its feature vector. Returns null when the
  /// bytes are not a readable image.
  static ImageFeatures? fromBytes(Uint8List bytes) {
    final decoded = _decode(bytes);
    if (decoded == null) return null;
    return fromImage(decoded);
  }

  /// `decodeImage` probes each format in turn and can throw — not just return
  /// null — on truncated or malformed input, so failures are contained here.
  static img.Image? _decode(Uint8List bytes) {
    try {
      return img.decodeImage(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Extracts features from an already-decoded image.
  static ImageFeatures fromImage(img.Image source) {
    // Center-crop to a square first so a wide photo is not squashed, matching
    // how the browser canvas was fed.
    final side = math.min(source.width, source.height);
    final square = img.copyCrop(
      source,
      x: (source.width - side) ~/ 2,
      y: (source.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final small = img.copyResize(
      square,
      width: _size,
      height: _size,
      interpolation: img.Interpolation.average,
    );
    return _analyze(small);
  }

  static ImageFeatures _analyze(img.Image image) {
    var white = 0.0;
    var orange = 0.0;
    var yellow = 0.0;
    var dark = 0.0;
    var gray = 0.0;
    var brown = 0.0;
    var satSum = 0.0;
    var lSum = 0.0;
    var lSq = 0.0;
    var n = 0;

    // Cache lightness per pixel; the spot pass below reads neighbours.
    final lightness = Float32List(_size * _size);
    for (var y = 0; y < _size; y++) {
      for (var x = 0; x < _size; x++) {
        final p = image.getPixel(x, y);
        lightness[y * _size + x] = _lightness(
          p.r.toDouble(),
          p.g.toDouble(),
          p.b.toDouble(),
        );
      }
    }

    for (var y = _margin; y < _size - _margin; y++) {
      for (var x = _margin; x < _size - _margin; x++) {
        final p = image.getPixel(x, y);
        final hsl = _rgbToHsl(p.r.toDouble(), p.g.toDouble(), p.b.toDouble());
        final h = hsl.h;
        final s = hsl.s;
        final l = hsl.l;

        n += 1;
        satSum += s;
        lSum += l;
        lSq += l * l;

        if (l < 0.16) dark += 1;
        if (s < 0.18 && l > 0.2 && l < 0.75) gray += 1;

        if (l > 0.72 && s < 0.35) {
          white += 1;
        } else if (l > 0.62 && s >= 0.2 && h >= 30 && h <= 70) {
          white += 0.6;
        }

        if (s > 0.28 && l > 0.22 && l < 0.75) {
          if (h < 28 || h > 345) orange += 0.5;
          if (h >= 18 && h < 42) orange += 1;
          if (h >= 42 && h < 72) yellow += 1;
          if (h >= 18 && h < 50 && l < 0.45) brown += 1;
          if (h >= 20 && h < 55 && s < 0.55 && l < 0.5) brown += 0.6;
        }
      }
    }

    // Dalmatian spots: dark pixels ringed by clearly lighter neighbours.
    var spots = 0;
    for (var y = _margin + 1; y < _size - _margin - 1; y += 2) {
      for (var x = _margin + 1; x < _size - _margin - 1; x += 2) {
        if (lightness[y * _size + x] > 0.22) continue;
        var lightNeighbours = 0;
        const offsets = [(0, 2), (0, -2), (2, 0), (-2, 0)];
        for (final (dx, dy) in offsets) {
          if (lightness[(y + dy) * _size + (x + dx)] > 0.42) {
            lightNeighbours += 1;
          }
        }
        if (lightNeighbours >= 3) spots += 1;
      }
    }

    // Horizontal gradient energy on the red channel as a focus proxy.
    var sharp = 0.0;
    for (var y = 1; y < _size - 1; y += 3) {
      for (var x = 1; x < _size - 1; x += 3) {
        sharp += (image.getPixel(x, y).r - image.getPixel(x - 1, y).r).abs();
      }
    }

    final meanL = lSum / n;
    final variance = lSq / n - meanL * meanL;

    return ImageFeatures(
      white: white / n,
      orange: orange / n,
      yellow: yellow / n,
      dark: dark / n,
      gray: gray / n,
      brown: brown / n,
      spots: math.min(1, spots / 90),
      sat: satSum / n,
      contrast: math.sqrt(math.max(variance, 0)),
      meanL: meanL,
      sharp: math.min(1, sharp / 180000),
    );
  }

  static double _lightness(double r, double g, double b) {
    final rn = r / 255;
    final gn = g / 255;
    final bn = b / 255;
    return (math.max(rn, math.max(gn, bn)) + math.min(rn, math.min(gn, bn))) /
        2;
  }

  /// Ported from `rgbToHsl()`. Hue in degrees, saturation and lightness 0–1.
  static ({double h, double s, double l}) _rgbToHsl(
    double r255,
    double g255,
    double b255,
  ) {
    final r = r255 / 255;
    final g = g255 / 255;
    final b = b255 / 255;
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final l = (max + min) / 2;
    final d = max - min;
    final s = d == 0 ? 0.0 : d / (1 - (2 * l - 1).abs());

    var h = 0.0;
    if (d != 0) {
      if (max == r) {
        h = ((g - b) / d) % 6;
      } else if (max == g) {
        h = (b - r) / d + 2;
      } else {
        h = (r - g) / d + 4;
      }
      h *= 60;
      if (h < 0) h += 360;
    }
    return (h: h, s: s, l: l);
  }

  /// Downscales and re-encodes a photo as JPEG for upload, matching
  /// `fileToDataUrl(file, maxSize)` in `js/library.js`.
  static Uint8List? encodeForUpload(
    Uint8List bytes, {
    required int maxEdge,
    required int quality,
  }) {
    final decoded = _decode(bytes);
    if (decoded == null) return null;
    final longest = math.max(decoded.width, decoded.height);
    final resized = longest <= maxEdge
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxEdge : null,
            height: decoded.height > decoded.width ? maxEdge : null,
            interpolation: img.Interpolation.average,
          );
    return img.encodeJpg(resized, quality: quality);
  }
}
