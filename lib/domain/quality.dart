import 'dart:math' as math;

import '../data/models/image_features.dart';
import '../data/models/morph.dart';

/// Quality tier, matching the `.stamp.s/.a/.b/.c` styles in `css/app.css`.
enum QualityRank {
  s('매우 좋음'),
  a('좋음'),
  b('보통'),
  c('안좋음');

  const QualityRank(this.labelKo);

  final String labelKo;
}

/// A graded quality assessment of a photographed animal.
class QualityGrade {
  const QualityGrade({
    required this.score,
    required this.rank,
    required this.reasons,
  });

  /// 8–98.
  final int score;
  final QualityRank rank;

  /// Human-readable justifications shown under the stamp.
  final List<String> reasons;

  String get labelKo => rank.labelKo;
}

/// An estimated Korean market price range in won.
class PriceEstimate {
  const PriceEstimate({
    required this.min,
    required this.max,
    required this.mid,
    required this.note,
  });

  final int min;
  final int max;
  final int mid;
  final String note;
}

/// Quality grading and price estimation, ported from `gradeQuality()`,
/// `estimatePrice()` and `formatWon()` in `js/engine.js`.
///
/// These judge the *photo* as much as the animal — contrast, saturation and
/// focus all feed the score — so the UI presents them as a rough guide only.
abstract final class QualityGrading {
  /// Price multipliers per rank.
  static const _multipliers = <QualityRank, (double, double)>{
    QualityRank.s: (1.8, 3.2),
    QualityRank.a: (1.15, 1.85),
    QualityRank.b: (0.75, 1.15),
    QualityRank.c: (0.4, 0.7),
  };

  static QualityGrade grade(ImageFeatures f, Morph? morph) {
    var score = 40.0;
    score += f.contrast * 90;
    score += f.sat * 35;
    score += f.sharp * 25;

    // Morph-specific bonuses: the traits that actually set price for that morph.
    switch (morph?.id) {
      case 'dalmatian':
      case 'super-dalmatian':
        score += f.spots * 30;
      case 'harlequin':
      case 'extreme-harlequin':
        score += f.white * 25;
      case 'lilly-white':
      case 'frappuccino':
        score += f.white * 20;
    }

    // Blown-out or crushed exposure, and soft focus, are photo problems rather
    // than animal problems — penalise so the grade is not falsely confident.
    if (f.meanL < 0.12 || f.meanL > 0.88) score -= 18;
    if (f.sharp < 0.15) score -= 12;

    final clamped = score.round().clamp(8, 98);
    final rank = switch (clamped) {
      >= 78 => QualityRank.s,
      >= 62 => QualityRank.a,
      >= 44 => QualityRank.b,
      _ => QualityRank.c,
    };

    final reasons = <String>[
      if (f.contrast > 0.16) '명암 대비가 또렷합니다' else '대비가 약한 편입니다',
      if (f.sat > 0.35) '발색이 선명합니다' else if (f.sat < 0.2) '채도가 낮아 발색이 밋밋합니다',
      if (f.sharp > 0.35) '피부 텍스처가 선명하게 찍혔습니다',
      if (f.spots > 0.4) '달마시안 점 표현이 분명합니다',
      if (f.white > 0.3) '크림/화이트 커버리지가 넓습니다',
    ];

    return QualityGrade(score: clamped, rank: rank, reasons: reasons);
  }

  static PriceEstimate estimate(Morph? morph, QualityGrade quality) {
    final base = morph?.price ?? PriceBand.fallback;
    final (lo, hi) = _multipliers[quality.rank] ?? _multipliers[QualityRank.b]!;
    final min = (base.min * lo / 10000).round() * 10000;
    final max = (base.max * hi / 10000).round() * 10000;
    return PriceEstimate(
      min: min,
      max: max,
      mid: ((min + max) / 2 / 10000).round() * 10000,
      note: '2026년 한국 분양 시장 대략 시세. 베이비/성체, 성별, 혈통, 브리더에 따라 크게 달라집니다.',
    );
  }
}

/// Formats won with thousands separators, e.g. `1,250,000원`.
/// Ported from `formatWon()`.
String formatWon(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  buffer.write('원');
  return buffer.toString();
}

/// Compact won formatting for tight spaces, e.g. `125만원`.
String formatWonShort(int value) {
  if (value >= 100000000) {
    final eok = value / 100000000;
    return '${_trim(eok)}억원';
  }
  if (value >= 10000) {
    final man = value / 10000;
    return '${_trim(man)}만원';
  }
  return formatWon(value);
}

String _trim(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

/// Rarity label for the 1–5 scale used by the catalog.
String rarityLabel(int rarity) => switch (rarity) {
  >= 5 => '매우 희귀',
  4 => '희귀',
  3 => '보통 이상',
  2 => '흔함',
  _ => '매우 흔함',
};

/// Guards against divide-by-zero when normalising bars.
double safeRatio(num value, num total) =>
    total == 0 ? 0 : math.min(1, value / total);
