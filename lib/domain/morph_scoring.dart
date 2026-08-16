import 'dart:math' as math;

import '../data/models/image_features.dart';
import '../data/models/morph.dart';
import '../data/morph_catalog.dart';

/// One candidate morph with its similarity breakdown.
class MorphMatch {
  const MorphMatch({
    required this.morph,
    required this.score,
    this.clipSimilarity,
    this.colorSimilarity = 0,
    this.confidence = 0,
  });

  final Morph morph;

  /// Combined score the ranking is based on.
  final double score;

  /// Cosine similarity against CLIP embeddings, when the server ranked this.
  final double? clipSimilarity;

  /// Colour-signature similarity, always available.
  final double colorSimilarity;

  /// Share of the top-4 total, shown as a percentage bar.
  final int confidence;

  MorphMatch withConfidence(int value) => MorphMatch(
    morph: morph,
    score: score,
    clipSimilarity: clipSimilarity,
    colorSimilarity: colorSimilarity,
    confidence: value,
  );
}

/// Where an identification result came from.
enum IdentificationSource {
  /// Server-side CLIP embeddings re-ranked the candidates.
  clip,

  /// On-device colour signature only.
  color,
}

/// The full outcome of identifying a photo.
class IdentificationResult {
  const IdentificationResult({
    required this.matches,
    required this.source,
    required this.features,
    required this.lowConfidence,
    this.note,
  });

  /// Top candidates, best first (at most four).
  final List<MorphMatch> matches;
  final IdentificationSource source;
  final ImageFeatures features;

  /// The result is too ambiguous to state confidently.
  final bool lowConfidence;

  /// Why CLIP was skipped, when it was.
  final String? note;

  MorphMatch? get top => matches.isEmpty ? null : matches.first;

  List<MorphMatch> get alternatives =>
      matches.length <= 1 ? const [] : matches.sublist(1);
}

/// Similarity scoring between a photo and the morph catalog.
abstract final class MorphScoring {
  /// How many candidates to surface.
  static const _topN = 4;

  /// Weighted distance between a photo's features and a morph's signature.
  /// Ported from `morphScore()` in `js/engine.js`.
  ///
  /// Weights emphasise the channels that actually separate crested gecko
  /// morphs: spot density, grey (axanthic) and white coverage.
  static double colorScore(ImageFeatures f, Morph morph) {
    var best = _scoreAgainst(f, morph.signature);
    for (final extra in morph.extraSignatures) {
      final score = _scoreAgainst(f, extra);
      if (score > best) best = score;
    }
    return best;
  }

  static double _scoreAgainst(ImageFeatures f, ImageFeatures? s) {
    if (s == null) return 0;
    final dist =
        math.pow(f.white - s.white, 2) * 1.4 +
        math.pow(f.orange - s.orange, 2) * 1.3 +
        math.pow(f.yellow - s.yellow, 2) * 1.2 +
        math.pow(f.dark - s.dark, 2) * 1.1 +
        math.pow(f.gray - s.gray, 2) * 1.5 +
        math.pow(f.brown - s.brown, 2) +
        math.pow(f.spots - s.spots, 2) * 1.6 +
        math.pow(f.sat - s.sat, 2);
    return math.max(0, 1 - math.sqrt(dist) * 1.15);
  }

  /// Colour-only identification against [catalog].
  /// Ported from `identifyMorph()` in `js/engine.js`.
  static IdentificationResult identifyByColor(
    ImageFeatures features, {
    List<Morph>? catalog,
    String? note,
  }) {
    final pool = (catalog ?? selectableMorphs)
        .where((m) => m.signature != null || m.extraSignatures.isNotEmpty)
        .toList();

    final scored =
        pool
            .map(
              (m) => MorphMatch(
                morph: m,
                score: colorScore(features, m),
                colorSimilarity: colorScore(features, m),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    final best = scored.isEmpty ? 0.0 : scored.first.score;
    return IdentificationResult(
      matches: _rank(scored),
      source: IdentificationSource.color,
      features: features,
      lowConfidence: best < 0.42,
      note: note,
    );
  }

  /// Blends server CLIP similarity with the on-device colour score.
  ///
  /// The 0.82 / 0.18 split is carried over from `identifyImage()` in
  /// `js/vision.js`: CLIP dominates, colour breaks ties.
  static IdentificationResult identifyWithClip({
    required ImageFeatures features,
    required List<Morph> catalog,
    required Map<String, double> clipSimilarityByMorphId,
  }) {
    final scored = catalog.map((m) {
      final clip = clipSimilarityByMorphId[m.id] ?? 0;
      final color = colorScore(features, m);
      return MorphMatch(
        morph: m,
        score: clip * 0.82 + color * 0.18,
        clipSimilarity: clip,
        colorSimilarity: color,
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));

    final ranked = _rank(scored);
    final gap = ranked.length >= 2
        ? ranked[0].score - ranked[1].score
        : ranked.isEmpty
        ? 0.0
        : 1.0;
    final topClip = ranked.isEmpty ? 0.0 : (ranked.first.clipSimilarity ?? 0);

    return IdentificationResult(
      matches: ranked,
      source: IdentificationSource.clip,
      features: features,
      lowConfidence: gap < 0.012 || topClip < 0.18,
    );
  }

  /// Trims to the top four and turns raw scores into percentages that sum to
  /// 100. Ported from `packResult()` in `js/vision.js`.
  static List<MorphMatch> _rank(List<MorphMatch> sorted) {
    final list = sorted.take(_topN).toList();
    if (list.isEmpty) return const [];
    final total = list.fold<double>(
      0,
      (sum, m) => sum + math.max(m.score, 0.001),
    );
    return list
        .map(
          (m) =>
              m.withConfidence(((math.max(m.score, 0) / total) * 100).round()),
        )
        .toList();
  }

  /// Cosine similarity between two embeddings. Ported from `cosine()`.
  static double cosine(List<double> a, List<double> b) {
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    final n = math.min(a.length, b.length);
    for (var i = 0; i < n; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    return dot / (math.sqrt(na) * math.sqrt(nb) + 1e-8);
  }
}
