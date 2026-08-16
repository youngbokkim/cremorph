import '../data/models/breeding.dart';
import '../data/models/morph.dart';
import '../data/morph_catalog.dart';

/// Crested gecko inheritance rules, ported from `js/engine.js`.
///
/// Confirmed genes (Lilly White, Axanthic, Phantom, Cappuccino) are resolved
/// with real Punnett squares. Pattern traits such as harlequin, pinstripe and
/// dalmatian are polygenic, so those percentages are deliberately approximate —
/// the same caveat the web version shows in its footer.
abstract final class Genetics {
  /// Copy-count outcomes for one locus.
  ///
  /// A parent with `copies` alleles contributes the gamete pair returned by
  /// [_gametes]; crossing the two pairs gives the 4-cell Punnett square.
  static List<({int copies, double p})> punnett(int copiesA, int copiesB) {
    final a = _gametes(copiesA);
    final b = _gametes(copiesB);
    final counts = <int, int>{0: 0, 1: 0, 2: 0};
    for (final x in a) {
      for (final y in b) {
        counts[x + y] = counts[x + y]! + 1;
      }
    }
    return [
      for (final k in const [0, 1, 2])
        if (counts[k]! > 0) (copies: k, p: counts[k]! / 4),
    ];
  }

  /// The two alleles a parent can pass on for a locus.
  static List<int> _gametes(int copies) => switch (copies) {
    <= 0 => const [0, 0],
    1 => const [1, 0],
    _ => const [1, 1],
  };

  /// Expands per-locus outcomes into every whole-genotype combination with its
  /// joint probability. Ported from `combineLoci()`.
  static List<({Map<String, int> genes, double p})> combineLoci(
    Map<String, List<({int copies, double p})>> locusMap,
  ) {
    var combos = <({Map<String, int> genes, double p})>[
      (genes: const <String, int>{}, p: 1),
    ];
    for (final entry in locusMap.entries) {
      final next = <({Map<String, int> genes, double p})>[];
      for (final combo in combos) {
        for (final outcome in entry.value) {
          next.add((
            genes: {...combo.genes, entry.key: outcome.copies},
            p: combo.p * outcome.p,
          ));
        }
      }
      combos = next;
    }
    return combos;
  }

