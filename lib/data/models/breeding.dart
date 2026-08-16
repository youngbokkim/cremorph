import '../morph_catalog.dart';
import 'morph.dart';

/// A parent's genotype going into the breeding calculator.
/// Ported from the object returned by `emptyProfile()` in `js/engine.js`.
class BreedingProfile {
  BreedingProfile({
    required this.genes,
    required this.traits,
    required this.label,
    this.morphId,
  });

  /// All loci zeroed out — a plain wild type.
  factory BreedingProfile.empty() => BreedingProfile(
    genes: {for (final k in GeneKey.all) k: 0},
    traits: {for (final k in TraitKey.all) k: 0.0},
    label: '노멀',
  );

  /// Builds a profile from a catalog morph (`morphToProfile()`).
  factory BreedingProfile.fromMorph(Morph morph) {
    final profile = BreedingProfile.empty();
    profile.genes.addAll(morph.genes);
    profile.traits.addAll(morph.traits);
    return BreedingProfile(
      genes: profile.genes,
      traits: profile.traits,
      label: morph.nameKo,
      morphId: morph.id,
    );
  }

  final Map<String, int> genes;
  final Map<String, double> traits;
  final String label;
  final String? morphId;

  int gene(String key) => genes[key] ?? 0;

  double trait(String key) => traits[key] ?? 0;

  /// Adds a het (single copy) on top of this profile without downgrading a
  /// visual that is already present.
  BreedingProfile withHet(String? geneKey) {
    if (geneKey == null) return this;
    final meta = geneMeta[geneKey];
    if (meta == null) return this;
    final current = gene(geneKey);
    if (current >= 1) return this;
    return BreedingProfile(
      genes: {...genes, geneKey: 1},
      traits: traits,
      label: '$label + ${meta.labels[1]}',
      morphId: morphId,
    );
  }
}

/// Severity of a breeding warning.
enum WarningLevel { danger, warn }

/// A caution shown above the offspring list.
class BreedingWarning {
  const BreedingWarning({
    required this.level,
    required this.title,
    required this.text,
  });

  final WarningLevel level;
  final String title;
  final String text;
}

/// One predicted offspring outcome.
class OffspringOutcome {
  const OffspringOutcome({
    required this.name,
    required this.percent,
    required this.imageId,
    this.detail = '',
    this.lethal = false,
    this.caution = false,
    this.genes = const {},
  });

  final String name;

  /// Probability as a percentage, rounded to one decimal.
  final double percent;

  /// Catalog id whose bundled photo best represents this outcome.
  final String imageId;

  final String detail;

  /// Two copies of Lilly White — does not survive.
  final bool lethal;

  /// Two copies of Cappuccino — health risks.
  final bool caution;

  final Map<String, int> genes;

  String get imagePath => morphImagePath(imageId);
}

/// Result of crossing two parents.
class BreedingResult {
  const BreedingResult({
    required this.parentA,
    required this.parentB,
    required this.warnings,
    required this.geneOutcomes,
    required this.patternOutcomes,
    required this.summary,
  });

  final String parentA;
  final String parentB;
  final List<BreedingWarning> warnings;

  /// Mendelian outcomes for the confirmed single-locus genes.
  final List<OffspringOutcome> geneOutcomes;

  /// Approximate forecast for the polygenic pattern traits.
  final List<OffspringOutcome> patternOutcomes;

  final String summary;
}
