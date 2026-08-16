import 'dart:typed_data';

import 'package:crehooni/data/models/image_features.dart';
import 'package:crehooni/data/morph_catalog.dart';
import 'package:crehooni/domain/image_analysis.dart';
import 'package:crehooni/domain/morph_scoring.dart';
import 'package:crehooni/domain/quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Builds a solid-colour test image.
///
/// PNG rather than JPEG so the pixels come back exactly as written — JPEG chroma
/// subsampling shifts channels enough to move HSL saturation noticeably on
/// near-white and near-black fills.
Uint8List solidImage(int r, int g, int b, {int size = 320}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

/// Builds an image with dark spots on a light background, like a dalmatian.
Uint8List spottedJpeg({int size = 320}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(230, 220, 190));
  final dark = img.ColorRgb8(15, 12, 10);
  for (var y = 8; y < size - 8; y += 16) {
    for (var x = 8; x < size - 8; x += 16) {
      img.fillCircle(image, x: x, y: y, radius: 3, color: dark);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('ImageAnalysis', () {
    test('returns null for bytes that are not an image', () {
      expect(ImageAnalysis.fromBytes(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });

    test('a white image reads as bright, unsaturated and spotless', () {
      final f = ImageAnalysis.fromBytes(solidImage(255, 255, 255))!;
      expect(f.white, greaterThan(0.9));
      expect(f.sat, 0);
      expect(f.spots, 0);
      expect(f.meanL, 1);
      expect(f.dark, 0);
    });

    test('a slightly tinted near-white still reads as white coverage', () {
      // HSL saturation climbs steeply near the extremes, so a faint tint reads
      // as saturated even though it looks white. The white channel is what the
      // morph signatures rely on here.
      final f = ImageAnalysis.fromBytes(solidImage(250, 248, 245))!;
      expect(f.white, greaterThan(0.9));
      expect(f.meanL, greaterThan(0.9));
    });

    test('a black image reads as dark with no white', () {
      final f = ImageAnalysis.fromBytes(solidImage(6, 6, 6))!;
      expect(f.dark, greaterThan(0.9));
      expect(f.white, 0);
      expect(f.meanL, lessThan(0.1));
    });

    test('a mid grey reads as grey, not coloured', () {
      final f = ImageAnalysis.fromBytes(solidImage(128, 128, 128))!;
      expect(f.gray, greaterThan(0.9));
      expect(f.orange, lessThan(0.05));
      expect(f.yellow, lessThan(0.05));
    });

    test('an orange image lands in the orange channel', () {
      final f = ImageAnalysis.fromBytes(solidImage(230, 120, 30))!;
      expect(f.orange, greaterThan(0.8));
      expect(f.sat, greaterThan(0.5));
    });

    test('flat colour has almost no contrast', () {
      final f = ImageAnalysis.fromBytes(solidImage(120, 90, 60))!;
      expect(f.contrast, lessThan(0.05));
    });

    test('a spotted pattern registers spot density and contrast', () {
      final f = ImageAnalysis.fromBytes(spottedJpeg())!;
      expect(f.spots, greaterThan(0.1));
      expect(f.contrast, greaterThan(0.05));
    });

    test('features are stable across runs', () {
      final bytes = spottedJpeg();
      final a = ImageAnalysis.fromBytes(bytes)!;
      final b = ImageAnalysis.fromBytes(bytes)!;
      expect(a.spots, b.spots);
      expect(a.white, b.white);
      expect(a.contrast, b.contrast);
    });

    test('a non-square photo is centre-cropped rather than squashed', () {
      // A wide frame whose centre square is mid grey: if the crop were skipped
      // and the frame squashed instead, the edge bands would dilute the result.
      final wide = img.Image(width: 600, height: 200);
      img.fill(wide, color: img.ColorRgb8(230, 90, 20));
      img.fillRect(
        wide,
        x1: 200,
        y1: 0,
        x2: 399,
        y2: 199,
        color: img.ColorRgb8(128, 128, 128),
      );
      final features = ImageAnalysis.fromImage(wide);
      expect(features.gray, greaterThan(0.9));
      expect(features.orange, lessThan(0.05));
    });
  });

  group('encodeForUpload', () {
    test('downscales an oversized photo to the requested longest edge', () {
      final encoded = ImageAnalysis.encodeForUpload(
        solidImage(200, 150, 100, size: 1600),
        maxEdge: 720,
        quality: 84,
      );
      final decoded = img.decodeImage(encoded!)!;
      expect(decoded.width, 720);
      expect(decoded.height, 720);
    });

    test('leaves an already-small photo alone', () {
      final encoded = ImageAnalysis.encodeForUpload(
        solidImage(200, 150, 100, size: 320),
        maxEdge: 720,
        quality: 84,
      );
      final decoded = img.decodeImage(encoded!)!;
      expect(decoded.width, 320);
    });

    test('returns null for undecodable bytes', () {
      expect(
        ImageAnalysis.encodeForUpload(
          Uint8List.fromList([9, 9, 9]),
          maxEdge: 720,
          quality: 84,
        ),
        isNull,
      );
    });
  });

  group('MorphScoring', () {
    test('a morph signature scores highest against itself', () {
      for (final morph in selectableMorphs) {
        final self = morph.signature!;
        final selfScore = MorphScoring.colorScore(self, morph);
        for (final other in selectableMorphs) {
          if (other.id == morph.id) continue;
          expect(
            MorphScoring.colorScore(self, other),
            lessThanOrEqualTo(selfScore + 1e-9),
            reason: '${other.id} outscored ${morph.id} on its own signature',
          );
        }
      }
    });

    test('an extra reference signature can lift that morph to the top', () {
      final features = ImageAnalysis.fromBytes(solidImage(20, 18, 16))!;
      final extra = ImageFeatures.signature(
        white: features.white,
        orange: features.orange,
        yellow: features.yellow,
        dark: features.dark,
        gray: features.gray,
        brown: features.brown,
        spots: features.spots,
        sat: features.sat,
      );
      final flame = getMorph('flame')!;
      final catalog = [
        for (final morph in selectableMorphs)
          if (morph.id == 'flame')
            morph.copyWith(extraSignatures: [extra])
          else
            morph,
      ];

      final without = MorphScoring.identifyByColor(features);
      final withExtra = MorphScoring.identifyByColor(
        features,
        catalog: catalog,
      );
      expect(withExtra.top!.morph.id, 'flame');
      expect(
        MorphScoring.colorScore(
          features,
          flame.copyWith(extraSignatures: [extra]),
        ),
        greaterThan(MorphScoring.colorScore(features, flame)),
      );
      expect(without.top?.morph.id, isNot(withExtra.top!.morph.id));
    });

    test('a grey, desaturated photo ranks axanthic-family morphs first', () {
      final features = ImageAnalysis.fromBytes(solidImage(140, 142, 145))!;
      final result = MorphScoring.identifyByColor(features);
      expect(result.matches, isNotEmpty);
      expect(
        result.matches.take(3).map((m) => m.morph.id),
        contains('axanthic'),
      );
    });

    test('confidences are percentages that sum to about 100', () {
      final features = ImageAnalysis.fromBytes(spottedJpeg())!;
      final result = MorphScoring.identifyByColor(features);
      final total = result.matches.fold<int>(0, (sum, m) => sum + m.confidence);
      expect(result.matches.length, lessThanOrEqualTo(4));
      expect(total, closeTo(100, 2));
    });

    test('CLIP similarity dominates the blended ranking', () {
      final features = ImageAnalysis.fromBytes(solidImage(250, 248, 245))!;
      final result = MorphScoring.identifyWithClip(
        features: features,
        catalog: selectableMorphs,
        clipSimilarityByMorphId: {'cappuccino': 0.95},
      );
      expect(result.top!.morph.id, 'cappuccino');
      expect(result.source, IdentificationSource.clip);
    });

    test(
      'cosine similarity is 1 for identical vectors and 0 for orthogonal',
      () {
        expect(MorphScoring.cosine([1, 0, 0], [1, 0, 0]), closeTo(1, 1e-6));
        expect(MorphScoring.cosine([1, 0, 0], [0, 1, 0]), closeTo(0, 1e-6));
        expect(MorphScoring.cosine([1, 2, 3], [2, 4, 6]), closeTo(1, 1e-6));
      },
    );
  });

  group('QualityGrading', () {
    test('a flat, blown-out photo grades poorly', () {
      final features = ImageAnalysis.fromBytes(solidImage(253, 253, 253))!;
      final grade = QualityGrading.grade(features, getMorph('harlequin'));
      expect(grade.rank, QualityRank.c);
      expect(grade.score, inInclusiveRange(8, 43));
    });

    test('scores stay inside the documented 8–98 range', () {
      for (final bytes in [
        solidImage(0, 0, 0),
        solidImage(255, 255, 255),
        solidImage(230, 120, 30),
        spottedJpeg(),
      ]) {
        final grade = QualityGrading.grade(
          ImageAnalysis.fromBytes(bytes)!,
          null,
        );
        expect(grade.score, inInclusiveRange(8, 98));
      }
    });

    test('price scales with rank and rounds to man-won', () {
      final morph = getMorph('lilly-white')!;
      final low = QualityGrading.estimate(
        morph,
        const QualityGrade(score: 20, rank: QualityRank.c, reasons: []),
      );
      final high = QualityGrading.estimate(
        morph,
        const QualityGrade(score: 90, rank: QualityRank.s, reasons: []),
      );
      expect(high.min, greaterThan(low.min));
      expect(high.max, greaterThan(low.max));
      expect(low.min % 10000, 0);
      expect(high.max % 10000, 0);
    });

    test('an unknown morph falls back to the default price band', () {
      final estimate = QualityGrading.estimate(
        null,
        const QualityGrade(score: 50, rank: QualityRank.b, reasons: []),
      );
      expect(estimate.min, greaterThan(0));
      expect(estimate.mid, inInclusiveRange(estimate.min, estimate.max));
    });
  });

  group('won formatting', () {
    test('formatWon groups thousands', () {
      expect(formatWon(1250000), '1,250,000원');
      expect(formatWon(0), '0원');
      expect(formatWon(999), '999원');
    });

    test('formatWonShort uses Korean 만/억 units', () {
      expect(formatWonShort(1250000), '125만원');
      expect(formatWonShort(250000), '25만원');
      expect(formatWonShort(120000000), '1.2억원');
      expect(formatWonShort(5000), '5,000원');
    });
  });
}