  /// Names the phenotype a genotype produces. Ported from `phenotypeName()`.
  static OffspringOutcome phenotype(
    Map<String, int> genes, {
    Map<String, double> traits = const {},
    double percent = 0,
  }) {
    if ((genes[GeneKey.lillyWhite] ?? 0) == 2) {
      return OffspringOutcome(
        name: '슈퍼 릴리 화이트',
        percent: percent,
        imageId: 'lilly-white',
        detail: '치사 유전자. 부화해도 대부분 며칠 내 폐사합니다. 릴리끼리 교배는 하지 마세요.',
        lethal: true,
        genes: genes,
      );
    }

    final lw = genes[GeneKey.lillyWhite] ?? 0;
    final ax = genes[GeneKey.axanthic] ?? 0;
    final ph = genes[GeneKey.phantom] ?? 0;
    final cap = genes[GeneKey.cappuccino] ?? 0;

    final parts = <String>[];

    // Confirmed-gene combos, most specific first.
    if (lw == 1 && cap == 1 && ax == 2) {
      parts.add('프라푸치노 아잔틱');
    } else if (lw == 1 && cap == 1 && ph == 2) {
      parts.add('팬텀 프라푸치노');
    } else if (lw == 1 && cap == 1) {
      parts.add('프라푸치노');
    } else if (lw == 1 && ax == 2) {
      parts.add('릴리 아잔틱');
    } else if (lw == 1 && ph == 2) {
      parts.add('팬텀 릴리');
    } else if (cap == 2) {
      parts.add('슈퍼 카푸치노');
    } else if (cap == 1 && ph == 2) {
      parts.add('팬텀 카푸치노');
    } else if (cap == 1 && ax == 2) {
      parts.add('카푸치노 아잔틱');
    } else if (lw == 1) {
      parts.add('릴리 화이트');
    } else if (cap == 1) {
      parts.add('카푸치노');
    } else if (ax == 2) {
      parts.add('아잔틱');
    } else if (ph == 2) {
      parts.add('팬텀');
    }

    double t(String key) => traits[key] ?? 0;

    if (t(TraitKey.halloween) > 0.55) {
      parts.add('할로윈');
    } else if (t(TraitKey.tricolor) > 0.55) {
      parts.add('트라이컬러');
    } else if (t(TraitKey.creamsicle) > 0.55) {
      parts.add('크림시클');
    } else if (t(TraitKey.extreme) > 0.7 || t(TraitKey.harlequin) > 0.85) {
      parts.add('익스트림 할리퀸');
    } else if (t(TraitKey.harlequin) > 0.45) {
      parts.add('할리퀸');
    } else if (t(TraitKey.flame) > 0.5) {
      parts.add('플레임');
    }
    if (t(TraitKey.pinstripe) > 0.5) parts.add('핀스트라이프');
    if (t(TraitKey.dalmatian) > 0.85) {
      parts.add('슈퍼 달마시안');
    } else if (t(TraitKey.dalmatian) > 0.4) {
      parts.add('달마시안');
    }
    if (t(TraitKey.tiger) > 0.5 && t(TraitKey.halloween) < 0.55) {
      parts.add('타이거');
    }

    if (ax == 1) parts.add('100% het 아잔틱');
    if (ph == 1) parts.add('100% het 팬텀');

    final unique = parts.toSet().toList();
    final name = unique.isEmpty ? '노멀 (유전자 비발현)' : unique.join(' · ');

    return OffspringOutcome(
      name: name,
      percent: percent,
      imageId: _pickImage(genes, traits, unique),
      detail: cap == 2 ? '슈퍼 카푸치노(멜라니스틱)는 콧구멍·척추 기형 위험이 큽니다.' : '',
      caution: cap == 2,
      genes: genes,
    );
  }

  /// Chooses the most representative bundled photo. Ported from `pickImage()`.
  static String _pickImage(
    Map<String, int> genes,
    Map<String, double> traits,
    List<String> parts,
  ) {
    final joined = parts.join(' ');
    if (joined.contains('프라푸치노')) return 'frappuccino';
    if (joined.contains('릴리 아잔틱')) return 'lilly-axanthic';
    if (joined.contains('팬텀 릴리')) return 'phantom-lilly';
    if (joined.contains('슈퍼 카푸')) return 'cappuccino';

    if ((genes[GeneKey.lillyWhite] ?? 0) == 1) return 'lilly-white';
    if ((genes[GeneKey.cappuccino] ?? 0) >= 1) return 'cappuccino';
    if ((genes[GeneKey.axanthic] ?? 0) == 2) return 'axanthic';
    if ((genes[GeneKey.phantom] ?? 0) == 2) return 'phantom';

    double t(String key) => traits[key] ?? 0;
    if (t(TraitKey.halloween) > 0.55) return 'halloween';
    if (t(TraitKey.tricolor) > 0.55) return 'tricolor';
    if (t(TraitKey.creamsicle) > 0.55) return 'creamsicle';
    if (t(TraitKey.dalmatian) > 0.85) return 'super-dalmatian';
    if (t(TraitKey.dalmatian) > 0.4) return 'dalmatian';
    if (t(TraitKey.pinstripe) > 0.5) return 'pinstripe';
    if (t(TraitKey.extreme) > 0.7) return 'extreme-harlequin';
    if (t(TraitKey.harlequin) > 0.45) return 'harlequin';
    if (t(TraitKey.flame) > 0.5) return 'flame';
    if (t(TraitKey.tiger) > 0.5) return 'tiger';
    return 'normal';
  }

  /// Approximate pattern outcomes. Ported from `patternForecast()`.
  ///
  /// These are hand-tuned heuristics, not Mendelian ratios — pattern traits are
  /// polygenic and shaped by selective breeding.
  static List<OffspringOutcome> patternForecast(
    BreedingProfile a,
    BreedingProfile b,
  ) {
    final rows = <OffspringOutcome>[];

    void push(String name, double p, String imageId, String note) {
      if (p <= 0.02) return;
      rows.add(
        OffspringOutcome(
          name: name,
          percent: (p * 1000).round() / 10,
          imageId: imageId,
          detail: note,
        ),
      );
    }

    double avg(String k) => (a.trait(k) + b.trait(k)) / 2;
    bool any(String k) => a.trait(k) > 0.2 || b.trait(k) > 0.2;
    bool both(String k) => a.trait(k) > 0.35 && b.trait(k) > 0.35;

    if (any(TraitKey.harlequin) ||
        any(TraitKey.extreme) ||
        any(TraitKey.flame)) {
      if (both(TraitKey.extreme) || avg(TraitKey.extreme) > 0.7) {
        push(
          '익스트림 할리퀸',
          0.45,
          'extreme-harlequin',
          '양쪽 커버리지가 높아 고퀄 패턴 확률이 큽니다.',
        );
        push('할리퀸', 0.4, 'harlequin', '');
        push('플레임 / 약한 패턴', 0.15, 'flame', '다지성이라 약하게 빠지는 개체도 나옵니다.');
      } else if (both(TraitKey.harlequin) || avg(TraitKey.harlequin) > 0.5) {
        push('할리퀸', 0.55, 'harlequin', '다지성 — 정확한 멘델 비율은 아닙니다.');
        push('익스트림 할리퀸', 0.18, 'extreme-harlequin', '운 좋게 커버리지가 더 쌓인 경우');
        push('플레임', 0.2, 'flame', '');
        push('약한 패턴 / 노멀', 0.07, 'normal', '');
      } else if (any(TraitKey.flame) || any(TraitKey.harlequin)) {
        push('플레임 또는 약한 할리퀸', 0.5, 'flame', '한쪽만 패턴을 가진 경우의 대략치');
        push('할리퀸', 0.22, 'harlequin', '');
        push('무늬 거의 없음', 0.28, 'normal', '');
      }
    }

    if (any(TraitKey.pinstripe)) {
      push(
        '핀스트라이프',
        both(TraitKey.pinstripe) ? 0.82 : 0.52,
        'pinstripe',
        '핀은 한 쪽만 있어도 절반 가까이 나오는 편입니다.',
      );
    }
    if (any(TraitKey.dalmatian)) {
      final superish = avg(TraitKey.dalmatian) > 0.8;
      push(
        superish ? '슈퍼 달마시안' : '달마시안',
        both(TraitKey.dalmatian) ? 0.78 : 0.48,
        superish ? 'super-dalmatian' : 'dalmatian',
        '점 밀도는 선발로 강해집니다.',
      );
    }
    if (any(TraitKey.halloween)) {
      push(
        '할로윈 (블랙+오렌지)',
        both(TraitKey.halloween) ? 0.7 : 0.35,
        'halloween',
        '노랑·크림이 섞이면 할로윈으로 안 칩니다.',
      );
    }
    if (any(TraitKey.creamsicle)) {
      push(
        '크림시클',
        both(TraitKey.creamsicle) ? 0.62 : 0.32,
        'creamsicle',
        '오렌지 발색은 개체 차가 큽니다.',
      );
    }
    if (any(TraitKey.tricolor)) {
      push(
        '트라이컬러',
        both(TraitKey.tricolor) ? 0.5 : 0.25,
        'tricolor',
        '세 색이 동시에 선명해야 트라이로 봅니다.',
      );
    }
    if (any(TraitKey.tiger)) {
      push('타이거 / 브린들', both(TraitKey.tiger) ? 0.65 : 0.4, 'tiger', '');
    }

    rows.sort((x, y) => y.percent.compareTo(x.percent));
    return rows;
  }

  /// Crosses two parents. Ported from `breed()`.
  static BreedingResult breed(BreedingProfile a, BreedingProfile b) {
    final locusMap = <String, List<({int copies, double p})>>{};
    for (final key in GeneKey.all) {
      final ca = a.gene(key);
      final cb = b.gene(key);
      if (ca > 0 || cb > 0) locusMap[key] = punnett(ca, cb);
    }

    final warnings = <BreedingWarning>[];
    if (a.gene(GeneKey.lillyWhite) >= 1 && b.gene(GeneKey.lillyWhite) >= 1) {
      warnings.add(
        const BreedingWarning(
          level: WarningLevel.danger,
          title: '릴리 화이트 × 릴리 화이트',
          text: '슈퍼 릴리 화이트가 25% 나옵니다. 치사 조합이라 브리더들은 이 교배를 하지 않습니다.',
        ),
      );
    }
    if (a.gene(GeneKey.cappuccino) >= 1 && b.gene(GeneKey.cappuccino) >= 1) {
      warnings.add(
        const BreedingWarning(
          level: WarningLevel.warn,
          title: '카푸치노 × 카푸치노',
          text: '슈퍼 카푸치노(멜라니스틱)가 25%입니다. 호흡기·척추 기형 보고가 있어 권장하지 않습니다.',
        ),
      );
    }

    final geneOutcomes = <OffspringOutcome>[];
    if (locusMap.isEmpty) {
      geneOutcomes.add(
        phenotype({for (final k in GeneKey.all) k: 0}, percent: 100),
      );
    } else {
      // Different genotypes can share a phenotype name (e.g. het carriers), so
      // merge on the label and sum the probabilities.
      final merged = <String, OffspringOutcome>{};
      for (final combo in combineLoci(locusMap)) {
        final outcome = phenotype(combo.genes, percent: combo.p * 100);
        final existing = merged[outcome.name];
        merged[outcome.name] = existing == null
            ? outcome
            : OffspringOutcome(
                name: existing.name,
                percent: existing.percent + outcome.percent,
                imageId: existing.imageId,
                detail: existing.detail,
                lethal: existing.lethal,
                caution: existing.caution,
                genes: existing.genes,
              );
      }
      for (final row in merged.values) {
        geneOutcomes.add(
          OffspringOutcome(
            name: row.name,
            percent: (row.percent * 10).round() / 10,
            imageId: row.imageId,
            detail: row.detail,
            lethal: row.lethal,
            caution: row.caution,
            genes: row.genes,
          ),
        );
      }
      geneOutcomes.sort((x, y) => y.percent.compareTo(x.percent));
    }

    return BreedingResult(
      parentA: a.label,
      parentB: b.label,
      warnings: warnings,
      geneOutcomes: geneOutcomes,
      patternOutcomes: patternForecast(a, b),
      summary: _summary(a, b, geneOutcomes, warnings),
    );
  }

  /// Ported from `buildSummary()`.
  static String _summary(
    BreedingProfile a,
    BreedingProfile b,
    List<OffspringOutcome> outcomes,
    List<BreedingWarning> warnings,
  ) {
    final buffer = StringBuffer('${a.label} × ${b.label} 교배입니다. ');
    if (outcomes.isNotEmpty) {
      final top = outcomes.first;
      buffer.write('가장 많이 나오는 표현형은 「${top.name}」약 ${_pct(top.percent)}%입니다. ');
    }
    if (warnings.isNotEmpty) {
      buffer.write(warnings.map((w) => w.text).join(' '));
    } else {
      buffer.write('확정 유전자는 멘델 비율로, 할리퀸·핀·달마 같은 패턴은 다지성이라 확률은 대략치입니다.');
    }
    return buffer.toString();
  }

  static String _pct(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}

/// Formats a percentage the way the UI shows it: `25` not `25.0`.
String formatPercent(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

/// Convenience for building a profile from a morph id.
BreedingProfile profileForMorphId(String id) {
  final morph = getMorph(id);
  return morph == null
      ? BreedingProfile.empty()
      : BreedingProfile.fromMorph(morph);
}

/// Convenience for building a profile from a [Morph].
BreedingProfile profileFor(Morph morph) => BreedingProfile.fromMorph(morph);
